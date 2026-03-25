## player.gd — Ярмір (Yaromir)
## Платформер: гравітація, стрибки, бій

extends Node2D

#region Фізика
var velocity: Vector2 = Vector2.ZERO
var is_on_ground: bool = false
#endregion

#region Стан
var current_hp: int = C.PLAYER_HP_MAX
var is_alive: bool = true
var is_blocking: bool = false
var is_recovering: bool = false
var facing_right: bool = true
var is_moving: bool = false
#endregion

#region Бій
var attack_combo: int = 0
var attack_cooldown: float = 0.0
var attack_timer: float = 0.0
#endregion

#region Одержимість
var obsession_level: int = 0
var obsession_active: bool = false
var obsession_time: float = 0.0
var obsession_cooldown: float = 0.0
var obsession_fill: float = 0.0
var degrade_stage: int = 0
#endregion

#region Ввід
var pressed_keys: Dictionary = {}
#endregion

#region Анімація
var _frame: int = 0
#endregion

signal player_died
signal hp_changed(hp)

func _ready() -> void:
	set_process(true)
	print("🗡️ Yaromir ready | HP:%d" % current_hp)

func _process(delta: float) -> void:
	if not is_alive:
		return
	_update_timers(delta)
	_handle_input()
	_apply_gravity(delta)
	_apply_movement(delta)
	_update_obsession(delta)
	if current_hp <= 0 and is_alive:
		is_alive = false
		player_died.emit()
	_frame += 1
	queue_redraw()

#region Ввід
func _handle_input() -> void:
	is_blocking = pressed_keys.has(KEY_R) and is_on_ground and not obsession_active
#endregion

#region Фізика та рух
func _apply_gravity(delta: float) -> void:
	if not is_on_ground:
		velocity.y += C.GRAVITY * delta
		velocity.y = minf(velocity.y, C.TERMINAL_VELOCITY)

func _apply_movement(delta: float) -> void:
	var h := 0
	if pressed_keys.has(KEY_D): h += 1
	if pressed_keys.has(KEY_A): h -= 1

	if h != 0 and not is_blocking:
		var spd = C.PLAYER_SPEED * (1.4 if obsession_active else 1.0)
		velocity.x = h * spd
		facing_right = h > 0
		is_moving = true
	else:
		velocity.x *= 0.55
		is_moving = absf(velocity.x) > 12.0

	var main = get_parent()
	if main and main.has_method("resolve_collision"):
		var result = main.resolve_collision(global_position, C.PLAYER_SIZE, velocity * delta)
		global_position = result["pos"]
		if result["on_ground"]:
			velocity.y = 0.0
		is_on_ground = result["on_ground"]
	else:
		global_position += velocity * delta

func do_jump() -> void:
	if is_on_ground and not is_blocking and not is_recovering:
		velocity.y = C.JUMP_FORCE
		is_on_ground = false
#endregion

#region Бій
func do_attack() -> void:
	if attack_cooldown > 0 or is_blocking or is_recovering:
		return
	attack_combo = (attack_combo + 1) % 3
	var dmg: int = C.PLAYER_ATTACK_DAMAGE[attack_combo]
	if obsession_active:
		dmg *= 2
	attack_timer = C.PLAYER_ATTACK_SPEED[attack_combo]
	attack_cooldown = C.PLAYER_ATTACK_SPEED[attack_combo]

	var dir := 1 if facing_right else -1
	var hr := Rect2(
		global_position.x + dir * 5.0,
		global_position.y - C.PLAYER_SIZE.y * 0.5,
		float(dir) * C.PLAYER_ATTACK_RANGE,
		C.PLAYER_SIZE.y
	)
	if hr.size.x < 0:
		hr.position.x += hr.size.x
		hr.size.x = -hr.size.x

	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var er := Rect2(e.global_position - e.enemy_size * 0.5, e.enemy_size)
		if hr.intersects(er):
			e.take_damage(dmg)

	obsession_fill = minf(
		obsession_fill + C.PLAYER_OBSESSION_FILL_PER_ATTACK,
		C.PLAYER_OBSESSION_LEVEL_THRESHOLD * C.PLAYER_OBSESSION_LEVELS
	)
	_sync_obsession_level()

func do_obsession() -> void:
	if obsession_level < C.PLAYER_OBSESSION_LEVELS or obsession_cooldown > 0:
		return
	obsession_active = true
	obsession_time = C.PLAYER_OBSESSION_DURATION
	degrade_stage = mini(degrade_stage + 1, 3)
	print("💜 OBSESSION активована! Стадія деградації: %d" % degrade_stage)

func take_damage(dmg: int) -> void:
	if not is_alive or is_recovering:
		return
	if randf() < C.PLAYER_DODGE_CHANCE:
		print("✨ Ухилення!")
		return
	var actual := int(dmg * C.PLAYER_BLOCK_DAMAGE_REDUCTION) if is_blocking else dmg
	current_hp -= actual
	obsession_fill = minf(
		obsession_fill + actual * C.PLAYER_OBSESSION_FILL_PER_DAMAGE,
		C.PLAYER_OBSESSION_LEVEL_THRESHOLD * C.PLAYER_OBSESSION_LEVELS
	)
	_sync_obsession_level()
	hp_changed.emit(current_hp)
#endregion

#region Одержимість
func _sync_obsession_level() -> void:
	obsession_level = mini(
		int(obsession_fill / C.PLAYER_OBSESSION_LEVEL_THRESHOLD),
		C.PLAYER_OBSESSION_LEVELS
	)

func _update_obsession(delta: float) -> void:
	if not obsession_active:
		return
	obsession_time -= delta
	if obsession_time <= 0.0:
		obsession_active = false
		obsession_fill = 0.0
		obsession_level = 0
		is_recovering = true
		obsession_cooldown = C.PLAYER_OBSESSION_COOLDOWN
		get_tree().create_timer(C.PLAYER_OBSESSION_RECOVERY).timeout.connect(
			func(): is_recovering = false
		)
#endregion

#region Таймери
func _update_timers(delta: float) -> void:
	if attack_cooldown > 0: attack_cooldown -= delta
	if attack_timer > 0:    attack_timer    -= delta
	if obsession_cooldown > 0: obsession_cooldown -= delta
#endregion

#region Статус
func get_status() -> Dictionary:
	return {
		"hp": current_hp,
		"obsession_fill": obsession_fill,
		"obsession_level": obsession_level,
		"is_blocking": is_blocking,
		"is_alive": is_alive,
		"degrade_stage": degrade_stage,
	}
#endregion

#region Відмалювання
func _draw() -> void:
	if not is_alive:
		return

	var dir := 1.0 if facing_right else -1.0

	# Кольори
	var skin  := Color(0.82, 0.65, 0.46)
	var armor := Color(0.20, 0.16, 0.10)
	var cloth := Color(0.40, 0.30, 0.18)
	var sword := Color(0.80, 0.78, 0.68)

	if obsession_active:
		skin  = Color(0.72, 0.32, 0.92)
		armor = Color(0.32, 0.08, 0.52)
		sword = Color(0.72, 0.20, 1.0)

	var alpha := 0.4 if (is_recovering and _frame % 8 < 4) else 1.0
	skin.a = alpha; armor.a = alpha; cloth.a = alpha

	var leg_a := sin(_frame * 0.35) * 9.0 if (is_moving and is_on_ground) else 0.0
	var bob   := absf(sin(_frame * 0.35)) * 1.5 if (is_moving and is_on_ground) else 0.0

	# Ноги
	draw_rect(Rect2(-10, 14 + leg_a * 0.5, 9, 22), armor)
	draw_rect(Rect2(1,   14 - leg_a * 0.5, 9, 22), armor)
	# Чоботи
	draw_rect(Rect2(-11, 30 + leg_a * 0.5, 11, 8), Color(0.14, 0.09, 0.05, alpha))
	draw_rect(Rect2(0,   30 - leg_a * 0.5, 11, 8), Color(0.14, 0.09, 0.05, alpha))

	# Тулуб
	draw_rect(Rect2(-13, -14, 26, 30), armor)
	draw_rect(Rect2(-11, -12, 22, 24), cloth)
	# Пояс
	draw_rect(Rect2(-13, 13, 26, 5), Color(0.24, 0.17, 0.07, alpha))

	# Голова
	draw_circle(Vector2(0, -28 - bob), 12, skin)
	# Вуса (козацькі)
	draw_rect(Rect2(-6, -26 - bob, 12, 3), Color(0.18, 0.09, 0.04, alpha))
	# Очі
	var eye_c := Color(0.55, 0.10, 1.0) if obsession_active else Color(0.08, 0.04, 0.02, alpha)
	draw_circle(Vector2(5.0 * dir, -30 - bob), 2.5, eye_c)
	# Шапка козацька
	draw_rect(Rect2(-10, -44 - bob, 20, 14), Color(0.08, 0.06, 0.04, alpha))
	draw_rect(Rect2(-8,  -46 - bob, 16,  5), Color(0.52, 0.10, 0.10, alpha))

	# Рука + зброя
	draw_rect(Rect2(dir * 10 - 5, -10, 10, 18), skin)
	if attack_timer > 0:
		var ext := C.PLAYER_ATTACK_RANGE * 0.85
		draw_line(Vector2(dir * 14, -8), Vector2(dir * (14 + ext), -28), sword, 5.0)
		if obsession_active:
			draw_line(Vector2(dir * 14, -8), Vector2(dir * (14 + ext), -28), Color(0.8, 0.3, 1.0, 0.55), 11.0)
	else:
		draw_line(Vector2(dir * 14, 5), Vector2(dir * 20, 22), sword, 4.0)

	# Щит при блоці
	if is_blocking:
		draw_circle(Vector2(-dir * 20, 0), 16, Color(0.28, 0.38, 0.85, 0.88))
		draw_circle(Vector2(-dir * 20, 0), 13, Color(0.18, 0.25, 0.65, 0.88))
		draw_rect(Rect2(-dir * 23 - 3, -6, 6, 12), Color(0.85, 0.78, 0.40, 0.9))
		draw_rect(Rect2(-dir * 26, -3, 12, 6),     Color(0.85, 0.78, 0.40, 0.9))

	# Аура одержимості
	if obsession_active:
		var pulse := sin(_frame * 0.18) * 0.3 + 0.6
		draw_circle(Vector2.ZERO, 54, Color(0.75, 0.0, 1.0, pulse * 0.22))
		draw_circle(Vector2.ZERO, 72, Color(0.50, 0.0, 0.8, pulse * 0.10))
		if degrade_stage >= 2:
			draw_line(Vector2(-8, -40 - bob), Vector2(-14, -57 - bob), Color(0.5, 0.1, 0.8), 3.0)
			draw_line(Vector2(8,  -40 - bob), Vector2(14,  -57 - bob), Color(0.5, 0.1, 0.8), 3.0)

	# Деградація (перший рівень — фіолетова рука)
	if degrade_stage >= 1 and not obsession_active:
		draw_rect(Rect2(-dir * 14, -8, 10, 16), Color(0.65, 0.1, 0.9, 0.4))

	# HP полоска
	var hp_pct := float(current_hp) / float(C.PLAYER_HP_MAX)
	draw_rect(Rect2(-22, -56, 44, 5),            Color(0.10, 0.10, 0.10))
	draw_rect(Rect2(-22, -56, 44 * hp_pct, 5),   Color(0.15, 0.85, 0.30))
#endregion
