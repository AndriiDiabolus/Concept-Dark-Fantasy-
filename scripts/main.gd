## main.gd — Sabbath - among life and death
## Main game controller & level manager

extends Node2D

# Используем Enemy из enemy.gd
var Enemy = preload("res://scripts/enemy.gd")

## Game State
var current_state: int = C.STATE.PLAY
var current_level: int = 0

## References
var player: Node2D
var camera: Camera2D
var ui_layer: CanvasLayer
var enemies: Array[Node2D] = []

## Level Management
var current_wave: int = 0
var waves_complete: int = 0
var current_wave_enemies: Array[Node2D] = []
var level_timer: float = 0.0

func _ready() -> void:
	print("🎮 Sabbath - among life and death v0.1.0")
	_setup_scene()
	_init_game()

func _process(delta: float) -> void:
	level_timer += delta
	queue_redraw()

	match current_state:
		C.STATE.PLAY:
			_update_play(delta)
		C.STATE.PAUSE:
			pass
		C.STATE.LOST:
			pass
		C.STATE.WON:
			pass

	queue_redraw()  # Перерисовываем каждый кадр

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


	# Системные клавиши
	if key == KEY_ESCAPE:
		if current_state == C.STATE.PAUSE:
			get_tree().paused = false
			current_state = C.STATE.PLAY
		elif current_state == C.STATE.PLAY:
			get_tree().paused = true
			current_state = C.STATE.PAUSE
	elif key == KEY_ENTER:
		if current_state == C.STATE.LOST:
			get_tree().paused = false
			load_level(current_level)
		elif current_state == C.STATE.WON:
			get_tree().paused = false
			load_level(current_level + 1)

	# Ввод игрока — передаём напрямую в player
	if player and current_state == C.STATE.PLAY:
		if event.pressed:
			player.pressed_keys[key] = true
			if not event.echo:
				if key == KEY_SPACE and not player.is_blocking:
					player._on_attack_input()
				elif key == KEY_V:
					player._try_activate_obsession()
		else:
			player.pressed_keys.erase(key)

func _draw() -> void:
	# Фон зависит от уровня
	match current_level:
		0:  # Level 1 - Zich Ruins
			_draw_level1_bg()
		1:  # Level 2 - Villages
			_draw_level2_bg()
		2:  # Level 3 - Approach
			_draw_level3_bg()
		3:  # Level 4 - Citadel
			_draw_level4_bg()
		_:
			draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), Color(0.1, 0.1, 0.15))

	# Рисуем HUD поверх всего
	_draw_hud()

	# Рисуем состояние игры (пауза, проигрыш, победа)
	match current_state:
		C.STATE.PAUSE:
			_draw_pause_screen()
		C.STATE.LOST:
			_draw_lost_screen()
		C.STATE.WON:
			_draw_won_screen()

## Scene Setup
func _setup_scene() -> void:
	print("=== SETTING UP SCENE ===")

	# Создаём базовые узлы если их нет
	if get_node_or_null("Player") == null:
		print("Creating Player node...")
		player = Node2D.new()
		player.name = "Player"
		add_child(player)
		print("Player node added to scene")

		# Добавляем player.gd скрипт
		print("Loading player script...")
		var player_script = load("res://scripts/player.gd")
		if player_script == null:
			print("ERROR: Could not load player script!")
			return

		print("Attaching script to player...")
		player.set_script(player_script)
		player.position = Vector2(C.VIEWPORT_WIDTH / 2, C.VIEWPORT_HEIGHT / 2)
		print("✓ Player created at: %v" % player.position)

		# Явно вызываем _ready если он не был вызван
		if player.has_method("_ready"):
			player._ready()
	else:
		player = get_node("Player")
		print("Player already exists in scene")

	if get_node_or_null("Camera2D") == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
		camera.make_current()
	else:
		camera = get_node("Camera2D")

	# Привязываем камеру к игроку
	if camera.get_parent() != self:
		remove_child(camera)
		add_child(camera)
	camera.global_position = player.global_position

	# Создаём UI слой
	if get_node_or_null("UILayer") == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)

	# Подключаем сигналы игрока
	if player.has_signal("player_died"):
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)

func _init_game() -> void:
	print("📍 Loading Level 1: Zich Ruins")
	load_level(0)

## Level Loading
func load_level(level_idx: int) -> void:
	current_level = level_idx
	var level_data = C.LEVELS[level_idx]

	print("📍 Level %d: %s" % [level_idx + 1, level_data.name])
	print("   Total waves: %d" % level_data.enemy_waves.size())

	current_wave = 0
	waves_complete = 0
	level_timer = 0.0
	current_wave_enemies.clear()

	current_state = C.STATE.PLAY
	_spawn_next_wave()

## Enemy Spawning
func _spawn_next_wave() -> void:
	if current_wave >= C.LEVELS[current_level].enemy_waves.size():
		_on_level_complete()
		return

	var wave_data = C.LEVELS[current_level].enemy_waves[current_wave]
	print("🌊 Wave %d spawning..." % (current_wave + 1))

	# Спавним врагов волны
	for enemy_config in wave_data:
		var enemy_type = enemy_config.get("type", "pehota")
		var count = enemy_config.get("count", 1)

		for i in range(count):
			var enemy = _spawn_enemy(enemy_type)
			if enemy:
				current_wave_enemies.append(enemy)

	current_wave += 1

func _spawn_enemy(enemy_type: String) -> Node2D:
	# Проверяем валидность типа врага
	if not C.ENEMY_TYPES.has(enemy_type):
		print("❌ Unknown enemy type: %s" % enemy_type)
		return null

	# Создаём врага через enemy.gd
	var enemy: Node2D = Node2D.new()
	var enemy_script = load("res://scripts/enemy.gd")
	if enemy_script == null:
		print("❌ Could not load enemy.gd script!")
		return null

	enemy.set_script(enemy_script)
	enemy.enemy_type = enemy_type  # Устанавливаем тип до _ready()

	add_child(enemy)
	enemy.global_position = Vector2(
		randf_range(100, C.VIEWPORT_WIDTH - 100),
		randf_range(100, C.VIEWPORT_HEIGHT - 100)
	)

	# Инициализируем врага (загружает конфиг из C.ENEMY_TYPES)
	if enemy.has_method("_ready"):
		enemy._ready()

	# Привязываем target (игрок)
	enemy.target = player

	# Подключаем сигнал смерти
	if enemy.has_signal("died"):
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)

	enemies.append(enemy)
	print("   ✓ %s spawned at %v" % [enemy_type.capitalize(), enemy.global_position])

	return enemy

## Game Loop
func _update_play(delta: float) -> void:
	# Обновляем камеру
	if camera:
		camera.global_position = camera.global_position.lerp(player.global_position, 0.1)

	# Перерисовываем все элементы
	if player:
		player.queue_redraw()
	for enemy in current_wave_enemies:
		if enemy and is_instance_valid(enemy):
			enemy.queue_redraw()

	# Проверяем завершение волны
	if current_wave_enemies.is_empty() and current_wave < C.LEVELS[current_level].enemy_waves.size():
		await get_tree().create_timer(1.0).timeout  # пауза 1 сек между волнами
		_spawn_next_wave()

## Callbacks
func _on_enemy_died(enemy: Node2D) -> void:
	if enemy in current_wave_enemies:
		current_wave_enemies.erase(enemy)
	if enemy in enemies:
		enemies.erase(enemy)

	print("📊 Enemies remaining: %d" % current_wave_enemies.size())

	if current_wave_enemies.is_empty():
		waves_complete += 1
		print("✓ Wave %d complete!" % waves_complete)

func _on_player_died() -> void:
	print("💀 GAME OVER!")
	current_state = C.STATE.LOST
	get_tree().paused = true

func _on_level_complete() -> void:
	print("🏆 LEVEL COMPLETE!")
	print("   Time: %.1f sec" % level_timer)
	current_state = C.STATE.WON
	get_tree().paused = true

## Level Backgrounds
func _draw_level1_bg() -> void:
	# Level 1 - Zich Ruins (раньше казацкая крепость)
	# Цвет: серый камень, дым, руины

	# Небо - мрачное
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT * 0.6), Color(0.15, 0.15, 0.18))

	# Дымка вверху
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, 200), Color(0.3, 0.25, 0.2, 0.3))

	# Земля - грязная, камень
	draw_rect(Rect2(0, C.VIEWPORT_HEIGHT * 0.6, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT * 0.4), Color(0.18, 0.15, 0.12))

	# Руины (большие камни/стены)
	_draw_ruin_block(Vector2(200, 650), 150, 200, Color(0.35, 0.32, 0.28))
	_draw_ruin_block(Vector2(500, 700), 200, 150, Color(0.32, 0.28, 0.25))
	_draw_ruin_block(Vector2(1400, 680), 180, 180, Color(0.38, 0.34, 0.30))
	_draw_ruin_block(Vector2(1700, 750), 220, 120, Color(0.33, 0.30, 0.26))
	_draw_ruin_block(Vector2(800, 820), 250, 80, Color(0.36, 0.32, 0.28))

	# Трещины в земле
	draw_line(Vector2(100, 750), Vector2(300, 850), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(600, 800), Vector2(800, 900), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(1200, 780), Vector2(1400, 900), Color(0.1, 0.1, 0.1), 2.0)

func _draw_level2_bg() -> void:
	# Level 2 - Villages (украинские деревни)
	var sky_color = Color(0.2, 0.18, 0.25)  # Более фиолетовый оттенок
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), sky_color)

	# Горизонт с деревьями (силуэты)
	draw_line(Vector2(0, 650), Vector2(C.VIEWPORT_WIDTH, 650), Color(0.1, 0.1, 0.1), 3.0)

	# Рваные дома (силуэты) - горят
	_draw_house_ruin(Vector2(300, 550), 100, 150, Color(0.4, 0.2, 0.1))
	_draw_house_ruin(Vector2(800, 580), 120, 140, Color(0.38, 0.18, 0.08))
	_draw_house_ruin(Vector2(1400, 560), 100, 160, Color(0.42, 0.22, 0.12))

func _draw_level3_bg() -> void:
	# Level 3 - Mountains (горы, артиллерия)
	var gradient_color = Color(0.25, 0.2, 0.3)  # Синий+фиолетовый горный цвет
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), gradient_color)

	# Горы (треугольники)
	var mountain_pts = PackedVector2Array([
		Vector2(0, 900),
		Vector2(500, 400),
		Vector2(1000, 900),
	])
	draw_colored_polygon(mountain_pts, Color(0.2, 0.15, 0.25))

	var mountain_pts2 = PackedVector2Array([
		Vector2(800, 900),
		Vector2(1300, 350),
		Vector2(1920, 900),
	])
	draw_colored_polygon(mountain_pts2, Color(0.22, 0.17, 0.27))

func _draw_level4_bg() -> void:
	# Level 4 - Citadel (замок, тронный зал)
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), Color(0.08, 0.06, 0.12))

	# Стены замка
	draw_rect(Rect2(0, 200, C.VIEWPORT_WIDTH, 150), Color(0.25, 0.2, 0.2))
	draw_rect(Rect2(0, 400, C.VIEWPORT_WIDTH, 50), Color(0.2, 0.15, 0.15))

func _draw_ruin_block(pos: Vector2, w: float, h: float, col: Color) -> void:
	# Рисует блок руин с тенью и трещинами
	draw_rect(Rect2(pos.x - w/2, pos.y - h/2, w, h), col)

	# Тень
	draw_rect(Rect2(pos.x - w/2, pos.y + h/2, w, 20), Color(0, 0, 0, 0.3))

	# Трещины
	if randf() > 0.5:
		draw_line(Vector2(pos.x - w/4, pos.y - h/2), Vector2(pos.x - w/4, pos.y + h/2), Color(0.1, 0.1, 0.1), 1.0)
		draw_line(Vector2(pos.x + w/4, pos.y - h/2), Vector2(pos.x + w/4, pos.y + h/2), Color(0.1, 0.1, 0.1), 1.0)

func _draw_house_ruin(pos: Vector2, w: float, h: float, col: Color) -> void:
	# Рисует сгоревший дом
	draw_rect(Rect2(pos.x - w/2, pos.y - h, w, h), col)

	# Черная крыша (торчит)
	var roof = PackedVector2Array([
		Vector2(pos.x - w/2, pos.y - h),
		Vector2(pos.x, pos.y - h - 40),
		Vector2(pos.x + w/2, pos.y - h),
	])
	draw_colored_polygon(roof, Color(0.1, 0.1, 0.1))

## HUD
func _draw_hud() -> void:
	if not player:
		return

	# Фон HUD (полоса вверху)
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, 60), Color(0.05, 0.05, 0.08, 0.8))
	draw_line(Vector2(0, 60), Vector2(C.VIEWPORT_WIDTH, 60), Color(0.5, 0.4, 0.3), 2.0)

	# HP (слева)
	draw_string(ThemeDB.fallback_font, Vector2(20, 25), "HP: %d/%d" % [player.current_hp, C.PLAYER_HP_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# Level и Wave (в центре)
	var level_text = "Level %d | Wave %d/%d" % [
		current_level + 1,
		waves_complete + 1,
		C.LEVELS[current_level].enemy_waves.size()
	]
	draw_string(ThemeDB.fallback_font, Vector2(C.VIEWPORT_WIDTH/2 - 150, 25), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))

	# Время (справа)
	var time_str = "Time: %.1fs" % level_timer
	draw_string(ThemeDB.fallback_font, Vector2(C.VIEWPORT_WIDTH - 200, 25), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 0.7))

	# Obsession bar (внизу слева в HUD)
	_draw_obsession_bar()

func _draw_obsession_bar() -> void:
	if not player:
		return

	var bar_x = 20
	var bar_y = 40
	var bar_width = 200
	var bar_height = 10

	# Фон полосы
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.1, 0.1, 0.1))

	# Заполнение
	var obsession_percent = player.obsession_fill / (C.PLAYER_OBSESSION_LEVEL_THRESHOLD * C.PLAYER_OBSESSION_LEVELS)
	var fill_width = bar_width * min(obsession_percent, 1.0)

	var obsession_color = Color.MAGENTA
	if player.obsession_active:
		obsession_color = Color(1.0, 0.5, 1.0)

	draw_rect(Rect2(bar_x, bar_y, fill_width, bar_height), obsession_color)

	# Граница
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.5, 0.3, 0.5), false, 2.0)

	# Уровень одержимости
	var level_text = "Obs: %d/3" % player.obsession_level
	draw_string(ThemeDB.fallback_font, Vector2(bar_x + 210, bar_y), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.5, 1.0))

func _draw_pause_screen() -> void:
	# Полусерый оверлей
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), Color(0, 0, 0, 0.5))

	# "PAUSE" текст в центре
	var pause_text = "ПАУЗА"
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(pause_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 40)
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - text_size.x/2, C.VIEWPORT_HEIGHT/2 - 40), pause_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)

	# Инструкция
	var hint = "Нажми Escape для продолжения"
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - 250, C.VIEWPORT_HEIGHT/2 + 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.7, 0.7))

func _draw_lost_screen() -> void:
	# Красный оверлей
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), Color(0.8, 0.1, 0.1, 0.6))

	# "GAME OVER" текст
	var font = ThemeDB.fallback_font
	var game_over_text = "ПОРАЖЕНИЕ"
	var text_size = font.get_string_size(game_over_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 50)
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - text_size.x/2, C.VIEWPORT_HEIGHT/2 - 60), game_over_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color.RED)

	# Статистика
	var stats = "Уровень: %d | Волна: %d | Время: %.1f сек" % [
		current_level + 1,
		waves_complete,
		level_timer
	]
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - 300, C.VIEWPORT_HEIGHT/2 + 20), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Подсказка
	var hint = "Нажми Enter для перезагрузки"
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - 250, C.VIEWPORT_HEIGHT/2 + 80), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.8))

func _draw_won_screen() -> void:
	# Зеленый оверлей
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), Color(0.1, 0.6, 0.1, 0.6))

	# "VICTORY" текст
	var font = ThemeDB.fallback_font
	var victory_text = "УРОВЕНЬ ПРОЙДЕН!"
	var text_size = font.get_string_size(victory_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 50)
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - text_size.x/2, C.VIEWPORT_HEIGHT/2 - 60), victory_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color(0.2, 1.0, 0.2))

	# Статистика
	var stats = "Волна: %d / %d | Время: %.1f сек" % [
		waves_complete,
		C.LEVELS[current_level].enemy_waves.size(),
		level_timer
	]
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - 300, C.VIEWPORT_HEIGHT/2 + 20), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Подсказка
	var hint = "Нажми Enter для следующего уровня"
	draw_string(font, Vector2(C.VIEWPORT_WIDTH/2 - 250, C.VIEWPORT_HEIGHT/2 + 80), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 1.0, 0.8))

## Debug
func _print_game_state() -> void:
	print("=== GAME STATE ===")
	print("Level: %d" % (current_level + 1))
	print("Wave: %d / %d" % [waves_complete, C.LEVELS[current_level].enemy_waves.size()])
	print("Enemies: %d" % current_wave_enemies.size())
	if player:
		print("Player: %s" % str(player.get_status()))
