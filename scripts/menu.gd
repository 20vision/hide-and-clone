extends Control
## Home, public lobbies, and the simple "pick a map, hit create" screen.
var main: Node
var body: Control
var msg_l: Label
var lobby_list: VBoxContainer
var settings: Dictionary = {}
var _adv: Control
var _filter := "all"
var _selected: Dictionary = {}
var _map_list: Container
var _refresh_t := 0.0
var _on_lobbies := false

func setup(m: Node) -> void:
	main = m
	settings = main.game.DEFAULTS.duplicate()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	body = UI.full(Control.new())
	add_child(body)
	msg_l = UI.label("", 18, Color("ffd166"), true)
	msg_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	msg_l.offset_top = -40
	msg_l.offset_bottom = -10
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_l.add_theme_constant_override("outline_size", 6)
	msg_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(msg_l)
	Net.lobbies.connect(_show_lobbies)
	_home()

func show_message(t: String) -> void: msg_l.text = t

func on_net_failed(code: String) -> void:
	var t := "Something went wrong."
	match code:
		"offline": t = "Lobby service unreachable. You can still play solo: Create a game."
		"not_found": t = "No game with that code."
		"full": t = "That game is full."
		"no_link": t = "Couldn't connect to that game."
	msg_l.text = t

func _clear() -> void:
	_on_lobbies = false
	for c in body.get_children(): c.queue_free()

func _home() -> void:
	_clear()
	var v := UI.vbox(14)
	v.custom_minimum_size = Vector2(440, 0)
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 48)
	wrap.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	var cc := CenterContainer.new()
	cc.add_child(v)
	wrap.add_child(cc)
	body.add_child(wrap)
	var t := UI.label("HIDE & CLONE", 58, Color.WHITE, true)
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_outline_color", Color("2a2350"))
	v.add_child(t)
	var sub := UI.label("Turn to glass. Fool The Original.", 20, Color.WHITE)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color("2a2350"))
	v.add_child(sub)
	var name_in := UI.input("Your name", main.player_name, 20)
	name_in.max_length = 16
	name_in.text_changed.connect(func(s: String) -> void: main.save_name(s))
	v.add_child(name_in)
	var play := UI.button("FIND A GAME", Color("ff5d8f"), 28, _lobbies)
	play.grab_focus.call_deferred()
	v.add_child(play)
	v.add_child(UI.button("CREATE GAME", Color("5e8bff"), 28, _create))
	v.add_child(UI.button("BUILD A MAP", Color("00b894"), 28, func() -> void: main.open_builder({})))
	var row := UI.hbox()
	var code := UI.input("Friend's code", "", 18)
	code.max_length = 5
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(code)
	row.add_child(UI.button("JOIN", Color("8e6cff"), 18, func() -> void:
		if code.text.strip_edges().length() == 5: main.play_join(code.text)
		else: msg_l.text = "Codes have 5 letters."))
	v.add_child(row)
	v.add_child(UI.button("WANT A REAL CLONE? MYCLAWN.COM", Color("2a2350"), 14, func() -> void: main.open_site("home")))

# ---------- public lobbies ---------------------------------------------------
func _lobbies() -> void:
	_clear()
	_on_lobbies = true
	msg_l.text = ""
	var p := UI.panel()
	p.custom_minimum_size = Vector2(760, 520)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label("PUBLIC GAMES", 34, Color.WHITE, true))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_list = UI.vbox(8)
	lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_list.add_child(UI.label("Looking for games…", 18))
	sc.add_child(lobby_list)
	v.add_child(sc)
	var row := UI.hbox()
	row.add_child(UI.button("BACK", Color("555b78"), 18, _home))
	row.add_child(UI.button("CREATE YOUR OWN", Color("5e8bff"), 18, _create))
	v.add_child(row)
	body.add_child(UI.center(p))
	Net.request_list()
	_refresh_t = 4.0

func _show_lobbies(list: Array) -> void:
	if not _on_lobbies or not is_instance_valid(lobby_list): return
	for c in lobby_list.get_children(): c.queue_free()
	if list.is_empty():
		lobby_list.add_child(UI.label("No public games right now. Create one and invite a friend!", 18, Color("ffd166")))
		lobby_list.add_child(UI.button("PLAY NOW WITH BOTS", Color("ff5d8f"), 20, func() -> void:
			var s: Dictionary = main.game.DEFAULTS.duplicate()
			main.play_host(Maps.builtin[randi() % Maps.builtin.size()], s)))
		return
	for l: Dictionary in list:
		var row := UI.hbox()
		var txt := UI.vbox(0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UI.label(str(l.get("name", "Game")), 20))
		txt.add_child(UI.label("%s · %d/%d players · %s" % [l.get("map", "?"), int(l.get("players", 0)), int(l.get("max", 0)), l.get("phase", "")], 14, Color(0.8, 0.85, 1)))
		row.add_child(txt)
		var code := str(l.get("code", ""))
		var b := UI.button("JOIN", Color("ff5d8f"), 18, func() -> void: main.play_join(code))
		b.disabled = int(l.get("players", 0)) >= int(l.get("max", 0))
		row.add_child(b)
		lobby_list.add_child(row)

func _process(delta: float) -> void:
	if _on_lobbies:
		_refresh_t -= delta
		if _refresh_t <= 0.0:
			_refresh_t = 4.0
			Net.request_list()

# ---------- create ----------------------------------------------------------
func _create() -> void:
	_clear()
	msg_l.text = ""
	var p := UI.panel()
	p.custom_minimum_size = Vector2(980, 600)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label("CREATE GAME", 34, Color.WHITE, true))
	var tabs := UI.hbox()
	for f: Array in [["all", "All maps"], ["star", "Starred"], ["mine", "My maps"], ["played", "Played"]]:
		var key: String = f[0]
		tabs.add_child(UI.button(f[1], Color("3b4170"), 15, func() -> void:
			_filter = key
			_render_maps()))
	v.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_list = UI.vbox(6)
	_map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_map_list)
	v.add_child(sc)
	_adv = _advanced()
	_adv.visible = false
	v.add_child(_adv)
	var row := UI.hbox()
	row.add_child(UI.button("BACK", Color("555b78"), 18, _home))
	row.add_child(UI.button("ADVANCED", Color("3b4170"), 18, func() -> void: _adv.visible = not _adv.visible))
	row.add_child(UI.button("BUILD NEW MAP", Color("00b894"), 18, func() -> void: main.open_builder({})))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var go := UI.button("CREATE", Color("ff5d8f"), 30, func() -> void:
		if _selected.is_empty(): _selected = Maps.all_maps()[0]
		main.play_host(_selected, settings))
	go.grab_focus.call_deferred()
	row.add_child(go)
	v.add_child(row)
	body.add_child(UI.center(p))
	if _selected.is_empty() and not Maps.all_maps().is_empty(): _selected = Maps.all_maps()[0]
	_render_maps()

func _render_maps() -> void:
	for c in _map_list.get_children(): c.queue_free()
	for m: Dictionary in Maps.all_maps():
		var src := str(m.get("src", "played"))
		if _filter == "star" and not m.get("star", false): continue
		if _filter == "mine" and src != "mine": continue
		if _filter == "played" and src != "played": continue
		var row := UI.hbox()
		var sel: bool = str(_selected.get("id", "")) == str(m.get("id", ""))
		var pick := UI.button(str(m.get("name", "Map")), Color("ff5d8f") if sel else Color("2c3158"), 17, func() -> void:
			_selected = m
			_render_maps())
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(pick)
		row.add_child(UI.label("%d objects · %s" % [(m.get("o", []) as Array).size(), {"builtin": "built-in", "mine": "my map", "played": "played"}.get(src, src)], 14, Color(0.8, 0.85, 1)))
		var starred: bool = m.get("star", false)
		row.add_child(UI.button("STARRED" if starred else "STAR", Color("c99a10") if starred else Color("3b4170"), 14, func() -> void:
			Maps.set_star(m, not starred)
			_render_maps()))
		row.add_child(UI.button("EDIT", Color("3b4170"), 14, func() -> void: main.open_builder(m)))
		if src != "builtin":
			var name_in := UI.input("Name", str(m.get("name", "")), 14)
			name_in.custom_minimum_size = Vector2(150, 0)
			name_in.text_submitted.connect(func(s: String) -> void:
				Maps.rename(str(m["id"]), s)
				_render_maps())
			row.add_child(name_in)
			row.add_child(UI.button("DEL", Color("7a3350"), 13, func() -> void:
				Maps.delete_map(str(m["id"]))
				_render_maps()))
		_map_list.add_child(row)
	if _map_list.get_child_count() == 0:
		_map_list.add_child(UI.label("Nothing here yet.", 16))

func _slider(parent: Container, title: String, key: String, a: float, b: float, step: float, suffix := "") -> void:
	var row := UI.hbox(6)
	var val := UI.label("", 14, Color("ffd166"))
	var fmt := func(x: float) -> String: return ("%d" % int(x) if step >= 1.0 else "%.1f" % x) + suffix
	val.text = fmt.call(float(settings[key]))
	val.custom_minimum_size = Vector2(52, 0)
	var t := UI.label(title, 14)
	t.custom_minimum_size = Vector2(170, 0)
	row.add_child(t)
	var s := HSlider.new()
	s.min_value = a
	s.max_value = b
	s.step = step
	s.value = float(settings[key])
	s.custom_minimum_size = Vector2(130, 22)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(x: float) -> void:
		settings[key] = x
		val.text = fmt.call(x))
	row.add_child(s)
	row.add_child(val)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

func _advanced() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	_slider(g, "Hiding time", "hide_time", 5, 90, 5, "s")
	_slider(g, "Round time", "seek_time", 30, 600, 15, "s")
	_slider(g, "Clone speed", "hider_speed", 60, 110, 1, "%")
	_slider(g, "Clone visibility", "visibility", 0, 100, 1, "%")
	_slider(g, "Hits to eliminate", "hits", 1, 6, 1)
	_slider(g, "Wand cooldown", "cooldown", 0.1, 3.0, 0.1, "s")
	_slider(g, "Decoy clones", "decoys", 0, 10, 1)
	_slider(g, "Originals (seekers)", "seekers", 1, 5, 1)
	_slider(g, "Bots", "bots", 0, 11, 1)
	_slider(g, "Max players", "max_players", 2, 16, 1)
	var c1 := CheckBox.new()
	c1.text = "Public lobby"
	c1.button_pressed = bool(settings["public"])
	c1.toggled.connect(func(b: bool) -> void: settings["public"] = b)
	g.add_child(c1)
	var c2 := CheckBox.new()
	c2.text = "Start rounds automatically"
	c2.button_pressed = bool(settings["autostart"])
	c2.toggled.connect(func(b: bool) -> void: settings["autostart"] = b)
	g.add_child(c2)
	return g
