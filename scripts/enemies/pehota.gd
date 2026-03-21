## pehota.gd — Польский пехотинец
## Наследует от Enemy, добавляет специфичное поведение

extends Enemy

# Pehota-специфичное поведение
var combo_hits: int = 0  # текущий удар в 3-ударной комбо
var combo_reset_time: float = 0.0

func _ready() -> void:
	enemy_type = "pehota"
	super._ready()
	combo_hits = 0

func _process(delta: float) -> void:
	# Сброс комбо если прошло слишком много времени
	if combo_reset_time > 0:
		combo_reset_time -= delta
	else:
		combo_hits = 0

	super._process(delta)

func _perform_attack() -> void:
	if not is_instance_valid(target):
		return

	# Pehota делает комбо из 3 ударов
	combo_hits = (combo_hits + 1) % 3
	combo_reset_time = 2.0  # если не атакует 2 сек - сброс

	var attack_damage = damage
	match combo_hits:
		0:
			attack_damage = 3  # первый удар слабый
		1:
			attack_damage = 3  # второй удар слабый
		2:
			attack_damage = 4  # третий удар сильнее

	print("⚔️ Pehota combo #%d | Damage: %d" % [combo_hits + 1, attack_damage])

	# Наносим урон
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		dealt_damage.emit(attack_damage)

	hit_flash_time = C.ENEMY_HIT_FLASH

func _update_animation() -> void:
	# TODO: Переключаем спрайт в зависимости от состояния
	# Идеи:
	# - Idle: стоит с оружием
	# - Chase: бежит
	# - Attack: комбо анимация с правильным номером удара
	# - Hit: мигание красным
	# - Dead: падает
	pass
