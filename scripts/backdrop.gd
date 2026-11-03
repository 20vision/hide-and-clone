extends Node3D
## Title screen scene: a row of clones, one keeps melting into glass.
var phase := "lobby"
var _cam: Camera3D
var _t := 0.0
var _world: Node3D
var _glass_id := -1
var _clones: Array[Clone] = []

func start() -> void:
	_world = Node3D.new()
	add_child(_world)
	var m: Dictionary = Maps.builtin[0] if not Maps.builtin.is_empty() else {"size": 40, "floor": "lab", "o": []}
	World.make_ground(_world, m)
	_cam = Camera3D.new()
	_cam.fov = 55
	add_child(_cam)
	_cam.current = true
	_load_props(m)
	for i in 5:
		var c := Clone.new()
		c.setup(-100 - i, Clone.DECOY, self, Game_COLORS()[i], "")
		add_child(c)
		c.teleport(Vector3(-1.6 + i * 1.7, 0.0, 0.0), PI)
		_clones.append(c)

func Game_COLORS() -> Array[Color]:
	return [Color("ff5d8f"), Color("4cc9f0"), Color("ffd166"), Color("7ae582"), Color("b388ff")]

func _load_props(m: Dictionary) -> void:
	var near: Array = []
	for e: Array in m.get("o", []):
		if float(e[3]) < -5.0 and absf(float(e[1])) < 22.0: near.append(e)
	for e: Array in near: Cat.need(e[0])
	var want := near.size()
	var placed := {}
	while placed.size() < want:
		for i in near.size():
			if placed.has(i): continue
			var e: Array = near[i]
			if Cat.failed(e[0]):
				placed[i] = true
				continue
			if Cat.loaded(e[0]):
				var b := Cat.prop(e[0], e[5])
				b.position = Vector3(e[1], e[2], e[3])
				b.rotation.y = e[4]
				if is_instance_valid(_world):
					_world.add_child(b)
				placed[i] = true
		await get_tree().process_frame
		if not is_inside_tree(): return

func _process(delta: float) -> void:
	if _cam == null: return
	_t += delta
	_cam.position = Vector3(sin(_t * 0.15) * 1.5, 2.1, 7.5)
	_cam.look_at(Vector3(0, 0.9, 0))
	_glass_id = int(_t / 3.0) % 5

func is_hiding_look(c: Clone) -> bool: return _clones.find(c) == _glass_id
func visibility() -> float: return 0.12
func show_label(_c: Clone) -> bool: return false
