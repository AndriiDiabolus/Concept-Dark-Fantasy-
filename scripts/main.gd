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
var _gate_intro: bool = false
var _gate_intro_t: float = 0.0
const GATE_INTRO_DUR: float = 3.2
const MENU_INTRO_DUR: int = 620   # кадры кинематографического интро
const MENU_INTRO_BTN: int = 540   # с какого кадра кнопки появляются
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

#region Назва кімнати
var _room_title_t: float = 999.0  # секунды с начала уровня; 999 = уже скрыто
#endregion

#region Перехід між рівнями
var _fade_t: float     = 0.0   # 0.0 = прозорий, 1.0 = чорний
var _fade_dir: int     = 0     # 0 = стоїмо, 1 = темніємо, 2 = світлішаємо
var _fade_next: int    = -1    # індекс наступного рівня
var _spawn_right: bool = false # true = спавн справа (повернення назад)
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
	if current_state != C.STATE.MENU or _gate_intro:
		return
	match _menu_selected:
		0:
			_gate_intro = true
			_gate_intro_t = 0.0
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
	_room_title_t = 0.0
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
		var spawn_x := (level_width - 150.0) if _spawn_right else 150.0
		player.global_position = Vector2(spawn_x, C.GROUND_Y - C.PLAYER_SIZE.y * 0.5)
		_spawn_right = false
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
		0:  # TESTROOM — тестовая комната для экспериментов
			return {
				"name": "TESTROOM",
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
		1:  # Sitch — WIP (пока тёмный экран)
			return {
				"name": "Sitch",
				"width": 3600.0,
				"platforms": [
					Rect2(0, gnd, 3600, 400),
				],
				"enemies": [],
			}
		2:  # Сожжённые Сёла
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
		3:  # Подступы к Замку
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
		4:  # Цитадель
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
			if _gate_intro:
				_gate_intro_t += delta
				if _gate_intro_t >= GATE_INTRO_DUR:
					_gate_intro = false
					_start_game()
		C.STATE.PLAY:
			level_timer += delta
			if _room_title_t < 5.0:
				_room_title_t += delta
			_update_camera()
			# Триггер правого края — переход вперёд
			if _fade_dir == 0 and player and player.global_position.x >= level_width - 80.0:
				_fade_dir  = 1
				_fade_next = current_level + 1
			# Триггер левого края — возврат назад
			elif _fade_dir == 0 and player and player.global_position.x <= 80.0 and current_level > 0:
				_fade_dir    = 1
				_fade_next   = current_level - 1
				_spawn_right = true

	# Обновляем фейд независимо от состояния
	if _fade_dir == 1:
		_fade_t = minf(_fade_t + delta * 2.0, 1.0)
		if _fade_t >= 1.0:
			if _fade_next < 5:
				load_level(_fade_next)
			else:
				_go_to_menu()
			_fade_dir = 2
	elif _fade_dir == 2:
		_fade_t = maxf(_fade_t - delta * 2.0, 0.0)
		if _fade_t <= 0.0:
			_fade_dir = 0
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
		if _gate_intro or _menu_t < MENU_INTRO_BTN:
			return
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
			if next < 5:
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

	# Sitch — пока тёмный экран, комната в разработке
	if current_level == 1:
		var vw := float(C.VIEWPORT_WIDTH)
		var vh := get_viewport_rect().size.y
		draw_rect(Rect2(ox, oy, vw, vh), Color(0.0, 0.0, 0.0, 0.92))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(ox, oy + vh * 0.5),
			"Sitch — в разработке", HORIZONTAL_ALIGNMENT_CENTER, vw, 28, Color(0.4, 0.3, 0.2, 0.6))

	_draw_hud(ox, oy)

	match current_state:
		C.STATE.PAUSE: _draw_overlay(ox, oy, "ПАУЗА",   Color(0.0, 0.0, 0.0, 0.55), "ESC — продолжить")
		C.STATE.LOST:  _draw_overlay(ox, oy, "ГИБЕЛЬ",  Color(0.35, 0.0, 0.0, 0.65), "Enter — в главное меню")
		C.STATE.WON:   _draw_overlay(ox, oy, "ПОБЕДА",  Color(0.0, 0.18, 0.0, 0.60), "Enter — продолжить" if current_level < 4 else "Enter — в главное меню")

	# Название комнаты — появляется при входе, потом тухнет (стиль SABBATH)
	if _room_title_t < 4.5:
		var font  := ThemeDB.fallback_font
		var vw    := float(C.VIEWPORT_WIDTH)
		var vh    := get_viewport_rect().size.y
		var ta    := clampf(_room_title_t / 0.8, 0.0, 1.0) * clampf((4.5 - _room_title_t) / 1.0, 0.0, 1.0)
		var tp    := (sin(_room_title_t * 1.8) * 0.04 + 0.96) * ta
		var ty    := oy + vh * 0.22
		draw_string(font, Vector2(ox+4, ty+5),  level_name,
			HORIZONTAL_ALIGNMENT_CENTER, vw, 88, Color(0.10, 0.02, 0.01, 0.55*tp))
		draw_string(font, Vector2(ox-1, ty-1),  level_name,
			HORIZONTAL_ALIGNMENT_CENTER, vw, 91, Color(0.95, 0.65, 0.15, 0.16*tp))
		draw_string(font, Vector2(ox,   ty),    level_name,
			HORIZONTAL_ALIGNMENT_CENTER, vw, 88, Color(0.98, 0.90, 0.62, tp))

	# Фейд перехода между уровнями — поверх всего
	if _fade_t > 0.0:
		draw_rect(Rect2(ox, oy, float(C.VIEWPORT_WIDTH), get_viewport_rect().size.y),
			Color(0.0, 0.0, 0.0, _fade_t))

	# Экран фокуса — показывается пока не кликнули
	if not _focused:
		var font := ThemeDB.fallback_font
		var vw := float(C.VIEWPORT_WIDTH)
		var vh := get_viewport_rect().size.y
		draw_rect(Rect2(ox, oy, vw, vh), Color(0.0, 0.0, 0.0, 0.65))
		draw_string(font, Vector2(ox + vw * 0.5 - 220, oy + vh * 0.5 - 10),
			"КЛИКНИ НА ЭКРАН ЧТОБЫ НАЧАТЬ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.85, 0.3))

func _draw_background(ox: float, oy: float) -> void:
	var vw := float(C.VIEWPORT_WIDTH)
	var vh := get_viewport_rect().size.y

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
	var vh   := get_viewport_rect().size.y
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
	var vh   := get_viewport_rect().size.y
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
	if _menu_t < MENU_INTRO_DUR:
		_draw_menu_intro(ox, oy)
		return

	var font := ThemeDB.fallback_font
	var vw   := float(C.VIEWPORT_WIDTH)
	var vh   := get_viewport_rect().size.y
	var t    := float(_menu_t)
	var mx   := ox + vw * 0.5
	var base := oy + vh



	# ── Анимация влёта в ворота ──
	if _gate_intro:
		var progress := clampf(_gate_intro_t / GATE_INTRO_DUR, 0.0, 1.0)
		var ease_p   := progress * progress * progress   # cubic ease-in
		var zoom     := 1.0 + 22.0 * ease_p             # 1.0 → 23.0
		# Центр ворот в координатах _draw
		var gate_x   := ox + vw * 0.5
		var gate_y   := oy + vh * 0.92 - 29.0
		# Масштабирование вокруг ворот
		draw_set_transform(Vector2(gate_x, gate_y) * (1.0 - zoom), 0.0, Vector2(zoom, zoom))

	# ══ СЛОЙ 1: Небо — холодный тёмно-синий градиент ══
	draw_rect(Rect2(ox, oy,            vw, vh * 0.30), Color(0.03, 0.02, 0.10))
	draw_rect(Rect2(ox, oy+vh*0.25,   vw, vh * 0.20), Color(0.05, 0.03, 0.12))
	draw_rect(Rect2(ox, oy+vh*0.40,   vw, vh * 0.20), Color(0.06, 0.03, 0.11))
	draw_rect(Rect2(ox, oy+vh*0.55,   vw, vh * 0.20), Color(0.07, 0.03, 0.09))
	draw_rect(Rect2(ox, oy+vh*0.70,   vw, vh * 0.30), Color(0.06, 0.02, 0.06))
	# Horizon glow — зловещее тёмно-пурпурное зарево у горизонта
	draw_rect(Rect2(ox, oy+vh*0.62,   vw, vh * 0.16), Color(0.20, 0.04, 0.10, 0.22))
	draw_rect(Rect2(ox, oy+vh*0.69,   vw, vh * 0.10), Color(0.24, 0.05, 0.08, 0.18))
	draw_rect(Rect2(ox, oy+vh*0.76,   vw, vh * 0.08), Color(0.14, 0.03, 0.05, 0.14))

	# ══ СЛОЙ 2: Звёзды ══
	var rng := RandomNumberGenerator.new()
	rng.seed = 7771
	for _s in range(120):
		var sx := ox + rng.randf() * vw
		var sy := oy + rng.randf() * vh * 0.52
		var sa := rng.randf() * 0.6 + 0.3
		var ss := rng.randf() * 2.0 + 0.5
		sa *= (sin(t * 0.04 + rng.randf() * TAU) * 0.30 + 0.70)
		if ss > 1.8:
			draw_line(Vector2(sx - ss*2.2, sy), Vector2(sx + ss*2.2, sy),
				Color(0.90, 0.88, 0.80, sa * 0.35), 1.0)
			draw_line(Vector2(sx, sy - ss*2.2), Vector2(sx, sy + ss*2.2),
				Color(0.90, 0.88, 0.80, sa * 0.35), 1.0)
		draw_circle(Vector2(sx, sy), ss, Color(0.88, 0.85, 0.82, sa))
	# Падающая звезда (~10 сек цикл)
	var shoot_phase := fmod(t * 0.007, TAU)
	if shoot_phase < 0.18:
		var sp2 := shoot_phase / 0.18
		draw_line(
			Vector2(ox + vw * 0.72 - sp2 * vw * 0.32, oy + vh * 0.07 + sp2 * vh * 0.10),
			Vector2(ox + vw * 0.72 - sp2 * vw * 0.32 + 55*(1-sp2), oy + vh * 0.07 + sp2 * vh * 0.10 - 18*(1-sp2)),
			Color(0.95, 0.92, 0.82, (1.0 - sp2) * 0.85), 2.0)

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

	# ══ СЛОЙ 4: Горы ══
	# Дальний план — голубоватые, туманные
	draw_colored_polygon(PackedVector2Array([
		Vector2(ox,           base - vh*0.22),
		Vector2(ox+vw*0.10,  base - vh*0.32),
		Vector2(ox+vw*0.22,  base - vh*0.24),
		Vector2(ox+vw*0.34,  base - vh*0.38),
		Vector2(ox+vw*0.46,  base - vh*0.28),
		Vector2(ox+vw*0.55,  base - vh*0.40),
		Vector2(ox+vw*0.66,  base - vh*0.26),
		Vector2(ox+vw*0.76,  base - vh*0.34),
		Vector2(ox+vw*0.88,  base - vh*0.24),
		Vector2(ox+vw,       base - vh*0.20),
		Vector2(ox+vw, base), Vector2(ox, base),
	]), Color(0.05, 0.03, 0.10, 0.75))
	# Ближний план — основные горы
	var mc := Color(0.08, 0.02, 0.09)
	var mountains := PackedVector2Array([
		Vector2(ox,           base - vh*0.18),
		Vector2(ox+vw*0.08,  base - vh*0.38),
		Vector2(ox+vw*0.18,  base - vh*0.22),
		Vector2(ox+vw*0.28,  base - vh*0.44),
		Vector2(ox+vw*0.38,  base - vh*0.26),
		Vector2(ox+vw*0.50,  base - vh*0.48),
		Vector2(ox+vw*0.62,  base - vh*0.28),
		Vector2(ox+vw*0.72,  base - vh*0.42),
		Vector2(ox+vw*0.82,  base - vh*0.20),
		Vector2(ox+vw*0.92,  base - vh*0.36),
		Vector2(ox+vw,       base - vh*0.18),
		Vector2(ox+vw, base), Vector2(ox, base),
	])
	draw_colored_polygon(mountains, mc)
	# Highlight вершин — холодный лунный свет
	draw_polyline(PackedVector2Array([
		Vector2(ox,           base - vh*0.18),
		Vector2(ox+vw*0.08,  base - vh*0.38),
		Vector2(ox+vw*0.18,  base - vh*0.22),
		Vector2(ox+vw*0.28,  base - vh*0.44),
		Vector2(ox+vw*0.38,  base - vh*0.26),
		Vector2(ox+vw*0.50,  base - vh*0.48),
		Vector2(ox+vw*0.62,  base - vh*0.28),
		Vector2(ox+vw*0.72,  base - vh*0.42),
		Vector2(ox+vw*0.82,  base - vh*0.20),
		Vector2(ox+vw*0.92,  base - vh*0.36),
		Vector2(ox+vw,       base - vh*0.18),
	]), Color(0.38, 0.28, 0.52, 0.55), 1.5)
		# ══ СЛОЙ 5: Замок — чёткий силуэт + лунный highlight ══
	var cc  := Color(0.07, 0.03, 0.08)
	var chl := Color(0.30, 0.26, 0.38)
	var bx := mx
	var castle_base := base - vh * 0.08

	# Лунное свечение вокруг замка
	draw_circle(Vector2(bx, castle_base - 150), 230, Color(0.38, 0.36, 0.52, 0.06 * moon_pulse))
	draw_circle(Vector2(bx, castle_base - 150), 140, Color(0.32, 0.30, 0.45, 0.09 * moon_pulse))

	# Центральная башня
	draw_rect(Rect2(bx - 52, castle_base - 260, 104, 260), cc)
	draw_line(Vector2(bx - 52, castle_base - 260), Vector2(bx - 52, castle_base), chl, 1.5)
	draw_line(Vector2(bx + 52, castle_base - 260), Vector2(bx + 52, castle_base), Color(chl.r*0.5, chl.g*0.5, chl.b*0.5, 0.4), 1.0)
	# Зубцы
	for i in range(6):
		draw_rect(Rect2(bx - 48 + i * 18, castle_base - 285, 12, 28), cc)
		draw_line(Vector2(bx - 48 + i*18, castle_base - 285),
			Vector2(bx - 36 + i*18, castle_base - 285), chl, 1.0)

	# Арочное окно — яркое
	draw_circle(Vector2(bx, castle_base - 120), 22, Color(0.01, 0.00, 0.02))
	draw_rect(Rect2(bx - 22, castle_base - 120, 44, 22), Color(0.01, 0.00, 0.02))
	var wf1 := sin(t * 0.13 + 0.7) * 0.18 + 0.82
	draw_circle(Vector2(bx, castle_base - 122), 22, Color(0.85, 0.42, 0.05, 0.50 * wf1))
	draw_circle(Vector2(bx, castle_base - 120), 13, Color(0.98, 0.75, 0.28, 0.92 * wf1))

	# Малые окна центра — яркие
	draw_rect(Rect2(bx - 14, castle_base - 200, 12, 18), Color(0.01, 0.00, 0.02))
	draw_rect(Rect2(bx +  2, castle_base - 200, 12, 18), Color(0.01, 0.00, 0.02))
	var wf2 := sin(t * 0.09 + 2.1) * 0.15 + 0.85
	draw_rect(Rect2(bx - 14, castle_base - 200, 12, 18), Color(0.95, 0.60, 0.15, 0.80 * wf2))
	draw_rect(Rect2(bx +  2, castle_base - 200, 12, 18), Color(0.95, 0.60, 0.15, 0.80 * wf2))

	# Левая башня
	draw_rect(Rect2(bx - 160, castle_base - 170, 62, 170), cc)
	draw_line(Vector2(bx - 160, castle_base - 170), Vector2(bx - 160, castle_base), chl, 1.5)
	draw_line(Vector2(bx - 160, castle_base - 170), Vector2(bx - 98, castle_base - 170), chl, 1.0)
	for i in range(4):
		draw_rect(Rect2(bx - 158 + i * 16, castle_base - 192, 11, 24), cc)
	var wf3 := sin(t * 0.11 + 4.2) * 0.20 + 0.80
	draw_rect(Rect2(bx - 148, castle_base - 130, 10, 16), Color(0.01, 0.00, 0.02))
	draw_rect(Rect2(bx - 148, castle_base - 130, 10, 16), Color(0.95, 0.60, 0.15, 0.80 * wf3))

	# Правая башня
	draw_rect(Rect2(bx + 98, castle_base - 155, 58, 155), cc)
	draw_line(Vector2(bx + 98, castle_base - 155), Vector2(bx + 98, castle_base), chl, 1.5)
	draw_line(Vector2(bx + 98, castle_base - 155), Vector2(bx + 156, castle_base - 155), chl, 1.0)
	for i in range(4):
		draw_rect(Rect2(bx + 100 + i * 15, castle_base - 176, 10, 22), cc)
	var wf4 := sin(t * 0.07 + 1.8) * 0.15 + 0.85
	draw_rect(Rect2(bx + 112, castle_base - 118, 10, 16), Color(0.01, 0.00, 0.02))
	draw_rect(Rect2(bx + 112, castle_base - 118, 10, 16), Color(0.95, 0.60, 0.15, 0.80 * wf4))

	# Стены
	draw_rect(Rect2(bx - 98, castle_base - 80, 46, 80), cc)
	draw_rect(Rect2(bx + 52, castle_base - 72, 46, 72), cc)
	draw_line(Vector2(bx - 98, castle_base - 80), Vector2(bx - 52, castle_base - 80), chl, 1.0)
	draw_line(Vector2(bx + 52, castle_base - 72), Vector2(bx + 98, castle_base - 72), chl, 1.0)

	# Ворота
	draw_rect(Rect2(bx - 22, castle_base - 58, 44, 58), Color(0.01, 0.00, 0.02))
	draw_circle(Vector2(bx, castle_base - 58), 22, Color(0.01, 0.00, 0.02))

	# Дым
	for sm in range(6):
		var smf := fmod(t * 0.014 + float(sm) * 0.38, 1.0)
		var smy := castle_base - 292 - smf * 90
		var smx := bx + sin(smf * 3.5 + float(sm) * 1.3) * 10
		draw_circle(Vector2(smx, smy), 7 + smf * 16, Color(0.14, 0.09, 0.16, (1.0 - smf) * 0.16))

	# ══ СЛОЙ 6: Деревья/руины по бокам ══
	var tc := Color(0.06, 0.015, 0.04)
	# Дальній план дерев (менший масштаб — глибина)
	_draw_menu_tree(ox+vw*0.20, base-vh*0.05, 36.0, 132.0, Color(0.048, 0.010, 0.030))
	_draw_menu_tree(ox+vw*0.78, base-vh*0.05, 32.0, 118.0, Color(0.048, 0.010, 0.030))
	# Ближній план дерев
	_draw_menu_tree(ox + vw*0.06, base - vh*0.05, 80.0, 280.0, tc)
	_draw_menu_tree(ox + vw*0.13, base - vh*0.04, 55.0, 200.0, tc)
	_draw_menu_tree(ox + vw*0.87, base - vh*0.05, 75.0, 260.0, tc)
	_draw_menu_tree(ox + vw*0.94, base - vh*0.04, 50.0, 190.0, tc)
	# Кресты на переднем плане
	var crosses: Array[float] = [0.18, 0.30, 0.68, 0.80]
	for cp: float in crosses:
		var gx := ox + vw * cp
		var gh := vh * (0.09 + fmod(cp * 7.3, 0.06))
		draw_rect(Rect2(gx - 4, base - gh, 8, gh), tc)
		draw_rect(Rect2(gx - 16, base - gh*0.72, 32, 6), tc)

	# ══ СЛОЙ 7: Туман — лёгкий, не перекрывает замок ══
	var ft := t * 0.006
	draw_rect(Rect2(ox, base - vh*0.18 + sin(ft*1.1)*5, vw, vh*0.08), Color(0.08, 0.02, 0.06, 0.10))
	draw_rect(Rect2(ox, base - vh*0.12 + sin(ft*0.7+1.2)*6, vw, vh*0.10), Color(0.10, 0.03, 0.07, 0.16))
	draw_rect(Rect2(ox, base - vh*0.06 + sin(ft*0.9+2.4)*4, vw, vh*0.07), Color(0.07, 0.02, 0.05, 0.22))
	# Земля
	draw_rect(Rect2(ox, base - vh*0.05, vw, vh*0.05), Color(0.025, 0.008, 0.018))

	# ══ СЛОЙ 8: Лунные лучи ══
	for ri2 in range(7):
		var angle2 := PI * 0.5 + (float(ri2) - 3.0) * 0.12
		var ray_a2 := (0.032 - absf(float(ri2) - 3.0) * 0.005) * moon_pulse
		draw_line(Vector2(lx, ly + 68),
			Vector2(lx + cos(angle2) * vw, ly + sin(angle2) * vh * 1.3),
			Color(0.55, 0.58, 0.75, ray_a2), 12.0)

	# ══ СЛОЙ 9: Угли ══
	for ember in _splash_embers:
		draw_circle(Vector2(ox + ember["x"], oy + ember["y"]),
			ember["size"], Color(0.90, 0.55, 0.20, ember["alpha"] * 0.45))

	# ══ СЛОЙ 10: Плавающие пылинки в лунном свете ══
	var prng := RandomNumberGenerator.new()
	prng.seed = 3337
	for _p in range(28):
		var px2 := prng.randf()
		var pspeed := prng.randf() * 0.35 + 0.18
		var psize2 := prng.randf() * 1.4 + 0.5
		var pa_base := prng.randf() * 0.35 + 0.15
		var ptime := fmod(t * pspeed * 0.007 + px2 * 8.0, 1.0)
		var pdx := ox + px2 * vw
		var pdy := oy + (1.0 - ptime) * vh * 0.82 + vh * 0.06
		var pa := maxf(0.0, pa_base * (1.0 - absf(ptime - 0.5) * 1.8) *
			(sin(t * 0.05 + prng.randf() * TAU) * 0.25 + 0.75))
		draw_circle(Vector2(pdx, pdy), psize2, Color(0.80, 0.78, 0.72, pa * 0.50))

	# ══ СЛОЙ 11: Виньетка ══
	for vi in range(5):
		var va := (1.0 - float(vi) / 4.0) * 0.30
		var vw2 := vw * (0.05 - float(vi) * 0.0075)
		draw_rect(Rect2(ox,              oy, vw2,  vh), Color(0, 0, 0, va))
		draw_rect(Rect2(ox + vw - vw2,   oy, vw2,  vh), Color(0, 0, 0, va))
	draw_rect(Rect2(ox, oy,           vw, vh * 0.04), Color(0, 0, 0, 0.50))
	draw_rect(Rect2(ox, oy+vh*0.96,   vw, vh * 0.04), Color(0, 0, 0, 0.50))

	# ══ UI: Заголовок ══
	var title_pulse := sin(t * 0.028) * 0.06 + 0.94
	var title_y := oy + vh * 0.38

	# Заголовок — 3 слоя: тень + свечение + основной
	draw_string(font, Vector2(ox + 4, title_y + 5),
		"SABBATH", HORIZONTAL_ALIGNMENT_CENTER, vw, 88,
		Color(0.10, 0.02, 0.01, 0.55 * title_pulse))
	draw_string(font, Vector2(ox - 1, title_y - 1),
		"SABBATH", HORIZONTAL_ALIGNMENT_CENTER, vw, 91,
		Color(0.95, 0.65, 0.15, 0.16 * title_pulse))
	draw_string(font, Vector2(ox + 1, title_y + 1),
		"SABBATH", HORIZONTAL_ALIGNMENT_CENTER, vw, 91,
		Color(0.95, 0.65, 0.15, 0.10 * title_pulse))
	draw_string(font, Vector2(ox, title_y),
		"SABBATH", HORIZONTAL_ALIGNMENT_CENTER, vw, 88,
		Color(0.98, 0.90, 0.62, title_pulse))

	# Подзаголовок
	draw_string(font, Vector2(ox + 1, title_y + 57),
		"A m o n g   L i f e   a n d   D e a t h",
		HORIZONTAL_ALIGNMENT_CENTER, vw, 20, Color(0.10, 0.04, 0.02, 0.45))
	draw_string(font, Vector2(ox, title_y + 56),
		"A m o n g   L i f e   a n d   D e a t h",
		HORIZONTAL_ALIGNMENT_CENTER, vw, 20, Color(0.72, 0.55, 0.38, 0.88))

	# Орнамент — линии + ромб + точки
	var orn_y := title_y + 84
	var orn_w  := vw * 0.24
	draw_line(Vector2(mx - orn_w, orn_y), Vector2(mx - 14, orn_y),
		Color(0.65, 0.42, 0.18, 0.52), 1.0)
	draw_line(Vector2(mx + 14, orn_y), Vector2(mx + orn_w, orn_y),
		Color(0.65, 0.42, 0.18, 0.52), 1.0)
	var ds := 5.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(mx, orn_y - ds), Vector2(mx + ds, orn_y),
		Vector2(mx, orn_y + ds), Vector2(mx - ds, orn_y),
	]), Color(0.85, 0.58, 0.22, 0.88))
	draw_circle(Vector2(mx - orn_w * 0.45, orn_y), 2.5, Color(0.65, 0.42, 0.18, 0.48))
	draw_circle(Vector2(mx + orn_w * 0.45, orn_y), 2.5, Color(0.65, 0.42, 0.18, 0.48))
	draw_circle(Vector2(mx - orn_w * 0.22, orn_y), 1.8, Color(0.65, 0.42, 0.18, 0.35))
	draw_circle(Vector2(mx + orn_w * 0.22, orn_y), 1.8, Color(0.65, 0.42, 0.18, 0.35))

	# ══ UI: Пункты меню ══
	var items: Array[String] = ["НОВАЯ  ИГРА", "ВЫХОД"]
	var item_start_y := title_y + 126.0
	var item_spacing := 78.0

	for i in range(items.size()):
		var item_y := item_start_y + float(i) * item_spacing
		var is_sel := i == _menu_selected

		if is_sel:
			var sp := sin(t * 0.07) * 0.08 + 0.92
			var sw  := font.get_string_size(items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
			var sx  := mx - sw * 0.5
			# Фоновое свечение
			draw_rect(Rect2(sx - 28, item_y - 36, sw + 56, 52), Color(0.12, 0.07, 0.02, 0.18 * sp))
			# Горизонтальные линии рамки
			draw_line(Vector2(sx - 22, item_y - 32), Vector2(sx + sw + 22, item_y - 32),
				Color(0.75, 0.50, 0.18, 0.38 * sp), 1.0)
			draw_line(Vector2(sx - 22, item_y + 11), Vector2(sx + sw + 22, item_y + 11),
				Color(0.75, 0.50, 0.18, 0.38 * sp), 1.0)
			# Угловые уголки
			for cxi in [sx - 24.0, sx + sw + 14.0]:
				for cyi_off in [-32.0, 11.0]:
					var cyi:  float = item_y + float(cyi_off)
					var cxif: float = float(cxi)
					var xd := 1.0 if cxif < mx else -1.0
					var yd := 1.0 if float(cyi_off) < 0.0 else -1.0
					draw_line(Vector2(cxif, cyi), Vector2(cxif + xd*10, cyi),
						Color(0.90, 0.64, 0.22, 0.72 * sp), 1.5)
					draw_line(Vector2(cxif, cyi), Vector2(cxif, cyi + yd*10),
						Color(0.90, 0.64, 0.22, 0.72 * sp), 1.5)
			# Боковые ромбы
			for rdx in [sx - 30.0, sx + sw + 30.0]:
				var rdxf: float = float(rdx)
				draw_colored_polygon(PackedVector2Array([
					Vector2(rdxf, item_y - 11), Vector2(rdxf + 4, item_y - 6),
					Vector2(rdxf, item_y - 2),  Vector2(rdxf - 4, item_y - 6),
				]), Color(0.90, 0.64, 0.22, 0.62 * sp))
			# Текст — тень + основной
			draw_string(font, Vector2(ox + 2, item_y + 2),
				items[i], HORIZONTAL_ALIGNMENT_CENTER, vw, 38,
				Color(0.12, 0.04, 0.01, 0.48 * sp))
			draw_string(font, Vector2(ox, item_y),
				items[i], HORIZONTAL_ALIGNMENT_CENTER, vw, 38,
				Color(1.00, 0.95, 0.68, sp))
		else:
			draw_string(font, Vector2(ox, item_y),
				items[i], HORIZONTAL_ALIGNMENT_CENTER, vw, 26,
				Color(0.50, 0.34, 0.20, 0.50))

	# ══ UI: Подсказка навигации ══
	if not _gate_intro:
		var ha := sin(t * 0.035) * 0.10 + 0.22
		draw_string(font, Vector2(ox, base - vh * 0.065),
			"W / S   навигация          Enter   выбор",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 14,
			Color(0.58, 0.50, 0.38, ha))

	# Сброс трансформации и затемнение при gate_intro
	if _gate_intro:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var progress := clampf(_gate_intro_t / GATE_INTRO_DUR, 0.0, 1.0)
		var dark_a   := clampf((progress - 0.55) / 0.45, 0.0, 1.0)
		draw_rect(Rect2(ox, oy, vw, vh), Color(0.0, 0.0, 0.0, dark_a))

func _draw_menu_intro(ox: float, oy: float) -> void:
	var tf   := _menu_t
	var vw   := float(C.VIEWPORT_WIDTH)
	var vh   := get_viewport_rect().size.y
	var mx   := ox + vw * 0.5
	var base := oy + vh
	var font := ThemeDB.fallback_font

	# Прогресс каждого слоя
	var comet_p   := clampf(float(tf -  10) / 120.0, 0.0, 1.0)
	var moon_p    := clampf(float(tf -  60) / 240.0, 0.0, 1.0)
	var land_a    := clampf(float(tf - 150) /  80.0, 0.0, 1.0)
	var sky_a     := clampf(float(tf - 180) / 220.0, 0.0, 1.0)
	var stars_a   := clampf(float(tf - 240) / 240.0, 0.0, 1.0)
	var lights_a  := clampf(float(tf - 300) / 140.0, 0.0, 1.0)
	var title_a   := clampf(float(tf - 440) / 120.0, 0.0, 1.0)
	var buttons_a := clampf(float(tf - 540) /  60.0, 0.0, 1.0)

	# ── 1. Чёрная подложка ──────────────────────────────────────────────────
	draw_rect(Rect2(ox, oy, vw, vh), Color(0.0, 0.0, 0.0))

	# ── 2. Небо (проявляется) ───────────────────────────────────────────────
	if sky_a > 0.0:
		draw_rect(Rect2(ox, oy,          vw, vh*0.30), Color(0.03, 0.02, 0.10, sky_a))
		draw_rect(Rect2(ox, oy+vh*0.25,  vw, vh*0.20), Color(0.05, 0.03, 0.12, sky_a))
		draw_rect(Rect2(ox, oy+vh*0.40,  vw, vh*0.20), Color(0.06, 0.03, 0.11, sky_a))
		draw_rect(Rect2(ox, oy+vh*0.55,  vw, vh*0.20), Color(0.07, 0.03, 0.09, sky_a))
		draw_rect(Rect2(ox, oy+vh*0.70,  vw, vh*0.30), Color(0.06, 0.02, 0.06, sky_a))
		draw_rect(Rect2(ox, oy+vh*0.62,  vw, vh*0.16), Color(0.20, 0.04, 0.10, 0.22*sky_a))
		draw_rect(Rect2(ox, oy+vh*0.69,  vw, vh*0.10), Color(0.24, 0.05, 0.08, 0.18*sky_a))
		draw_rect(Rect2(ox, oy+vh*0.76,  vw, vh*0.08), Color(0.14, 0.03, 0.05, 0.14*sky_a))

	# ── 3. Луна (восходит из-за гор) ────────────────────────────────────────
	# Те же радиусы, цвета и формула пульса что в _draw_menu → переход незаметен
	var moon_y      := oy + vh * (0.80 - moon_p * 0.62)
	var mtn_peak_y  := oy + vh * 0.52   # высота ближнего пика гор
	var moon_emerge_a := clampf((mtn_peak_y - moon_y) / 90.0, 0.0, 1.0)
	var moon_pi  := (sin(float(tf) * 0.03) * 0.04 + 0.96) * moon_p * moon_emerge_a
	if moon_emerge_a > 0.0:
		draw_circle(Vector2(mx, moon_y), 240, Color(0.30, 0.30, 0.50, 0.03 * moon_pi))
		draw_circle(Vector2(mx, moon_y), 160, Color(0.45, 0.45, 0.60, 0.05 * moon_pi))
		draw_circle(Vector2(mx, moon_y), 110, Color(0.60, 0.62, 0.72, 0.08 * moon_pi))
		draw_circle(Vector2(mx, moon_y),  82, Color(0.75, 0.78, 0.85, 0.12 * moon_pi))
		draw_circle(Vector2(mx, moon_y),  68, Color(0.92, 0.92, 0.96, moon_pi))
		draw_circle(Vector2(mx, moon_y),  68, Color(0.20, 0.24, 0.45, 0.08 * moon_pi))
		draw_circle(Vector2(mx-18, moon_y-12), 8, Color(0.80, 0.80, 0.85, 0.45*moon_emerge_a))
		draw_circle(Vector2(mx+22, moon_y+10), 6, Color(0.80, 0.80, 0.85, 0.38*moon_emerge_a))
		draw_circle(Vector2(mx-6,  moon_y+24), 5, Color(0.80, 0.80, 0.85, 0.32*moon_emerge_a))

	# ── 4. Звёзды (зажигаются постепенно, каждая со случайной задержкой) ────
	if stars_a > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7771
		for _s in range(120):
			var sx  := ox + rng.randf() * vw
			var sy  := oy + rng.randf() * vh * 0.52
			var sa  := rng.randf() * 0.6 + 0.3
			var ss  := rng.randf() * 2.0 + 0.5
			# задержка по золотому сечению — без лишнего randf(), RNG-последовательность
			# остаётся идентичной _draw_menu → в момент перехода звёзды не прыгают
			var sdl := fmod(float(_s) * 0.618034, 1.0)
			var sfa := clampf((stars_a - sdl * 0.65) / 0.35, 0.0, 1.0)
			sa *= sfa * (sin(float(tf) * 0.04 + rng.randf() * TAU) * 0.30 + 0.70)
			if sa <= 0.01:
				continue
			if ss > 1.8:
				draw_line(Vector2(sx-ss*2.2, sy), Vector2(sx+ss*2.2, sy), Color(0.90,0.88,0.80,sa*0.35), 1.0)
				draw_line(Vector2(sx, sy-ss*2.2), Vector2(sx, sy+ss*2.2), Color(0.90,0.88,0.80,sa*0.35), 1.0)
			draw_circle(Vector2(sx, sy), ss, Color(0.88, 0.85, 0.82, sa))

	# ── 5. Комета с ореолом освещения ───────────────────────────────────────
	if comet_p > 0.0 and comet_p < 1.0:
		var ca  := sin(comet_p * PI)
		var cx2 := ox + vw * (0.86 - comet_p * 0.54)
		var cy2 := oy + vh * (0.07 + comet_p * 0.14)
		draw_circle(Vector2(cx2, cy2), 200, Color(0.50, 0.44, 0.30, ca * 0.05))
		draw_circle(Vector2(cx2, cy2),  90, Color(0.65, 0.58, 0.40, ca * 0.12))
		draw_circle(Vector2(cx2, cy2),  40, Color(0.82, 0.74, 0.52, ca * 0.20))
		draw_line(Vector2(cx2, cy2),
			Vector2(cx2 + 80.0*(1.0-comet_p), cy2 - 25.0*(1.0-comet_p)),
			Color(0.95, 0.92, 0.82, ca * 0.80), 2.5)
		draw_line(Vector2(cx2, cy2),
			Vector2(cx2 + 140.0*(1.0-comet_p), cy2 - 44.0*(1.0-comet_p)),
			Color(0.95, 0.92, 0.82, ca * 0.35), 1.5)
		draw_circle(Vector2(cx2, cy2), 4, Color(1.0, 0.98, 0.90, ca))
		draw_circle(Vector2(cx2, cy2), 2, Color(1.0, 1.0, 1.0, ca * 0.90))

	# ── 6–7. Гори — два плани (ідентично _draw_menu, з land_a) ─────────────
	if land_a > 0.0:
		# Дальній план — голубоватый туманный
		draw_colored_polygon(PackedVector2Array([
			Vector2(ox,           base - vh*0.22),
			Vector2(ox+vw*0.10,  base - vh*0.32),
			Vector2(ox+vw*0.22,  base - vh*0.24),
			Vector2(ox+vw*0.34,  base - vh*0.38),
			Vector2(ox+vw*0.46,  base - vh*0.28),
			Vector2(ox+vw*0.55,  base - vh*0.40),
			Vector2(ox+vw*0.66,  base - vh*0.26),
			Vector2(ox+vw*0.76,  base - vh*0.34),
			Vector2(ox+vw*0.88,  base - vh*0.24),
			Vector2(ox+vw,       base - vh*0.20),
			Vector2(ox+vw, base), Vector2(ox, base),
		]), Color(0.05, 0.03, 0.10, 0.75*land_a))
		# Ближній план — основні гори
		draw_colored_polygon(PackedVector2Array([
			Vector2(ox,           base - vh*0.18),
			Vector2(ox+vw*0.08,  base - vh*0.38),
			Vector2(ox+vw*0.18,  base - vh*0.22),
			Vector2(ox+vw*0.28,  base - vh*0.44),
			Vector2(ox+vw*0.38,  base - vh*0.26),
			Vector2(ox+vw*0.50,  base - vh*0.48),
			Vector2(ox+vw*0.62,  base - vh*0.28),
			Vector2(ox+vw*0.72,  base - vh*0.42),
			Vector2(ox+vw*0.82,  base - vh*0.20),
			Vector2(ox+vw*0.92,  base - vh*0.36),
			Vector2(ox+vw,       base - vh*0.18),
			Vector2(ox+vw, base), Vector2(ox, base),
		]), Color(0.08, 0.02, 0.09, land_a))
		# Highlight вершин — холодний місячний блиск
		draw_polyline(PackedVector2Array([
			Vector2(ox,           base - vh*0.18),
			Vector2(ox+vw*0.08,  base - vh*0.38),
			Vector2(ox+vw*0.18,  base - vh*0.22),
			Vector2(ox+vw*0.28,  base - vh*0.44),
			Vector2(ox+vw*0.38,  base - vh*0.26),
			Vector2(ox+vw*0.50,  base - vh*0.48),
			Vector2(ox+vw*0.62,  base - vh*0.28),
			Vector2(ox+vw*0.72,  base - vh*0.42),
			Vector2(ox+vw*0.82,  base - vh*0.20),
			Vector2(ox+vw*0.92,  base - vh*0.36),
			Vector2(ox+vw,       base - vh*0.18),
		]), Color(0.38, 0.28, 0.52, 0.55*land_a), 1.5)

	# ── 8. Замок (проявляется вместе с ландшафтом, огни зажигаются позже) ──
	if land_a > 0.0:
		var cc  := Color(0.07, 0.03, 0.08, land_a)
		var chl := Color(0.30, 0.26, 0.38, land_a)
		var bx  := mx
		var cb  := base - vh * 0.08
		draw_circle(Vector2(bx, cb-150), 230, Color(0.38, 0.36, 0.52, 0.06*land_a*moon_p))
		draw_circle(Vector2(bx, cb-150), 140, Color(0.32, 0.30, 0.45, 0.09*land_a*moon_p))
		draw_rect(Rect2(bx-52, cb-260, 104, 260), cc)
		draw_line(Vector2(bx-52, cb-260), Vector2(bx-52, cb), chl, 1.5)
		draw_line(Vector2(bx+52, cb-260), Vector2(bx+52, cb),
			Color(chl.r*0.5, chl.g*0.5, chl.b*0.5, 0.4*land_a), 1.0)
		for i in range(6):
			draw_rect(Rect2(bx-48+i*18, cb-285, 12, 28), cc)
			draw_line(Vector2(bx-48+i*18, cb-285), Vector2(bx-36+i*18, cb-285), chl, 1.0)
		draw_circle(Vector2(bx, cb-120), 22, Color(0.01, 0.00, 0.02, land_a))
		draw_rect(Rect2(bx-22, cb-120, 44, 22), Color(0.01, 0.00, 0.02, land_a))
		if lights_a > 0.0:
			var wf1 := sin(float(tf)*0.13+0.7)*0.18+0.82
			draw_circle(Vector2(bx, cb-122), 22, Color(0.85, 0.42, 0.05, 0.50*wf1*lights_a))
			draw_circle(Vector2(bx, cb-120), 13, Color(0.98, 0.75, 0.28, 0.92*wf1*lights_a))
		draw_rect(Rect2(bx-14, cb-200, 12, 18), Color(0.01, 0.00, 0.02, land_a))
		draw_rect(Rect2(bx+2,  cb-200, 12, 18), Color(0.01, 0.00, 0.02, land_a))
		if lights_a > 0.0:
			var wf2 := sin(float(tf)*0.09+2.1)*0.15+0.85
			draw_rect(Rect2(bx-14, cb-200, 12, 18), Color(0.95, 0.60, 0.15, 0.80*wf2*lights_a))
			draw_rect(Rect2(bx+2,  cb-200, 12, 18), Color(0.95, 0.60, 0.15, 0.80*wf2*lights_a))
		draw_rect(Rect2(bx-160, cb-170, 62, 170), cc)
		draw_line(Vector2(bx-160, cb-170), Vector2(bx-160, cb), chl, 1.5)
		draw_line(Vector2(bx-160, cb-170), Vector2(bx-98,  cb-170), chl, 1.0)
		for i in range(4):
			draw_rect(Rect2(bx-158+i*16, cb-192, 11, 24), cc)
		if lights_a > 0.0:
			var wf3 := sin(float(tf)*0.11+4.2)*0.20+0.80
			draw_rect(Rect2(bx-148, cb-130, 10, 16), Color(0.01, 0.00, 0.02, land_a))
			draw_rect(Rect2(bx-148, cb-130, 10, 16), Color(0.95, 0.60, 0.15, 0.80*wf3*lights_a))
		draw_rect(Rect2(bx+98, cb-155, 58, 155), cc)
		draw_line(Vector2(bx+98, cb-155), Vector2(bx+98,  cb), chl, 1.5)
		draw_line(Vector2(bx+98, cb-155), Vector2(bx+156, cb-155), chl, 1.0)
		for i in range(4):
			draw_rect(Rect2(bx+100+i*15, cb-176, 10, 22), cc)
		if lights_a > 0.0:
			var wf4 := sin(float(tf)*0.07+1.8)*0.15+0.85
			draw_rect(Rect2(bx+112, cb-118, 10, 16), Color(0.01, 0.00, 0.02, land_a))
			draw_rect(Rect2(bx+112, cb-118, 10, 16), Color(0.95, 0.60, 0.15, 0.80*wf4*lights_a))
		draw_rect(Rect2(bx-98, cb-80,  46, 80), cc)
		draw_rect(Rect2(bx+52, cb-72,  46, 72), cc)
		draw_line(Vector2(bx-98, cb-80), Vector2(bx-52, cb-80), chl, 1.0)
		draw_line(Vector2(bx+52, cb-72), Vector2(bx+98, cb-72), chl, 1.0)
		draw_rect(Rect2(bx-22, cb-58, 44, 58), Color(0.01, 0.00, 0.02, land_a))
		draw_circle(Vector2(bx, cb-58), 22, Color(0.01, 0.00, 0.02, land_a))

	# ── 9. Деревья и кресты ─────────────────────────────────────────────────
	if land_a > 0.0:
		var tc := Color(0.06, 0.015, 0.04, land_a)
		_draw_menu_tree(ox+vw*0.20, base-vh*0.05, 36.0, 132.0, Color(0.048, 0.010, 0.030, land_a))
		_draw_menu_tree(ox+vw*0.78, base-vh*0.05, 32.0, 118.0, Color(0.048, 0.010, 0.030, land_a))
		_draw_menu_tree(ox+vw*0.06, base-vh*0.05, 80.0, 280.0, tc)
		_draw_menu_tree(ox+vw*0.13, base-vh*0.04, 55.0, 200.0, tc)
		_draw_menu_tree(ox+vw*0.87, base-vh*0.05, 75.0, 260.0, tc)
		_draw_menu_tree(ox+vw*0.94, base-vh*0.04, 50.0, 190.0, tc)
		var crosses: Array[float] = [0.18, 0.30, 0.68, 0.80]
		for cp: float in crosses:
			var gx  := ox + vw * cp
			var gh  := vh * (0.09 + fmod(cp * 7.3, 0.06))
			draw_rect(Rect2(gx-4,  base-gh,      8,  gh),  tc)
			draw_rect(Rect2(gx-16, base-gh*0.72, 32, 6),   tc)

	# ── 10. Туман и земля ───────────────────────────────────────────────────
	if land_a > 0.0:
		var ft := float(tf) * 0.006
		draw_rect(Rect2(ox, base-vh*0.18+sin(ft*1.1)*5, vw, vh*0.08),
			Color(0.08, 0.02, 0.06, 0.10*land_a))
		draw_rect(Rect2(ox, base-vh*0.12+sin(ft*0.7+1.2)*6, vw, vh*0.10),
			Color(0.10, 0.03, 0.07, 0.16*land_a))
		draw_rect(Rect2(ox, base-vh*0.06+sin(ft*0.9+2.4)*4, vw, vh*0.07),
			Color(0.07, 0.02, 0.05, 0.22*land_a))
		draw_rect(Rect2(ox, base-vh*0.05, vw, vh*0.05), Color(0.025, 0.008, 0.018, land_a))

	# ── 11. Лунные лучи (медленно появляются только когда луна полностью взошла) ──
	var rays_a := clampf(float(tf - 300) / 200.0, 0.0, 1.0)
	if rays_a > 0.0:
		# Два несвязанных синуса на луч — разные частоты и фазы, никогда не синхронизируются
		var ray_f1 := [0.011, 0.071, 0.029, 0.083, 0.017, 0.059, 0.041]
		var ray_f2 := [0.067, 0.019, 0.053, 0.013, 0.079, 0.031, 0.061]
		var ray_ph := [0.00,  2.10,  4.50,  1.30,  5.80,  3.20,  0.90]
		for ri2 in range(7):
			var angle2  := PI * 0.5 + (float(ri2) - 3.0) * 0.12
			var t2      := float(tf)
			var flicker := sin(t2 * ray_f1[ri2] + ray_ph[ri2]) * 0.20 \
						 + sin(t2 * ray_f2[ri2] + ray_ph[ri2] * 1.7) * 0.12 + 0.68
			var r_a     := (0.032 - absf(float(ri2) - 3.0) * 0.005) * rays_a * flicker
			draw_line(Vector2(mx, moon_y + 68),
				Vector2(mx + cos(angle2) * vw, moon_y + sin(angle2) * vh * 1.3),
				Color(0.55, 0.58, 0.75, r_a), 12.0)

	# ── 11.5. Угли (проявляются снизу вверх по sweep-линии) ─────────────────
	var ember_a := clampf(float(tf - 380) / 160.0, 0.0, 1.0)
	if ember_a > 0.0:
		# sweep_y: стартует ниже экрана (vh*1.2), поднимается выше экрана (-vh*0.2)
		var sweep_y := oy + vh * (1.2 - ember_a * 1.4)
		var fade_z  := vh * 0.10
		for ember in _splash_embers:
			var ey: float = oy + float(ember["y"])
			if ey < sweep_y:
				continue  # ещё не достигнуто sweep — не рисуем
			var efa := clampf((ey - sweep_y) / fade_z, 0.0, 1.0)
			draw_circle(Vector2(ox + float(ember["x"]), ey),
				float(ember["size"]), Color(0.90, 0.55, 0.20, float(ember["alpha"]) * 0.45 * efa))

	# ── 12. Виньетка ────────────────────────────────────────────────────────
	if land_a > 0.0:
		for vi in range(5):
			var va  := (1.0 - float(vi) / 4.0) * 0.30 * land_a
			var vw2 := vw * (0.05 - float(vi) * 0.0075)
			draw_rect(Rect2(ox,         oy, vw2, vh), Color(0, 0, 0, va))
			draw_rect(Rect2(ox+vw-vw2,  oy, vw2, vh), Color(0, 0, 0, va))
		draw_rect(Rect2(ox, oy,          vw, vh * 0.04), Color(0, 0, 0, 0.50 * land_a))
		draw_rect(Rect2(ox, oy+vh*0.96,  vw, vh * 0.04), Color(0, 0, 0, 0.50 * land_a))

	# ── 13. Заголовок «SABBATH» (проявляется) ───────────────────────────────
	if title_a > 0.0:
		# та же формула пульса что в _draw_menu → фаза непрерывна при переходе
		var tp := (sin(float(tf) * 0.028) * 0.06 + 0.94) * title_a
		var title_y := oy + vh * 0.38
		draw_string(font, Vector2(ox+4, title_y+5),  "SABBATH",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 88, Color(0.10, 0.02, 0.01, 0.55*tp))
		draw_string(font, Vector2(ox-1, title_y-1),  "SABBATH",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 91, Color(0.95, 0.65, 0.15, 0.16*tp))
		draw_string(font, Vector2(ox+1, title_y+1),  "SABBATH",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 91, Color(0.95, 0.65, 0.15, 0.10*tp))
		draw_string(font, Vector2(ox,   title_y),    "SABBATH",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 88, Color(0.98, 0.90, 0.62, tp))
		draw_string(font, Vector2(ox+1, title_y+57), "A m o n g   L i f e   a n d   D e a t h",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 20, Color(0.10, 0.04, 0.02, 0.45*title_a))
		draw_string(font, Vector2(ox,   title_y+56), "A m o n g   L i f e   a n d   D e a t h",
			HORIZONTAL_ALIGNMENT_CENTER, vw, 20, Color(0.72, 0.55, 0.38, 0.88*title_a))

	# ── 14. Орнамент + полные кнопки (появляются последними) ────────────────
	if buttons_a > 0.0:
		var title_y := oy + vh * 0.38
		var orn_y   := title_y + 84.0
		var orn_w   := vw * 0.24
		draw_line(Vector2(mx - orn_w, orn_y), Vector2(mx - 14, orn_y),
			Color(0.65, 0.42, 0.18, 0.52*buttons_a), 1.0)
		draw_line(Vector2(mx + 14, orn_y), Vector2(mx + orn_w, orn_y),
			Color(0.65, 0.42, 0.18, 0.52*buttons_a), 1.0)
		var ds := 5.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(mx, orn_y-ds), Vector2(mx+ds, orn_y),
			Vector2(mx, orn_y+ds), Vector2(mx-ds, orn_y),
		]), Color(0.85, 0.58, 0.22, 0.88*buttons_a))
		draw_circle(Vector2(mx - orn_w*0.45, orn_y), 2.5, Color(0.65, 0.42, 0.18, 0.48*buttons_a))
		draw_circle(Vector2(mx + orn_w*0.45, orn_y), 2.5, Color(0.65, 0.42, 0.18, 0.48*buttons_a))
		draw_circle(Vector2(mx - orn_w*0.22, orn_y), 1.8, Color(0.65, 0.42, 0.18, 0.35*buttons_a))
		draw_circle(Vector2(mx + orn_w*0.22, orn_y), 1.8, Color(0.65, 0.42, 0.18, 0.35*buttons_a))

		var items: Array[String] = ["НОВАЯ  ИГРА", "ВЫХОД"]
		var iy := title_y + 126.0
		for i in range(items.size()):
			var item_y := iy + float(i) * 78.0
			if i == _menu_selected:
				# та же формула пульса что в _draw_menu → фаза непрерывна при переходе
				var sp  := (sin(float(tf) * 0.07) * 0.08 + 0.92) * buttons_a
				var sw  := font.get_string_size(items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
				var sx  := mx - sw * 0.5
				draw_rect(Rect2(sx-28, item_y-36, sw+56, 52), Color(0.12, 0.07, 0.02, 0.18*sp))
				draw_line(Vector2(sx-22, item_y-32), Vector2(sx+sw+22, item_y-32),
					Color(0.75, 0.50, 0.18, 0.38*sp), 1.0)
				draw_line(Vector2(sx-22, item_y+11), Vector2(sx+sw+22, item_y+11),
					Color(0.75, 0.50, 0.18, 0.38*sp), 1.0)
				for cxi in [sx - 24.0, sx + sw + 14.0]:
					for cyi_off in [-32.0, 11.0]:
						var cyi:  float = item_y + float(cyi_off)
						var cxif: float = float(cxi)
						var xd := 1.0 if cxif < mx else -1.0
						var yd := 1.0 if float(cyi_off) < 0.0 else -1.0
						draw_line(Vector2(cxif, cyi), Vector2(cxif+xd*10, cyi),
							Color(0.90, 0.64, 0.22, 0.72*sp), 1.5)
						draw_line(Vector2(cxif, cyi), Vector2(cxif, cyi+yd*10),
							Color(0.90, 0.64, 0.22, 0.72*sp), 1.5)
				for rdx in [sx - 30.0, sx + sw + 30.0]:
					var rdxf: float = float(rdx)
					draw_colored_polygon(PackedVector2Array([
						Vector2(rdxf, item_y-11), Vector2(rdxf+4, item_y-6),
						Vector2(rdxf, item_y-2),  Vector2(rdxf-4, item_y-6),
					]), Color(0.90, 0.64, 0.22, 0.62*sp))
				draw_string(font, Vector2(ox+2, item_y+2), items[i],
					HORIZONTAL_ALIGNMENT_CENTER, vw, 38, Color(0.12, 0.04, 0.01, 0.48*sp))
				draw_string(font, Vector2(ox, item_y), items[i],
					HORIZONTAL_ALIGNMENT_CENTER, vw, 38, Color(1.00, 0.95, 0.68, sp))
			else:
				draw_string(font, Vector2(ox, item_y), items[i],
					HORIZONTAL_ALIGNMENT_CENTER, vw, 26, Color(0.50, 0.34, 0.20, 0.50*buttons_a))

func _draw_menu_tree(tx: float, ty: float, tw: float, th: float, col: Color) -> void:
	var hl := Color(0.30, 0.24, 0.42, 0.50)  # холодный лунный highlight
	# Ствол
	draw_rect(Rect2(tx - tw*0.08, ty - th*0.35, tw*0.16, th*0.35), col)
	# Highlight левого края ствола (лунный свет)
	draw_rect(Rect2(tx - tw*0.08, ty - th*0.35, tw*0.04, th*0.35), Color(hl.r, hl.g, hl.b, 0.35 * col.a))
	# Крона — несколько наслоённых треугольников через полигоны
	for layer in range(4):
		var lf := float(layer) / 3.0
		var lw := tw * (1.0 - lf * 0.45)
		var lh := th * 0.30
		var ly2 := ty - th * (0.30 + lf * 0.55)
		var tri := PackedVector2Array([
			Vector2(tx,          ly2 - lh),
			Vector2(tx - lw*0.5, ly2),
			Vector2(tx + lw*0.5, ly2),
		])
		draw_colored_polygon(tri, col)
		# Highlight левой грани треугольника (лунный свет слева)
		draw_line(Vector2(tx - lw*0.5, ly2), Vector2(tx, ly2 - lh),
			Color(hl.r, hl.g, hl.b, (0.45 - lf * 0.10) * col.a), 1.5)
#endregion
