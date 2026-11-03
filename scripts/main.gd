extends Node
## Screens: menu ↔ builder ↔ game.
@onready var game: Node3D = $Game
var menu_layer: CanvasLayer
var hud: CanvasLayer
var builder: Node3D
var menu: Control
var player_name := "Clone"

func _ready() -> void:
	var beat := Timer.new()
	beat.wait_time = 60.0
	beat.autostart = true
	beat.timeout.connect(_beat)
	add_child(beat)
	_beat.call_deferred()
	randomize()
	ThemeDB.fallback_font = UI.body_font()
	ThemeDB.get_default_theme().merge_with(UI.theme())
	_pad_actions()
	player_name = _load_name()
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)
	hud.build(game)
	game.hud = hud
	game.left_game.connect(_back_to_menu)
	Net.failed.connect(_on_net_failed)
	_show_menu()
	track("clone_open", {})
	_auto()

## Lets the left stick move through menus, not only the D-pad.
func _pad_actions() -> void:
	for a: Array in [["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[1]
		ev.axis_value = a[2]
		InputMap.action_add_event(a[0], ev)
	for a: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var btn := InputEventJoypadButton.new()
		btn.button_index = a[1]
		if not InputMap.action_has_event(a[0], btn): InputMap.action_add_event(a[0], btn)
	InputMap.action_set_deadzone("ui_left", 0.5)
	InputMap.action_set_deadzone("ui_right", 0.5)
	InputMap.action_set_deadzone("ui_up", 0.5)
	InputMap.action_set_deadzone("ui_down", 0.5)

func _load_name() -> String:
	var t := FileAccess.get_file_as_string("user://name.txt").strip_edges()
	if t != "": return t.substr(0, 16)
	return "Clone %03d" % (randi() % 1000)

func save_name(n: String) -> void:
	player_name = n.strip_edges().substr(0, 16)
	var f := FileAccess.open("user://name.txt", FileAccess.WRITE)
	if f: f.store_string(player_name)

## Every minute: who is online, on what. The dashboard counts these.
func _beat() -> void:
	track("clone_online", {"platform": platform(), "state": "playing" if game.active else "menu"})

func platform() -> String:
	if OS.has_feature("web"):
		var ua := str(JavaScriptBridge.eval("navigator.userAgent"))
		if ua.contains("Xbox"): return "xbox"
		if ua.contains("PlayStation"): return "playstation"
		if ua.contains("Steam Deck") or ua.contains("Valve"): return "steam"
		return "web"
	return OS.get_name().to_lower()

func track(ev: String, props: Dictionary) -> void:
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval("window.track&&window.track(%s,%s)" % [JSON.stringify(ev), JSON.stringify(props)])

func open_site(from: String) -> void:
	track("clone_site_click", {"from": from})
	OS.shell_open("https://www.myclawn.com/?utm_source=hide-and-clone&utm_medium=game&utm_content=" + from)

func _qs(k: String) -> String:
	if not OS.has_feature("web"): return ""
	return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get(%s)||''" % JSON.stringify(k)))

## ?join=CODE opens an invite. ?auto=... is used by the automated tests.
func _auto() -> void:
	var j := _qs("join")
	if j != "":
		play_join(j)
		return
	var a := _qs("auto")
	if a == "": return
	game.ai_mode = _qs("ai") == "1"
	game.force_role = _qs("force")
	game.debug = _qs("dbg") == "1"
	if a == "host":
		if _qs("nohud") == "1":
			hud.visible = false
			game.birdseye = true
		var s := {"bots": int(_qs("bots")), "autostart": false, "hide_time": 3, "seek_time": 40, "public": true, "max_players": 12}
		if _qs("vis") != "": s["visibility"] = int(_qs("vis"))
		if _qs("hide") != "": s["hide_time"] = int(_qs("hide"))
		if _qs("start") == "auto": s["autostart"] = true
		var maps: Array = Maps.builtin
		play_host(maps[int(_qs("map")) % maps.size()], s)
	elif a == "code":
		play_join(_qs("code"))

func _show_menu() -> void:
	_remove_builder()
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	menu = Control.new()
	menu.set_script(load("res://scripts/menu.gd"))
	UI.full(menu)
	menu_layer.add_child(menu)
	menu.setup(self)

func _hide_menu() -> void:
	if menu_layer:
		menu_layer.queue_free()
		menu_layer = null

func _remove_builder() -> void:
	if builder:
		builder.queue_free()
		builder = null

func _back_to_menu(msg: String) -> void:
	_show_menu()
	if msg != "": menu.show_message(msg)

func _on_net_failed(code: String) -> void:
	track("clone_net_fail", {"code": code})
	if menu and is_instance_valid(menu) and menu.has_method("on_net_failed"): menu.on_net_failed(code)
	if code == "no_link" and game.active: _back_after_fail()
	if code == "offline" and game.active and multiplayer.is_server() and hud: hud.toast("Lobby service offline: playing solo with bots")

func _back_after_fail() -> void:
	game.leave()
	_show_menu()
	menu.show_message("Couldn't connect to that game.")

func play_host(m: Dictionary, s: Dictionary) -> void:
	_hide_menu()
	_remove_builder()
	game.host_game(m, s, player_name)
	track("clone_host", {"bots": s.get("bots", 5), "public": s.get("public", true), "objects": (m.get("o", []) as Array).size()})

func play_join(code: String) -> void:
	if not menu_layer: _show_menu()
	menu.show_message("Connecting to %s…" % code.to_upper())
	Net.join(code)
	game.my_name = player_name
	if not multiplayer.connected_to_server.is_connected(_joined):
		multiplayer.connected_to_server.connect(_joined)
	track("clone_join_try", {})

func _joined() -> void:
	_hide_menu()
	track("clone_join_ok", {})

func open_builder(m: Dictionary) -> void:
	_hide_menu()
	builder = Node3D.new()
	builder.set_script(load("res://scripts/builder.gd"))
	add_child(builder)
	builder.setup(self, m)
	track("clone_builder", {})

func leave_builder() -> void:
	_show_menu()
