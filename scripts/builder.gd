extends Node3D
## Map builder: pick from thousands of models, click to place, hit Play.
const PAGE := 40
const GROUND_LAYERS := 1 | 4
var main: Node
var map: Dictionary = {}
var objects: Array = []  # [asset,x,y,z,yaw,scale]
var nodes: Array = []
var undo: Array = []
var world: Node3D
var cam: Camera3D
var ghost: Node3D
var ghost_id := ""
var ghost_scale_mult := 1.0
var ghost_yaw := 0.0
var snap := true
var erase := false
var focus := Vector3.ZERO
var cam_yaw := 0.7
var cam_pitch := -0.85
var cam_dist := 26.0
var filtered: Array[String] = []
var page := 0
var search: LineEdit
var pack_opt: OptionButton
var grid: GridContainer
var page_l: Label
var name_in: LineEdit
var info: Label
var layer: CanvasLayer
var panel_root: PanelContainer
var _thumb_rects: Dictionary = {}
var _rmb := false
var _size := 40.0
var _floor := "lab"

func setup(m: Node, src: Dictionary) -> void:
	main = m
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Dictionary = Maps.clean(src) if not src.is_empty() else {"name": "My map", "floor": "lab", "size": 40.0, "o": []}
	_size = float(c["size"])
	_floor = str(c["floor"])
	map = c
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 800
	add_child(cam)
	cam.current = true
	_rebuild_ground()
	_ui(str(c["name"]))
	Cat.thumb_ready.connect(_on_thumb)
	Cat.item_ready.connect(_on_item)
	for e: Array in c["o"]:
		objects.append(e.duplicate())
		nodes.append(null)
		Cat.need(e[0])
	_place_all_loaded()
	_filter()

func _rebuild_ground() -> void:
	if world: world.queue_free()
	world = Node3D.new()
	add_child(world)
	World.make_ground(world, {"size": _size, "floor": _floor})
	for i in nodes.size(): nodes[i] = null
	_place_all_loaded()

func _on_item(_id: String) -> void:
	_place_all_loaded()
	if ghost_id != "" and ghost == null: _make_ghost()

func _place_all_loaded() -> void:
	for i in objects.size():
		if nodes[i] == null and Cat.loaded(objects[i][0]): _spawn(i)

func _spawn(i: int) -> void:
	var e: Array = objects[i]
	var b := Cat.prop(e[0], e[5])
	if b == null: return
	b.position = Vector3(e[1], e[2], e[3])
	b.rotation.y = e[4]
	b.set_meta("idx", i)
	world.add_child(b)
	nodes[i] = b

func _ui(n: String) -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	var top := UI.panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	layer.add_child(top)
	var row := UI.hbox(8)
	top.add_child(row)
	row.add_child(UI.button("BACK", Color("5a5f9e"), 15, func() -> void: main.leave_builder()))
	name_in = UI.input("Map name", n, 16)
	name_in.custom_minimum_size = Vector2(220, 0)
	row.add_child(name_in)
	var fl := OptionButton.new()
	for k: String in World.FLOORS: fl.add_item(k.capitalize())
	fl.select(World.FLOORS.keys().find(_floor))
	fl.item_selected.connect(func(i: int) -> void:
		_floor = World.FLOORS.keys()[i]
		_rebuild_ground())
	row.add_child(fl)
	var sz := OptionButton.new()
	var sizes: Array = [24.0, 40.0, 60.0, 90.0, 130.0]
	for s: float in sizes: sz.add_item("%dm" % int(s))
	sz.select(maxi(sizes.find(_size), 0))
	sz.item_selected.connect(func(i: int) -> void:
		_size = sizes[i]
		_rebuild_ground())
	row.add_child(sz)
	var sn := CheckBox.new()
	sn.text = "Snap"
	sn.button_pressed = true
	sn.toggled.connect(func(b: bool) -> void: snap = b)
	row.add_child(sn)
	row.add_child(UI.button("UNDO", Color("3a3ea8"), 15, _undo))
	var er := UI.button("ERASER", Color("7a3350"), 15)
	er.pressed.connect(func() -> void:
		erase = not erase
		er.text = "ERASING" if erase else "ERASER"
		if erase: _set_ghost(""))
	row.add_child(er)
	row.add_child(UI.button("SAVE", Color("14bf8e"), 15, _save))
	row.add_child(UI.button("PLAY THIS MAP", Color("ff4f8b"), 18, func() -> void:
		var m := _save()
		var s: Dictionary = main.game.DEFAULTS.duplicate()
		main.play_host(m, s)))
	panel_root = UI.panel()
	panel_root.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel_root.offset_top = 72
	panel_root.offset_bottom = -8
	panel_root.offset_left = 8
	panel_root.offset_right = 318
	layer.add_child(panel_root)
	var v := UI.vbox(6)
	panel_root.add_child(v)
	search = UI.input("Search %d objects…" % Cat.ids.size(), "", 15)
	search.text_changed.connect(func(_s: String) -> void:
		page = 0
		_filter())
	v.add_child(search)
	pack_opt = OptionButton.new()
	pack_opt.add_item("All kits")
	for p: String in Cat.packs: pack_opt.add_item(p.replace("-kit", "").replace("-", " ").capitalize())
	pack_opt.item_selected.connect(func(_i: int) -> void:
		page = 0
		_filter())
	v.add_child(pack_opt)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(grid)
	v.add_child(sc)
	var pg := UI.hbox()
	pg.add_child(UI.button("PREV", Color("3a3ea8"), 13, func() -> void:
		page = maxi(page - 1, 0)
		_render_grid()))
	page_l = UI.label("", 14)
	page_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pg.add_child(page_l)
	pg.add_child(UI.button("NEXT", Color("3a3ea8"), 13, func() -> void:
		page = mini(page + 1, _last_page())
		_render_grid()))
	v.add_child(pg)
	info = UI.label("", 14, Color.WHITE)
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_left = 330
	info.offset_top = -30
	info.offset_bottom = -6
	info.add_theme_constant_override("outline_size", 5)
	info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	layer.add_child(info)
	_update_info()

func _update_info() -> void:
	info.text = "%d objects · Click place · R rotate · [ ] size · Right-drag look · Scroll zoom · WASD move · Ctrl+Z undo" % objects.size()

func _last_page() -> int: return maxi((filtered.size() - 1) / PAGE, 0)

func _filter() -> void:
	filtered.clear()
	var q := search.text.strip_edges().to_lower().replace(" ", "")
	var sel := pack_opt.selected
	var pack := "" if sel <= 0 else (Cat.packs.keys()[sel - 1] as String)
	for id in Cat.ids:
		if pack != "" and not id.begins_with(pack + "/"): continue
		if q != "" and not id.to_lower().replace("-", "").replace("_", "").contains(q): continue
		filtered.append(id)
	_render_grid()

func _render_grid() -> void:
	Cat.clear_thumb_queue()
	_thumb_rects.clear()
	for c in grid.get_children(): c.queue_free()
	page_l.text = "%d / %d · %d items" % [page + 1, _last_page() + 1, filtered.size()]
	var from := page * PAGE
	for i in range(from, mini(from + PAGE, filtered.size())):
		var id := filtered[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(92, 92)
		b.tooltip_text = Cat.pretty(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_stylebox_override("normal", UI.style(Color("2a2d82"), 10))
		b.add_theme_stylebox_override("hover", UI.style(Color("4a4fd0"), 10))
		b.add_theme_stylebox_override("pressed", UI.style(Color("ff4f8b"), 10))
		b.pressed.connect(func() -> void: _set_ghost(id))
		grid.add_child(b)
		_thumb_rects[id] = b
		Cat.thumb(id)

func _on_thumb(id: String, tex: Texture2D) -> void:
	if _thumb_rects.has(id) and is_instance_valid(_thumb_rects[id]):
		(_thumb_rects[id] as Button).icon = tex

func _set_ghost(id: String) -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	ghost_id = id
	ghost_scale_mult = 1.0
	if id == "": return
	erase = false
	Cat.need(id)
	_make_ghost()

func _make_ghost() -> void:
	if ghost or ghost_id == "": return
	ghost = Cat.visual(ghost_id)
	if ghost:
		world.add_child(ghost)
		ghost.scale = Vector3.ONE * Cat.default_scale(ghost_id) * ghost_scale_mult

func _ray() -> Dictionary:
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 700.0
	var q := PhysicsRayQueryParameters3D.create(from, to, GROUND_LAYERS)
	return get_world_3d().direct_space_state.intersect_ray(q)

func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _process(delta: float) -> void:
	cam_tick(delta)
	if ghost:
		var r := _ray()
		ghost.visible = not r.is_empty() and not _over_ui()
		if r:
			var p: Vector3 = r["position"]
			if snap:
				p.x = snappedf(p.x, 0.5)
				p.z = snappedf(p.z, 0.5)
			ghost.global_position = p
			ghost.rotation.y = ghost_yaw

func cam_tick(delta: float) -> void:
	if not name_in.has_focus() and not search.has_focus():
		var v := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): v.z -= 1
		if Input.is_physical_key_pressed(KEY_S): v.z += 1
		if Input.is_physical_key_pressed(KEY_A): v.x -= 1
		if Input.is_physical_key_pressed(KEY_D): v.x += 1
		focus += Basis(Vector3.UP, cam_yaw) * v * delta * cam_dist * 0.9
	var half := _size * 0.5
	focus.x = clampf(focus.x, -half, half)
	focus.z = clampf(focus.z, -half, half)
	var b := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch)
	cam.global_transform = Transform3D(b, focus + b * Vector3(0, 0, cam_dist))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT: _rmb = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: cam_dist = maxf(cam_dist * 0.9, 4.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: cam_dist = minf(cam_dist * 1.1, 200.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed: _click()
	elif e is InputEventMouseMotion and _rmb:
		cam_yaw -= (e as InputEventMouseMotion).relative.x * 0.005
		cam_pitch = clampf(cam_pitch - (e as InputEventMouseMotion).relative.y * 0.005, -1.45, -0.1)
	elif e is InputEventKey and e.is_pressed():
		var k := e as InputEventKey
		match k.physical_keycode:
			KEY_R: ghost_yaw += PI / 4.0
			KEY_BRACKETLEFT: _rescale(0.9)
			KEY_BRACKETRIGHT: _rescale(1.1)
			KEY_ESCAPE: _set_ghost("")
			KEY_Z: if k.ctrl_pressed: _undo()

func _rescale(f: float) -> void:
	ghost_scale_mult = clampf(ghost_scale_mult * f, 0.1, 10.0)
	if ghost: ghost.scale = Vector3.ONE * Cat.default_scale(ghost_id) * ghost_scale_mult

func _click() -> void:
	var r := _ray()
	if r.is_empty(): return
	if erase:
		var c: Object = r.get("collider")
		if c and c.has_meta("idx"): _remove(int(c.get_meta("idx")))
		return
	if ghost == null or not ghost.visible: return
	var p := ghost.global_position
	var s := snappedf(Cat.default_scale(ghost_id) * ghost_scale_mult, 0.001)
	if objects.size() >= 2000:
		info.text = "This map is full (2,000 objects)."
		return
	objects.append([ghost_id, snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(ghost_yaw, 0.001), s])
	nodes.append(null)
	undo.append(["add"])
	_spawn(objects.size() - 1)
	_update_info()

func _remove(i: int) -> void:
	undo.append(["del", objects[i]])
	if nodes[i]: nodes[i].queue_free()
	objects.remove_at(i)
	nodes.remove_at(i)
	for j in range(i, nodes.size()):
		if nodes[j]: nodes[j].set_meta("idx", j)
	_update_info()

func _undo() -> void:
	if undo.is_empty(): return
	var u: Array = undo.pop_back()
	if u[0] == "add":
		var i := objects.size() - 1
		if i >= 0:
			if nodes[i]: nodes[i].queue_free()
			objects.remove_at(i)
			nodes.remove_at(i)
	else:
		objects.append(u[1])
		nodes.append(null)
		_spawn(objects.size() - 1)
	_update_info()

func _save() -> Dictionary:
	var m := Maps.clean({"name": name_in.text if name_in.text.strip_edges() != "" else "My map", "floor": _floor, "size": _size, "o": objects})
	m["src"] = "mine"
	m["last"] = Time.get_unix_time_from_system()
	var old := Maps.get_map(str(m["id"]))
	m["star"] = old.get("star", false)
	Maps.save_map(m)
	info.text = "Saved “%s”." % m["name"]
	return m
