extends Node
## ============================================================
##  OnlineService — Personne C
##  Liaison HTTPS entre le jeu (navigateur ou PC) et Supabase.
##
##  Contrat d'équipe :
##   A -> C : appeler submit_sort(item_id, selected_bin, reaction_ms)
##            (Main.gd branche automatiquement le signal sort_completed de A)
##   C -> B : signal global_progress_changed(ocean_percent)  (0 à 100)
## ============================================================

signal global_progress_changed(ocean_percent: float)
signal stats_updated(stats: Dictionary)
signal connection_changed(online: bool)
signal sort_result(item_id: String, is_correct: bool, correct_bin: String)

# ====== À REMPLIR : Supabase > Project Settings > API Keys ======
# Uniquement la clé PUBLIQUE (« publishable » sb_publishable_… ou l'ancienne « anon »).
# Ne JAMAIS mettre la clé secrète / service_role : le jeu web est public.
const SUPABASE_URL := "https://aqkvatlviikgoowhqbur.supabase.co"
const SUPABASE_KEY := "sb_publishable_cZujiLIhESaQ5Nq9ym_rhw_xgyVvP-p"
const POLL_INTERVAL := 2.5          # secondes entre deux lectures de l'océan global
const MAX_QUEUE := 50               # tris gardés en attente si le réseau tombe

var session_id: String = ""
var online: bool = false
var last_sync_msec: int = -1
var rtt_ms: int = -1
var stats: Dictionary = {}
var ocean_percent: float = -1.0
var last_error: String = ""
var verified_5g: bool = false       # activé à la main (F9) uniquement après vérification réelle
var schema_v2: bool = true          # passe à false si la migration 002 n'est pas encore appliquée
var _stats_rpc: String = "get_ocean_stats_v2"

var _queue: Array = []
var _current: Dictionary = {}
var _http_submit: HTTPRequest
var _http_poll: HTTPRequest
var _submit_busy: bool = false
var _poll_busy: bool = false
var _submit_sent_at: int = 0
var _poll_sent_at: int = 0

# Version web : on passe par fetch() du navigateur (Godot web décompresse
# à tort les réponses gzip déjà décompressées par le navigateur).
const JS_HELPER := """
window.btFetch = function (url, key, body, cb) {
  fetch(url, {method: 'POST', headers: {'Content-Type': 'application/json', 'apikey': key}, body: body})
    .then(function (r) { return r.text().then(function (t) { cb(r.status, t); }); })
    .catch(function (e) { cb(0, String(e)); });
};
"""
var _is_web: bool = false
var _js_win = null
var _cb_submit = null
var _cb_poll = null


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	session_id = "player-%06x" % rng.randi_range(0, 0xFFFFFF)

	_is_web = OS.has_feature("web")
	if _is_web:
		JavaScriptBridge.eval(JS_HELPER, true)
		_js_win = JavaScriptBridge.get_interface("window")
		_cb_submit = JavaScriptBridge.create_callback(_on_js_submit)
		_cb_poll = JavaScriptBridge.create_callback(_on_js_poll)

	_http_submit = HTTPRequest.new()
	_http_submit.timeout = 8.0
	# Web : le navigateur décompresse déjà les réponses ; Godot ne doit pas le refaire
	_http_submit.accept_gzip = false
	add_child(_http_submit)
	_http_submit.request_completed.connect(_on_submit_done)

	_http_poll = HTTPRequest.new()
	_http_poll.timeout = 8.0
	_http_poll.accept_gzip = false
	add_child(_http_poll)
	_http_poll.request_completed.connect(_on_poll_done)

	var timer := Timer.new()
	timer.wait_time = POLL_INTERVAL
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(poll_now)
	poll_now()


func is_configured() -> bool:
	return SUPABASE_URL.begins_with("https://") and not SUPABASE_URL.contains("VOTRE-PROJET") \
		and not SUPABASE_KEY.begins_with("COLLER_ICI")


func seconds_since_sync() -> float:
	if last_sync_msec < 0:
		return -1.0
	return float(Time.get_ticks_msec() - last_sync_msec) / 1000.0


func pending_count() -> int:
	return _queue.size()


func _headers() -> PackedStringArray:
	var h := PackedStringArray(["Content-Type: application/json", "apikey: " + SUPABASE_KEY])
	# L'ancienne clé « anon » est un JWT : elle va aussi dans Authorization.
	if SUPABASE_KEY.begins_with("eyJ"):
		h.append("Authorization: Bearer " + SUPABASE_KEY)
	return h


# ---------------------------------------------------------------
#  Envoi d'un tri (appelé par le jeu)
# ---------------------------------------------------------------
## Contrat historique (5 anciens bacs cotton/polyester/pet/mixed/reject) : conservé tel quel.
func submit_sort(item_id: String, selected_bin: String, reaction_ms: int) -> void:
	_enqueue("submit_sort", {
		"p_session_id": session_id,
		"p_item_id": item_id,
		"p_selected_bin": selected_bin,
		"p_reaction_ms": maxi(reaction_ms, 0),
	})


## THE LAST BLUE : 5 bacs paper/textile/pet/residual/special + identifiant du niveau.
func submit_sort_v2(item_id: String, selected_bin: String, reaction_ms: int, level_id: String) -> void:
	_enqueue("submit_sort_v2", {
		"p_session_id": session_id,
		"p_level_id": level_id,
		"p_item_id": item_id,
		"p_selected_bin": selected_bin,
		"p_reaction_ms": maxi(reaction_ms, 0),
	})


## Fin de niveau (comptée une seule fois par session et par niveau, côté serveur).
func complete_level_v2(level_id: String) -> void:
	_enqueue("complete_level_v2", {"p_session_id": session_id, "p_level_id": level_id})


func _enqueue(rpc_name: String, body: Dictionary) -> void:
	body["_rpc"] = rpc_name
	_queue.append(body)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()
	_flush()


func _body_of(entry: Dictionary) -> String:
	var b: Dictionary = entry.duplicate()
	b.erase("_rpc")
	return JSON.stringify(b)


func _flush() -> void:
	if _submit_busy or _queue.is_empty() or not is_configured():
		return
	_current = _queue[0]
	_submit_busy = true
	_submit_sent_at = Time.get_ticks_msec()
	var url: String = SUPABASE_URL + "/rest/v1/rpc/" + String(_current.get("_rpc", "submit_sort"))
	if _is_web:
		_js_win.btFetch(url, SUPABASE_KEY, _body_of(_current), _cb_submit)
		return
	var err: int = _http_submit.request(url, _headers(), HTTPClient.METHOD_POST, _body_of(_current))
	if err != OK:
		_submit_busy = false
		last_error = "Requête impossible (code %d)" % err
		_set_online(false)


func _on_js_submit(args: Array) -> void:
	_after_submit(int(args[0]) > 0, int(args[0]), str(args[1]))


func _on_submit_done(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	_after_submit(result == HTTPRequest.RESULT_SUCCESS, code, body.get_string_from_utf8())


func _after_submit(net_ok: bool, code: int, text: String) -> void:
	_submit_busy = false
	if net_ok and code >= 200 and code < 300:
		rtt_ms = Time.get_ticks_msec() - _submit_sent_at
		_queue.pop_front()
		_set_online(true)
		var data = JSON.parse_string(text)
		if data is Dictionary and data.has("is_correct"):
			sort_result.emit(String(_current.get("p_item_id", "")), bool(data.get("is_correct", false)), String(data.get("correct_bin", "")))
		poll_now()
		_flush()
	elif net_ok and code >= 400 and code < 500:
		# Le serveur a refusé ce tri (objet inconnu, anti-spam, clé invalide) : on l'abandonne.
		last_error = "Refusé par le serveur (%d) : %s" % [code, text.left(120)]
		push_warning("submit_sort " + last_error)
		_queue.pop_front()
		if code == 401 or code == 403:
			_set_online(false)
		_flush()
	else:
		# Réseau coupé : on garde le tri en file, il repartira au prochain cycle.
		last_error = "Réseau indisponible (HTTP %d) %s" % [code, text.left(80)]
		_set_online(false)


# ---------------------------------------------------------------
#  Lecture de l'océan global (toutes les 2,5 s)
# ---------------------------------------------------------------
func poll_now() -> void:
	if not is_configured():
		last_error = "Supabase non configuré (voir OnlineService.gd)"
		_set_online(false)
		return
	if not _queue.is_empty() and not _submit_busy:
		_flush()
	if _poll_busy:
		return
	_poll_busy = true
	_poll_sent_at = Time.get_ticks_msec()
	var url: String = SUPABASE_URL + "/rest/v1/rpc/" + _stats_rpc
	if _is_web:
		_js_win.btFetch(url, SUPABASE_KEY, "{}", _cb_poll)
		return
	var err: int = _http_poll.request(url, _headers(), HTTPClient.METHOD_POST, "{}")
	if err != OK:
		_poll_busy = false
		last_error = "Requête impossible (code %d)" % err
		_set_online(false)


func _on_js_poll(args: Array) -> void:
	_after_poll(int(args[0]) > 0, int(args[0]), str(args[1]))


func _on_poll_done(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	_after_poll(result == HTTPRequest.RESULT_SUCCESS, code, body.get_string_from_utf8())


func _after_poll(net_ok: bool, code: int, text: String) -> void:
	_poll_busy = false
	if net_ok and code >= 200 and code < 300:
		var data = JSON.parse_string(text)
		if data is Dictionary:
			rtt_ms = Time.get_ticks_msec() - _poll_sent_at
			last_sync_msec = Time.get_ticks_msec()
			last_error = ""
			stats = data
			_set_online(true)
			var p: float = float(data.get("ocean_percent", 0))
			if not is_equal_approx(p, ocean_percent):
				ocean_percent = p
				global_progress_changed.emit(p)
			stats_updated.emit(stats)
			return
	if net_ok and code == 404 and _stats_rpc == "get_ocean_stats_v2":
		# Migration 002 pas encore appliquée : on lit l'ancien océan en attendant.
		schema_v2 = false
		_stats_rpc = "get_ocean_stats"
		last_error = "Migration 002 absente : statistiques v1"
		poll_now()
		return
	last_error = "Lecture impossible (HTTP %d) %s" % [code, text.left(120)]
	_set_online(false)


func _set_online(v: bool) -> void:
	if v != online:
		online = v
		connection_changed.emit(v)
