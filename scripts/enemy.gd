## enemy.gd — Базовий ворог (сайд-скроллер)
## Патруль → Переслідування → Атака | Спрайт: enemy_knight.png

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

#region Спрайт і анімація
var _k_tex: Texture2D = null
const KNIGHT_W: int = 160
const KNIGHT_H: int = 178
const KNIGHT_SCALE: float = 0.65   # дисплей: 104×116 px
const KNIGHT_FOOT_PCT: float = 0.93  # ноги на 93% висоти кадру

var _k_anim: String = "idle"
var _k_anim_t: int = 0      # лічильник кадрів у поточній анімації
var _k_combo: int = 0       # поточний удар комбо: 0 / 1 / 2
#endregion

signal died(enemy)

func setup(type: String, player: Node2D) -> void:
	enemy_type = type
	enemy_data = C.ENEMY_TYPES[type]
	enemy_size = enemy_data["size"]
	current_hp = enemy_data["hp"]
	target = player
	add_to_group("enemies")
	set_process(true)
	_k_tex = load("res://assets/sprites/enemy_knight.png")
	print("👹 %s | HP:%d DMG:%d" % [enemy_data["name"], current_hp, enemy_data["damage"]])

func _process(delta: float) -> void:
	# Анімація смерті продовжує працювати ще 55 кадрів
	if not is_alive:
		_k_anim_t += 1
		queue_redraw()
		if _k_anim_t > 55:
			set_process(false)
		return

	_update_timers(delta)
	_apply_gravity(delta)
	_update_ai(delta)
	_update_k_anim()
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
	var dy_raw := absf(target.global_position.y - global_position.y)
	var same_level: bool = dy_raw <= 80 or enemy_type == "musketeer"
	var chase:  float = enemy_data["chase_range"]
	var arange: float = enemy_data["attack_range"]

	match _ai_state:
		"patrol":
			if dist < chase and same_level:
				_ai_state = "chase"
			else:
				_do_patrol(_delta)
		"chase":
			if dist > chase * 1.4 or not same_level:
				_ai_state = "patrol"
				patrol_walked = 0.0
			elif dist <= arange:
				_ai_state = "attack"
				velocity.x = 0.0
			else:
				_do_chase(dx)
		"attack":
			velocity.x = 0.0
			if dist > arange * 1.3 or not same_level:
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
	if dy > 80:
		return
	target.take_damage(enemy_data["damage"])
	_k_combo = (_k_combo + 1) % 3   # перемикаємо удар комбо
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
	_k_anim = "death"
	_k_anim_t = 0
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

#region Стан анімації
func _update_k_anim() -> void:
	var want: String
	if hit_flash > 0.05:
		want = "hurt"
	elif not is_on_ground:
		want = "jump"
	elif is_telegraphing:
		want = "attack%d" % _k_combo
	elif absf(velocity.x) > 8.0:
		want = "run"
	else:
		want = "idle"

	if want != _k_anim:
		_k_anim = want
		_k_anim_t = 0
	else:
		_k_anim_t += 1
#endregion

#region Відмалювання
func _draw() -> void:
	var hh  := enemy_size.y * 0.5
	var hp_pct := float(current_hp) / float(enemy_data["hp"]) if current_hp > 0 else 0.0

	if _k_tex != null:
		_draw_knight()
	else:
		_draw_primitive_fallback()

	# HP-полоска (поверх спрайта)
	if is_alive:
		var bw := float(KNIGHT_W) * KNIGHT_SCALE
		var btop := -hh - 14.0
		draw_rect(Rect2(-bw * 0.5, btop, bw,          4), Color(0.08, 0.08, 0.08))
		draw_rect(Rect2(-bw * 0.5, btop, bw * hp_pct, 4), Color(0.85, 0.15, 0.15))

	# Телеграф — червоне сяйво
	if is_telegraphing:
		var glow := sin(_frame * 0.5) * 0.5 + 0.5
		draw_circle(Vector2.ZERO, hh * 1.1, Color(1.0, 0.08, 0.08, glow * 0.28))

# ── Спрайт з процедурними анімаціями ──────────────────────────────────────
func _draw_knight() -> void:
	var sw    := float(KNIGHT_W) * KNIGHT_SCALE     # 104
	var sh    := float(KNIGHT_H) * KNIGHT_SCALE     # 115.7
	var hh    := enemy_size.y * 0.5                 # точка контакту з землею
	var flip  := -1.0 if not facing_right else 1.0
	var t     := _k_anim_t

	# --- Параметри анімації ---
	var off_x := 0.0
	var off_y := 0.0
	var rot   := 0.0
	var sc_x  := 1.0
	var sc_y  := 1.0
	var tint  := Color(1.0, 1.0, 1.0, 1.0)

	if hit_flash > 0:
		tint = Color(1.0, 0.28, 0.28, 1.0)

	match _k_anim:
		"idle":
			off_y = sin(t * 0.07) * 2.5
			sc_y  = 1.0 + sin(t * 0.07) * 0.012

		"run":
			var s := sin(t * 0.24)
			off_y = abs(s) * 5.0
			rot   = flip * 0.065
			sc_x  = 1.0 + abs(s) * 0.025
			sc_y  = 1.0 - abs(s) * 0.025

		"jump":
			if t < 8:                          # відрив — стиск
				sc_x  = 1.0 + t * 0.018
				sc_y  = 1.0 - t * 0.022
				off_y = t * 0.5
			elif t < 26:                       # повітря — розтяжка
				sc_x  = 0.88; sc_y = 1.12
				rot   = -flip * 0.08
				off_y = -6.0
			else:                              # приземлення — відновлення
				var p := clampf(float(t - 26) / 10.0, 0.0, 1.0)
				sc_x  = lerpf(0.88, 1.0, p)
				sc_y  = lerpf(1.12, 1.0, p)

		"attack0":  # швидкий горизонтальний удар — 22 кадри
			if t < 7:
				var p := float(t) / 7.0
				rot   = -flip * 0.22 * p
				off_x = -flip * 9.0 * p
				sc_y  = 1.0 + p * 0.08
			elif t < 15:
				var p := float(t - 7) / 8.0
				rot   = lerpf(-flip * 0.22, flip * 0.30, p)
				off_x = lerpf(-flip * 9.0,  flip * 16.0, p)
				sc_x  = 1.0 + p * 0.12
				sc_y  = lerpf(1.08, 0.92, p)
			else:
				var p := clampf(float(t - 15) / 8.0, 0.0, 1.0)
				rot   = lerpf(flip * 0.30, 0.0, p)
				off_x = lerpf(flip * 16.0,  0.0, p)
				sc_x  = lerpf(1.12, 1.0, p)
				sc_y  = lerpf(0.92, 1.0, p)

		"attack1":  # кидок вперед (колючий удар) — 28 кадрів
			if t < 8:
				var p := float(t) / 8.0
				off_x = -flip * 10.0 * p
				sc_x  = lerpf(1.0, 0.90, p)
				sc_y  = lerpf(1.0, 1.12, p)
			elif t < 17:
				var p := float(t - 8) / 9.0
				off_x = lerpf(-flip * 10.0, flip * 24.0, p)
				rot   = flip * 0.14 * p
				sc_x  = lerpf(0.90, 1.08, p)
				sc_y  = lerpf(1.12, 0.94, p)
			else:
				var p := clampf(float(t - 17) / 11.0, 0.0, 1.0)
				off_x = lerpf(flip * 24.0, 0.0, p)
				rot   = lerpf(flip * 0.14,  0.0, p)
				sc_x  = lerpf(1.08, 1.0, p)
				sc_y  = lerpf(0.94, 1.0, p)

		"attack2":  # важкий удар зверху вниз — 35 кадрів
			if t < 10:
				var p := float(t) / 10.0
				off_y = -16.0 * p
				sc_x  = lerpf(1.0, 0.92, p)
				sc_y  = lerpf(1.0, 1.15, p)
				rot   = -flip * 0.15 * p
			elif t < 18:
				off_y = -16.0; sc_x = 0.92; sc_y = 1.15; rot = -flip * 0.15
			elif t < 23:
				var p := float(t - 18) / 5.0
				off_y = lerpf(-16.0, 8.0,  p)
				sc_x  = lerpf(0.92,  1.28, p)
				sc_y  = lerpf(1.15,  0.76, p)
				rot   = lerpf(-flip * 0.15, 0.0, p)
			else:
				var p := clampf(float(t - 23) / 12.0, 0.0, 1.0)
				off_y = lerpf(8.0,  0.0, p)
				sc_x  = lerpf(1.28, 1.0, p)
				sc_y  = lerpf(0.76, 1.0, p)

		"hurt":
			tint.a = 1.0 if (_frame % 3 != 0) else 0.3
			off_x  = -flip * 8.0 * maxf(0.0, 1.0 - float(t) / 10.0)
			sc_x   = 1.12 - clampf(float(t) * 0.015, 0.0, 0.12)
			sc_y   = 0.88 + clampf(float(t) * 0.015, 0.0, 0.12)

		"death":
			var fade := maxf(0.0, 1.0 - float(t) / 50.0)
			tint  = Color(0.55, 0.30, 0.30, fade)
			rot   = flip * minf(0.55, float(t) * 0.016)
			off_y = minf(14.0, float(t) * 0.32)

	# Обчислення реального розміру (squash/stretch)
	var dsw := sw * sc_x
	var dsh := sh * sc_y
	# Ноги залишаються на місці незалежно від squash
	var dtop_y := (hh + off_y) - dsh * KNIGHT_FOOT_PCT

	# Поворот через draw_set_transform (навколо хітбокс-центру)
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)

	# Відмалювання (фліп через від'ємну ширину прямокутника)
	if facing_right:
		draw_texture_rect(_k_tex, Rect2(off_x - dsw * 0.5, dtop_y, dsw, dsh), false, tint)
	else:
		draw_texture_rect(_k_tex, Rect2(-off_x + dsw * 0.5, dtop_y, -dsw, dsh), false, tint)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Запасний примітив (якщо текстура не завантажена) ──────────────────────
func _draw_primitive_fallback() -> void:
	var hw  := enemy_size.x * 0.5
	var hh  := enemy_size.y * 0.5
	var dir := 1.0 if facing_right else -1.0
	if not is_alive:
		draw_rect(Rect2(-hw, -6, hw * 2, 14), Color(0.28, 0.18, 0.12, 0.5))
		return
	var body_c := Color(0.45, 0.28, 0.18)
	if hit_flash > 0:
		body_c = Color(1.0, 0.28, 0.28)
	draw_rect(Rect2(-hw * 0.72, -hh * 0.50, hw * 1.44, hh * 1.50), body_c)
	draw_circle(Vector2(0.0, -hh * 0.72), hh * 0.30, Color(0.76, 0.58, 0.40))
	draw_line(Vector2(dir * hw * 0.7, -hh * 0.28), Vector2(dir * (hw + 36), -hh * 0.54),
		Color(0.75, 0.72, 0.64), 4.0)
#endregion
