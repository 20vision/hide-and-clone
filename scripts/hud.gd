extends CanvasLayer
## In-game screen: timer, counter, player list, end screen, game panel.
var game: Node
var root: Control
var top: Label
var count: Label
var role: Label
var hint: Label
var blind: ColorRect
var blind_text: Label
var cross: Control
var board: PanelContainer
var board_list: VBoxContainer
var end_panel: PanelContainer
var end_v: VBoxContainer
var pause: PanelContainer
var code_l: Label
var start_b: Button
var copy_b: Button
var map_l: Label
var loading: Label
var toast_l: Label
var hit_flash: ColorRect
var _toast_t := 0.0
var _board_t := 0.0
var _last_list := ""
var _fading_end := false
var first_button: Button
var play_b: Button
var pad_menu := false
var end_timer: Label
var _cross_kick := 0.0

func build(g: Node) -> void:
	game = g
	root = UI.full(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	blind = ColorRect.new()
	UI.full(blind)
	blind.color = Color(0.08, 0.07, 0.3, 1)
	blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(blind)
	blind_text = UI.label("", 38, Color("ffc928"), true)
	blind_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blind_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bc := UI.center(blind_text)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blind_text.custom_minimum_size = Vector2(760, 0)
	blind.add_child(bc)
	hit_flash = ColorRect.new()
	UI.full(hit_flash)
	hit_flash.color = Color(1, 0.2, 0.3, 0)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hit_flash)
	var topbox := UI.vbox(2)
	topbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	topbox.position = Vector2(-220, 12)
	topbox.custom_minimum_size = Vector2(440, 0)
	topbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(topbox)
	var chip := UI.pill()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var chipv := UI.vbox(0)
	chipv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chipv)
	topbox.add_child(chip)
	top = UI.label("", 40, Color.WHITE, true)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipv.add_child(top)
	count = UI.label("", 18, Color("ffe27a"), false)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chipv.add_child(count)
	role = UI.outlined(UI.label("", 22, Color("ffc928"), true), 8)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topbox.add_child(role)
	toast_l = UI.outlined(UI.label("", 22, Color("ffffff"), true), 8)
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topbox.add_child(toast_l)
	cross = Control.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	root.add_child(cross)
	hint = UI.label("", 16, Color(1, 1, 1, 0.95))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position.y = -34
	hint.offset_top = -38
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.outlined(hint, 7)
	root.add_child(hint)
	loading = UI.label("", 22, Color.WHITE, true)
	loading.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	loading.offset_left = 20
	loading.offset_top = -60
	root.add_child(loading)
	# player list (hold Tab)
	board = UI.panel()
	var bv := UI.vbox(6)
	bv.add_child(UI.label("Players", 30, UI.VIOLET, true))
	board_list = UI.vbox(4)
	bv.add_child(board_list)
	board.add_child(bv)
	board.custom_minimum_size = Vector2(580, 0)
	var bc2 := UI.center(board)
	bc2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bc2)
	board.visible = false
	# end screen
	end_panel = UI.panel()
	end_v = UI.vbox(8)
	end_panel.add_child(end_v)
	end_panel.custom_minimum_size = Vector2(640, 0)
	var ec := UI.center(end_panel)
	ec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ec)
	end_panel.visible = false
	# panel shown whenever the mouse is free
	pause = UI.panel()
	var pv := UI.vbox(10)
	pause.add_child(pv)
	map_l = UI.label("", 24, UI.INK, true)
	pv.add_child(map_l)
	code_l = UI.label("", 20, Color("0b9b74"), true)
	pv.add_child(code_l)
	copy_b = UI.button("COPY INVITE LINK", Color("14bf8e"), 18, _copy)
	pv.add_child(copy_b)
	start_b = UI.button("START ROUND", Color("ff4f8b"), 24, func() -> void:
		game.request_start()
		_capture())
	pv.add_child(start_b)
	play_b = UI.button("BACK TO GAME", Color("3d7bff"), 20, _capture)
	pv.add_child(play_b)
	var sens_row := UI.hbox()
	sens_row.add_child(UI.label("Look speed", 16))
	var sl := HSlider.new()
	sl.min_value = 0.0008
	sl.max_value = 0.006
	sl.step = 0.0002
	sl.value = game.sens
	sl.custom_minimum_size = Vector2(190, 24)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v: float) -> void: game.sens = v)
	first_button = copy_b
	sens_row.add_child(sl)
	pv.add_child(sens_row)
	pv.add_child(UI.button("LEAVE GAME", Color("8f8cc0"), 16, func() -> void: game._quit("")))
	pv.add_child(UI.button("WANT A REAL CLONE? MYCLAWN.COM", Color("8f8cc0"), 13, func() -> void: game.get_parent().open_site("panel")))
	pause.custom_minimum_size = Vector2(380, 0)
	pause.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	var pwrap := MarginContainer.new()
	pwrap.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	pwrap.offset_left = -420
	pwrap.offset_right = -20
	pwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := CenterContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(pause)
	pwrap.add_child(pc)
	root.add_child(pwrap)
	show_game(false)

func _capture() -> void:
	if pad_menu: toggle_pad_menu(true)
	if not game.using_pad: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _copy() -> void:
	if OS.has_feature("web"):
		var link := str(JavaScriptBridge.eval("location.href.split('?')[0]")) + "?join=" + Net.code
		JavaScriptBridge.eval("navigator.clipboard&&navigator.clipboard.writeText(%s)" % JSON.stringify(link))
		toast("Invite link copied!")
	else:
		DisplayServer.clipboard_set("https://20vision.github.io/hide-and-clone/?join=" + Net.code)
		toast("Invite link copied!")

func show_game(on: bool) -> void:
	root.visible = on

func set_map_name(n: String) -> void: map_l.text = n

func set_loading(done: int, total: int) -> void:
	loading.text = "" if done >= total else "Loading map %d/%d" % [done, total]

func toast(t: String) -> void:
	toast_l.text = t
	_toast_t = 3.5

func flash_hit() -> void:
	hit_flash.color.a = 0.45
	var tw := create_tween()
	tw.tween_property(hit_flash, "color:a", 0.0, 0.45)

func pop_cross() -> void: _cross_kick = 1.0

func _draw_cross() -> void:
	var r := 15.0 + _cross_kick * 12.0
	var a := Color(0.07, 0.06, 0.28, 0.75)
	var c := Color("ffe27a")
	cross.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, a, 6.0, true)
	cross.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, 3.0, true)
	cross.draw_circle(Vector2.ZERO, 4.0, a)
	cross.draw_circle(Vector2.ZERO, 2.5, Color.WHITE)

func toggle_pad_menu(from_start: bool) -> void:
	if not pad_menu and not from_start: return
	pad_menu = not pad_menu
	game.menu_open = pad_menu
	if pad_menu:
		(start_b if start_b.visible else play_b).grab_focus()
	elif get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()

func toggle_pause() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func on_state(prev: String, now: String) -> void:
	if prev != now and now == "hide":
		var m: Clone = game.me()
		toast("")
		if m and m.seeker: toast("You are The Original")
		else: toast("Hide! Get close to things to turn into glass")
	if now == "seek" and prev == "hide": toast("The Original is coming!")
	_last_list = ""
	_render_end()

func _clone_line(my: Dictionary) -> String:
	var h := int(my.get("hp", 0))
	var d := int(my.get("decoys", 0))
	return "CLONE  ·  %d %s  ·  %d %s" % [h, "hit" if h == 1 else "hits", d, "decoy" if d == 1 else "decoys"]

func _keys(pad_text: String, key_text: String) -> String:
	return pad_text if game.using_pad else key_text

func _lobby_hint(captured: bool) -> String:
	var host: bool = game._is_host()
	if game.using_pad: return "Left stick move  ·  A jump  ·  View players  ·  Menu button menu" + ("  ·  Y start" if host else "")
	if not captured: return "Click the map to play"
	return "WASD move  ·  Space jump  ·  Tab players  ·  Esc menu" + ("  ·  Enter start" if host else "")

func _mmss(t: float) -> String:
	var s := int(ceil(maxf(t, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]

func tick(delta: float) -> void:
	_toast_t -= delta
	_cross_kick = move_toward(_cross_kick, 0.0, delta * 6.0)
	if cross.visible: cross.queue_redraw()
	if _toast_t <= 0.0: toast_l.text = ""
	var phase: String = game.phase
	var m: Clone = game.me()
	var my: Dictionary = game.players.get(game.uid(), {})
	var total := 0
	var left := 0
	for p: Dictionary in game.players.values():
		if p["in_round"] and not p["seeker"]:
			total += 1
			if p["alive"]: left += 1
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var pad: bool = game.using_pad
	game.menu_open = pad_menu
	pause.get_parent().get_parent().visible = phase != "end" and (pad_menu if pad else not captured)
	code_l.text = ("Invite code: " + Net.code) if Net.code != "" else "Solo game with bots"
	copy_b.visible = Net.code != ""
	start_b.visible = game._is_host() and phase == "lobby"
	var seeker_me := m != null and m.seeker and phase != "lobby" and phase != "end"
	blind.visible = phase == "hide" and seeker_me
	cross.visible = seeker_me and phase == "seek" and bool(my.get("alive", false))
	match phase:
		"lobby":
			var at: float = game._start_at
			top.text = "Starting in %d" % int(ceil(at)) if at >= 0.0 else "Lobby"
			count.text = "%d player%s" % [game.players.size(), "" if game.players.size() == 1 else "s"]
			role.text = "Waiting for the host" if not game._is_host() else ""
			hint.text = _lobby_hint(captured)
		"hide":
			top.text = "HIDE " + _mmss(game.time_left)
			count.text = "%d clone%s hiding" % [total, "" if total == 1 else "s"]
			if seeker_me:
				blind_text.text = "You are THE ORIGINAL\nYour clones are hiding.\nHunt starts in %d" % int(ceil(game.time_left))
				role.text = ""
				hint.text = ""
			elif my.get("in_round", false):
				role.text = _clone_line(my)
				hint.text = "Stand still near things to turn to glass  ·  %s" % _keys("X decoy clone  ·  View players", "E decoy clone  ·  Tab players")
			else:
				role.text = "Watching this round"
				hint.text = ""
		"seek":
			top.text = _mmss(game.time_left)
			count.text = "Clones left %d / %d" % [left, total]
			if not my.get("in_round", false):
				role.text = "Watching this round"
				hint.text = _keys("View players", "Tab players")
			elif seeker_me:
				role.text = "THE ORIGINAL"
				hint.text = _keys("RT shoot  ·  View players", "Click to shoot your wand  ·  Tab players")
			elif my.get("alive", false):
				role.text = _clone_line(my)
				hint.text = "Run or stay still  ·  %s" % _keys("X decoy clone  ·  View players", "E decoy clone  ·  Tab players")
			else:
				role.text = "YOU WERE UN-CLONED"
				hint.text = _keys("A watch another player  ·  View players", "Click to watch another player  ·  Tab players")
		"end":
			top.text = ""
			count.text = ""
			role.text = ""
			hint.text = ""
	end_panel.visible = phase == "end"
	if phase == "end" and is_instance_valid(end_timer): end_timer.text = "Back to lobby in %d" % int(ceil(game.time_left))
	var holding := Input.is_physical_key_pressed(KEY_TAB) or Input.is_joy_button_pressed(0, JOY_BUTTON_BACK)
	board.visible = holding and phase != "end"
	if board.visible: _render_board()

func _render_board() -> void:
	var key := str(game.players)
	if key == _last_list: return
	_last_list = key
	for c in board_list.get_children(): c.queue_free()
	var rows: Array = game.players.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["seeker"] != b["seeker"]: return a["seeker"]
		if a["alive"] != b["alive"]: return a["alive"]
		return str(a["name"]) < str(b["name"]))
	for p: Dictionary in rows:
		var row := UI.hbox()
		var c: Color = game.COLORS[int(p["color"]) % game.COLORS.size()]
		var dot := ColorRect.new()
		dot.color = c
		dot.custom_minimum_size = Vector2(20, 20)
		row.add_child(dot)
		var nm := UI.label(str(p["name"]) + (" (you)" if int(p["id"]) == game.uid() else ""), 20)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var st := ""
		var col := Color("7ae582")
		if game.phase == "lobby" or not p["in_round"]:
			st = "in lobby" if game.phase == "lobby" else "watching"
			col = Color(0.8, 0.8, 0.85)
		elif p["seeker"]:
			st = "THE ORIGINAL · %d found" % int(p["tags"])
			col = Color("ffc928")
		elif p["alive"]:
			st = "still here · %d hits" % int(p["hp"])
		else:
			st = "eliminated"
			col = Color("ff6b6b")
		row.add_child(UI.label(st, 16, col))
		board_list.add_child(row)

func _chip(text: String, c: Color) -> PanelContainer:
	var p := UI.pill(c)
	p.add_child(UI.label(text, 18, Color.WHITE))
	return p

func _names(parent: Container, names: Array, c: Color) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	if names.is_empty(): f.add_child(UI.label("Nobody", 18, UI.MUTED))
	for n: Variant in names: f.add_child(_chip(str(n), c))
	parent.add_child(f)

func _render_end() -> void:
	for c in end_v.get_children(): c.queue_free()
	var r: Dictionary = game.result
	if r.is_empty(): return
	var side := str(r["side"])
	var head := UI.outlined(UI.label("THE CLONES ESCAPED!" if side == "hiders" else "THE ORIGINAL WINS!", 42, UI.VIOLET, true), 0, Color.WHITE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_v.add_child(head)
	end_v.add_child(UI.label("Winners", 22, Color("0b9b74"), true))
	_names(end_v, r["winners"], Color("149a63"))
	end_v.add_child(UI.label("Eliminated", 22, Color("e0457b"), true))
	_names(end_v, r["out"], Color("b83a5e"))
	end_timer = UI.label("", 16, UI.MUTED)
	end_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_v.add_child(end_timer)
	var by := UI.label("Made by MyClawn: real AI clones that work for you. Open the menu for the link.", 14, UI.MUTED)
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_v.add_child(by)
