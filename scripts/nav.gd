class_name Nav
extends RefCounted
## Walkable-floor grid of a map, measured with real physics. It tells which floor is
## actually connected, so nobody spawns in a sealed room and bots can find the doors.
const CELL := 0.25
const CLEAR := 0.38      # free radius a cell needs; a door 1.04 m wide still has cells
const LIFT := 0.28       # low things like rugs and road tiles don't block
const BODY := 1.45

var ready := false
var n := 0
var half := 0.0
var free_cells := 0
var regions := 0
var main_size := 0
var _region := PackedInt32Array()
var _main := PackedInt32Array()
var _astar: AStarGrid2D
var _paths_this_frame := 0
var _frame := -1

func idx(x: int, z: int) -> int: return z * n + x
func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + half) / CELL), 0, n - 1), clampi(int((p.z + half) / CELL), 0, n - 1))
func to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - half, 0.1, (c.y + 0.5) * CELL - half)

## Runs over many frames so loading never stutters. Check is_valid() to stop on map change.
func build(node: Node, space: PhysicsDirectSpaceState3D, size: float, is_valid: Callable) -> void:
	half = size * 0.5
	n = int(size / CELL)
	var blocked := PackedByteArray()
	blocked.resize(n * n)
	var cap := CapsuleShape3D.new()
	cap.radius = CLEAR
	cap.height = BODY
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	var t := Transform3D()
	var y := LIFT + BODY * 0.5
	var start := Time.get_ticks_usec()
	for z in n:
		for x in n:
			t.origin = Vector3((x + 0.5) * CELL - half, y, (z + 0.5) * CELL - half)
			q.transform = t
			if not space.intersect_shape(q, 1).is_empty(): blocked[idx(x, z)] = 1
		if Time.get_ticks_usec() - start > 7000:
			await node.get_tree().physics_frame
			if not is_valid.call(): return
			start = Time.get_ticks_usec()
	_flood(blocked)
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, n, n)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.jumping_enabled = true
	_astar.update()
	for z in n:
		for x in n:
			if _region[idx(x, z)] < 0: _astar.set_point_solid(Vector2i(x, z), true)
	ready = true

func _flood(blocked: PackedByteArray) -> void:
	_region.resize(n * n)
	_region.fill(-1)
	var best := -1
	var stack := PackedInt32Array()
	stack.resize(n * n)
	for i in n * n:
		if blocked[i] or _region[i] >= 0: continue
		var r := regions
		regions += 1
		var count := 0
		var top := 1
		stack[0] = i
		_region[i] = r
		while top > 0:
			top -= 1
			var c: int = stack[top]
			count += 1
			var x: int = c % n
			if x > 0 and not blocked[c - 1] and _region[c - 1] < 0:
				_region[c - 1] = r; stack[top] = c - 1; top += 1
			if x < n - 1 and not blocked[c + 1] and _region[c + 1] < 0:
				_region[c + 1] = r; stack[top] = c + 1; top += 1
			if c >= n and not blocked[c - n] and _region[c - n] < 0:
				_region[c - n] = r; stack[top] = c - n; top += 1
			if c < n * n - n and not blocked[c + n] and _region[c + n] < 0:
				_region[c + n] = r; stack[top] = c + n; top += 1
		free_cells += count
		if count > main_size:
			main_size = count
			best = r
	_main.resize(main_size)
	var k := 0
	for i in n * n:
		if _region[i] == best:
			_main[k] = i
			k += 1
		else:
			_region[i] = -1   # sealed-off floor counts as not walkable
	regions = maxi(regions, 1)

## Share of the free floor that can really be walked to.
func reachable_share() -> float:
	return float(main_size) / float(maxi(free_cells, 1))

func ok() -> bool: return ready and main_size > 0

## Random connected spot, preferably within radius of the map center.
func random_spot(radius := 1000.0) -> Vector3:
	for i in 40:
		var c: int = _main[randi() % main_size]
		var w := to_world(Vector2i(c % n, c / n))
		if absf(w.x) <= radius and absf(w.z) <= radius: return w
	var c2: int = _main[randi() % main_size]
	return to_world(Vector2i(c2 % n, c2 / n))

## Closest connected spot to any position.
func nearest(p: Vector3) -> Vector3:
	var c := to_cell(p)
	if _region[idx(c.x, c.y)] >= 0: return to_world(c)
	for r in range(1, n):
		for d in range(-r, r + 1):
			for v: Vector2i in [Vector2i(c.x + d, c.y - r), Vector2i(c.x + d, c.y + r), Vector2i(c.x - r, c.y + d), Vector2i(c.x + r, c.y + d)]:
				if v.x >= 0 and v.y >= 0 and v.x < n and v.y < n and _region[idx(v.x, v.y)] >= 0: return to_world(v)
	return p

## World-space route. Only a few per frame so many bots can't cause a hitch; empty = try later.
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_paths_this_frame = 0
	if _paths_this_frame >= 2: return out
	_paths_this_frame += 1
	var a := to_cell(nearest(from))
	var b := to_cell(nearest(to))
	for c: Vector2i in _astar.get_id_path(a, b):
		out.append(to_world(c))
	return out
