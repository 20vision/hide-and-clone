extends SceneTree
## Dev only: renders a lineup of clones to a PNG for checking the figure.
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var out := OS.get_environment("HC_OUT")
	var w := Node3D.new()
	root.add_child(w)
	World.make_ground(w, {"size": 40, "floor": OS.get_environment("HC_FLOOR") if OS.get_environment("HC_FLOOR") != "" else "grass"})
	var stub: Node = load("res://scripts/dev_stub.gd").new()
	root.add_child(stub)
	var colors: Array[Color] = [Color("ff4f8b"), Color("2db8f5"), Color("ffc928"), Color("47d16c"), Color("9a6bff")]
	var cam := Camera3D.new()
	cam.fov = 32
	w.add_child(cam)
	cam.current = true
	var clones: Array[Clone] = []
	for i in 5:
		var c := Clone.new()
		c.setup(i, Clone.DECOY, stub, colors[i], "", i)
		w.add_child(c)
		var yaw := PI if i != 3 else 0.0
		if i == 1: yaw = PI + 0.5
		c.teleport(Vector3((i - 2) * 1.75, 0.02, 0), yaw)
		clones.append(c)
	clones[2].set_role(true)
	stub.glass_ids = [4]
	cam.position = Vector3(0, 1.3, 8.2)
	cam.look_at(Vector3(0, 0.92, 0))
	for i in 30: await process_frame
	clones[2].kick()
	for i in 3: await process_frame
	if OS.get_environment("HC_BEAM") != "":
		cam.position = Vector3(0.9, 2.2, 5.0)
		cam.look_at(Vector3(0, 1.0, -2))
		clones[2].rotation.y = 0.0
		for i in 2: await process_frame
		FX.beam(w, clones[2].wand_tip(), clones[2].wand_tip() + Vector3(-6.5, -0.5, -2.0))
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
