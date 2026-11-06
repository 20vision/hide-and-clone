extends Control
## Phone controls: left thumb moves (floating stick), right thumb drags to look,
## buttons for jump, the round action (wand / decoy / next / start) and the menu.
## Only drawn and active while game.using_touch is on.
var game: Node
var move := Vector2.ZERO
var jump_held := false
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _look_start := Vector2.ZERO
var _look_t := 0
var _look_moved := false
var _jump_id := -1
var _action_id := -1
const STICK_R := 80.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _jump_c() -> Vector2: return size - Vector2(110, 130)
func _action_c() -> Vector2: return size - Vector2(250, 95)
func _menu_c() -> Vector2: return Vector2(size.x - 52, 52)

func _on() -> bool: return game != null and game.active and game.using_touch and get_parent().is_visible_in_tree()

## Text on the action button, or "" when there is nothing to do.
func action_text() -> String:
	var m: Clone = game.me()
	var my: Dictionary = game.players.get(game.uid(), {})
	match game.phase:
		"lobby": return "START" if game._is_host() and game._start_at < 0.0 else ""
		"hide", "seek":
			if not my.get("in_round", false) or (m and not m.alive): return "NEXT" if game.phase == "seek" else ""
			if m and m.seeker: return "WAND" if game.phase == "seek" else ""
			return "DECOY"
	return ""

func _do_action() -> void:
	match action_text():
		"START": game.request_start_lobby()
		"WAND": game.local_fire()
		"DECOY": game.local_decoy()
		"NEXT": game._spec_idx += 1

func release_all() -> void:
	_stick_id = -1
	_look_id = -1
	_jump_id = -1
	_action_id = -1
	move = Vector2.ZERO
	jump_held = false
	queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if not _on(): return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed: _press(t.index, t.position)
		else: _release(t.index, t.position)
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _stick_id:
			_stick_pos = d.position
			var off := _stick_pos - _stick_origin
			move = off.limit_length(STICK_R) / STICK_R
			if move.length() < 0.12: move = Vector2.ZERO
		elif d.index == _look_id:
			game.touch_look(d.relative)
			if d.position.distance_to(_look_start) > 14.0: _look_moved = true
		get_viewport().set_input_as_handled()
		queue_redraw()

func _press(i: int, p: Vector2) -> void:
	if p.distance_to(_menu_c()) < 44.0:
		game.hud.toggle_pad_menu(true)
		return
	if game.menu_open: return
	if p.distance_to(_jump_c()) < 70.0:
		_jump_id = i
		jump_held = true
		return
	if p.distance_to(_action_c()) < 58.0 and action_text() != "":
		_action_id = i
		_do_action()
		return
	if p.x < size.x * 0.42 and _stick_id < 0:
		_stick_id = i
		_stick_origin = p
		_stick_pos = p
		move = Vector2.ZERO
	elif _look_id < 0:
		_look_id = i
		_look_start = p
		_look_t = Time.get_ticks_msec()
		_look_moved = false

func _release(i: int, _p: Vector2) -> void:
	if i == _stick_id:
		_stick_id = -1
		move = Vector2.ZERO
	elif i == _look_id:
		_look_id = -1
		# a quick tap on the world fires the wand / watches the next player
		if not _look_moved and Time.get_ticks_msec() - _look_t < 250 and action_text() in ["WAND", "NEXT"]: _do_action()
	elif i == _jump_id:
		_jump_id = -1
		jump_held = false
	elif i == _action_id:
		_action_id = -1

func _process(_d: float) -> void:
	var want := _on()
	if not want and (_stick_id >= 0 or _look_id >= 0 or _jump_id >= 0): release_all()
	if visible != want: visible = want
	if visible: queue_redraw()

func _button(c: Vector2, r: float, text: String, held: bool, col: Color) -> void:
	draw_circle(c, r, Color(0.07, 0.06, 0.28, 0.55 if held else 0.35))
	draw_arc(c, r, 0.0, TAU, 48, Color(col, 0.9), 4.0, true)
	var f := get_theme_default_font()
	var fs := int(r * 0.42)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _draw() -> void:
	if not _on(): return
	var c := _stick_origin if _stick_id >= 0 else Vector2(150, size.y - 150)
	draw_circle(c, STICK_R, Color(0.07, 0.06, 0.28, 0.3))
	draw_arc(c, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
	var k := c + move * STICK_R if _stick_id >= 0 else c
	draw_circle(k, 34.0, Color(1, 1, 1, 0.75))
	_button(_jump_c(), 62.0, "JUMP", jump_held, Color("3d7bff"))
	var a := action_text()
	if a != "": _button(_action_c(), 50.0, a, _action_id >= 0, Color("ff4f8b"))
	_button(_menu_c(), 34.0, "II", game.menu_open, Color("8f8cc0"))
