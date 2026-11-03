extends SceneTree
## Dev tool: renders one small picture per model for the map builder.
func _init() -> void:
	_run.call_deferred()

func _aabb(n: Node, x: Transform3D, a: Array) -> void:
	var t := x
	if n is Node3D: t = x * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		if a.is_empty(): a.append(b)
		else: a[0] = (a[0] as AABB).merge(b)
	for c in n.get_children(): _aabb(c, t, a)

func _flat(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i) as BaseMaterial3D
			if mat:
				mat.metallic = 0.0
				mat.roughness = 1.0
	for c in n.get_children(): _flat(c)

func _run() -> void:
	var web := OS.get_environment("HC_WEB")
	var limit := int(OS.get_environment("HC_LIMIT"))
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://catalog.json"))
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 28
	vp.add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var n := 0
	for p: String in cat:
		DirAccess.make_dir_recursive_absolute(web + "t/" + p)
		for name: String in cat[p]["n"]:
			var out: String = web + "t/" + p + "/" + name + ".png"
			if FileAccess.file_exists(out): continue
			var bytes := FileAccess.get_file_as_bytes(web + "a/" + p + "/" + name + ".glb")
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_buffer(bytes, "", st) != OK: continue
			var s := doc.generate_scene(st)
			if s == null: continue
			_flat(s)
			vp.add_child(s)
			var a: Array = []
			_aabb(s, Transform3D.IDENTITY, a)
			if not a.is_empty():
				var b: AABB = a[0]
				var c := b.get_center()
				var d := maxf(b.size.length(), 0.01) / (2.0 * tan(deg_to_rad(14.0))) * 1.02
				cam.look_at_from_position(c + Vector3(1, 0.8, 1).normalized() * d, c)
				cam.near = d * 0.05
				cam.far = d * 4.0
			await process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(out)
			s.free()
			n += 1
			if limit > 0 and n >= limit:
				print("thumbs ", n)
				quit()
				return
			if n % 500 == 0: print("thumbs ", n)
	print("thumbs done ", n)
	quit()
