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

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_tree().paused = !get_tree().paused
			current_state = C.STATE.PAUSE if get_tree().paused else C.STATE.PLAY

func _draw() -> void:
	# Фон игры
	draw_rect(Rect2(0, 0, C.VIEWPORT_WIDTH, C.VIEWPORT_HEIGHT), Color(0.1, 0.1, 0.15))

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
	# Создаём врага в зависимости от типа
	var enemy: Node2D

	match enemy_type:
		"pehota":
			enemy = Enemy.new()
			enemy.set_script(load("res://scripts/enemies/pehota.gd"))
		"musketeer":
			enemy = Enemy.new()
			enemy.set_script(load("res://scripts/enemies/pehota.gd"))  # TODO: replace with musketeer
		"piker":
			enemy = Enemy.new()
			enemy.set_script(load("res://scripts/enemies/pehota.gd"))  # TODO: replace with piker
		_:
			print("❌ Unknown enemy type: %s" % enemy_type)
			return null

	if enemy:
		add_child(enemy)
		enemy.global_position = Vector2(
			randf_range(100, C.VIEWPORT_WIDTH - 100),
			randf_range(100, C.VIEWPORT_HEIGHT - 100)
		)

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

	# Проверяем завершение волны
	if current_wave_enemies.is_empty() and current_wave < C.LEVELS[current_level].enemy_waves.size():
		await get_tree().create_timer(1.0).timeout  # пауза 1 сек между волнами
		_spawn_next_wave()

## Callbacks
func _on_enemy_died(enemy: Enemy) -> void:
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

## Debug
func _print_game_state() -> void:
	print("=== GAME STATE ===")
	print("Level: %d" % (current_level + 1))
	print("Wave: %d / %d" % [waves_complete, C.LEVELS[current_level].enemy_waves.size()])
	print("Enemies: %d" % current_wave_enemies.size())
	if player:
		print("Player: %s" % str(player.get_status()))
