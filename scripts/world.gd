class_name World extends RefCounted
## Ground, light and sky shared by game and map builder.
const FLOORS := {
	"lab": [Color("b4c2cf"), Color("a4b3c1"), Color("bfe6ff")],
	"grass": [Color("86c95a"), Color("79bd4e"), Color("a7dcff")],
	"wood": [Color("c99a66"), Color("bd8d59"), Color("ffe2c2")],
	"sand": [Color("d4bd86"), Color("c9b27b"), Color("bfeaff")],
	"snow": [Color("d5dfe8"), Color("c8d4de"), Color("d8ecff")],
	"night": [Color("3a4466"), Color("333c5c"), Color("1b2140")],
}
const FLOOR_SHADER := """
shader_type spatial;
uniform vec3 a : source_color; uniform vec3 b : source_color; uniform float cell = 2.0;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
	vec2 c = floor(wp.xz / cell);
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(a, b, k) * 0.62;
	ROUGHNESS = 0.9;
}
"""

static func make_ground(parent: Node3D, map: Dictionary) -> void:
	var size: float = float(map.get("size", 40))
	var f: Array = FLOORS.get(str(map.get("floor", "lab")), FLOORS["lab"])
	var ground := StaticBody3D.new()
	ground.collision_layer = 4
	ground.collision_mask = 0
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sh := Shader.new()
	sh.code = FLOOR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("a", Vector3((f[0] as Color).r, (f[0] as Color).g, (f[0] as Color).b))
	mat.set_shader_parameter("b", Vector3((f[1] as Color).r, (f[1] as Color).g, (f[1] as Color).b))
	mi.material_override = mat
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	cs.shape = box
	cs.position.y = -1.0
	ground.add_child(cs)
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(1.0 if d.x != 0.0 else size + 2.0, 60.0, 1.0 if d.z != 0.0 else size + 2.0)
		wall.shape = wb
		wall.position = d * (size * 0.5 + 0.5) + Vector3.UP * 30.0
		ground.add_child(wall)
	parent.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	parent.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = f[2]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
