## player.gd — Yaromir (Игрок)
## Полный контроллер персонажа: движение, атака, блок, уклон, одержимость

extends Node2D

## Позиция и движение
var velocity: Vector2 = Vector2.ZERO
var is_moving: bool = false
var pressed_keys: Dictionary = {}  # Отслеживаем нажатые клавиши

## Health & Status
var current_hp: int = C.PLAYER_HP_MAX
var is_alive: bool = true
var is_blocking: bool = false
var is_recovering: bool = false  # после одержимости (на коленях)

## Combat
var attack_combo: int = 0  # текущий удар в комбо (0, 1, 2)
var attack_cooldown: float = 0.0
var last_attack_time: float = 0.0

## Obsession (Одержимость)
var obsession_level: int = 0  # 0-3 уровня
var obsession_active: bool = false
var obsession_time_remaining: float = 0.0
var obsession_cooldown: float = 0.0
var obsession_fill: float = 0.0  # 0-300 points

## Dodge (Уклон)
var last_dodge_time: float = 0.0

## Animation & Visual
var facing_right: bool = true
var degrade_stage: int = 0  # 0, 1, 2, 3 (визуальная деградация)
var _frame: int = 0  # Счётчик кадров для анимаций

## Signals
signal hp_changed(new_hp)
signal obsession_changed(level, fill)
signal obsession_activated
signal player_died
signal attack_hit(damage)

func _ready() -> void:
	print("🗡️ Yaromir READY at position: %v" % global_position)
	set_process(true)  # КРИТИЧНО: включаем _process()
	set_process_unhandled_input(true)  # Обработка unhandled input
	_setup_visuals()
	print("🗡️ Yaromir initialized | HP: %d | Speed: %d px/s" % [current_hp, C.PLAYER_SPEED])

func _process(delta: float) -> void:
	if not is_alive:
		return

	# Проверяем input здесь напрямую
	_handle_input()

	# Обновляем таймеры
	_update_timers(delta)

	# Обновляем состояния
	_update_obsession(delta)
	_update_movement(delta)
	_update_animation()

	# Счётчик кадров для анимаций
	_frame += 1

	# Проверяем смерть
	if current_hp <= 0:
		_on_died()

	# КРИТИЧНО: перерисовываем каждый кадр
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	"""Обрабатываем input события напрямую"""
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_W:
					pressed_keys[KEY_W] = true
				KEY_A:
					pressed_keys[KEY_A] = true
				KEY_S:
					pressed_keys[KEY_S] = true
				KEY_D:
					pressed_keys[KEY_D] = true
				KEY_R:
					pressed_keys[KEY_R] = true
				KEY_SPACE:
					pressed_keys[KEY_SPACE] = true
		else:
			match event.keycode:
				KEY_W:
					pressed_keys.erase(KEY_W)
				KEY_A:
					pressed_keys.erase(KEY_A)
				KEY_S:
					pressed_keys.erase(KEY_S)
				KEY_D:
					pressed_keys.erase(KEY_D)
				KEY_R:
					pressed_keys.erase(KEY_R)
				KEY_SPACE:
					pressed_keys.erase(KEY_SPACE)

func _handle_input() -> void:
	"""pressed_keys уже заполнены из _unhandled_input()"""
	# Блок (R)
	is_blocking = pressed_keys.has(KEY_R)

	# Атака (Space)
	if pressed_keys.has(KEY_SPACE) and not is_blocking:
		_on_attack_input()

	# Одержимость (V)
	if pressed_keys.has(KEY_V):
		_try_activate_obsession()

#region MOVEMENT
func _update_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO

	# Читаем WASD из pressed_keys
	if pressed_keys.has(KEY_W):
		input_dir.y -= 1
	if pressed_keys.has(KEY_S):
		input_dir.y += 1
	if pressed_keys.has(KEY_A):
		input_dir.x -= 1
		facing_right = false
	if pressed_keys.has(KEY_D):
		input_dir.x += 1
		facing_right = true

	input_dir = input_dir.normalized()
	is_moving = input_dir.length() > 0

	# Применяем скорость (снижается на 25% во время блока)
	var current_speed = C.PLAYER_SPEED
	if is_blocking:
		current_speed *= 0.75

	# Движение
	velocity = input_dir * current_speed
	position += velocity * delta

	# Ограничиваем позицию в пределах экрана (примерно)
	position.x = clamp(position.x, 50, C.VIEWPORT_WIDTH - 50)
	position.y = clamp(position.y, 50, C.VIEWPORT_HEIGHT - 50)
	queue_redraw()  # Принудительно перерисовываем

#endregion

#region ATTACK
func _on_attack_input() -> void:
	if is_blocking or is_recovering or obsession_cooldown > 0:
		return

	# Проверяем cooldown
	if attack_cooldown > 0:
		return

	# Увеличиваем комбо
	attack_combo = (attack_combo + 1) % 3

	# Наносим урон
	var damage = C.PLAYER_ATTACK_DAMAGE[attack_combo]
	var attack_duration = C.PLAYER_ATTACK_SPEED[attack_combo]

	print("⚔️ Attack #%d | Damage: %d" % [attack_combo + 1, damage])

	# Наносим урон врагам в радиусе атаки
	var attack_radius = 60.0  # пиксели
	var hit_count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and global_position.distance_to(enemy.global_position) <= attack_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
				hit_count += 1

	if hit_count > 0:
		print("💥 Hit %d enemies!" % hit_count)
		attack_hit.emit(damage)

	# Заполняем одержимость
	if obsession_level < C.PLAYER_OBSESSION_LEVELS:
		obsession_fill += C.PLAYER_OBSESSION_FILL_PER_ATTACK
		_update_obsession_bar()

	# Визуальный эффект
	_play_attack_animation(attack_combo, attack_duration)

	# Cooldown между ударами
	attack_cooldown = attack_duration
	last_attack_time = 0.0

#endregion

#region OBSESSION
func _try_activate_obsession() -> void:
	if obsession_level < C.PLAYER_OBSESSION_LEVELS:
		print("⚠️ Obsession not full! Level: %d/3" % obsession_level)
		return

	if obsession_cooldown > 0:
		print("⏳ Obsession on cooldown: %.1f sec" % obsession_cooldown)
		return

	# Активируем
	obsession_active = true
	obsession_time_remaining = C.PLAYER_OBSESSION_DURATION
	obsession_level = 0  # сброс после использования
	obsession_fill = 0.0

	print("💜 OBSESSION ACTIVATED! 20 sec of power!")
	obsession_activated.emit()

func _update_obsession(delta: float) -> void:
	if not obsession_active:
		return

	obsession_time_remaining -= delta

	if obsession_time_remaining <= 0:
		_end_obsession()

func _end_obsession() -> void:
	obsession_active = false
	is_recovering = true
	obsession_time_remaining = 0.0
	obsession_cooldown = C.PLAYER_OBSESSION_COOLDOWN

	print("🔄 Recovery: 2 sec on knees | Cooldown: 2 min")

	# Запускаем 2-сек уязвимость (асинхронно)
	_recovery_timer()

func _update_obsession_bar() -> void:
	# Проверяем можем ли перейти на следующий уровень
	var points_per_level = C.PLAYER_OBSESSION_LEVEL_THRESHOLD
	var next_level = int(obsession_fill / points_per_level)

	if next_level > obsession_level:
		obsession_level = next_level
		print("📈 Obsession Level: %d/3" % obsession_level)
		obsession_changed.emit(obsession_level, int(obsession_fill))

		# Визуальная деградация
		_update_degrade_stage()

func _update_degrade_stage() -> void:
	match obsession_level:
		0:
			degrade_stage = 0  # normal
		1:
			degrade_stage = 1  # левая рука фиолетовая
		2:
			degrade_stage = 2  # глаза светятся + рога
		3:
			degrade_stage = 3  # полная демоническая форма

#endregion

#region DAMAGE
func take_damage(damage: int) -> void:
	if not is_alive or is_recovering:
		return

	var actual_damage = damage
	var dodge_hit = _check_dodge()

	if is_blocking:
		actual_damage = int(damage * C.PLAYER_BLOCK_DAMAGE_REDUCTION)
		print("🛡️ Blocked! Damage reduced: %d → %d" % [damage, actual_damage])
	elif dodge_hit:
		actual_damage = 0
		print("✨ Dodged! 0 damage")
	else:
		print("💥 Hit! Damage: %d" % actual_damage)

	current_hp -= actual_damage

	# Заполняем одержимость от урона
	if actual_damage > 0 and obsession_level < C.PLAYER_OBSESSION_LEVELS:
		obsession_fill += damage * C.PLAYER_OBSESSION_FILL_PER_DAMAGE
		_update_obsession_bar()

	hp_changed.emit(current_hp)
	print("❤️ HP: %d / %d" % [current_hp, C.PLAYER_HP_MAX])

	# Проверяем смерть сразу
	if current_hp <= 0:
		_on_died()

func _check_dodge() -> bool:
	# Пассивный уклон с 5% шансом
	if randf() < C.PLAYER_DODGE_CHANCE:
		last_dodge_time = 0.0
		return true
	return false

#endregion

#region ASYNC HELPERS
func _recovery_timer() -> void:
	await get_tree().create_timer(C.PLAYER_OBSESSION_RECOVERY).timeout
	is_recovering = false

#endregion

#region TIMERS
func _update_timers(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if obsession_cooldown > 0:
		obsession_cooldown -= delta
	if last_attack_time >= 0:
		last_attack_time += delta
	if last_dodge_time >= 0:
		last_dodge_time += delta

#endregion

#region VISUAL & ANIMATION

func _setup_visuals() -> void:
	# Setup визуализации — всё рисуется через _draw()
	print("✓ Player visual initialized")

func _update_animation() -> void:
	# Обновляем отрисовку
	queue_redraw()

func _draw() -> void:
	# Определяем цвет героя в зависимости от состояния
	var color = Color(0.8, 0.6, 0.4)  # Кожа
	var armor_color = Color(0.3, 0.2, 0.1)  # Доспехи (коричневые)

	if obsession_active:
		color = Color(1.0, 0.0, 1.0)  # Фиолетовый при одержимости
		armor_color = Color(1.0, 0.2, 1.0)

	# Базовая поза
	var leg_offset_y = 0.0
	var head_offset = 0.0

	# Анимация ног при ходьбе
	if is_moving and _frame > 0:
		leg_offset_y = sin(_frame * 0.3) * 3.0
		head_offset = abs(cos(_frame * 0.3)) * 2.0

	# Рисуем тело (торс)
	draw_rect(Rect2(-16, -16, 32, 28), armor_color)

	# Рисуем голову
	draw_circle(Vector2(0, -26 - head_offset), 8, color)

	# Глаза (если не одержимость)
	if not obsession_active:
		draw_circle(Vector2(-3, -28 - head_offset), 2, Color.BLACK)
		draw_circle(Vector2(3, -28 - head_offset), 2, Color.BLACK)
	else:
		# Горящие глаза при одержимости
		draw_circle(Vector2(-3, -28 - head_offset), 2, Color.YELLOW)
		draw_circle(Vector2(3, -28 - head_offset), 2, Color.YELLOW)

	# Левая рука (с оружием)
	draw_rect(Rect2(-22, -8, 8, 20), color)

	# Правая рука (защита если блок)
	if is_blocking:
		# Щит
		draw_circle(Vector2(18, -8), 12, Color.BLUE)
		draw_circle(Vector2(18, -8), 10, Color(0.2, 0.3, 0.8))
		# Символ на щите
		draw_circle(Vector2(18, -8), 4, Color.YELLOW)
	else:
		draw_rect(Rect2(14, -8, 8, 20), color)

	# Ноги с анимацией
	var left_leg_y = 12 + leg_offset_y
	var right_leg_y = 12 - leg_offset_y

	draw_rect(Rect2(-10, left_leg_y, 6, 18), Color(0.6, 0.4, 0.2))  # Левая нога (тёмнее)
	draw_rect(Rect2(4, right_leg_y, 6, 18), Color(0.6, 0.4, 0.2))  # Правая нога

	# HP полоса сверху
	var hp_percent = float(current_hp) / float(C.PLAYER_HP_MAX)
	draw_rect(Rect2(-24, -40, 48 * hp_percent, 3), Color.GREEN)
	draw_rect(Rect2(-24, -40, 48, 3), Color(0.2, 0.2, 0.2))

	# При уклоне - прозрачность/эффект
	if last_dodge_time < 0.15:
		# Недавний уклон - немного прозрачнее
		modulate = Color(1.0, 1.0, 1.0, 0.7)

	# При блоке - подсветка
	if is_blocking:
		draw_rect(Rect2(-28, -35, 56, 65), Color(0, 0, 1, 0.1))

	# При восстановлении после одержимости - сидит на коленях
	if is_recovering:
		# Измененная поза
		draw_rect(Rect2(-14, -10, 28, 20), armor_color)  # торс более низко
		draw_circle(Vector2(0, -20), 8, color)  # голова выше

func _play_attack_animation(combo_idx: int, duration: float) -> void:
	# TODO: воспроизводим анимацию атаки
	# На данный момент просто логируем
	pass

#endregion

#region STATUS
func _on_died() -> void:
	is_alive = false
	print("💀 Yaromir has fallen!")
	player_died.emit()

func get_status() -> Dictionary:
	return {
		"hp": current_hp,
		"obsession_level": obsession_level,
		"obsession_fill": int(obsession_fill),
		"is_blocking": is_blocking,
		"is_recovering": is_recovering,
		"degrade_stage": degrade_stage,
		"facing_right": facing_right
	}

#endregion
