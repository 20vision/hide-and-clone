class_name FX extends RefCounted
static func beam(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var len_: float = from.distance_to(to)
	c.top_radius = 0.035
	c.bottom_radius = 0.035
	c.height = maxf(len_, 0.01)
	c.radial_segments = 6
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = (from + to) * 0.5
	if len_ > 0.01:
		var dir := (to - from) / len_
		var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
		var x := up.cross(dir).normalized()
		mi.global_basis = Basis(x, dir, x.cross(dir))
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, 0.22)
	t.tween_callback(mi.queue_free)
	splash(parent, to, Color(1.0, 0.92, 0.35), 6)

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
	s.radius = 0.08
	s.height = 0.16
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = m
	p.mesh = s
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
