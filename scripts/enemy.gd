## enemy.gd — Базовый класс для всех врагов
## Наследуется Pehota, Musketeer, Piker

extends Node2D

class_name Enemy

## Статистика врага
var enemy_type: String = "pehota"
var current_hp: int
var max_hp: int
var damage: int
var attack_speed: float
var speed: float

## Поведение
var target: Node2D  # игрок (Yaromir)
var velocity: Vector2 = Vector2.ZERO
var facing_right: bool = true
var state: String = "idle"  # idle, chase, attack, hit, dead

## Combat
var attack_cooldown: float = 0.0
var in_attack_range: bool = false
var chase_range: float
var attack_range: float

## Visual
var hit_flash_time: float = 0.0

## Signals
signal died(enemy)
signal dealt_damage(damage)

func _ready() -> void:
	var config = C.ENEMY_TYPES.get(enemy_type, {})
	if config.is_empty():
		print("❌ Enemy type '%s' not found!" % enemy_type)
		queue_free()
		return

	# Загружаем статистику
	max_hp = config.get("hp", 30)
	current_hp = max_hp
	damage = config.get("damage", 5)
	attack_speed = config.get("attack_speed", 1.0)
	speed = config.get("speed", 100)
	chase_range = config.get("chase_range", 150)
	attack_range = config.get("attack_range", 40)

	print("👹 %s spawned | HP: %d | DMG: %d" % [enemy_type.capitalize(), current_hp, damage])

func _process(delta: float) -> void:
	if state == "dead":
		return

	# Обновляем таймеры
	_update_timers(delta)

	# Обновляем AI
	_update_ai(delta)

	# Обновляем анимацию
	_update_animation()

func _update_ai(delta: float) -> void:
	if not is_instance_valid(target):
		state = "idle"
		velocity = Vector2.ZERO
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	in_attack_range = distance_to_target <= attack_range

	match state:
		"idle":
			velocity = Vector2.ZERO
			if distance_to_target <= chase_range:
				state = "chase"

		"chase":
			_move_towards_target(delta)
			if distance_to_target > chase_range * 1.5:
				state = "idle"
			elif in_attack_range:
				state = "attack"

		"attack":
			velocity = Vector2.ZERO
			if attack_cooldown <= 0:
				_perform_attack()
				attack_cooldown = attack_speed
			if not in_attack_range:
				state = "chase"

		"hit":
			# Пока в состоянии "попадания", просто стоим
			pass

	# Применяем движение
	global_position += velocity * delta

	# Проверяем направление
	if velocity.x != 0:
		facing_right = velocity.x > 0

func _move_towards_target(delta: float) -> void:
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * speed

func _perform_attack() -> void:
	if not is_instance_valid(target):
		return

	print("⚔️ %s attacks!" % enemy_type.capitalize())

	# Наносим урон игроку
	if target.has_method("take_damage"):
		target.take_damage(damage)
		dealt_damage.emit(damage)

	# Визуальный эффект (мигание)
	hit_flash_time = C.ENEMY_HIT_FLASH

func take_damage(amount: int) -> void:
	if state == "dead":
		return

	current_hp -= amount
	state = "hit"
	hit_flash_time = C.ENEMY_HIT_FLASH

	print("💥 %s takes %d damage! HP: %d/%d" % [
		enemy_type.capitalize(), amount, current_hp, max_hp
	])

	if current_hp <= 0:
		_on_died()

func _on_died() -> void:
	state = "dead"
	print("☠️ %s defeated!" % enemy_type.capitalize())

	# Эмитируем сигнал для игровой логики
	died.emit(self)

	# Удаляем врага из сцены
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _update_timers(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if hit_flash_time > 0:
		hit_flash_time -= delta

func _update_animation() -> void:
	# TODO: Переключаем анимации по состоянию
	pass

func get_status() -> Dictionary:
	return {
		"type": enemy_type,
		"hp": current_hp,
		"max_hp": max_hp,
		"state": state,
		"position": global_position
	}
