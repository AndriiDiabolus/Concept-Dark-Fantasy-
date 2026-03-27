## main.gd — Sabbath: Among Life and Death
## Сайд-скроллер-платформер: фізика, камера, рівні, HUD

extends Node2D

#region Стан гри
var current_state: int = C.STATE.SPLASH
var current_level: int = 0
var level_timer: float = 0.0
var _focused: bool = false   # true после первого клика — фокус получен
#endregion

#region Сплэш
var _splash_t: int = 0
var _splash_embers: Array = []
#endregion

#region Меню
var _menu_selected: int = 0
var _menu_t: int = 0
#endregion

#region Ноди
var player: Node2D
var camera: Camera2D
var enemies: Array[Node2D] = []
var _input_catcher: ColorRect = null
#endregion

#region Рівень
var current_platforms: Array = []
var level_width: float = 3600.0
var level_name: String = ""
#endregion

# ──────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process_unhandled_input(true)
	get_viewport().handle_input_locally = true
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	print("🎮 Sabbath v0.2 — Platformer%s" % (" [AUTOTEST]" if _autotest else ""))
	# Камера нужна сразу — используем существующую из сцены (не создаём новую)
	camera = get_node("Camera2D")
	camera.make_current()
	camera.global_position = Vector2(C.VIEWPORT_WIDTH / 2.0, C.VIEWPORT_HEIGHT / 2.0)

	_init_splash_embers()
	await get_tree().process_frame
	get_window().grab_focus()
	if _autotest:
		_start_game()
	else:
		current_state = C.STATE.MENU
		get_tree().paused = true

func _start_game() -> void:
	get_tree().paused = false
	_focused = true
	_setup_scene()
	_setup_input_catcher()
	load_level(0)

func _go_to_menu() -> void:
	get_tree().paused = true
	current_state = C.STATE.MENU
	_menu_selected = 0
	_menu_t = 0

func _menu_activate() -> void:
	if current_state != C.STATE.MENU:
		return
	current_state = C.STATE.PLAY  # блок повторного вызова
	match _menu_selected:
		0: _start_game()
		1: get_tree().quit()

# ──────────────────────────────────────────────
#region Ініціалізація сцени
func _setup_scene() -> void:
	# Гравець
	if get_node_or_null("Player") == null:
		player = Node2D.new()
		player.name = "Player"
		var ps = load("res://scripts/player.gd")
		player.set_script(ps)   # set_script ДО add_child — _ready() сработает при входе в дерево
		add_child(player)
		player.player_died.connect(_on_player_died)
	else:
		player = get_node("Player")

	# Камера — всегда используем ноду из сцены
	camera = get_node("Camera2D")
	camera.make_current()
	camera.global_position = Vector2(C.VIEWPORT_WIDTH / 2.0, C.VIEWPORT_HEIGHT / 2.0)
#endregion

# ──────────────────────────────────────────────
# Control-кетчер в CanvasLayer — работает в embedded режиме через GUI систему
func _setup_input_catcher() -> void:
	var ui := get_node_or_null("UILayer")
	if ui == null:
		ui = CanvasLayer.new()
		ui.name = "UILayer"
		add_child(ui)
	_input_catcher = ColorRect.new()
	_input_catcher.color = Color(0, 0, 0, 0)          # прозрачный
	_input_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(_input_catcher)
	_input_catcher.gui_input.connect(_on_catcher_gui_input)

func _on_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_focused = true
		_input_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE  # убрать захват после клика
		get_window().grab_focus()
		get_viewport().handle_input_locally = true

# ──────────────────────────────────────────────
#region Завантаження рівня
func load_level(idx: int) -> void:
	current_level = idx
	level_timer = 0.0
	current_state = C.STATE.PLAY

	# Очищаємо ворогів
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

	var data := _get_level_data(idx)
	current_platforms = data["platforms"]
	level_width       = data["width"]
	level_name        = data["name"]

	# Повний ресет гравця
	if player:
		player.global_position = Vector2(150, C.GROUND_Y - C.PLAYER_SIZE.y * 0.5)
		player.velocity        = Vector2.ZERO
		player.pressed_keys.clear()
		player.current_hp        = C.PLAYER_HP_MAX
		player.is_alive          = true
		player.is_blocking       = false
		player.is_recovering     = false
		player.obsession_fill    = 0.0
		player.obsession_level   = 0
		player.obsession_active  = false
		player.obsession_cooldown = 0.0
		player.attack_cooldown   = 0.0
		player.attack_timer      = 0.0
		player.dash_cooldown     = 0.0
		player.dash_timer        = 0.0
		player.is_dashing        = false
		player.degrade_stage     = 0

	# Спавн ворогів
	for ed in data["enemies"]:
		_spawn_enemy(ed["type"], Vector2(ed["x"], ed["y"]))

	print("📍 Уровень %d: %s | Врагов: %d" % [idx + 1, level_name, enemies.size()])

func _get_level_data(idx: int) -> Dictionary:
	var gnd := float(C.GROUND_Y)
	match idx:
		0:  # Сечь — Руины
			return {
				"name": "Сечь — Руины",
				"width": 3600.0,
				"platforms": [
					Rect2(0,    gnd,       3600, 400),   # земля
					Rect2(320,  gnd - 140, 200,  22),
					Rect2(650,  gnd - 220, 170,  22),
					Rect2(960,  gnd - 150, 210,  22),
					Rect2(1280, gnd - 260, 180,  22),
					Rect2(1600, gnd - 180, 200,  22),
					Rect2(1950, gnd - 250, 170,  22),
					Rect2(2280, gnd - 160, 210,  22),
					Rect2(2650, gnd - 220, 180,  22),
					Rect2(3000, gnd - 150, 200,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 550,  "y": gnd - 34},
					{"type": "pehota",    "x": 950,  "y": gnd - 34},
					{"type": "pehota",    "x": 1350, "y": gnd - 34},
					{"type": "pehota",    "x": 1800, "y": gnd - 34},
					{"type": "pehota",    "x": 2300, "y": gnd - 34},
					{"type": "pehota",    "x": 2800, "y": gnd - 34},
					{"type": "pehota",    "x": 3200, "y": gnd - 34},
				],
			}
		1:  # Сожжённые Сёла
			return {
				"name": "Сожжённые Сёла",
				"width": 4200.0,
				"platforms": [
					Rect2(0,    gnd,       4200, 400),
					Rect2(250,  gnd - 160, 180,  22),
					Rect2(580,  gnd - 240, 160,  22),
					Rect2(900,  gnd - 160, 200,  22),
					Rect2(1250, gnd - 270, 180,  22),
					Rect2(1600, gnd - 190, 200,  22),
					Rect2(1980, gnd - 260, 170,  22),
					Rect2(2350, gnd - 180, 200,  22),
					Rect2(2750, gnd - 240, 180,  22),
					Rect2(3150, gnd - 170, 200,  22),
					Rect2(3600, gnd - 240, 180,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 400,  "y": gnd - 34},
					{"type": "musketeer", "x": 750,  "y": gnd - 34},
					{"type": "pehota",    "x": 1100, "y": gnd - 34},
					{"type": "piker",     "x": 1500, "y": gnd - 36},
					{"type": "musketeer", "x": 1900, "y": gnd - 34},
					{"type": "pehota",    "x": 2400, "y": gnd - 34},
					{"type": "piker",     "x": 2900, "y": gnd - 36},
					{"type": "musketeer", "x": 3400, "y": gnd - 34},
					{"type": "pehota",    "x": 3900, "y": gnd - 34},
				],
			}
		2:  # Подступы к Замку
			return {
				"name": "Подступы к Замку",
				"width": 4800.0,
				"platforms": [
					Rect2(0,    gnd,       4800, 400),
					Rect2(200,  gnd - 150, 160,  22),
					Rect2(480,  gnd - 260, 160,  22),
					Rect2(760,  gnd - 370, 160,  22),
					Rect2(1100, gnd - 190, 200,  22),
					Rect2(1450, gnd - 280, 180,  22),
					Rect2(1850, gnd - 190, 200,  22),
					Rect2(2250, gnd - 280, 170,  22),
					Rect2(2650, gnd - 190, 200,  22),
					Rect2(3100, gnd - 280, 180,  22),
					Rect2(3550, gnd - 190, 200,  22),
					Rect2(4050, gnd - 280, 180,  22),
					Rect2(4450, gnd - 190, 200,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 400,  "y": gnd - 34},
					{"type": "piker",     "x": 800,  "y": gnd - 36},
					{"type": "musketeer", "x": 1200, "y": gnd - 34},
					{"type": "pehota",    "x": 1650, "y": gnd - 34},
					{"type": "piker",     "x": 2100, "y": gnd - 36},
					{"type": "musketeer", "x": 2600, "y": gnd - 34},
					{"type": "pehota",    "x": 3100, "y": gnd - 34},
					{"type": "piker",     "x": 3600, "y": gnd - 36},
					{"type": "musketeer", "x": 4100, "y": gnd - 34},
					{"type": "pehota",    "x": 4500, "y": gnd - 34},
				],
			}
		3:  # Цитадель
			return {
				"name": "Цитадель",
				"width": 5500.0,
				"platforms": [
					Rect2(0,    gnd,       5500, 400),
					Rect2(280,  gnd - 170, 180,  22),
					Rect2(600,  gnd - 270, 160,  22),
					Rect2(950,  gnd - 180, 200,  22),
					Rect2(1350, gnd - 280, 180,  22),
					Rect2(1750, gnd - 190, 200,  22),
					Rect2(2150, gnd - 280, 170,  22),
					Rect2(2550, gnd - 190, 200,  22),
					Rect2(2950, gnd - 280, 180,  22),
					Rect2(3350, gnd - 190, 200,  22),
					Rect2(3750, gnd - 280, 180,  22),
					Rect2(4150, gnd - 190, 200,  22),
					Rect2(4550, gnd - 280, 180,  22),
					Rect2(4950, gnd - 190, 200,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 500,  "y": gnd - 34},
					{"type": "musketeer", "x": 850,  "y": gnd - 34},
					{"type": "piker",     "x": 1250, "y": gnd - 36},
					{"type": "pehota",    "x": 1700, "y": gnd - 34},
					{"type": "musketeer", "x": 2100, "y": gnd - 34},
					{"type": "piker",     "x": 2550, "y": gnd - 36},
					{"type": "pehota",    "x": 3000, "y": gnd - 34},
					{"type": "musketeer", "x": 3450, "y": gnd - 34},
					{"type": "piker",     "x": 3900, "y": gnd - 36},
					{"type": "pehota",    "x": 4350, "y": gnd - 34},
					{"type": "musketeer", "x": 4800, "y": gnd - 34},
					{"type": "piker",     "x": 5200, "y": gnd - 36},
				],
			}
		_:
			return {"name": "???", "width": 3600.0, "platforms": [Rect2(0, float(C.GROUND_Y), 3600, 400)], "enemies": []}
#endregion

# ──────────────────────────────────────────────
#region Спавн ворогів
func _spawn_enemy(type: String, pos: Vector2) -> void:
	var e := Node2D.new()
	e.name = "Enemy_%s_%d" % [type, enemies.size()]
	var es = load("res://scripts/enemy.gd")
	e.set_script(es)       # set_script ДО add_child
	add_child(e)
	e.global_position = pos
	e.setup(type, player)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
#endregion

# ──────────────────────────────────────────────
#region Колізія (платформер)
func resolve_collision(pos: Vector2, char_size: Vector2, move_delta: Vector2) -> Dictionary:
	var new_pos   := pos + move_delta
	var hw        := char_size.x * 0.5
	var hh        := char_size.y * 0.5
	var on_ground := false

	for plat_v in current_platforms:
		var plat    := plat_v as Rect2
		var prev_bottom := pos.y + hh
		var new_bottom  := new_pos.y + hh
		var plat_top    := plat.position.y

		if prev_bottom <= plat_top + 2.0 and new_bottom >= plat_top:
			var left  := new_pos.x - hw
			var right := new_pos.x + hw
			if right > plat.position.x and left < plat.position.x + plat.size.x:
				new_pos.y = plat_top - hh
				on_ground = true

	# Межі рівня (горизонтальні)
	new_pos.x = clampf(new_pos.x, hw + 5.0, level_width - hw - 5.0)

	return {"pos": new_pos, "on_ground": on_ground}
#endregion

# ──────────────────────────────────────────────
#region Game Loop
var _autotest: bool = false
var _autotest_frame: int = 0

func _process(delta: float) -> void:
	if _autotest:
		_run_autotest()
	match current_state:
		C.STATE.SPLASH:
			_splash_t += 1
			_update_splash_embers()
		C.STATE.MENU:
			_menu_t += 1
			_update_splash_embers()
		C.STATE.PLAY:
			level_timer += delta
			_update_camera()
			_check_win()
		_:
			pass
	queue_redraw()

# Автотест — запускается при --autotest аргументе
# Симулирует нажатия клавиш через Input.parse_input_event()
func _run_autotest() -> void:
	_autotest_frame += 1
	var f := _autotest_frame

	# Кадр 30: нажать D (двигаться вправо)
	if f == 30:
		_sim_key(KEY_D, true)
		print("🧪 [%d] Нажат D, игрок X=%.1f" % [f, player.global_position.x if player else 0])
	# Кадр 90: отпустить D
	if f == 90:
		_sim_key(KEY_D, false)
		print("🧪 [%d] Отпущен D, игрок X=%.1f" % [f, player.global_position.x if player else 0])
	# Кадр 100: прыжок W
	if f == 100:
		_sim_key(KEY_W, true)
		print("🧪 [%d] Нажат W (прыжок), Y=%.1f" % [f, player.global_position.y if player else 0])
	if f == 103: _sim_key(KEY_W, false)
	# Кадр 130: результат
	if f == 130:
		if player:
			print("🧪 ИТОГ: X=%.1f Y=%.1f | на земле: %s" % [
				player.global_position.x, player.global_position.y, str(player.is_on_ground)
			])
			if player.global_position.x > 160:
				print("✅ ДВИЖЕНИЕ РАБОТАЕТ")
			else:
				print("❌ ДВИЖЕНИЕ НЕ РАБОТАЕТ — игрок не сдвинулся с X=150")
		get_tree().quit()

func _sim_key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
	# Также пишем напрямую в pressed_keys игрока
	if player:
		if pressed:
			player.pressed_keys[keycode] = true
		else:
			player.pressed_keys.erase(keycode)

func _update_camera() -> void:
	if not player or not camera:
		return
	var half_w := C.VIEWPORT_WIDTH / 2.0
	var half_h := C.VIEWPORT_HEIGHT / 2.0
	var target_x := clampf(player.global_position.x, half_w, level_width - half_w)
	camera.global_position.x = lerpf(camera.global_position.x, target_x, 0.14)
	camera.global_position.y = half_h

func _check_win() -> void:
	var alive_count := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive:
			alive_count += 1
	if alive_count == 0 and not enemies.is_empty():
		current_state = C.STATE.WON
		get_tree().paused = true
#endregion

# ──────────────────────────────────────────────
#region Ввод
func _input(event: InputEvent) -> void:
	# Сплэш — только Enter/Space после полной анимации → главное меню
	if current_state == C.STATE.SPLASH:
		get_viewport().set_input_as_handled()
		if _splash_t > 240 and event is InputEventKey and event.pressed and not event.echo:
			var k2: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			if k2 == KEY_ENTER or k2 == KEY_SPACE:
				_go_to_menu()
		return

	# Меню — навигация и выбор
	if current_state == C.STATE.MENU:
		get_viewport().set_input_as_handled()
		if event is InputEventMouseButton and event.pressed:
			get_window().grab_focus()
			_menu_activate()
			return
		if not (event is InputEventKey) or not event.pressed or event.echo:
			return
		var km: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		match km:
			KEY_W, KEY_UP:
				_menu_selected = (_menu_selected - 1 + 2) % 2
			KEY_S, KEY_DOWN:
				_menu_selected = (_menu_selected + 1) % 2
			KEY_ENTER, KEY_SPACE:
				_menu_activate()
		return

	# Клик мышью → даём фокус окну
	if event is InputEventMouseButton and event.pressed:
		_focused = true
		get_window().grab_focus()
		get_viewport().set_input_as_handled()
		return

	if not _focused:
		return
	if not (event is InputEventKey):
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	# Системные клавиши
	if key == KEY_ESCAPE:
		if current_state == C.STATE.PAUSE:
			get_tree().paused = false
			current_state = C.STATE.PLAY
		elif current_state == C.STATE.PLAY:
			get_tree().paused = true
			current_state = C.STATE.PAUSE
		return
	if key == KEY_ENTER:
		if current_state == C.STATE.LOST:
			_go_to_menu()
		elif current_state == C.STATE.WON:
			var next := current_level + 1
			if next < 4:
				get_tree().paused = false
				load_level(next)
			else:
				_go_to_menu()
		return

	# Передаємо гравцеві
	if not player or current_state != C.STATE.PLAY:
		return
	if event.pressed:
		player.pressed_keys[key] = true
		if not event.echo:
			if key == KEY_W:
				player.do_jump()
			elif key == KEY_SPACE and not player.is_blocking:
				player.do_attack()
			elif key == KEY_V:
				player.do_obsession()
	else:
		player.pressed_keys.erase(key)

# Резервный обработчик — передаём только то, что не обработано в _input
func _unhandled_input(_event: InputEvent) -> void:
	pass
#endregion

# ──────────────────────────────────────────────
#region Колбеки
func _on_player_died() -> void:
	current_state = C.STATE.LOST
	get_tree().paused = true

func _on_enemy_died(enemy: Node2D) -> void:
	enemies.erase(enemy)
#endregion

# ──────────────────────────────────────────────
#region Відмалювання
func _draw() -> void:
	var cx := camera.global_position.x if camera else C.VIEWPORT_WIDTH / 2.0
	var ox := cx - C.VIEWPORT_WIDTH / 2.0  # ліва межа камери у світових координатах
	var oy := 0.0

	if current_state == C.STATE.SPLASH:
		_draw_splash(ox, oy)
		return

	if current_state == C.STATE.MENU:
		_draw_menu(ox, oy)
		return

	_draw_background(ox, oy)
	_draw_platforms()
	_draw_hud(ox, oy)

	match current_state:
		C.STATE.PAUSE: _draw_overlay(ox, oy, "ПАУЗА",   Color(0.0, 0.0, 0.0, 0.55), "ESC — продолжить")
		C.STATE.LOST:  _draw_overlay(ox, oy, "ГИБЕЛЬ",  Color(0.35, 0.0, 0.0, 0.65), "Enter — в главное меню")
		C.STATE.WON:   _draw_overlay(ox, oy, "ПОБЕДА",  Color(0.0, 0.18, 0.0, 0.60), "Enter — продолжить" if current_level < 3 else "Enter — в главное меню")

	# Экран фокуса — показывается пока не кликнули
	if not _focused:
		var font := ThemeDB.fallback_font
		var vw := float(C.VIEWPORT_WIDTH)
		var vh := float(C.VIEWPORT_HEIGHT)
		draw_rect(Rect2(ox, oy, vw, vh), Color(0.0, 0.0, 0.0, 0.65))
		draw_string(font, Vector2(ox + vw * 0.5 - 220, oy + vh * 0.5 - 10),
			"КЛИКНИ НА ЭКРАН ЧТОБЫ НАЧАТЬ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.85, 0.3))

func _draw_background(ox: float, _oy: float) -> void:
	var vw := float(C.VIEWPORT_WIDTH)
	var vh := float(C.VIEWPORT_HEIGHT)

	# Небо — темний градієнт (Castlevania/Berserk атмосфера)
	draw_rect(Rect2(ox, 0, vw, vh * 0.55), Color(0.03, 0.02, 0.08))
	draw_rect(Rect2(ox, vh * 0.35, vw, vh * 0.40), Color(0.04, 0.03, 0.06))

	# Місяць
	var moon_x := ox + vw * 0.80
	draw_circle(Vector2(moon_x, 85), 48, Color(0.92, 0.88, 0.78, 0.18))
	draw_circle(Vector2(moon_x, 85), 42, Color(0.95, 0.92, 0.82))

	# Далекий силует руїн (паралакс 0.18)
	var px := ox * 0.18
	var ruin_color := Color(0.07, 0.04, 0.06)
	for i in range(8):
		var rx := px + i * 480.0 + fmod(float(i) * 137.0, 200.0)
		var rh := 120.0 + fmod(float(i) * 53.0, 80.0)
		draw_rect(Rect2(rx, float(C.GROUND_Y) - rh, 60, rh), ruin_color)
		# Вікна
		draw_rect(Rect2(rx + 10, float(C.GROUND_Y) - rh + 20, 12, 16), Color(0.20, 0.14, 0.08, 0.6))
		draw_rect(Rect2(rx + 38, float(C.GROUND_Y) - rh + 20, 12, 16), Color(0.20, 0.14, 0.08, 0.6))

	# Середній план — дерева/колони (паралакс 0.45)
	var mx := ox * 0.45
	var tree_c := Color(0.06, 0.04, 0.05)
	for i in range(12):
		var tx := mx + i * 320.0 + fmod(float(i) * 97.0, 160.0)
		var th := 80.0 + fmod(float(i) * 41.0, 60.0)
		draw_rect(Rect2(tx, float(C.GROUND_Y) - th, 18, th), tree_c)
		draw_circle(Vector2(tx + 9, float(C.GROUND_Y) - th - 20), 28, tree_c)

	# Туман/серпанок над землею
	draw_rect(Rect2(ox, float(C.GROUND_Y) - 55, vw, 55), Color(0.06, 0.04, 0.10, 0.22))
	draw_rect(Rect2(ox, float(C.GROUND_Y) - 30, vw, 30), Color(0.04, 0.03, 0.08, 0.15))

func _draw_platforms() -> void:
	for plat_v in current_platforms:
		var plat    := plat_v as Rect2
		var is_ground := plat.size.y > 50  # земля vs платформа

		if is_ground:
			# Земля — темний камінь
			draw_rect(plat, Color(0.14, 0.10, 0.08))
			draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 6), Color(0.22, 0.16, 0.12))
			# Текстура тріщин (псевдо)
			var nx := int(plat.size.x / 80)
			for i in range(nx):
				var cx2 := plat.position.x + i * 80 + 30
				draw_line(Vector2(cx2, plat.position.y + 8), Vector2(cx2 + 12, plat.position.y + 20), Color(0.10, 0.07, 0.05), 1.0)
		else:
			# Платформа — кам'яна плита
			draw_rect(plat, Color(0.24, 0.18, 0.14))
			# Верхній край (яскравіший)
			draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 4), Color(0.36, 0.27, 0.20))
			# Бічні тіні
			draw_rect(Rect2(plat.position.x, plat.position.y, 4, plat.size.y), Color(0.18, 0.13, 0.10))
			draw_rect(Rect2(plat.position.x + plat.size.x - 4, plat.position.y, 4, plat.size.y), Color(0.18, 0.13, 0.10))

func _draw_hud(ox: float, oy: float) -> void:
	if not player:
		return
	var font := ThemeDB.fallback_font
	var pad  := 24.0

	# === HP ПОЛОСКА ===
	var hp_pct  := float(player.current_hp) / float(C.PLAYER_HP_MAX)
	var bar_w   := 220.0
	var bar_h   := 18.0
	var bar_x   := ox + pad
	var bar_y   := oy + pad

	draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), Color(0.04, 0.03, 0.06))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.06, 0.06))
	draw_rect(Rect2(bar_x, bar_y, bar_w * hp_pct, bar_h), Color(0.78, 0.14, 0.14))
	draw_string(font, Vector2(bar_x + 4, bar_y + 13), "ХП %d / %d" % [player.current_hp, C.PLAYER_HP_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# === ШКАЛА ОДЕРЖИМОСТІ ===
	var obs_max := float(C.PLAYER_OBSESSION_LEVEL_THRESHOLD * C.PLAYER_OBSESSION_LEVELS)
	var obs_pct: float = float(player.obsession_fill) / obs_max
	var ob_y    := bar_y + bar_h + 8
	var ob_w    := bar_w

	draw_rect(Rect2(bar_x - 2, ob_y - 2, ob_w + 4, 12), Color(0.04, 0.03, 0.06))
	draw_rect(Rect2(bar_x, ob_y, ob_w, 10), Color(0.12, 0.06, 0.18))
	draw_rect(Rect2(bar_x, ob_y, ob_w * obs_pct, 10), Color(0.65, 0.10, 1.0))
	# Мітки рівнів одержимості
	for i in range(1, C.PLAYER_OBSESSION_LEVELS):
		var lx := bar_x + ob_w * float(i) / float(C.PLAYER_OBSESSION_LEVELS)
		draw_rect(Rect2(lx - 1, ob_y, 2, 10), Color(0.04, 0.03, 0.06))
	draw_string(font, Vector2(bar_x + 4, ob_y + 9), "Одержимость  Уровень %d / %d" % [player.obsession_level, C.PLAYER_OBSESSION_LEVELS], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.80, 0.60, 1.0))

	# === РІВЕНЬ ТА ЧАС ===
	var mins := int(level_timer) / 60
	var secs := int(level_timer) % 60
	var time_str := "%02d:%02d" % [mins, secs]
	draw_string(font, Vector2(ox + float(C.VIEWPORT_WIDTH) - 160, oy + 36), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.80, 0.78, 0.65))
	draw_string(font, Vector2(ox + float(C.VIEWPORT_WIDTH) / 2.0 - 120, oy + 36), level_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.70, 0.60, 0.50))

	# === ПОДСКАЗКИ (только уровень 1) ===
	if current_level == 0 and level_timer < 12.0:
		draw_string(font, Vector2(ox + float(C.VIEWPORT_WIDTH) / 2.0 - 180, oy + float(C.VIEWPORT_HEIGHT) - 50),
			"A/D — движение   W — прыжок   Space — атака   R — блок   V — одержимость",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.72, 0.60, 0.9))


func _draw_overlay(ox: float, oy: float, title: String, bg: Color, hint: String) -> void:
	var font := ThemeDB.fallback_font
	var vw   := float(C.VIEWPORT_WIDTH)
	var vh   := float(C.VIEWPORT_HEIGHT)
	draw_rect(Rect2(ox, oy, vw, vh), bg)

	var tx := ox + vw / 2.0 - 160
	var ty := oy + vh / 2.0
	draw_string(font, Vector2(tx, ty - 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color.WHITE)
	draw_string(font, Vector2(tx, ty + 36), hint,  HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.80, 0.78, 0.65))
#endregion

# ──────────────────────────────────────────────
#region Сплэш
func _init_splash_embers() -> void:
	_splash_embers.clear()
	for i in range(55):
		_splash_embers.append({
			"x":    randf() * float(C.VIEWPORT_WIDTH),
			"y":    randf() * float(C.VIEWPORT_HEIGHT),
			"vx":   (randf() - 0.5) * 0.9,
			"vy":   -(0.5 + randf() * 1.4),
			"size": 0.8 + randf() * 2.2,
			"base_alpha": 0.35 + randf() * 0.65,
			"alpha": 0.5,
			"phase": randf() * TAU,
		})

func _update_splash_embers() -> void:
	for ember in _splash_embers:
		ember["x"]  += ember["vx"]
		ember["y"]  += ember["vy"]
		ember["alpha"] = ember["base_alpha"] * (sin(float(_splash_t) * 0.08 + ember["phase"]) * 0.35 + 0.65)
		if ember["y"] < -8.0:
			ember["y"] = float(C.VIEWPORT_HEIGHT) + 5.0
			ember["x"] = randf() * float(C.VIEWPORT_WIDTH)

func _draw_splash(ox: float, oy: float) -> void:
	var font := ThemeDB.fallback_font
	var vw   := float(C.VIEWPORT_WIDTH)
	var vh   := float(C.VIEWPORT_HEIGHT)
	var t    := float(_splash_t)

	# ── Фон ──────────────────────────────────────
	draw_rect(Rect2(ox, oy,           vw, vh * 0.55), Color(0.02, 0.01, 0.05))
	draw_rect(Rect2(ox, oy + vh*0.4, vw, vh * 0.60), Color(0.07, 0.02, 0.04))

	# ── Луна ─────────────────────────────────────
	var moon_fade := clampf((t - 30.0) / 90.0, 0.0, 1.0)
	var mx := ox + vw * 0.5
	var my := oy + vh * 0.24
	draw_circle(Vector2(mx, my), 148, Color(0.72, 0.50, 0.22, moon_fade * 0.05))
	draw_circle(Vector2(mx, my), 110, Color(0.82, 0.62, 0.32, moon_fade * 0.09))
	draw_circle(Vector2(mx, my),  82, Color(0.90, 0.78, 0.52, moon_fade * 0.16))
	draw_circle(Vector2(mx, my),  64, Color(0.94, 0.90, 0.76, moon_fade))
	# Кровавый оттенок луны
	draw_circle(Vector2(mx, my),  64, Color(0.75, 0.08, 0.04, moon_fade * 0.28))
	# Кратеры
	draw_circle(Vector2(mx - 18, my - 12), 7, Color(0.80, 0.72, 0.58, moon_fade * 0.55))
	draw_circle(Vector2(mx + 22, my + 10), 5, Color(0.80, 0.72, 0.58, moon_fade * 0.45))
	draw_circle(Vector2(mx - 8,  my + 22), 4, Color(0.80, 0.72, 0.58, moon_fade * 0.40))

	# ── Руины + кресты ───────────────────────────
	var ruin_fade := clampf((t - 80.0) / 90.0, 0.0, 1.0)
	_draw_splash_ruins(ox, oy, vw, vh, ruin_fade)

	# ── Туман ────────────────────────────────────
	var mist_fade := clampf((t - 100.0) / 80.0, 0.0, 1.0)
	draw_rect(Rect2(ox, oy + vh * 0.82, vw, vh * 0.18), Color(0.10, 0.04, 0.06, mist_fade * 0.50))
	draw_rect(Rect2(ox, oy + vh * 0.89, vw, vh * 0.11), Color(0.14, 0.06, 0.08, mist_fade * 0.38))

	# ── Искры/угли ───────────────────────────────
	var ember_fade := clampf((t - 60.0) / 80.0, 0.0, 1.0)
	if ember_fade > 0.01:
		for ember in _splash_embers:
			draw_circle(
				Vector2(ox + ember["x"], oy + ember["y"]),
				ember["size"],
				Color(0.95, 0.42, 0.08, ember["alpha"] * ember_fade)
			)

	# ── Заголовок "SABBATH" ───────────────────────
	var title_fade := clampf((t - 150.0) / 90.0, 0.0, 1.0)
	if title_fade > 0.01:
		var pulse := sin(t * 0.045) * 0.14 + 0.86
		# Малиновое свечение за заголовком
		draw_circle(Vector2(mx, oy + vh * 0.525), 280, Color(0.50, 0.03, 0.03, title_fade * 0.055 * pulse))
		draw_circle(Vector2(mx, oy + vh * 0.525), 200, Color(0.58, 0.04, 0.04, title_fade * 0.08  * pulse))
		draw_circle(Vector2(mx, oy + vh * 0.525), 130, Color(0.65, 0.05, 0.05, title_fade * 0.11  * pulse))
		# Заголовок
		var tc := Color(0.96, 0.84, 0.48, title_fade * pulse)
		draw_string(font, Vector2(mx - 205, oy + vh * 0.555),
			"SABBATH", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, tc)
		# Декоративные линии по бокам заголовка
		var lc := Color(0.72, 0.52, 0.26, title_fade * 0.85)
		draw_line(Vector2(ox + vw * 0.08, oy + vh * 0.560), Vector2(ox + vw * 0.295, oy + vh * 0.560), lc, 1.5)
		draw_line(Vector2(ox + vw * 0.08, oy + vh * 0.564), Vector2(ox + vw * 0.245, oy + vh * 0.564), lc, 0.8)
		draw_line(Vector2(ox + vw * 0.705, oy + vh * 0.560), Vector2(ox + vw * 0.92,  oy + vh * 0.560), lc, 1.5)
		draw_line(Vector2(ox + vw * 0.755, oy + vh * 0.564), Vector2(ox + vw * 0.92,  oy + vh * 0.564), lc, 0.8)

	# ── Подзаголовок ─────────────────────────────
	var sub_fade := clampf((t - 240.0) / 70.0, 0.0, 1.0)
	if sub_fade > 0.01:
		draw_string(font, Vector2(mx - 185, oy + vh * 0.598),
			"Among  Life  and  Death", HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Color(0.68, 0.50, 0.36, sub_fade))

	# ── Разделитель ──────────────────────────────
	if sub_fade > 0.01:
		draw_rect(Rect2(ox + vw * 0.35, oy + vh * 0.608, vw * 0.30, 1),
			Color(0.55, 0.38, 0.22, sub_fade * 0.6))

	# ── "Нажми Enter" ────────────────────────────
	if t > 320:
		var hint_pulse := sin(t * 0.065) * 0.38 + 0.62
		var ha := clampf((t - 320.0) / 60.0, 0.0, 1.0) * hint_pulse
		draw_string(font, Vector2(mx - 132, oy + vh * 0.88),
			"Нажми Enter чтобы начать", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(0.80, 0.74, 0.58, ha))

	# ── Затухание из черного при старте ───────────
	if t < 90:
		var black_a := 1.0 - clampf(t / 90.0, 0.0, 1.0)
		draw_rect(Rect2(ox, oy, vw, vh), Color(0.0, 0.0, 0.0, black_a))

func _draw_splash_ruins(ox: float, oy: float, vw: float, vh: float, alpha: float) -> void:
	if alpha < 0.01:
		return
	var rc   := Color(0.05, 0.03, 0.04, alpha)
	var wc   := Color(0.16, 0.09, 0.05, alpha * 0.75)   # окна (чуть теплее)
	var base := oy + vh                                   # низ экрана

	# ── Левая башня ──────────────────────────────
	draw_rect(Rect2(ox + vw * 0.055, base - 300, 72, 300), rc)
	draw_rect(Rect2(ox + vw * 0.038, base - 345, 106, 52), rc)   # зубцы основа
	# Зубцы
	for i in range(4):
		draw_rect(Rect2(ox + vw * 0.038 + i * 28, base - 380, 18, 40), rc)
	# Окна башни
	draw_rect(Rect2(ox + vw * 0.055 + 14, base - 250, 14, 22), wc)
	draw_rect(Rect2(ox + vw * 0.055 + 44, base - 250, 14, 22), wc)
	draw_rect(Rect2(ox + vw * 0.055 + 22, base - 180, 28, 36), wc)  # большое окно

	# ── Правая башня ─────────────────────────────
	draw_rect(Rect2(ox + vw * 0.870, base - 260, 68, 260), rc)
	draw_rect(Rect2(ox + vw * 0.856, base - 302, 96, 48), rc)
	for i in range(4):
		draw_rect(Rect2(ox + vw * 0.856 + i * 25, base - 336, 16, 38), rc)
	draw_rect(Rect2(ox + vw * 0.870 + 12, base - 210, 14, 20), wc)
	draw_rect(Rect2(ox + vw * 0.870 + 40, base - 210, 14, 20), wc)

	# ── Стена между башнями (фрагменты) ──────────
	draw_rect(Rect2(ox + vw * 0.13,  base - 120, vw * 0.12, 120), rc)
	draw_rect(Rect2(ox + vw * 0.72,  base - 100, vw * 0.14, 100), rc)
	draw_rect(Rect2(ox + vw * 0.38,  base - 75,  vw * 0.08, 75),  rc)

	# ── Центральный Казацкий крест ────────────────
	var cx := ox + vw * 0.5
	# Вертикаль
	draw_rect(Rect2(cx - 6, base - 215, 12, 215), rc)
	# Верхняя перекладина
	draw_rect(Rect2(cx - 40, base - 170, 80, 10), rc)
	# Нижняя перекладина (казацкий крест)
	draw_rect(Rect2(cx - 26, base - 140, 52,  8), rc)
	# Диагональная планка (характерно для казацкого креста)
	draw_line(Vector2(cx - 26, base - 132), Vector2(cx + 26, base - 148),
		Color(0.05, 0.03, 0.04, alpha), 7.0)

	# ── Малые могилы слева и справа ──────────────
	var graves: Array[float] = [0.18, 0.26, 0.34, 0.60, 0.68, 0.76]
	for gp: float in graves:
		var gx := ox + vw * gp
		draw_rect(Rect2(gx - 4, base - 85, 8, 85), rc)
		draw_rect(Rect2(gx - 16, base - 66, 32, 7), rc)

	# ── Земля ─────────────────────────────────────
	draw_rect(Rect2(ox, base - 50, vw, 50), Color(0.04, 0.02, 0.03, alpha))

# ── Меню — атмосферная сцена с глубиной (GOW-стиль) ──
func _draw_menu(ox: float, oy: float) -> void:
	var font := ThemeDB.fallback_font
	var vw   := float(C.VIEWPORT_WIDTH)
	var vh   := float(C.VIEWPORT_HEIGHT)
	var t    := float(_menu_t)
	var mx   := ox + vw * 0.5
	var base := oy + vh

	# ══ СЛОЙ 1: Небо — холодный тёмно-синий градиент ══
	draw_rect(Rect2(ox, oy,            vw, vh * 0.30), Color(0.01, 0.01, 0.05))
	draw_rect(Rect2(ox, oy+vh*0.25,   vw, vh * 0.20), Color(0.02, 0.02, 0.07))
	draw_rect(Rect2(ox, oy+vh*0.40,   vw, vh * 0.20), Color(0.03, 0.02, 0.06))
	draw_rect(Rect2(ox, oy+vh*0.55,   vw, vh * 0.20), Color(0.04, 0.02, 0.05))
	draw_rect(Rect2(ox, oy+vh*0.70,   vw, vh * 0.30), Color(0.03, 0.01, 0.03))

	# ══ СЛОЙ 2: Звёзды ══
	var rng := RandomNumberGenerator.new()
	rng.seed = 7771
	for _s in range(80):
		var sx := ox + rng.randf() * vw
		var sy := oy + rng.randf() * vh * 0.55
		var sa := rng.randf() * 0.5 + 0.2
		var ss := rng.randf() * 1.5 + 0.5
		# мерцание
		sa *= (sin(t * 0.06 + rng.randf() * 6.28) * 0.25 + 0.75)
		draw_circle(Vector2(sx, sy), ss, Color(0.85, 0.80, 0.75, sa))

	# ══ СЛОЙ 3: Луна — холодная, серебристая ══
	var lx := mx
	var ly := oy + vh * 0.18
	var moon_pulse := sin(t * 0.03) * 0.04 + 0.96
	# Мягкий ореол — серебристо-голубой, без лучей
	draw_circle(Vector2(lx, ly), 240, Color(0.30, 0.30, 0.50, 0.03 * moon_pulse))
	draw_circle(Vector2(lx, ly), 160, Color(0.45, 0.45, 0.60, 0.05 * moon_pulse))
	draw_circle(Vector2(lx, ly), 110, Color(0.60, 0.62, 0.72, 0.08 * moon_pulse))
	draw_circle(Vector2(lx, ly),  82, Color(0.75, 0.78, 0.85, 0.12 * moon_pulse))
	# Тело луны — холодный серебристо-белый
	draw_circle(Vector2(lx, ly), 68, Color(0.92, 0.92, 0.96, moon_pulse))
	# Очень слабый синеватый оттенок поверх
	draw_circle(Vector2(lx, ly), 68, Color(0.20, 0.24, 0.45, 0.08 * moon_pulse))
	# Кратеры
	draw_circle(Vector2(lx - 18, ly - 12), 8,  Color(0.80, 0.80, 0.85, 0.45))
	draw_circle(Vector2(lx + 22, ly + 10), 6,  Color(0.80, 0.80, 0.85, 0.38))
	draw_circle(Vector2(lx -  6, ly + 24), 5,  Color(0.80, 0.80, 0.85, 0.32))

	# ══ СЛОЙ 4: Далёкие горы (силуэт) ══
	var mc := Color(0.04, 0.01, 0.05)
	var mountains := PackedVector2Array([
		Vector2(ox,            base - vh*0.18),
		Vector2(ox+vw*0.08,   base - vh*0.38),
		Vector2(ox+vw*0.18,   base - vh*0.22),
		Vector2(ox+vw*0.28,   base - vh*0.44),
		Vector2(ox+vw*0.38,   base - vh*0.26),
		Vector2(ox+vw*0.50,   base - vh*0.48),
		Vector2(ox+vw*0.62,   base - vh*0.28),
		Vector2(ox+vw*0.72,   base - vh*0.42),
		Vector2(ox+vw*0.82,   base - vh*0.20),
		Vector2(ox+vw*0.92,   base - vh*0.36),
		Vector2(ox+vw,        base - vh*0.18),
		Vector2(ox+vw,        base),
		Vector2(ox,           base),
	])
	draw_colored_polygon(mountains, mc)

	# ══ СЛОЙ 5: Замок по центру (силуэт, средний план) ══
	var cc := Color(0.03, 0.01, 0.03)
	var bx := mx
	var castle_base := base - vh * 0.08
	# Центральная башня
	draw_rect(Rect2(bx - 52, castle_base - 260, 104, 260), cc)
	# Зубцы центральной башни
	for i in range(6):
		draw_rect(Rect2(bx - 48 + i * 18, castle_base - 285, 12, 28), cc)
	# Арочное окно
	draw_circle(Vector2(bx, castle_base - 120), 22, Color(0.01, 0.00, 0.02))
	draw_rect(Rect2(bx - 22, castle_base - 120, 44, 22), Color(0.01, 0.00, 0.02))
	# Малые окна
	draw_rect(Rect2(bx - 14, castle_base - 200, 12, 18), Color(0.01, 0.00, 0.02))
	draw_rect(Rect2(bx +  2, castle_base - 200, 12, 18), Color(0.01, 0.00, 0.02))
	# Левая боковая башня
	draw_rect(Rect2(bx - 160, castle_base - 170, 62, 170), cc)
	for i in range(4):
		draw_rect(Rect2(bx - 158 + i * 16, castle_base - 192, 11, 24), cc)
	draw_rect(Rect2(bx - 148, castle_base - 130, 10, 16), Color(0.01, 0.00, 0.02))
	# Правая боковая башня
	draw_rect(Rect2(bx + 98,  castle_base - 155, 58, 155), cc)
	for i in range(4):
		draw_rect(Rect2(bx + 100 + i * 15, castle_base - 176, 10, 22), cc)
	draw_rect(Rect2(bx + 112, castle_base - 118, 10, 16), Color(0.01, 0.00, 0.02))
	# Стены (соединяют башни)
	draw_rect(Rect2(bx - 98, castle_base - 80, 46, 80), cc)
	draw_rect(Rect2(bx + 52, castle_base - 72, 46, 72), cc)
	# Ворота
	draw_rect(Rect2(bx - 22, castle_base - 58, 44, 58), Color(0.01, 0.00, 0.02))
	draw_circle(Vector2(bx, castle_base - 58), 22, Color(0.01, 0.00, 0.02))

	# ══ СЛОЙ 6: Деревья/руины по бокам ══
	var tc := Color(0.025, 0.008, 0.02)
	# Левое дерево
	_draw_menu_tree(ox + vw*0.06, base - vh*0.05, 80.0, 280.0, tc)
	_draw_menu_tree(ox + vw*0.13, base - vh*0.04, 55.0, 200.0, tc)
	# Правое дерево
	_draw_menu_tree(ox + vw*0.87, base - vh*0.05, 75.0, 260.0, tc)
	_draw_menu_tree(ox + vw*0.94, base - vh*0.04, 50.0, 190.0, tc)
	# Кресты на переднем плане
	var crosses: Array[float] = [0.18, 0.30, 0.68, 0.80]
	for cp: float in crosses:
		var gx := ox + vw * cp
		var gh := vh * (0.09 + fmod(cp * 7.3, 0.06))
		draw_rect(Rect2(gx - 4, base - gh, 8, gh), tc)
		draw_rect(Rect2(gx - 16, base - gh*0.72, 32, 6), tc)

	# ══ СЛОЙ 7: Туман (3 полосы, разная глубина) ══
	draw_rect(Rect2(ox, base - vh*0.28, vw, vh*0.10),
		Color(0.08, 0.02, 0.06, 0.30))
	draw_rect(Rect2(ox, base - vh*0.20, vw, vh*0.12),
		Color(0.10, 0.03, 0.07, 0.42))
	draw_rect(Rect2(ox, base - vh*0.10, vw, vh*0.10),
		Color(0.06, 0.02, 0.04, 0.60))
	# Земля
	draw_rect(Rect2(ox, base - vh*0.06, vw, vh*0.06), Color(0.03, 0.01, 0.02))

	# ══ СЛОЙ 8: Лунный свет вниз — едва заметные холодные лучи ══
	for ri2 in range(5):
		var angle2 := PI * 0.5 + (float(ri2) - 2.0) * 0.14
		var ray_a2 := (0.025 - absf(float(ri2) - 2.0) * 0.006) * moon_pulse
		draw_line(
			Vector2(lx, ly + 68),
			Vector2(lx + cos(angle2) * vw * 0.9, ly + sin(angle2) * vh * 1.2),
			Color(0.55, 0.58, 0.75, ray_a2), 10.0
		)

	# ══ СЛОЙ 9: Угли — приглушённее ══
	for ember in _splash_embers:
		draw_circle(
			Vector2(ox + ember["x"], oy + ember["y"]),
			ember["size"],
			Color(0.90, 0.55, 0.20, ember["alpha"] * 0.45)
		)

	# ══ СЛОЙ 10: Затемнение центра для читаемости UI ══
	# Мягкий тёмный овал позади текста — как тень от нависающего облака
	for layer in range(4):
		var la := 0.12 - float(layer) * 0.025
		var lw := vw * (0.70 - float(layer) * 0.10)
		var lh := vh * (0.55 - float(layer) * 0.06)
		draw_rect(Rect2(mx - lw*0.5, oy + vh*0.28 - lh*0.05, lw, lh),
			Color(0.0, 0.0, 0.0, la))

	# ══ UI: Заголовок ══
	var title_pulse := sin(t * 0.032) * 0.08 + 0.92
	var title_y := oy + vh * 0.38

	# Тёмный подложка за заголовком для читаемости
	draw_circle(Vector2(mx, title_y - 20), 300, Color(0.0, 0.0, 0.02, 0.30 * title_pulse))
	draw_circle(Vector2(mx, title_y - 20), 180, Color(0.0, 0.0, 0.02, 0.20 * title_pulse))

	# Главный заголовок
	draw_string(font, Vector2(ox, title_y),
		"SABBATH", HORIZONTAL_ALIGNMENT_CENTER, vw, 88,
		Color(0.98, 0.88, 0.55, title_pulse))
	# Тень заголовка
	draw_string(font, Vector2(ox + 3, title_y + 3),
		"SABBATH", HORIZONTAL_ALIGNMENT_CENTER, vw, 88,
		Color(0.30, 0.05, 0.02, 0.40 * title_pulse))

	# Подзаголовок
	draw_string(font, Vector2(ox, title_y + 56),
		"A m o n g   L i f e   a n d   D e a t h",
		HORIZONTAL_ALIGNMENT_CENTER, vw, 20,
		Color(0.68, 0.50, 0.35, 0.80))

	# Горизонтальный орнамент под подзаголовком
	var orn_y := title_y + 82
	var orn_w  := vw * 0.18
	draw_line(Vector2(mx - orn_w, orn_y), Vector2(mx - 12, orn_y),
		Color(0.62, 0.40, 0.18, 0.50), 1.0)
	draw_line(Vector2(mx + 12, orn_y), Vector2(mx + orn_w, orn_y),
		Color(0.62, 0.40, 0.18, 0.50), 1.0)
	draw_circle(Vector2(mx, orn_y), 4, Color(0.78, 0.50, 0.20, 0.75))
	draw_circle(Vector2(mx - orn_w * 0.5, orn_y), 2, Color(0.62, 0.40, 0.18, 0.45))
	draw_circle(Vector2(mx + orn_w * 0.5, orn_y), 2, Color(0.62, 0.40, 0.18, 0.45))

	# ══ UI: Пункты меню ══
	var items: Array[String] = ["НОВАЯ  ИГРА", "ВЫХОД"]
	var item_start_y := title_y + 120.0
	var item_spacing := 80.0

	for i in range(items.size()):
		var item_y := item_start_y + float(i) * item_spacing
		var is_sel := i == _menu_selected

		if is_sel:
			var sp := sin(t * 0.07) * 0.10 + 0.90
			# Мягкое затемнение за выбранным — без цвета, просто читаемость
			draw_rect(Rect2(ox + vw*0.25, item_y - 36, vw*0.50, 54),
				Color(0.0, 0.0, 0.0, 0.22 * sp))
			draw_rect(Rect2(ox + vw*0.32, item_y - 30, vw*0.36, 44),
				Color(0.0, 0.0, 0.0, 0.12 * sp))
			# Текст выбранного — ярко, крупно
			draw_string(font, Vector2(ox, item_y),
				items[i], HORIZONTAL_ALIGNMENT_CENTER, vw, 38,
				Color(0.98, 0.92, 0.65, sp))
			# Подчёркивание — тонкая светящаяся линия
			var sw := font.get_string_size(items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
			var sx := mx - sw * 0.5
			draw_line(Vector2(sx, item_y + 7), Vector2(sx + sw, item_y + 7),
				Color(0.85, 0.65, 0.28, 0.70 * sp), 1.5)
		else:
			draw_string(font, Vector2(ox, item_y),
				items[i], HORIZONTAL_ALIGNMENT_CENTER, vw, 28,
				Color(0.52, 0.34, 0.22, 0.55))

	# ══ UI: Подсказка навигации (едва заметна) ══
	var ha := sin(t * 0.04) * 0.12 + 0.28
	draw_string(font, Vector2(ox, base - vh * 0.06),
		"W / S   навигация          Enter   выбор",
		HORIZONTAL_ALIGNMENT_CENTER, vw, 14,
		Color(0.55, 0.48, 0.38, ha))

func _draw_menu_tree(tx: float, ty: float, tw: float, th: float, col: Color) -> void:
	# Ствол
	draw_rect(Rect2(tx - tw*0.08, ty - th*0.35, tw*0.16, th*0.35), col)
	# Крона — несколько наслоённых треугольников через полигоны
	for layer in range(4):
		var lf := float(layer) / 3.0
		var lw := tw * (1.0 - lf * 0.45)
		var lh := th * 0.30
		var ly2 := ty - th * (0.30 + lf * 0.55)
		var tri := PackedVector2Array([
			Vector2(tx,        ly2 - lh),
			Vector2(tx - lw*0.5, ly2),
			Vector2(tx + lw*0.5, ly2),
		])
		draw_colored_polygon(tri, col)
#endregion
