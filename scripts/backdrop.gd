extends Node3D
## Title screen: the clone crew on a little stage, one keeps melting into glass.
var phase := "lobby"
var _cam: Camera3D
var _t := 0.0
var _world: Node3D
var _glass_id := -1
var _clones: Array[Clone] = []
const CREW: Array[Color] = [Color("ff4f8b"), Color("2db8f5"), Color("ffc928"), Color("47d16c"), Color("9a6bff")]

func start() -> void:
	_world = Node3D.new()
	add_child(_world)
	var m: Dictionary = {"size": 70, "floor": "grass", "o": []}
	for b: Dictionary in Maps.builtin:
		if str(b.get("name", "")) == "Forest Camp": m = b
	World.make_ground(_world, m)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	_cam.current = true
	_stage()
	_load_props(m)
	for i in 5:
		var c := Clone.new()
		c.setup(-100 - i, Clone.DECOY, self, CREW[i], "", i)
		add_child(c)
		c.teleport(Vector3(0.75 + i * 1.28, 0.42 if i != 2 else 0.84, 0.0 if i != 2 else -0.5), PI)
		_clones.append(c)

func _stage() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.2
	cyl.bottom_radius = 4.5
	cyl.height = 0.42
	cyl.radial_segments = 48
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3d7bff")
	m.roughness = 0.6
	mi.material_override = m
	mi.position = Vector3(3.3, 0.21, 0)
	_world.add_child(mi)
	var top := CylinderMesh.new()
	top.top_radius = 1.0
	top.bottom_radius = 1.05
	top.height = 0.42
	top.radial_segments = 32
	var pod := MeshInstance3D.new()
	pod.mesh = top
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("ff4f8b")
	pod.material_override = pm
	pod.position = Vector3(3.31, 0.63, -0.5)
	_world.add_child(pod)

func _load_props(m: Dictionary) -> void:
	var near: Array = []
	for e: Array in m.get("o", []):
		if float(e[3]) < -6.0 and absf(float(e[1]) - 2.0) < 30.0 and float(e[3]) > -34.0: near.append(e)
	for e: Array in near: Cat.need(e[0])
	var placed := {}
	while placed.size() < near.size():
		for i in near.size():
			if placed.has(i): continue
			var e: Array = near[i]
			if Cat.failed(e[0]):
				placed[i] = true
			elif Cat.loaded(e[0]):
				var b := Cat.prop(e[0], e[5])
				b.position = Vector3(e[1], e[2], e[3])
				b.rotation.y = e[4]
				if is_instance_valid(_world): _world.add_child(b)
				placed[i] = true
		await get_tree().process_frame
		if not is_inside_tree(): return

func _process(delta: float) -> void:
	if _cam == null: return
	_t += delta
	_cam.position = Vector3(0.9 + sin(_t * 0.18) * 0.4, 1.75, 10.0)
	_cam.look_at(Vector3(0.9, 1.35, 0))
	_glass_id = [0, 4, 1, 3][int(_t / 3.0) % 4]

func is_hiding_look(c: Clone) -> bool: return _clones.find(c) == _glass_id
func visibility() -> float: return 0.1
func show_label(_c: Clone) -> bool: return false
