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
var _thumbs: Dictionary = {}
var _refresh_t := 0.0
var _on_lobbies := false
var _screen := "home"
var _focus_id := ""
var _hero_rect: Control
var _video_key := ""
var _native_vid: VideoStreamPlayer

func setup(m: Node) -> void:
	main = m
	settings = main.game.DEFAULTS.duplicate()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(UI.backdrop())
	body = UI.full(Control.new())
	add_child(body)
	msg_l = UI.label("", 18, Color("c2185b"), true)
	msg_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	msg_l.offset_top = -40
	msg_l.offset_bottom = -10
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _screen != "home": _home()

func _clear() -> void:
	_on_lobbies = false
	_screen = "other"
	_hero_rect = null
	_video(false)
	for c in body.get_children(): c.queue_free()

func _home() -> void:
	_clear()
	_screen = "home"
	var m := MarginContainer.new()
	UI.full(m)
	for k: String in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + k, 40)
	body.add_child(m)
	var h := UI.hbox(36)
	m.add_child(h)
	var v := UI.vbox(12)
	v.custom_minimum_size = Vector2(390, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var logo := UI.vbox(-12)
	logo.add_child(UI.label("HIDE &", 46, UI.INK, true))
	logo.add_child(UI.label("CLONE", 82, UI.VIOLET, true))
	v.add_child(logo)
	var sub_l := UI.label("Turn to glass. Fool The Original.", 19, UI.MUTED)
	v.add_child(sub_l)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var play := UI.menu_item("Find a game", Color("ff3d81"), _lobbies)
	play.grab_focus.call_deferred()
	v.add_child(play)
	v.add_child(UI.menu_item("Create game", Color("2f7bff"), _create))
	v.add_child(UI.menu_item("Build a map", Color("0fbf8f"), func() -> void: main.open_builder({})))
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp2)
	var name_in := UI.input("Your name", main.player_name, 19)
	name_in.max_length = 16
	name_in.text_changed.connect(func(t: String) -> void: main.save_name(t))
	v.add_child(name_in)
	var row := UI.hbox()
	var code := UI.input("Friend's code", "", 19)
	code.max_length = 5
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(code)
	row.add_child(UI.button("JOIN", UI.VIOLET, 18, func() -> void:
		if code.text.strip_edges().length() == 5: main.play_join(code.text)
		else: msg_l.text = "Codes have 5 letters."))
	v.add_child(row)
	var site := UI.button("Want a real clone? myclawn.com", Color("8f8cc0"), 14, func() -> void: main.open_site("home"))
	v.add_child(site)
	if not OS.has_feature("web"):
		v.add_child(UI.button("Quit game", Color("8f8cc0"), 14, func() -> void: get_tree().quit()))
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	var ar := AspectRatioContainer.new()
	ar.ratio = 1280.0 / 622.0
	ar.custom_minimum_size = Vector2(760, 370)
	ar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.remove_child(c)
	h.add_child(ar)
	var hero := Panel.new()
	var hs := UI.style(Color("120f2e"), 30)
	hs.shadow_color = Color(0.3, 0.2, 0.7, 0.35)
	hs.shadow_size = 30
	hs.shadow_offset = Vector2(0, 12)
	hero.add_theme_stylebox_override("panel", hs)
	ar.add_child(hero)
	var img := Image.new()
	if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes("res://maps/hero.thumb")) == OK:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		UI.full(tr)
		hero.add_child(tr)
	_hero_rect = hero
	_video(true)

## The looping hero animation is a real video element laid over its spot on the canvas.
func _video(on: bool) -> void:
	if not OS.has_feature("web"):
		_play_native(on)
		return
	if on:
		JavaScriptBridge.eval("""(function(){var v=document.getElementById('hero');if(!v){v=document.createElement('video');v.id='hero';v.src='hero.mp4';v.muted=true;v.loop=true;v.autoplay=true;v.playsInline=true;v.setAttribute('playsinline','');v.style.cssText='position:fixed;pointer-events:none;object-fit:cover;clip-path:inset(0 round 30px);opacity:0;transition:opacity .5s;z-index:5';v.addEventListener('playing',function(){v.style.opacity=1});document.body.appendChild(v);}v.style.display='block';v.play().catch(function(){});})()""")
		_video_key = ""
	else:
		JavaScriptBridge.eval("(function(){var v=document.getElementById('hero');if(v){v.pause();v.style.display='none'}})()")

## Outside the browser the same loop plays from a Theora copy, muted, inside the hero panel.
func _play_native(on: bool) -> void:
	if is_instance_valid(_native_vid): _native_vid.queue_free()
	_native_vid = null
	if not on or not is_instance_valid(_hero_rect): return
	var stream := load("res://video/hero.ogv") as VideoStream
	if stream == null: return
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = "shader_type canvas_item; uniform vec2 box = vec2(760.0, 370.0); uniform float radius = 30.0; void fragment() { vec2 q = abs((UV - 0.5) * box) - box * 0.5 + radius; COLOR.a *= 1.0 - smoothstep(-1.0, 0.0, length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius); }"
	var vid := VideoStreamPlayer.new()
	vid.stream = stream
	vid.loop = true
	vid.expand = true
	vid.volume = 0.0
	vid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vid.material = mat
	vid.modulate.a = 0.0
	UI.full(vid)
	_hero_rect.add_child(vid)
	var fit := func() -> void: mat.set_shader_parameter("box", _hero_rect.size)
	_hero_rect.resized.connect(fit)
	fit.call()
	if _hero_rect.get_child_count() > 1: (_hero_rect.get_child(0) as CanvasItem).material = mat
	vid.play()
	vid.create_tween().tween_property(vid, "modulate:a", 1.0, 0.5)
	_native_vid = vid

func _exit_tree() -> void:
	_video(false)

func _place_video() -> void:
	if not OS.has_feature("web") or not is_instance_valid(_hero_rect): return
	var r: Rect2 = _hero_rect.get_global_rect()
	var vp := get_viewport_rect().size
	var key := "%s|%s" % [r, vp]
	if key == _video_key: return
	_video_key = key
	JavaScriptBridge.eval("(function(){var v=document.getElementById('hero'),c=document.getElementById('canvas');if(!v||!c)return;var b=c.getBoundingClientRect(),s=b.width/%f;v.style.left=(b.left+%f*s)+'px';v.style.top=(b.top+%f*s)+'px';v.style.width=(%f*s)+'px';v.style.height=(%f*s)+'px';})()" % [vp.x, r.position.x, r.position.y, r.size.x, r.size.y])

# ---------- public lobbies ---------------------------------------------------
func _lobbies() -> void:
	_clear()
	_on_lobbies = true
	msg_l.text = ""
	var p := UI.panel()
	p.custom_minimum_size = Vector2(760, 520)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label("Public games", 34, UI.INK, true))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_list = UI.vbox(8)
	lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_list.add_child(UI.label("Looking for games…", 18))
	sc.add_child(lobby_list)
	v.add_child(sc)
	var row := UI.hbox()
	row.add_child(UI.button("BACK", Color("8f8cc0"), 18, _home))
	row.add_child(UI.button("CREATE YOUR OWN", Color("3d7bff"), 18, _create))
	v.add_child(row)
	body.add_child(UI.center(p))
	Net.request_list()
	_refresh_t = 4.0

func _show_lobbies(list: Array) -> void:
	if not _on_lobbies or not is_instance_valid(lobby_list): return
	for c in lobby_list.get_children(): c.queue_free()
	if list.is_empty():
		lobby_list.add_child(UI.label("No public games right now. Create one and invite a friend!", 18, UI.MUTED))
		var bots := UI.button("PLAY NOW WITH BOTS", Color("ff4f8b"), 22, func() -> void:
			var s: Dictionary = main.game.DEFAULTS.duplicate()
			main.play_host(Maps.builtin[randi() % Maps.builtin.size()], s))
		lobby_list.add_child(bots)
		bots.grab_focus.call_deferred()
		return
	for l: Dictionary in list:
		var rowp := UI.pill(Color("f1edff"))
		rowp.mouse_filter = Control.MOUSE_FILTER_PASS
		var row := UI.hbox()
		rowp.add_child(row)
		var txt := UI.vbox(0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UI.label(str(l.get("name", "Game")), 20, UI.INK, true))
		txt.add_child(UI.label("%s · %d/%d players · %s" % [l.get("map", "?"), int(l.get("players", 0)), int(l.get("max", 0)), l.get("phase", "")], 14, UI.MUTED))
		row.add_child(txt)
		var code := str(l.get("code", ""))
		var b := UI.button("JOIN", Color("ff4f8b"), 18, func() -> void: main.play_join(code))
		b.disabled = int(l.get("players", 0)) >= int(l.get("max", 0))
		row.add_child(b)
		lobby_list.add_child(rowp)
		if lobby_list.get_child_count() == 1: b.grab_focus.call_deferred()

func _process(delta: float) -> void:
	_place_video()
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
	p.custom_minimum_size = Vector2(1060, 640)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.label("Create game", 34, UI.INK, true))
	var tabs := UI.hbox()
	for f: Array in [["all", "All maps"], ["star", "Starred"], ["mine", "My maps"], ["played", "Played"]]:
		var key: String = f[0]
		tabs.add_child(UI.button(f[1], Color("7c6fe0"), 15, func() -> void:
			_filter = key
			_render_maps()))
	v.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_map_list = grid
	_map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_map_list)
	v.add_child(sc)
	_adv = _advanced()
	_adv.visible = false
	v.add_child(_adv)
	var row := UI.hbox()
	row.add_child(UI.button("BACK", Color("8f8cc0"), 18, _home))
	row.add_child(UI.button("ADVANCED", Color("7c6fe0"), 18, func() -> void: _adv.visible = not _adv.visible))
	row.add_child(UI.button("BUILD NEW MAP", Color("14bf8e"), 18, func() -> void: main.open_builder({})))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var go := UI.button("CREATE", Color("ff4f8b"), 30, func() -> void:
		if _selected.is_empty(): _selected = Maps.all_maps()[0]
		main.play_host(_selected, settings))
	go.grab_focus.call_deferred()
	row.add_child(go)
	v.add_child(row)
	body.add_child(UI.center(p))
	if _selected.is_empty() and not Maps.all_maps().is_empty(): _selected = Maps.all_maps()[0]
	_render_maps()

func _thumb_for(m: Dictionary) -> Texture2D:
	var key := str(m.get("thumb", ""))
	if key == "": return null
	if not _thumbs.has(key):
		var b := FileAccess.get_file_as_bytes("res://maps/%s.thumb" % key)
		var img := Image.new()
		if b.is_empty() or img.load_png_from_buffer(b) != OK: _thumbs[key] = null
		else: _thumbs[key] = ImageTexture.create_from_image(img)
	return _thumbs[key]

## One card per map: picture, name, details and its actions.
func _card(m: Dictionary) -> Control:
	var id := str(m.get("id", ""))
	var sel: bool = str(_selected.get("id", "")) == id
	var src := str(m.get("src", "played"))
	var card := PanelContainer.new()
	var st := UI.style(Color("f4f1ff") if not sel else Color("ffe3ee"), 20, Color("ff3d81") if sel else Color(0.12, 0.11, 0.32, 0.08), 4 if sel else 2)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(7)
	card.add_child(v)
	var pick := Button.new()
	pick.custom_minimum_size = Vector2(0, 118)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.expand_icon = true
	var tex := _thumb_for(m)
	pick.icon = tex
	var floor_col: Color = (World.FLOORS.get(str(m.get("floor", "lab")), World.FLOORS["lab"]) as Array)[0]
	for k: String in ["normal", "hover", "pressed"]:
		var bs := UI.style(floor_col, 12)
		bs.content_margin_left = 2
		bs.content_margin_right = 2
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		pick.add_theme_stylebox_override(k, bs)
	var fs := UI.style(floor_col, 12, Color.WHITE, 4)
	fs.content_margin_left = 2
	fs.content_margin_right = 2
	fs.content_margin_top = 2
	fs.content_margin_bottom = 2
	pick.add_theme_stylebox_override("focus", fs)
	if tex == null:
		pick.text = "%d objects" % (m.get("o", []) as Array).size()
		pick.add_theme_font_override("font", UI.title_font())
		pick.add_theme_font_size_override("font_size", 18)
		pick.add_theme_color_override("font_color", Color("1a1b55"))
	pick.pressed.connect(func() -> void:
		_selected = m
		_focus_id = id
		_render_maps())
	if id == _focus_id: pick.grab_focus.call_deferred()
	v.add_child(pick)
	var nm := UI.label(str(m.get("name", "Map")), 18, UI.INK, true)
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(190, 0)
	v.add_child(nm)
	v.add_child(UI.label("%d objects · %s" % [(m.get("o", []) as Array).size(), {"builtin": "built-in", "mine": "my map", "played": "played"}.get(src, src)], 13, UI.MUTED))
	var row := UI.hbox(5)
	var starred: bool = m.get("star", false)
	row.add_child(UI.button("STARRED" if starred else "STAR", Color("d9a400") if starred else Color("7c6fe0"), 12, func() -> void:
		Maps.set_star(m, not starred)
		_render_maps()))
	row.add_child(UI.button("EDIT", Color("7c6fe0"), 12, func() -> void: main.open_builder(m)))
	if src != "builtin":
		row.add_child(UI.button("DEL", Color("e0457b"), 12, func() -> void:
			Maps.delete_map(id)
			_render_maps()))
	v.add_child(row)
	if src != "builtin":
		var name_in := UI.input("Rename", str(m.get("name", "")), 13)
		name_in.text_submitted.connect(func(s: String) -> void:
			Maps.rename(id, s)
			_render_maps())
		v.add_child(name_in)
	return card

func _render_maps() -> void:
	for c in _map_list.get_children(): c.queue_free()
	var n := 0
	for m: Dictionary in Maps.all_maps():
		var src := str(m.get("src", "played"))
		if _filter == "star" and not m.get("star", false): continue
		if _filter == "mine" and src != "mine": continue
		if _filter == "played" and src != "played": continue
		_map_list.add_child(_card(m))
		n += 1
	if n == 0:
		_map_list.add_child(UI.label("Nothing here yet.", 18))

func _slider(parent: Container, title: String, key: String, a: float, b: float, step: float, suffix := "") -> void:
	var row := UI.hbox(6)
	var val := UI.label("", 14, UI.VIOLET)
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
	var c3 := CheckBox.new()
	c3.text = "Infection: un-cloned hiders join the Originals"
	c3.button_pressed = bool(settings.get("infect", false))
	c3.toggled.connect(func(b: bool) -> void: settings["infect"] = b)
	g.add_child(c3)
	return g
