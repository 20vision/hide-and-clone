extends SceneTree
## Dev only: renders the robot next to the reference for checking the look.
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var out := OS.get_environment("HC_OUT")
	var w := Node3D.new()
	root.add_child(w)
	var fl := OS.get_environment("HC_FLOOR")
	World.make_ground(w, {"size": 40, "floor": fl if fl != "" else "lab"})
	var stub: Node = load("res://scripts/dev_stub.gd").new()
	root.add_child(stub)
	stub.phase = "lobby"
	var colors: Array[Color] = [Color("3f8cff"), Color("ff4f8b"), Color("47d16c")]
	var cam := Camera3D.new()
	cam.fov = 26
	w.add_child(cam)
	cam.current = true
	var mode := OS.get_environment("HC_MODE")
	var c := Clone.new()
	c.setup(1, Clone.DECOY, stub, colors[0], "ALEX", 0)
	w.add_child(c)
	c.teleport(Vector3(0, 0.0, 0), PI - 0.25)
	if mode == "wave": c.wave_mode = true
	cam.position = Vector3(0, 1.15, 6.6)
	cam.look_at(Vector3(0, 0.92, 0))
	var extra: Array[Clone] = []
	if mode == "lineup":
		cam.position = Vector3(0, 1.3, 10.5)
		cam.look_at(Vector3(0, 0.9, 0))
		for i in 2:
			var e := Clone.new()
			e.setup(2 + i, Clone.DECOY, stub, colors[1 + i], "BOT", 1 + i)
			w.add_child(e)
			e.teleport(Vector3(-2.0 + i * 4.0, 0.0, 0), PI + (0.5 if i == 0 else -0.5))
			extra.append(e)
		extra[0].set_role(true)
		stub.phase = "seek"
	if mode == "anim":
		cam.position = Vector3(3.2, 1.25, 5.6)
		cam.look_at(Vector3(0, 0.95, 0))
		c.rotation.y = -PI * 0.5
		var images: Array[Image] = []
		var x := 0.0
		for f in 60:
			x += 0.1
			c.position.x = 0.0
			c.set("_last_pos", c.global_position - Vector3(0.1, 0, 0))
			if f == 34: c.set("_vy", 7.0)
			if f >= 34 and f < 46: c.position.y = 0.9 * sin((f - 34) / 12.0 * PI); 
			if f >= 46: c.position.y = 0.0
			await process_frame
			if f % 7 == 6:
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image())
		var base: Image = images[0]
		for i in images.size(): images[i].save_png(out.replace(".png", "_%d.png" % i))
		quit()
		return
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
