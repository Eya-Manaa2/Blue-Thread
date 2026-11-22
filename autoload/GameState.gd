extends Node
## ============================================================
##  GameState — BLUE THREAD: THE LAST BLUE
##  Profil joueur (nom + avatar), score, cœurs, oxygène, inventaire réel
##  par niveau, restauration LOCALE (histoire) et sauvegarde user://.
##
##  Contrat d'équipe conservé :
##   signal sort_completed(item_id, selected_bin, reaction_ms)
##   -> Main.gd le branche sur OnlineService (submit_sort_v2 + niveau).
##  La restauration LOCALE (0/33/67/100) est distincte de la valeur
##  GLOBALE du serveur (OnlineService.ocean_percent).
##  Rien de personnel n'est envoyé au serveur : le nom reste sur l'appareil.
## ============================================================

signal sort_completed(item_id: String, selected_bin: String, reaction_ms: int)
signal score_changed(score: int, delta: int, reason: String)
signal hearts_changed(hearts: int)
signal air_changed(air: float)
signal restoration_changed(percent: float)
signal heart_lost(reason: String)
signal out_of_hearts
signal profile_changed

const SAVE_PATH := "user://blue_thread_save.cfg"
const MAX_HEARTS := 3
const MAX_AIR := 100.0
const AIR_DRAIN := 1.0             # règle stricte : 1 unité d'oxygène par seconde d'exploration
const AIR_DRAIN_DEMO := 1.0        # même règle en mode jury

const PTS_SORT_OK := 10
const PTS_SORT_BAD := -5
const PTS_COLLECT := 10
const PTS_STEP := 15

var score: int = 0
var hearts: int = MAX_HEARTS
var air: float = MAX_AIR
var local_restoration: float = 0.0      # 0..100, histoire
var current_level: String = ""
var demo_mode: bool = false
var rewards: Array = []
var completed: Array = []
var inventory: Dictionary = {}          # level_id -> [item_id, ...] (objets UTILES réellement ramassés)
var stats: Dictionary = {}
var player_name: String = ""
var avatar_id: int = -1
var portrait: Texture2D = null          # portrait de l'avatar (généré à la validation du profil)
var _level_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_inputs()
	reset_stats()
	load_game()


func reset_stats() -> void:
	stats = {"correct": 0, "wrong": 0, "collected": 0, "steps": 0, "hearts_lost": 0, "deaths": 0,
		"distractors": 0, "start_msec": Time.get_ticks_msec(), "per_level": {}}


func display_name() -> String:
	return player_name if player_name != "" else "Keeper"


# ------------------------------------------------------------ profil
## Nom : 2 à 20 caractères visibles, lettres (accents et arabe compris),
## espaces, apostrophes, tirets et points.
static func validate_name(raw: String) -> Dictionary:
	var n: String = raw.strip_edges()
	while n.contains("  "):
		n = n.replace("  ", " ")
	if n.length() < 2:
		return {"ok": false, "name": n, "error": "Please enter at least 2 characters."}
	if n.length() > 20:
		return {"ok": false, "name": n, "error": "20 characters maximum."}
	var letters := 0
	for i in n.length():
		var c: String = n[i]
		var code: int = n.unicode_at(i)
		var is_letter: bool = c.to_upper() != c.to_lower() or (code >= 0x0600 and code <= 0x06FF)
		if is_letter:
			letters += 1
		elif not (c == " " or c == "'" or c == "-" or c == "." or code == 0x2019):
			return {"ok": false, "name": n, "error": "Use letters, spaces, apostrophes or hyphens only."}
	if letters < 2:
		return {"ok": false, "name": n, "error": "Your name needs at least 2 letters."}
	return {"ok": true, "name": n, "error": ""}


func set_profile(name_in: String, avatar: int) -> void:
	player_name = name_in
	avatar_id = clampi(avatar, 0, GameData.AVATARS.size() - 1)
	save_game()
	profile_changed.emit()


func has_profile() -> bool:
	return player_name != "" and avatar_id >= 0


# ------------------------------------------------------------ partie
func new_game() -> void:
	score = 0
	hearts = MAX_HEARTS
	air = MAX_AIR
	rewards.clear()
	completed.clear()
	inventory.clear()
	current_level = ""
	reset_stats()
	set_local_restoration(0.0)
	score_changed.emit(score, 0, "")
	hearts_changed.emit(hearts)
	air_changed.emit(air)
	save_game()


func start_level(level_id: String) -> void:
	current_level = level_id
	var lv: Dictionary = GameData.level(level_id)
	hearts = MAX_HEARTS
	air = MAX_AIR
	inventory[level_id] = []
	set_local_restoration(float(lv.get("r_from", 0.0)))
	_level_snapshot = {"score": score, "correct": stats.correct, "wrong": stats.wrong,
		"collected": stats.collected, "steps": stats.steps, "msec": Time.get_ticks_msec()}
	hearts_changed.emit(hearts)
	air_changed.emit(air)
	save_game()


## Rejouer un niveau : on revient au score du début du niveau.
func restart_level() -> void:
	if not _level_snapshot.is_empty():
		score = int(_level_snapshot.score)
		stats.correct = int(_level_snapshot.correct)
		stats.wrong = int(_level_snapshot.wrong)
		stats.collected = int(_level_snapshot.collected)
		stats.steps = int(_level_snapshot.steps)
		score_changed.emit(score, 0, "")
	start_level(current_level)


func add_score(points: int, reason: String) -> void:
	score = maxi(0, score + points)
	score_changed.emit(score, points, reason)


func collect(item_id: String) -> void:
	stats.collected += 1
	if not inventory.has(current_level):
		inventory[current_level] = []
	(inventory[current_level] as Array).append(item_id)
	add_score(PTS_COLLECT, "collect")
	save_game()


func level_inventory(level_id: String) -> Array:
	return inventory.get(level_id, [])


func distractor_picked() -> void:
	stats.distractors += 1


func step_done(_step_id: String) -> void:
	stats.steps += 1
	add_score(PTS_STEP, "step")


## Tri d'un objet. Le résultat local est immédiat ; le serveur revérifie via OnlineService.
func sort_item(item_id: String, selected_bin: String, reaction_ms: int) -> Dictionary:
	var it: Dictionary = GameData.item(item_id)
	var correct_bin: String = String(it.get("bin", ""))
	var ok: bool = selected_bin == correct_bin
	if ok:
		stats.correct += 1
		add_score(PTS_SORT_OK, "sort_ok")
	else:
		stats.wrong += 1
		add_score(PTS_SORT_BAD, "sort_bad")
		lose_heart("wrong_sort")
	sort_completed.emit(item_id, selected_bin, reaction_ms)
	return {"ok": ok, "correct_bin": correct_bin, "tip": String(it.get("tip", ""))}


func lose_heart(reason: String) -> void:
	if demo_mode and hearts <= 1:
		heart_lost.emit(reason)       # mode jury : on montre l'effet sans bloquer la démo
		return
	hearts = maxi(0, hearts - 1)
	stats.hearts_lost += 1
	hearts_changed.emit(hearts)
	heart_lost.emit(reason)
	if hearts == 0:
		out_of_hearts.emit()


## Oxygène : exactement 1 unité par seconde (delta en secondes, indépendant du framerate).
## Renvoie true quand l'air vient d'atteindre zéro.
func drain_air(delta: float) -> bool:
	var rate: float = AIR_DRAIN_DEMO if demo_mode else AIR_DRAIN
	air = maxf(air - rate * delta, 0.0)
	air_changed.emit(air)
	return air <= 0.0


func refill_air(amount: float = MAX_AIR) -> void:
	air = clampf(amount, 0.0, MAX_AIR)
	air_changed.emit(air)


func set_local_restoration(p: float) -> void:
	local_restoration = clampf(p, 0.0, 100.0)
	restoration_changed.emit(local_restoration)


func complete_level(level_id: String) -> Dictionary:
	var lv: Dictionary = GameData.level(level_id)
	set_local_restoration(float(lv.get("r_to", 0.0)))
	if not completed.has(level_id):
		completed.append(level_id)
	var rw: String = String(lv.get("reward", ""))
	if rw != "" and not rewards.has(rw):
		rewards.append(rw)
	var snap: Dictionary = _level_snapshot
	var res := {
		"level": level_id,
		"score": score - int(snap.get("score", 0)),
		"total_score": score,
		"correct": int(stats.correct) - int(snap.get("correct", 0)),
		"wrong": int(stats.wrong) - int(snap.get("wrong", 0)),
		"collected": int(stats.collected) - int(snap.get("collected", 0)),
		"steps": int(stats.steps) - int(snap.get("steps", 0)),
		"hearts": hearts,
		"seconds": float(Time.get_ticks_msec() - int(snap.get("msec", Time.get_ticks_msec()))) / 1000.0,
	}
	res["stars"] = 1 + int(hearts >= 2) + int(res.wrong == 0 and hearts == MAX_HEARTS)
	stats.per_level[level_id] = res
	save_game()
	return res


func accuracy() -> float:
	var t: int = int(stats.correct) + int(stats.wrong)
	return 100.0 * float(stats.correct) / float(t) if t > 0 else 0.0


func play_seconds() -> float:
	return float(Time.get_ticks_msec() - int(stats.start_msec)) / 1000.0


# ------------------------------------------------------------ sauvegarde
## Prochain rivage à jouer (ou "ending" si tout est fini).
func next_level() -> String:
	for id in GameData.LEVEL_ORDER:
		if not completed.has(id):
			return id
	return "ending"


func has_progress() -> bool:
	return completed.size() > 0 and completed.size() < GameData.LEVEL_ORDER.size()


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("profile", "name", player_name)
	cf.set_value("profile", "avatar", avatar_id)
	cf.set_value("progress", "restoration", local_restoration)
	cf.set_value("progress", "completed", completed)
	cf.set_value("progress", "rewards", rewards)
	cf.set_value("progress", "score", score)
	cf.set_value("progress", "inventory", inventory)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	player_name = String(cf.get_value("profile", "name", ""))
	avatar_id = int(cf.get_value("profile", "avatar", -1))
	local_restoration = float(cf.get_value("progress", "restoration", 0.0))
	completed = cf.get_value("progress", "completed", [])
	rewards = cf.get_value("progress", "rewards", [])
	score = int(cf.get_value("progress", "score", 0))
	inventory = cf.get_value("progress", "inventory", {})


## Les actions clavier sont créées ici : project.godot n'a pas de carte d'entrées.
## Touches physiques : WASD en QWERTY = ZQSD en AZERTY, automatiquement.
func ensure_inputs() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			var exists := false
			for e in InputMap.action_get_events(action):
				if e is InputEventKey and (e as InputEventKey).physical_keycode == k:
					exists = true
			if not exists:
				InputMap.action_add_event(action, ev)
