class_name Voice
## Voix off (lecture à voix haute des répliques) via la synthèse vocale
## du système : DisplayServer.tts_* (Windows : voix SAPI/OneCore ;
## navigateur : Web Speech API). Aucune voix n'est enregistrée ni générée
## par le projet : le timbre dépend de l'appareil / du navigateur du joueur.
## Si aucune voix n'est disponible, le jeu fonctionne exactement comme avant
## (sous-titres seuls). Touche V : couper / remettre la voix.

static var enabled: bool = true
static var _picked: bool = false
static var _ids: Dictionary = {}          # rôle -> id de voix
static var _busy: bool = false
static var _started_ms: int = 0
static var _expected_ms: int = 0

const FEMALE := ["aria", "jenny", "zira", "female", "samantha", "hazel", "susan", "libby",
	"sonia", "natasha", "karen", "moira", "tessa", "fiona", "victoria", "emma", "michelle",
	"ava", "allison", "ana", "clara", "maisie", "joanna", "salli", "kimberly", "serena"]
const MALE := ["david", "mark", "guy", "male", "daniel", "george", "ryan", "alex", "fred",
	"christopher", "eric", "brian", "james", "andrew", "roger", "steffan", "thomas", "william",
	"matthew", "liam", "arthur", "oliver"]

## [hauteur, débit, volume] par rôle
const STYLE := {
	"NARRATOR": [0.92, 0.9, 85],
	"MIMA": [0.85, 0.82, 90],
	"BOY": [1.35, 1.0, 85],
	"OTHER": [1.0, 0.95, 85],
}


static func _feature_on() -> bool:
	return enabled and bool(ProjectSettings.get_setting("audio/general/text_to_speech", false))


static func _score(v: Dictionary, wanted: Array) -> int:
	var n: String = String(v.get("name", "")).to_lower()
	var lang: String = String(v.get("language", "")).to_lower()
	var s: int = 0
	for w in wanted:
		if n.contains(w):
			s += 10
			break
	if n.contains("natural") or n.contains("online") or n.contains("neural"):
		s += 6
	elif n.contains("google"):
		s += 4
	if lang.begins_with("en_gb") or lang.begins_with("en-gb"):
		s += 2
	elif lang.begins_with("en"):
		s += 1
	return s


static func _best(voices: Array, wanted: Array) -> String:
	var best: String = ""
	var best_s: int = -1
	for v in voices:
		var s := _score(v, wanted)
		if s > best_s:
			best_s = s
			best = String(v.get("id", ""))
	return best


## Choisit une voix par rôle (les voix du navigateur arrivent parfois en
## retard : on réessaie tant que la liste est vide).
static func _pick() -> void:
	if _picked:
		return
	var all: Array = DisplayServer.tts_get_voices()
	var en: Array = []
	for v in all:
		if String(v.get("language", "")).to_lower().begins_with("en"):
			en.append(v)
	if en.is_empty():
		en = all
	if en.is_empty():
		return
	_picked = true
	var fem := _best(en, FEMALE)
	var mal := _best(en, MALE)
	_ids["MIMA"] = fem
	_ids["NARRATOR"] = mal
	_ids["BOY"] = fem if fem != "" else mal   # voix claire, plus aiguë
	_ids["OTHER"] = mal


static func available() -> bool:
	if not _feature_on():
		return false
	_pick()
	return _picked


static func _role(who: String) -> String:
	match who:
		"MIMA":
			return "MIMA"
		"NARRATOR":
			return "NARRATOR"
		"PLAYER", "YASSINE", "GRANDSON", "BOY":
			return "BOY"
	return "OTHER"


static func _clean(text: String) -> String:
	var t := text.replace("—", ", ").replace("“", "").replace("”", "").replace("·", ",")
	t = t.replace("O2", "oxygen")
	if t == t.to_upper():
		t = t.to_lower()        # titres en capitales : éviter l'épellation
	return t


## Lit une réplique (coupe la précédente).
static func say(who: String, text: String) -> void:
	if not available():
		return
	var role := _role(who)
	var st: Array = STYLE[role]
	var t := _clean(text)
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(t, String(_ids.get(role, "")), int(st[2]), float(st[0]), float(st[1]), 0, true)
	_busy = true
	_started_ms = Time.get_ticks_msec()
	# garde-fou : environ 13 caractères par seconde à débit 1
	_expected_ms = int(1500.0 + t.length() * 78.0 / float(st[1]))


## Vrai tant que la phrase est en cours de lecture.
static func speaking() -> bool:
	if not _busy:
		return false
	var el: int = Time.get_ticks_msec() - _started_ms
	if el > _expected_ms + 2500:
		_busy = false
		return false
	if el < 600:
		return true                 # la synthèse peut démarrer avec un léger retard
	if not DisplayServer.tts_is_speaking():
		_busy = false
		return false
	return true


static func stop() -> void:
	_busy = false
	if _feature_on():
		DisplayServer.tts_stop()


static func toggle() -> bool:
	enabled = not enabled
	if not enabled:
		_busy = false
		if bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)):
			DisplayServer.tts_stop()
	return enabled
