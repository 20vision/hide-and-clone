extends Node3D
## Title screen: the clone crew in a soft studio, one keeps melting into glass.
var phase := "lobby"
var _cam: Camera3D
var _t := 0.0
var _world: Node3D
var _glass_id := -1
var _clones: Array[Clone] = []
const CREW: Array[Color] = [Color("ff4f8b"), Color("3f8cff"), Color("ffb02e"), Color("2fe07a"), Color("a56bff")]

func start() -> void:
	_world = Node3D.new()
	add_child(_world)
	World.make_ground(_world, {"size": 500, "floor": "studio"})
	_cam = Camera3D.new()
	_cam.fov = 34
	add_child(_cam)
	_cam.current = true
	# hero in the middle of the free space, crew behind
	var spots: Array[Vector3] = [Vector3(1.05, 0, -1.4), Vector3(2.75, 0, 0.3), Vector3(4.55, 0, -1.5), Vector3(0.0, 0, 0.0), Vector3(5.75, 0, -0.1)]
	var yaws: Array[float] = [PI + 0.28, PI - 0.08, PI - 0.3, PI + 0.35, PI - 0.42]
	var order: Array[int] = [0, 1, 2, 4, 3]
	for i in 4:
		var c := Clone.new()
		var col := order[i]
		c.setup(-100 - i, Clone.DECOY, self, CREW[col], ["ROBIN", "ALEX", "NOVA", "PIXEL"][i], i)
		add_child(c)
		c.teleport(spots[[0, 1, 2, 4][i]], yaws[[0, 1, 2, 4][i]])
		if i == 1: c.wave_mode = true
		_clones.append(c)

func _process(delta: float) -> void:
	if _cam == null: return
	_t += delta
	_cam.position = Vector3(2.9 + sin(_t * 0.2) * 0.25, 1.35, 8.8)
	_cam.look_at(Vector3(1.55, 1.0, 0))
	_glass_id = [0, 3, 2][int(_t / 3.5) % 3]

func is_hiding_look(c: Clone) -> bool: return _clones.find(c) == _glass_id
func visibility() -> float: return 0.1
func show_label(_c: Clone) -> bool: return false
