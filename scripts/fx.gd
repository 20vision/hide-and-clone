class_name FX extends RefCounted
static func _add_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	return m

## Magic bolt: white-hot core, golden glow, flash at the wand and burst on impact.
static func beam(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var len_: float = from.distance_to(to)
	var mid := (from + to) * 0.5
	var basis_ := Basis.IDENTITY
	if len_ > 0.01:
		var dir := (to - from) / len_
		var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
		var x := up.cross(dir).normalized()
		basis_ = Basis(x, dir, x.cross(dir))
	for layer: Array in [[0.34, Color(1.0, 0.35, 0.6, 0.3)], [0.17, Color(1.0, 0.75, 0.1, 0.75)], [0.065, Color(1.0, 1.0, 0.92, 1.0)]]:
		var c := CylinderMesh.new()
		c.top_radius = layer[0]
		c.bottom_radius = layer[0]
		c.height = maxf(len_, 0.01)
		c.radial_segments = 10
		c.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = c
		var m := _add_mat(layer[1])
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = mid
		mi.global_basis = basis_
		var t := mi.create_tween()
		t.set_parallel(true)
		t.tween_property(m, "albedo_color:a", 0.0, 0.38)
		t.tween_property(mi, "scale", Vector3(0.25, 1.0, 0.25), 0.38)
		t.chain().tween_callback(mi.queue_free)
	_burst(parent, from, 0.42, Color(1.0, 0.9, 0.45, 0.9))
	_burst(parent, to, 0.7, Color(1.0, 0.72, 0.3, 0.85))
	splash(parent, to, Color(1.0, 0.86, 0.3), 16)

static func _burst(parent: Node3D, at: Vector3, r: float, c: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = s
	var m := _add_mat(c)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * 0.3
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * 1.3, 0.22).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, 0.26)
	t.chain().tween_callback(mi.queue_free)

static func splash(parent: Node3D, at: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	s.radial_segments = 12
	s.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = m
	p.mesh = s
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
