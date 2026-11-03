class_name Clone extends CharacterBody3D
## A clone: cute glass bean. Local player, remote player, bot or frozen decoy.
enum {LOCAL, REMOTE, BOT, DECOY}
const SPEED := 6.2
const JUMP := 7.2
const GRAV := 20.0
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D screen_tex: hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float camo = 0.0;
uniform float rim = 0.0;
void fragment() {
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, 2.5);
	vec2 uv = SCREEN_UV + NORMAL.xy * vec2(-0.016, 0.016) * (0.35 + fres);
	vec3 bg = texture(screen_tex, uv).rgb;
	float l = 0.7 + 0.3 * clamp(NORMAL.y * 0.6 + NORMAL.z * 0.5, -1.0, 1.0);
	vec3 solid = tint * l + vec3(0.22) * fres * fres;
	vec3 glass = bg + vec3(1.0) * fres * rim;
	ALBEDO = mix(solid, glass, camo);
}
"""
static var _shader: Shader
var pid := 0
var mode := REMOTE
var game: Node = null
var tint := Color.WHITE
var seeker := false
var alive := true
var frozen := false
var speed_mult := 1.0
var move_input := Vector2.ZERO
var want_jump := false
var yaw_target := 0.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var _visual: Node3D
var _body_mats: Array[ShaderMaterial] = []
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _pupil_mat: StandardMaterial3D
var _feet: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []
var _label: Label3D
var _wand: Node3D
var _crown: Node3D
var _near := false
var _near_t := 0.0
var _camo := 0.0
var _t := randf() * 10.0
var _speed2d := 0.0
var _blink := randf() * 4.0
var _last_pos := Vector3.ZERO
# bot brain
var _bot_goal := Vector3.ZERO
var _bot_t := 0.0
var _bot_fire := 0.0
var ai := false

func setup(id: int, m: int, g: Node, color: Color, shown_name: String) -> void:
	pid = id
	mode = m
	game = g
	tint = color
	collision_layer = 2
	collision_mask = 5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.55
	cs.shape = cap
	cs.position.y = 0.78
	add_child(cs)
	_build(shown_name)

func _part(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else _visual).add_child(mi)
	return mi

func _glass() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_body_mats.append(m)
	return m

func _build(shown_name: String) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var mat := _glass()
	var body := CapsuleMesh.new()
	body.radius = 0.42
	body.height = 1.5
	body.radial_segments = 24
	body.rings = 10
	_part(body, mat, Vector3(0, 0.82, 0))
	var limb := SphereMesh.new()
	limb.radius = 0.15
	limb.height = 0.26
	limb.radial_segments = 12
	limb.rings = 6
	for x: float in [-0.2, 0.2]:
		_feet.append(_part(limb, mat, Vector3(x, 0.1, -0.04)))
	var hand := SphereMesh.new()
	hand.radius = 0.11
	hand.height = 0.22
	hand.radial_segments = 10
	hand.rings = 5
	for x: float in [-0.47, 0.47]:
		_hands.append(_part(hand, mat, Vector3(x, 0.72, -0.04)))
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color.WHITE
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pupil_mat = StandardMaterial3D.new()
	_pupil_mat.albedo_color = Color(0.05, 0.05, 0.1)
	_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pupil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ew := SphereMesh.new()
	ew.radius = 0.135
	ew.height = 0.27
	ew.radial_segments = 12
	ew.rings = 6
	var ep := SphereMesh.new()
	ep.radius = 0.07
	ep.height = 0.14
	ep.radial_segments = 10
	ep.rings = 5
	for x: float in [-0.16, 0.16]:
		var e := _part(ew, _eye_mat, Vector3(x, 1.16, -0.33))
		_part(ep, _pupil_mat, Vector3(0, 0, -0.095), e)
		_eyes.append(e)
	_label = Label3D.new()
	_label.text = shown_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.95
	_label.font_size = 40
	_label.pixel_size = 0.0055
	_label.outline_size = 10
	_label.no_depth_test = false
	add_child(_label)
	_wand = Node3D.new()
	_wand.position = Vector3(0.47, 0.75, -0.12)
	_wand.rotation.x = -1.25
	_visual.add_child(_wand)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.025
	stick.bottom_radius = 0.035
	stick.height = 0.7
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.25, 0.12, 0.45)
	var sm := _part(stick, smat, Vector3(0, 0.3, 0), _wand)
	sm.name = "stick"
	var star := SphereMesh.new()
	star.radius = 0.09
	star.height = 0.18
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 0.9, 0.3)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_part(star, gmat, Vector3(0, 0.68, 0), _wand)
	_crown = Node3D.new()
	_crown.position = Vector3(0, 1.58, 0)
	_visual.add_child(_crown)
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.26
	cmesh.bottom_radius = 0.2
	cmesh.height = 0.2
	cmesh.radial_segments = 8
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.8, 0.15)
	cmat.metallic = 0.4
	_part(cmesh, cmat, Vector3.ZERO, _crown)
	set_role(false)

func camo_amount() -> float: return _camo

func set_role(is_seeker: bool) -> void:
	seeker = is_seeker
	if _wand: _wand.visible = is_seeker
	if _crown: _crown.visible = is_seeker

func set_alive(on: bool) -> void:
	alive = on
	visible = on
	collision_layer = 2 if on else 0
	collision_mask = 5 if on else 0

func teleport(p: Vector3, yaw: float) -> void:
	global_position = p
	net_pos = p
	net_yaw = yaw
	yaw_target = yaw
	rotation.y = yaw
	velocity = Vector3.ZERO
	_last_pos = p

func _physics_process(delta: float) -> void:
	if game == null: return
	match mode:
		LOCAL:
			if ai: _brain(delta)
			_walk(delta)
		BOT:
			_brain(delta)
			_walk(delta)
		REMOTE:
			global_position = global_position.lerp(net_pos, clampf(delta * 14.0, 0.0, 1.0))
			rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 14.0, 0.0, 1.0))
		DECOY: pass

func _walk(delta: float) -> void:
	if not alive: return
	if not is_on_floor(): velocity.y -= GRAV * delta
	var dir := Vector3.ZERO
	if not frozen:
		dir = (Basis(Vector3.UP, yaw_target) * Vector3(move_input.x, 0, move_input.y))
		if dir.length() > 1.0: dir = dir.normalized()
		if want_jump and is_on_floor(): velocity.y = JUMP
	want_jump = false
	var v := dir * SPEED * speed_mult
	velocity.x = lerpf(velocity.x, v.x, clampf(delta * 12.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, v.z, clampf(delta * 12.0, 0.0, 1.0))
	move_and_slide()
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 12.0, 0.0, 1.0))
	if global_position.y < -20.0: global_position = Vector3(0, 3, 0)

func _process(delta: float) -> void:
	if game == null or _visual == null: return
	_t += delta
	var moved := (global_position - _last_pos) * Vector3(1, 0, 1)
	_last_pos = global_position
	_speed2d = lerpf(_speed2d, moved.length() / maxf(delta, 0.001), clampf(delta * 8.0, 0.0, 1.0))
	var w := clampf(_speed2d / SPEED, 0.0, 1.0)
	var s := sin(_t * 13.0)
	_visual.rotation.z = s * 0.11 * w
	_visual.position.y = absf(s) * 0.09 * w
	if _feet.size() == 2:
		_feet[0].position.z = -0.04 + s * 0.2 * w
		_feet[1].position.z = -0.04 - s * 0.2 * w
		_hands[0].position.y = 0.72 + s * 0.07 * w
		_hands[1].position.y = 0.72 - s * 0.07 * w
	_blink -= delta
	if _blink < 0.0: _blink = 2.0 + randf() * 3.5
	var open := 0.1 if _blink < 0.1 else 1.0
	for e in _eyes: e.scale.y = open
	_update_look(delta)

## The chameleon part: near things and standing still you turn to glass.
func _update_look(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var hiding: bool = game.is_hiding_look(self)
	var target := 0.0
	var eye_alpha := 1.0
	_near_t -= delta
	if _near_t <= 0.0 and hiding:
		_near_t = 0.25 + randf() * 0.1
		_near = _check_near()
	if hiding:
		var base: float = game.visibility()
		var moving := _speed2d > 1.0
		var factor := 1.0
		if _near and moving: factor = 1.8
		elif not _near and not moving: factor = 2.0
		elif not _near and moving: factor = 3.2
		var v := clampf(base * factor, 0.0, 1.0)
		var dist := cam.global_position.distance_to(global_position) if cam else 50.0
		v = clampf(v + clampf(1.0 - dist / 5.0, 0.0, 1.0) * 0.14 * minf(base * 5.0, 1.0), 0.0, 1.0)
		var me: bool = (mode == LOCAL)
		if me: v = maxf(v, 0.35)
		target = 1.0 - v
		eye_alpha = clampf(0.05 + base + clampf(1.0 - dist / 7.0, 0.0, 1.0) * 0.8, 0.0, 1.0)
		if me: eye_alpha = 1.0
	_camo = lerpf(_camo, target, clampf(delta * 5.0, 0.0, 1.0))
	for m in _body_mats:
		m.set_shader_parameter("camo", _camo)
		m.set_shader_parameter("rim", (1.0 - _camo) * 0.5 + 0.02)
	_eye_mat.albedo_color.a = eye_alpha
	_pupil_mat.albedo_color.a = eye_alpha
	_label.visible = game.show_label(self)

func _check_near() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.5
	q.shape = sp
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.8)
	q.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

# --- simple bot brain -----------------------------------------------------
func _brain(delta: float) -> void:
	_bot_t -= delta
	_bot_fire -= delta
	if frozen or not alive:
		move_input = Vector2.ZERO
		return
	var goal_near := Vector2(global_position.x - _bot_goal.x, global_position.z - _bot_goal.z).length() < 1.0
	if seeker and game.phase == "seek":
		var tgt: Clone = game.nearest_hider(self, 13.0)
		if tgt:
			_bot_goal = tgt.global_position
			_bot_t = 1.0
			if _bot_fire <= 0.0:
				_bot_fire = 1.1 + randf() * 0.9
				game.ai_fire(self, tgt)
		elif goal_near or _bot_t <= 0.0:
			_bot_goal = game.random_spot()
			_bot_t = 5.0
	else:
		var threat: Clone = game.nearest_seeker(self, 6.0) if game.phase == "seek" else null
		if threat:
			_bot_goal = global_position + (global_position - threat.global_position).normalized() * 6.0
			_bot_t = 0.8
		elif game.phase == "lobby":
			if goal_near or _bot_t <= 0.0:
				_bot_goal = game.random_spot()
				_bot_t = 4.0 + randf() * 3.0
		elif _bot_t <= 0.0 and not _near:
			_bot_goal = game.random_prop_spot()
			_bot_t = 6.0
		elif goal_near:
			move_input = Vector2.ZERO
			return
	var to := _bot_goal - global_position
	to.y = 0.0
	if to.length() < 0.5:
		move_input = Vector2.ZERO
		return
	yaw_target = 0.0
	var d := to.normalized()
	move_input = Vector2(d.x, d.z)
	if is_on_wall() and randf() < 0.05: want_jump = true
