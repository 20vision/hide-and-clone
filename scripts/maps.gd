extends Node
## Saved maps: your own, every map you played on, and the built-in ones.
## Map = {id,name,floor,size,o:[[asset,x,y,z,yaw,scale],...],src,star,last}
const DIR := "user://maps/"
var builtin: Array = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in ["clone_lab", "tiny_town", "cozy_house", "forest_camp"]:
		var t := FileAccess.get_file_as_string("res://maps/%s.json" % f)
		if t != "":
			var m: Variant = JSON.parse_string(t)
			if m is Dictionary:
				var c := clean(m)
				c["src"] = "builtin"
				builtin.append(c)

static func content_id(m: Dictionary) -> String:
	return JSON.stringify([m.get("floor", ""), m.get("size", 0), m.get("o", [])]).md5_text().substr(0, 12)

## Keeps only valid data from a map that came over the network or from disk.
static func clean(m: Variant) -> Dictionary:
	if not m is Dictionary: return {}
	var out := {"name": str(m.get("name", "Untitled")).substr(0, 40), "floor": str(m.get("floor", "lab")).substr(0, 12)}
	out["size"] = clampf(float(m.get("size", 40)), 16.0, 200.0)
	var o: Array = []
	var raw: Variant = m.get("o", [])
	if raw is Array:
		for e: Variant in raw:
			if e is Array and e.size() == 6 and Cat.known(str(e[0])) and o.size() < 2000:
				o.append([str(e[0]), float(e[1]), float(e[2]), float(e[3]), float(e[4]), clampf(float(e[5]), 0.1, 20.0)])
	out["o"] = o
	out["id"] = content_id(out)
	return out

func save_map(m: Dictionary) -> void:
	var path: String = DIR + str(m["id"]) + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(m))
		f.close()

func get_map(id: String) -> Dictionary:
	var t := FileAccess.get_file_as_string(DIR + id + ".json")
	var v: Variant = JSON.parse_string(t) if t != "" else null
	if v is Dictionary: return v
	return {}

## Every game you join or host lands here, so the map can be reused later.
func remember(m: Dictionary, src := "played") -> Dictionary:
	var c := clean(m)
	if c.is_empty(): return c
	var old := get_map(str(c["id"]))
	c["src"] = old.get("src", src)
	c["star"] = old.get("star", false)
	if old.has("name"): c["name"] = old["name"]
	c["last"] = Time.get_unix_time_from_system()
	save_map(c)
	return c

func all_saved() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			var m := get_map(f.get_basename())
			if not m.is_empty(): out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("last", 0)) > float(b.get("last", 0)))
	return out

func all_maps() -> Array:
	var seen := {}
	var out: Array = []
	for m: Dictionary in all_saved() + builtin:
		var id := str(m.get("id", ""))
		if seen.has(id): continue
		seen[id] = true
		out.append(m)
	return out

func rename(id: String, new_name: String) -> void:
	var m := get_map(id)
	if m.is_empty(): return
	m["name"] = new_name.substr(0, 40)
	save_map(m)

func set_star(m: Dictionary, on: bool) -> void:
	var s := remember(m, str(m.get("src", "played")))
	s["star"] = on
	save_map(s)

func delete_map(id: String) -> void:
	DirAccess.remove_absolute(DIR + id + ".json")
