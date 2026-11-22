extends Node
## ============================================================
##  GameState — BLUE THREAD: THE LAST BLUE
##  Score, cœurs, oxygène, restauration locale (histoire) et statistiques.
##
##  Contrat d'équipe conservé :
##   signal sort_completed(item_id, selected_bin, reaction_ms)
##   -> Main.gd le branche sur OnlineService (submit_sort_v2 + niveau).
##  La restauration LOCALE (0/33/67/100, progression de l'histoire) est
##  distincte de la valeur GLOBALE du serveur (OnlineService.ocean_percent).
## ============================================================

signal sort_completed(item_id: String, selected_bin: String, reaction_ms: int)
signal score_changed(score: int, delta: int, reason: String)
signal hearts_changed(hearts: int)
signal air_changed(air: float)
signal restoration_changed(percent: float)
signal heart_lost(reason: String)
signal out_of_hearts

const MAX_HEARTS := 3
const MAX_AIR := 100.0
const AIR_DRAIN := 0.45            # par seconde (le prompt demande 0,35 à 0,6)
const AIR_DRAIN_DEMO := 0.12

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
var stats: Dictionary = {}
var _level_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_inputs()
	reset_stats()


func reset_stats() -> void:
	stats = {"correct": 0, "wrong": 0, "collected": 0, "steps": 0, "hearts_lost": 0,
		"start_msec": Time.get_ticks_msec(), "per_level": {}}


func new_game() -> void:
	score = 0
	hearts = MAX_HEARTS
	air = MAX_AIR
	rewards.clear()
	completed.clear()
	reset_stats()
	set_local_restoration(0.0)
	score_changed.emit(score, 0, "")
	hearts_changed.emit(hearts)
	air_changed.emit(air)


func start_level(level_id: String) -> void:
	current_level = level_id
	var lv: Dictionary = GameData.level(level_id)
	hearts = MAX_HEARTS
	air = MAX_AIR
	set_local_restoration(float(lv.get("r_from", 0.0)))
	_level_snapshot = {"score": score, "correct": stats.correct, "wrong": stats.wrong,
		"collected": stats.collected, "steps": stats.steps, "msec": Time.get_ticks_msec()}
	hearts_changed.emit(hearts)
	air_changed.emit(air)


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
	add_score(PTS_COLLECT, "collect")


func step_done(step_id: String) -> void:
	stats.steps += 1
	add_score(PTS_STEP, "step")


## Tri d'un objet. Le résultat local est immédiat (jeu fluide hors ligne) ;
## le serveur revérifie de son côté via OnlineService.
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


func drain_air(delta: float) -> bool:
	## Renvoie true quand l'air vient d'atteindre zéro.
	var rate: float = AIR_DRAIN_DEMO if demo_mode else AIR_DRAIN
	air = maxf(0.0, air - rate * delta)
	air_changed.emit(air)
	return air <= 0.0


func refill_air() -> void:
	air = MAX_AIR
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
	return res


func accuracy() -> float:
	var t: int = int(stats.correct) + int(stats.wrong)
	return 100.0 * float(stats.correct) / float(t) if t > 0 else 0.0


func play_seconds() -> float:
	return float(Time.get_ticks_msec() - int(stats.start_msec)) / 1000.0


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
