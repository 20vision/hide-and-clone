extends Node
## Catalog of 4,000+ CC0 models, downloaded one by one when a map needs them.
signal item_ready(id: String)
signal thumb_ready(id: String, tex: Texture2D)

var packs: Dictionary = {}
var ids: Array[String] = []
var _known: Dictionary = {}
var _tmpl: Dictionary = {}
var _faces: Dictionary = {}
var _shapes: Dictionary = {}
var _failed: Dictionary = {}
var _queue: Array[String] = []
var _queued: Dictionary = {}
var _active := 0
var _thumbs: Dictionary = {}
var _thumb_q: Array[String] = []
var _thumb_active := 0
var _base := ""

func _ready() -> void:
	packs = JSON.parse_string(FileAccess.get_file_as_string("res://catalog.json"))
	var order: Array[String] = ["furniture-kit", "nature-kit", "city-kit-suburban", "city-kit-commercial", "survival-kit", "food-kit", "factory-kit", "holiday-kit"]
	for p: String in packs:
		if not order.has(p): order.append(p)
	for p: String in order:
		if not packs.has(p): continue
		for n: String in packs[p]["n"]:
			var id := p + "/" + n
			ids.append(id)
			_known[id] = true
	if OS.has_feature("web"):
		_base = str(JavaScriptBridge.eval("location.href.split('?')[0].replace(/[^/]*$/,'')"))
	else:
		_base = OS.get_environment("HC_WEB")
		if _base == "" and OS.has_feature("editor"): _base = ProjectSettings.globalize_path("res://web_extra/")
		if _base == "":
			# Store builds ship the models in gamedata/ next to the exe; a bare exe downloads them.
			var local := OS.get_executable_path().get_base_dir() + "/gamedata/"
			_base = local if DirAccess.dir_exists_absolute(local) else "https://20vision.github.io/hide-and-clone/"

func known(id: String) -> bool: return _known.has(id)
func loaded(id: String) -> bool: return _tmpl.has(id)
func failed(id: String) -> bool: return _failed.has(id)
func default_scale(id: String) -> float: return float(packs[id.split("/")[0]]["s"])
static func pretty(id: String) -> String:
	var n: String = id.split("/")[1].replace("_", " ").replace("-", " ")
	var out := ""
	for i in n.length():
		var c := n[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower() and n[i - 1] != " ": out += " "
		out += c
	return out.capitalize()

func need(id: String) -> void:
	if not known(id) or _tmpl.has(id) or _queued.has(id) or _failed.has(id): return
	_queued[id] = true
	_queue.append(id)
	_pump()

func _pump() -> void:
	while _active < 8 and not _queue.is_empty():
		_active += 1
		_fetch(_queue.pop_front())

func _fetch(id: String) -> void:
	var bytes := await _get_bytes("a/" + id + ".glb")
	if bytes.is_empty(): _failed[id] = true
	else: _parse(id, bytes)
	_active -= 1
	_queued.erase(id)
	item_ready.emit(id)
	_pump()

func _get_bytes(rel: String) -> PackedByteArray:
	if not _base.begins_with("http"):
		await get_tree().process_frame
		return FileAccess.get_file_as_bytes(_base + rel)
	var h := HTTPRequest.new()
	add_child(h)
	h.timeout = 30.0
	h.accept_gzip = false
	h.use_threads = not OS.has_feature("web")
	if h.request(_base + rel) != OK:
		h.queue_free()
		return PackedByteArray()
	var r: Array = await h.request_completed
	h.queue_free()
	return r[3] if int(r[1]) == 200 else PackedByteArray()

func _parse(id: String, bytes: PackedByteArray) -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_buffer(bytes, "", st) != OK:
		_failed[id] = true
		return
	var n := doc.generate_scene(st)
	if n == null:
		_failed[id] = true
		return
	_flatten_metal(n)
	_tmpl[id] = n
	var f := PackedVector3Array()
	_collect(n, Transform3D.IDENTITY, f)
	_faces[id] = f

## Metallic surfaces turn black without reflections, so make them plain.
func _flatten_metal(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i) as BaseMaterial3D
			if mat:
				mat.metallic = 0.0
				mat.roughness = 1.0
				var c := mat.albedo_color
				if c.g > 0.7 and c.b > 0.6 and c.r < 0.6: mat.albedo_color = Color(0.36, 0.7, 0.27) if c.g > 0.85 else Color(0.27, 0.58, 0.25)
				elif c.r > 0.9 and c.g > 0.9 and c.b > 0.85: mat.albedo_color = Color(c.r * 0.97, c.g * 0.92, c.b * 0.83)  # pure white blows out in the sun
	for c in n.get_children(): _flatten_metal(c)

func _collect(n: Node, x: Transform3D, out: PackedVector3Array) -> void:
	var t := x
	if n is Node3D: t = x * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		for v in (n as MeshInstance3D).mesh.get_faces(): out.append(t * v)
	for c in n.get_children(): _collect(c, t, out)

## Visual copy without collision (builder ghost, thumbnails).
func visual(id: String) -> Node3D:
	if not _tmpl.has(id): return null
	return (_tmpl[id] as Node).duplicate() as Node3D

## Placed object with collision. Layer 1 = props.
func prop(id: String, s: float) -> StaticBody3D:
	if not _tmpl.has(id): return null
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var v := visual(id)
	v.scale = Vector3.ONE * s
	b.add_child(v)
	var key := "%s|%.3f" % [id, s]
	if not _shapes.has(key):
		var src: PackedVector3Array = _faces[id]
		var scaled := PackedVector3Array()
		scaled.resize(src.size())
		for i in src.size(): scaled[i] = src[i] * s
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(scaled)
		_shapes[key] = shape
	var cs := CollisionShape3D.new()
	cs.shape = _shapes[key]
	b.add_child(cs)
	return b

func thumb(id: String) -> void:
	if _thumbs.has(id):
		if _thumbs[id] != null: thumb_ready.emit(id, _thumbs[id])
		return
	_thumbs[id] = null
	_thumb_q.append(id)
	_pump_thumbs()

func clear_thumb_queue() -> void:
	for id in _thumb_q: _thumbs.erase(id)
	_thumb_q.clear()

func _pump_thumbs() -> void:
	while _thumb_active < 8 and not _thumb_q.is_empty():
		_thumb_active += 1
		_fetch_thumb(_thumb_q.pop_front())

func _fetch_thumb(id: String) -> void:
	var b := await _get_bytes("t/" + id + ".png")
	if not b.is_empty():
		var img := Image.new()
		if img.load_png_from_buffer(b) == OK:
			var tex := ImageTexture.create_from_image(img)
			_thumbs[id] = tex
			thumb_ready.emit(id, tex)
	_thumb_active -= 1
	_pump_thumbs()
