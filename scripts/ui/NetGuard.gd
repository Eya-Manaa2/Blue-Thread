extends CanvasLayer
## ============================================================
##  NetGuard — jeu connecté obligatoire.
##  Si la connexion Internet (4G / 5G / Wi-Fi) est perdue, le jeu se met
##  en pause et un écran bloquant s'affiche : impossible de continuer tant
##  que le serveur n'est pas de nouveau joignable. Reprise automatique dès
##  que la connexion revient (vérification réelle par OnlineService).
##  Pas de faux statut : on se base uniquement sur les réponses du serveur
##  et sur l'événement « offline » du navigateur.
## ============================================================

const GRACE_AT_START := 8.0     # le temps de la première connexion au lancement
const CONFIRM_DELAY := 3.0      # évite de bloquer sur une micro-coupure

var blocking: bool = false
var _t: float = 0.0
var _offline_for: float = 0.0
var _was_paused: bool = false
var _root: Control
var _status: Label
var _spinner: Spinner


class Spinner extends Control:
	var a: float = 0.0
	func _process(delta: float) -> void:
		a += delta * 4.0
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 26.0, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 6.0, true)
		draw_arc(c, 26.0, a, a + 1.6, 24, Color(1.0, 0.45, 0.4), 6.0, true)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UiKit.full_rect(Control.new())
	_root.theme = UiKit.theme()
	add_child(_root)
	var dim := UiKit.full_rect(ColorRect.new()) as ColorRect
	dim.color = Color(0.01, 0.02, 0.04, 0.88)
	_root.add_child(dim)
	var p := UiKit.panel(Color(0.06, 0.04, 0.05, 0.96), 26, Color(1.0, 0.4, 0.38, 0.6))
	p.custom_minimum_size = Vector2(620, 0)
	UiKit.place(p, Vector2(0.5, 0.5), Vector2.ZERO, 0, 0)
	_root.add_child(p)
	var v := UiKit.vbox(14)
	p.add_child(v)
	_spinner = Spinner.new()
	_spinner.custom_minimum_size = Vector2(0, 64)
	v.add_child(_spinner)
	var t := UiKit.label("CONNECTION LOST", 40, UiKit.BAD, "black")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiKit.label("Blue Thread is a connected game: every sort restores the ocean shared by all players. "
		+ "The game is paused until the connection comes back.", 19, UiKit.PAPER, "regular")
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(560, 0)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var fr := UiKit.label("Connexion perdue : réactive la 4G / 5G ou le Wi-Fi pour continuer.", 17, UiKit.MUTED, "bold")
	fr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fr.custom_minimum_size = Vector2(560, 0)
	fr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fr)
	_status = UiKit.label("", 15, Color(1, 1, 1, 0.6), "bold")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var b := UiKit.button("RETRY NOW", UiKit.TEAL, 20, 260)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): OnlineService.poll_now())
	v.add_child(b)
	_root.visible = false
	OnlineService.connection_changed.connect(_on_conn)


func _on_conn(is_online: bool) -> void:
	if is_online and blocking:
		_unblock()


func _process(delta: float) -> void:
	_t += delta
	var os = OnlineService
	if os.online:
		_offline_for = 0.0
		if blocking:
			_unblock()
		return
	if _t < GRACE_AT_START and not os.browser_offline:
		return
	_offline_for += delta
	if not blocking and (os.browser_offline or _offline_for >= CONFIRM_DELAY):
		_block()
	if blocking:
		get_tree().paused = true     # reste en pause même si un écran tente de reprendre
		var since: float = os.seconds_since_sync()
		_status.text = "Waiting for the network...  " + (("last server contact %d s ago" % int(since)) if since >= 0.0 else "no server contact yet")


func _block() -> void:
	blocking = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	OnlineService.poll_now()


func _unblock() -> void:
	blocking = false
	_offline_for = 0.0
	_root.visible = false
	get_tree().paused = _was_paused
