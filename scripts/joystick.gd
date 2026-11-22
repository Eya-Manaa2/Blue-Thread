extends Control
## Joystick virtuel tactile : touche la moitié gauche de l'écran et glisse.

const RADIUS := 90.0

var output: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed and _touch_index == -1 and st.position.x < get_viewport_rect().size.x * 0.5:
			_touch_index = st.index
			_center = st.position
			_knob = st.position
			queue_redraw()
		elif (not st.pressed) and st.index == _touch_index:
			_touch_index = -1
			output = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		if sd.index == _touch_index:
			var d: Vector2 = sd.position - _center
			if d.length() > RADIUS:
				d = d.normalized() * RADIUS
			_knob = _center + d
			output = d / RADIUS
			queue_redraw()


func _draw() -> void:
	if _touch_index == -1:
		return
	draw_circle(_center, RADIUS, Color(1, 1, 1, 0.15))
	draw_arc(_center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(_knob, 38.0, Color(0.1, 0.5, 0.95, 0.75))
