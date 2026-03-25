## enemy.gd — Базовий ворог (сайд-скроллер)
## Патруль → Переслідування → Атака

extends Node2D

var enemy_type: String = "pehota"
var enemy_data: Dictionary = {}
var enemy_size: Vector2 = Vector2(38, 68)
var target: Node2D = null

var velocity: Vector2 = Vector2.ZERO
var is_on_ground: bool = false
var is_alive: bool = true
var facing_right: bool = false

var current_hp: int = 0
var attack_cooldown: float = 0.0
var hit_flash: float = 0.0
var telegraph_timer: float = 0.0
var is_telegraphing: bool = false

var patrol_dir: int = -1
var patrol_walked: float = 0.0
const PATROL_RANGE: float = 200.0

var _ai_state: String = "patrol"
var _frame: int = 0

signal died(enemy)

func setup(type: String, player: Node2D) -> void:
	enemy_type = type
	enemy_data = C.ENEMY_TYPES[type]
	enemy_size = enemy_data["size"]
	current_hp = enemy_data["hp"]
	target = player
	add_to_group("enemies")
	set_process(true)
	print("👹 %s | HP:%d DMG:%d" % [enemy_data["name"], current_hp, enemy_data["damage"]])

func _process(delta: float) -> void:
	if not is_alive:
		return
	_update_timers(delta)
	_apply_gravity(delta)
	_update_ai(delta)
	_frame += 1
	queue_redraw()

#region Фізика
func _apply_gravity(delta: float) -> void:
	if not is_on_ground:
		velocity.y += C.GRAVITY * delta
		velocity.y = minf(velocity.y, C.TERMINAL_VELOCITY)

	var main = get_parent()
	if main and main.has_method("resolve_collision"):
		var result = main.resolve_collision(global_position, enemy_size, velocity * delta)
		global_position = result["pos"]
		if result["on_ground"]:
			velocity.y = 0.0
		is_on_ground = result["on_ground"]
	else:
		global_position += velocity * delta
#endregion

#region AI
func _update_ai(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_telegraphing:
		velocity.x = 0.0
		return

	var dx     := target.global_position.x - global_position.x
	var dist   := absf(dx)
	var chase:  float = enemy_data["chase_range"]
	var arange: float = enemy_data["attack_range"]

	match _ai_state:
		"patrol":
			if dist < chase:
				_ai_state = "chase"
			else:
				_do_patrol(_delta)
		"chase":
			if dist > chase * 1.4:
				_ai_state = "patrol"
				patrol_walked = 0.0
			elif dist <= arange:
				_ai_state = "attack"
				velocity.x = 0.0
			else:
				_do_chase(dx)
		"attack":
			velocity.x = 0.0
			if dist > arange * 1.3:
				_ai_state = "chase"
			elif attack_cooldown <= 0:
				_start_telegraph()

func _do_patrol(delta: float) -> void:
	var spd: float = float(enemy_data["speed"]) * 0.45
	velocity.x = patrol_dir * spd
	facing_right = patrol_dir > 0
	patrol_walked += spd * delta
	if patrol_walked >= PATROL_RANGE:
		patrol_dir *= -1
		patrol_walked = 0.0

func _do_chase(dx: float) -> void:
	facing_right = dx > 0
	velocity.x = sign(dx) * float(enemy_data["speed"])

func _start_telegraph() -> void:
	is_telegraphing = true
	telegraph_timer = 1.0 if enemy_type == "piker" else 0.6
	attack_cooldown = enemy_data["attack_cooldown"]

func _do_attack() -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive:
		return
	var dy := absf(target.global_position.y - global_position.y)
	if enemy_type == "musketeer" and dy > 130:
		return
	target.take_damage(enemy_data["damage"])
#endregion

#region Шкода
func take_damage(dmg: int) -> void:
	if not is_alive:
		return
	current_hp -= dmg
	hit_flash = 0.18
	if current_hp <= 0:
		_die()

func _die() -> void:
	is_alive = false
	_ai_state = "dead"
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	died.emit(self)
	get_tree().create_timer(0.9).timeout.connect(queue_free)
#endregion

#region Таймери
func _update_timers(delta: float) -> void:
	if attack_cooldown > 0:   attack_cooldown -= delta
	if hit_flash > 0:         hit_flash -= delta
	if is_telegraphing:
		telegraph_timer -= delta
		if telegraph_timer <= 0:
			is_telegraphing = false
			_do_attack()
#endregion

#region Відмалювання
func _draw() -> void:
	var hw  := enemy_size.x * 0.5
	var hh  := enemy_size.y * 0.5
	var dir := 1.0 if facing_right else -1.0

	# Смерть
	if not is_alive:
		draw_rect(Rect2(-hw, -6, hw * 2, 14), Color(0.28, 0.18, 0.12, 0.5))
		draw_circle(Vector2(dir * hw * 0.6, 4), 9, Color(0.26, 0.16, 0.10, 0.5))
		return

	# Кольори
	var body_c: Color
	var cloth_c: Color
	match enemy_type:
		"pehota":
			body_c = Color(0.55, 0.20, 0.16); cloth_c = Color(0.42, 0.15, 0.12)
		"musketeer":
			body_c = Color(0.20, 0.28, 0.55); cloth_c = Color(0.16, 0.22, 0.42)
		"piker":
			body_c = Color(0.20, 0.38, 0.20); cloth_c = Color(0.15, 0.30, 0.15)
		_:
			body_c = Color(0.45, 0.28, 0.18); cloth_c = Color(0.36, 0.22, 0.14)

	if hit_flash > 0:
		body_c = Color(1.0, 0.28, 0.28); cloth_c = Color(1.0, 0.38, 0.38)

	# Телеграфія
	if is_telegraphing:
		var t := sin(_frame * 0.5) * 0.5 + 0.5
		draw_circle(Vector2.ZERO, hh * 0.85, Color(1.0, 0.12, 0.12, t * 0.35))

	var leg_a := sin(_frame * 0.30) * 7.0 if (absf(velocity.x) > 5 and is_on_ground) else 0.0

	# Ноги
	draw_rect(Rect2(-hw * 0.50, hh * 0.28 + leg_a, hw * 0.46, hh * 0.52), body_c)
	draw_rect(Rect2(0,           hh * 0.28 - leg_a, hw * 0.46, hh * 0.52), body_c)

	# Тулуб
	draw_rect(Rect2(-hw * 0.72, -hh * 0.50, hw * 1.44, hh * 0.82), cloth_c)

	# Голова
	draw_circle(Vector2(0, -hh * 0.72), hh * 0.30, Color(0.76, 0.58, 0.40))
	draw_circle(Vector2(0, -hh * 0.86), hh * 0.26, body_c)  # шолом

	# Очі
	draw_circle(Vector2(3.5 * dir, -hh * 0.76), 2.0, Color(0.06, 0.02, 0.02))

	# Зброя
	match enemy_type:
		"pehota":
			draw_line(
				Vector2(dir * hw * 0.7, -hh * 0.28),
				Vector2(dir * (hw * 0.7 + 36), -hh * 0.54),
				Color(0.75, 0.72, 0.64), 4.0
			)
		"musketeer":
			draw_line(
				Vector2(dir * hw * 0.5, -hh * 0.18),
				Vector2(dir * (hw * 0.5 + 65), -hh * 0.34),
				Color(0.42, 0.32, 0.22), 5.0
			)
			draw_line(
				Vector2(dir * hw * 0.5, -hh * 0.18),
				Vector2(dir * (hw * 0.5 + 65), -hh * 0.34),
				Color(0.68, 0.66, 0.58), 2.0
			)
		"piker":
			draw_line(
				Vector2(-dir * hw * 0.4, -hh),
				Vector2(dir * (hw + 90), -hh * 0.08),
				Color(0.52, 0.42, 0.28), 4.0
			)
			draw_circle(Vector2(dir * (hw + 90), -hh * 0.08), 5.0, Color(0.72, 0.70, 0.60))

	# HP полоска
	var hp_pct := float(current_hp) / float(enemy_data["hp"])
	draw_rect(Rect2(-hw, -hh - 12, hw * 2, 4),           Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(-hw, -hh - 12, hw * 2 * hp_pct, 4),  Color(0.85, 0.15, 0.15))
#endregion
