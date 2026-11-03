extends SceneTree
## Dev only: contact sheet of candidate characters in the game's light.
func _init() -> void: _run.call_deferred()
func _aabb(n: Node, x: Transform3D, a: Array) -> void:
	var t := x
	if n is Node3D: t = x * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		a[0] = b if a[0] == null else (a[0] as AABB).merge(b)
	for c in n.get_children(): _aabb(c, t, a)
func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	World.make_ground(w, {"size": 60, "floor": "grass"})
	var cam := Camera3D.new()
	cam.fov = 30
	w.add_child(cam)
	cam.current = true
	var files := FileAccess.get_file_as_string(OS.get_environment("HC_LIST")).strip_edges().split("\n")
	var base := OS.get_environment("HC_BASE")
	var cols := 8
	var i := 0
	for f in files:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(base + f, st) != OK:
			print("FAIL ", f)
			continue
		var s := doc.generate_scene(st)
		if s == null: continue
		var a: Array = [null]
		_aabb(s, Transform3D.IDENTITY, a)
		var b: AABB = a[0] if a[0] != null else AABB(Vector3.ZERO, Vector3.ONE)
		var k := 1.7 / maxf(b.size.y, 0.01)
		(s as Node3D).scale = Vector3.ONE * k
		var col := i % cols
		var row := i / cols
		(s as Node3D).position = Vector3((col - 3.5) * 2.1, 0.0, -row * 3.2)
		w.add_child(s)
		var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var names := ap.get_animation_list() if ap else PackedStringArray()
		print(i, " ", f.get_file(), " anims=", names.size(), " ", ", ".join(names.slice(0, 6)))
		if ap and names.size() > 0:
			var pick := names[0]
			for n: String in names:
				if n.to_lower().contains("idle"):
					pick = n
					break
			ap.play(pick)
		i += 1
	cam.position = Vector3(0, 3.6, 13.5)
	cam.look_at(Vector3(0, 0.6, -1.5))
	for j in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("HC_OUT"))
	quit()
