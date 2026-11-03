extends SceneTree
## Dev only: real robots run around a real map; counts wall crossings and stuck time.
var bots: Array = []
var t := 0.0
var cross := 0
var stuck := 0.0
var frames := 0
var space
func _init() -> void: _run.call_deferred()
func _map() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://maps/%s.json" % OS.get_environment("HC_MAP")))
func _run() -> void:
	await process_frame
	var cat: Node = root.get_node("Cat")
	var m := _map()
	var w := Node3D.new()
	root.add_child(w)
	World.make_ground(w, m)
	var ids := {}
	for e: Array in m["o"]: ids[e[0]] = true
	for id: String in ids: cat.need(id)
	for i in 900:
		await process_frame
		var left := 0
		for id: String in ids:
			if not cat.loaded(id) and not cat.failed(id): left += 1
		if left == 0: break
	for e: Array in m["o"]:
		var b: StaticBody3D = cat.prop(e[0], e[5])
		if b:
			b.position = Vector3(e[1], e[2], e[3])
			b.rotation.y = e[4]
			w.add_child(b)
	var stub: Node = load("res://scripts/dev_stub.gd").new()
	root.add_child(stub)
	stub.phase = "lobby"
	await physics_frame
	await physics_frame
	space = w.get_world_3d().direct_space_state
	var nav := Nav.new()
	var t1 := Time.get_ticks_msec()
	await nav.build(w, space, float(m["size"]), func() -> bool: return true)
	print("NAV map=%s ms=%d free=%d main=%d reachable=%.1f%% regions=%d" % [OS.get_environment("HC_MAP"), Time.get_ticks_msec() - t1, nav.free_cells, nav.main_size, nav.reachable_share() * 100.0, nav.regions])
	if OS.get_environment("HC_SECS") == "0": quit(); return
	if OS.get_environment("HC_MODE") == "route":
		stub.nav = nav
		await _routes(w, stub, nav, m)
		quit()
		return
	var half: float = float(m["size"]) * 0.5 - 1.5
	for i in 12:
		var c := Clone.new()
		c.setup(i + 1, Clone.LOCAL, stub, Color.WHITE, "B", i)
		w.add_child(c)
		var p := Vector3.ZERO
		for k in 200:
			p = Vector3(randf_range(-half, half), 0.1, randf_range(-half, half))
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = (c.get_child(0) as CollisionShape3D).shape
			q.transform = Transform3D(Basis(), p + Vector3.UP * 1.0)
			q.collision_mask = 1
			if space.intersect_shape(q, 1).is_empty(): break
		c.teleport(p, 0.0)
		bots.append({"c": c, "t": 0.0, "prev": p, "stuck": 0.0, "last": p})
	var secs := float(OS.get_environment("HC_SECS") if OS.get_environment("HC_SECS") != "" else "60")
	var t0 := Time.get_ticks_msec()
	while t < secs:
		await physics_frame
		_step(1.0 / 60.0)
	print("RESULT map=%s engine=%s sim=%ds wall_ms=%d crossings=%d stuck_robot_seconds=%.1f" % [OS.get_environment("HC_MAP"), ProjectSettings.get_setting("physics/3d/physics_engine"), int(secs), Time.get_ticks_msec() - t0, cross, stuck])
	quit()
func _hit(a: Vector3, b: Vector3) -> bool:
	if a.distance_squared_to(b) < 0.000001: return false
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.hit_from_inside = false
	return not space.intersect_ray(q).is_empty()
func _step(dt: float) -> void:
	t += dt
	for b: Dictionary in bots:
		var c: Clone = b["c"]
		b["t"] -= dt
		if b["t"] <= 0.0:
			b["t"] = randf_range(0.5, 3.0)
			var a := randf() * TAU
			c.move_input = Vector2(cos(a), sin(a))
			c.yaw_target = 0.0
			if randf() < 0.3: c.want_jump = true
		var p: Vector3 = c.global_position
		var pv: Vector3 = b["prev"]
		if absf(p.y - pv.y) < 0.2 and (_hit(pv + Vector3.UP * 0.55, p + Vector3.UP * 0.55) or _hit(pv + Vector3.UP * 1.25, p + Vector3.UP * 1.25)):
			cross += 1
		b["prev"] = p
		if p.distance_to(b["last"]) < 0.01 * 60.0 * dt * 0.1 and c.is_on_floor():
			stuck += dt
		b["last"] = p

## Real robots walk to random far spots through the map's doors.
func _routes(w: Node3D, stub: Node, nav: Nav, m: Dictionary) -> void:
	var list: Array = []
	for i in 8:
		var c := Clone.new()
		c.setup(i + 1, Clone.LOCAL, stub, Color.WHITE, "B", i)
		w.add_child(c)
		c.teleport(nav.random_spot(), 0.0)
		c._bot_goal = nav.random_spot()
		list.append({"c": c, "t": 0.0, "from": c.global_position})
	var ok := 0
	var fail := 0
	var longest := 0.0
	var secs := 0.0
	while secs < 200.0:
		await physics_frame
		secs += 1.0 / 60.0
		for b: Dictionary in list:
			var c: Clone = b["c"]
			b["t"] += 1.0 / 60.0
			var g: Vector3 = c._bot_goal
			c._follow(1.0 / 60.0)
			if c._bot_goal != g: # gave up and took a new goal
				fail += 1
				b["t"] = 0.0
			var d := Vector2(c.global_position.x - c._bot_goal.x, c.global_position.z - c._bot_goal.z).length()
			if d < 1.0:
				ok += 1
				longest = maxf(longest, b["t"])
				b["t"] = 0.0
				c._bot_goal = nav.random_spot()
				c._route.clear()
			elif b["t"] > 40.0:
				print("TIMEOUT at ", c.global_position, " goal ", c._bot_goal)
				fail += 1
				b["t"] = 0.0
				c._bot_goal = nav.random_spot()
				c._route.clear()
	print("ROUTES map=%s arrived=%d failed=%d slowest=%.1fs" % [OS.get_environment("HC_MAP"), ok, fail, longest])
