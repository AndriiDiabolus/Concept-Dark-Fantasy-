## enemy.gd — Ворог-рицар | AI + puppet-анімація (ноги / корпус / голова окремо)
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
const KNIGHT_SCALE: float  = 0.65    # дисплей: 104 × 116 px
const KNIGHT_FOOT_PCT: float = 0.93  # ноги на 93% висоти кадру

# Частини тіла (частки висоти у вихідному спрайті)
# Перекривання навмисне — прибирає шви між шарами
const LEG_START:  float = 0.54   # ноги: 54-100%
const BODY_START: float = 0.10   # корпус: 10-80%
const BODY_END:   float = 0.80
const HEAD_END:   float = 0.32   # голова: 0-32%

# Шарніри (частки висоти = осі обертання)
const HIP_FRAC:  float = 0.62   # стегна (вісь корпусу)
const NECK_FRAC: float = 0.22   # шия (вісь голови)

var _k_anim:  String = "idle"
var _k_anim_t: int   = 0
var _k_combo:  int   = 0        # поточний удар 0/1/2
#endregion

signal died(enemy)

# ──────────────────────────────────────────────
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
	if not is_alive:
		_k_anim_t += 1
		queue_redraw()
		if _k_anim_t > 60:
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
		if result["on_ground"]: velocity.y = 0.0
		is_on_ground = result["on_ground"]
	else:
		global_position += velocity * delta
#endregion

#region AI
func _update_ai(_delta: float) -> void:
	if target == null or not is_instance_valid(target): return
	if is_telegraphing: velocity.x = 0.0; return
	var dx     := target.global_position.x - global_position.x
	var dist   := absf(dx)
	var dy_raw := absf(target.global_position.y - global_position.y)
	var same_level: bool = dy_raw <= 80 or enemy_type == "musketeer"
	var chase:  float = enemy_data["chase_range"]
	var arange: float = enemy_data["attack_range"]
	match _ai_state:
		"patrol":
			if dist < chase and same_level: _ai_state = "chase"
			else: _do_patrol(_delta)
		"chase":
			if dist > chase * 1.4 or not same_level: _ai_state = "patrol"; patrol_walked = 0.0
			elif dist <= arange: _ai_state = "attack"; velocity.x = 0.0
			else: _do_chase(dx)
		"attack":
			velocity.x = 0.0
			if dist > arange * 1.3 or not same_level: _ai_state = "chase"
			elif attack_cooldown <= 0: _start_telegraph()

func _do_patrol(delta: float) -> void:
	var spd := float(enemy_data["speed"]) * 0.45
	velocity.x = patrol_dir * spd
	facing_right = patrol_dir > 0
	patrol_walked += spd * delta
	if patrol_walked >= PATROL_RANGE: patrol_dir *= -1; patrol_walked = 0.0

func _do_chase(dx: float) -> void:
	facing_right = dx > 0
	velocity.x = sign(dx) * float(enemy_data["speed"])

func _start_telegraph() -> void:
	is_telegraphing = true
	telegraph_timer  = 1.0 if enemy_type == "piker" else 0.6
	attack_cooldown  = enemy_data["attack_cooldown"]

func _do_attack() -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive: return
	if absf(target.global_position.y - global_position.y) > 80: return
	target.take_damage(enemy_data["damage"])
	_k_combo = (_k_combo + 1) % 3
#endregion

#region Шкода
func take_damage(dmg: int) -> void:
	if not is_alive: return
	current_hp -= dmg
	hit_flash = 0.18
	if current_hp <= 0: _die()

func _die() -> void:
	is_alive  = false
	_ai_state = "dead"
	_k_anim   = "death"
	_k_anim_t = 0
	velocity  = Vector2.ZERO
	remove_from_group("enemies")
	died.emit(self)
	get_tree().create_timer(0.9).timeout.connect(queue_free)
#endregion

#region Таймери
func _update_timers(delta: float) -> void:
	if attack_cooldown > 0:  attack_cooldown -= delta
	if hit_flash > 0:        hit_flash -= delta
	if is_telegraphing:
		telegraph_timer -= delta
		if telegraph_timer <= 0:
			is_telegraphing = false
			_do_attack()
#endregion

#region Стан анімації
func _update_k_anim() -> void:
	var want: String
	if hit_flash > 0.05:                  want = "hurt"
	elif not is_on_ground:                want = "jump"
	elif is_telegraphing:                 want = "attack%d" % _k_combo
	elif absf(velocity.x) > 8.0:         want = "run"
	else:                                 want = "idle"
	if want != _k_anim: _k_anim = want; _k_anim_t = 0
	else:               _k_anim_t += 1
#endregion

# ══════════════════════════════════════════════
#region Відмалювання
func _draw() -> void:
	var hh     := enemy_size.y * 0.5
	var hp_pct := float(current_hp) / float(enemy_data["hp"]) if current_hp > 0 else 0.0

	if _k_tex != null:
		_draw_knight()
	else:
		_draw_primitive_fallback()

	# HP-полоска
	if is_alive:
		var bw   := float(KNIGHT_W) * KNIGHT_SCALE
		var btop := -hh - 14.0
		draw_rect(Rect2(-bw * 0.5, btop, bw,          4), Color(0.08, 0.08, 0.08))
		draw_rect(Rect2(-bw * 0.5, btop, bw * hp_pct, 4), Color(0.85, 0.15, 0.15))

	# Телеграф-сяйво
	if is_telegraphing:
		var glow := sin(_frame * 0.5) * 0.5 + 0.5
		draw_circle(Vector2.ZERO, hh * 1.15, Color(1.0, 0.08, 0.08, glow * 0.28))

# ── Головна функція анімації ───────────────────────────────────────────────
func _draw_knight() -> void:
	var sw   := float(KNIGHT_W) * KNIGHT_SCALE
	var sh   := float(KNIGHT_H) * KNIGHT_SCALE
	var hh   := enemy_size.y * 0.5
	var flip := -1.0 if not facing_right else 1.0
	var t    := _k_anim_t

	# ── Параметри анімації ──
	var off_x    := 0.0   # зміщення всього персонажа (X — напрямок руху)
	var off_y    := 0.0   # зміщення (Y — підйом/опускання)
	var sc_x     := 1.0   # горизонтальний squash усього тіла
	var sc_y     := 1.0   # вертикальний squash
	var body_rot := 0.0   # кут обертання корпусу навколо стегон
	var head_rot := 0.0   # кут обертання голови навколо шиї
	var leg_sc_x := 1.0   # ширина ніг (стійка при ударі)
	var tint     := Color(1.0, 1.0, 1.0, 1.0)

	if hit_flash > 0:
		tint = Color(1.0, 0.28, 0.28, 1.0)

	match _k_anim:

		"idle":
			var bob  := sin(t * 0.07) * 2.5
			off_y    = bob
			sc_y     = 1.0 + sin(t * 0.07) * 0.012
			body_rot = sin(t * 0.055) * 0.028 * flip  # легке гойдання корпусу
			head_rot = sin(t * 0.055 + 0.4) * 0.040   # голова гойдається трохи інакше

		"run":
			var s    := sin(t * 0.24)
			off_y    = abs(s) * 5.0
			sc_x     = 1.0 + abs(s) * 0.025
			sc_y     = 1.0 - abs(s) * 0.025
			body_rot = flip * (0.065 + sin(t * 0.24) * 0.035)  # нахил + крок
			head_rot = -body_rot * 0.35                          # голова злегка протилежна

		"jump":
			if t < 8:
				var p := float(t) / 8.0
				sc_x     = 1.0 + p * 0.14
				sc_y     = 1.0 - p * 0.18
				off_y    = p * 4.0
				body_rot = -flip * p * 0.10
				head_rot =  flip * p * 0.06
			elif t < 26:
				sc_x     = 0.88; sc_y = 1.12
				off_y    = -6.0
				body_rot = -flip * 0.08
				head_rot =  flip * 0.05
			else:
				var p    := clampf(float(t - 26) / 10.0, 0.0, 1.0)
				sc_x     = lerpf(0.88, 1.0, p)
				sc_y     = lerpf(1.12, 1.0, p)
				body_rot = lerpf(-flip * 0.08, 0.0, p)
				head_rot = lerpf( flip * 0.05, 0.0, p)

		# ── КОМБО 0 — швидкий горизонтальний удар сокирою ──────────────────
		"attack0":
			if t < 7:             # замах назад
				var p := float(t) / 7.0
				body_rot = -flip * 0.28 * p
				head_rot =  flip * 0.12 * p
				off_x    = -flip * 10.0 * p
				sc_y     = 1.0 + p * 0.08
			elif t < 15:          # удар вперед
				var p := float(t - 7) / 8.0
				body_rot = lerpf(-flip * 0.28,  flip * 0.36, p)
				head_rot = lerpf( flip * 0.12, -flip * 0.10, p)
				off_x    = lerpf(-flip * 10.0,  flip * 18.0, p)
				sc_x     = 1.0 + p * 0.12
				sc_y     = lerpf(1.08, 0.90, p)
				leg_sc_x = 1.0 + p * 0.06
			else:                 # відновлення
				var p := clampf(float(t - 15) / 9.0, 0.0, 1.0)
				body_rot = lerpf(flip * 0.36, 0.0, p)
				head_rot = lerpf(-flip * 0.10, 0.0, p)
				off_x    = lerpf(flip * 18.0,  0.0, p)
				sc_x     = lerpf(1.12, 1.0, p)
				sc_y     = lerpf(0.90, 1.0, p)
				leg_sc_x = lerpf(1.06, 1.0, p)

		# ── КОМБО 1 — кидок-укол вперед ─────────────────────────────────────
		"attack1":
			if t < 8:             # підготовка — корпус стягується
				var p := float(t) / 8.0
				body_rot = -flip * 0.18 * p
				head_rot =  flip * 0.08 * p
				off_x    = -flip * 12.0 * p
				sc_x     = lerpf(1.0, 0.88, p)
				sc_y     = lerpf(1.0, 1.14, p)
			elif t < 17:          # випад
				var p := float(t - 8) / 9.0
				body_rot = lerpf(-flip * 0.18,  flip * 0.20, p)
				head_rot = lerpf( flip * 0.08, -flip * 0.06, p)
				off_x    = lerpf(-flip * 12.0,  flip * 26.0, p)
				sc_x     = lerpf(0.88, 1.10, p)
				sc_y     = lerpf(1.14, 0.92, p)
				leg_sc_x = lerpf(1.0,  1.08, p)
			else:                 # відновлення
				var p := clampf(float(t - 17) / 11.0, 0.0, 1.0)
				body_rot = lerpf(flip * 0.20, 0.0, p)
				head_rot = lerpf(-flip * 0.06, 0.0, p)
				off_x    = lerpf(flip * 26.0,  0.0, p)
				sc_x     = lerpf(1.10, 1.0, p)
				sc_y     = lerpf(0.92, 1.0, p)
				leg_sc_x = lerpf(1.08, 1.0, p)

		# ── КОМБО 2 — важкий удар зверху вниз ──────────────────────────────
		"attack2":
			if t < 10:            # підіймання — відхил назад
				var p := float(t) / 10.0
				body_rot = -flip * 0.24 * p
				head_rot = -flip * 0.16 * p   # голова теж відкидається
				off_y    = -18.0 * p
				sc_x     = lerpf(1.0, 0.90, p)
				sc_y     = lerpf(1.0, 1.18, p)
				leg_sc_x = lerpf(1.0, 1.10, p)
			elif t < 18:          # апогей
				body_rot = -flip * 0.24
				head_rot = -flip * 0.16
				off_y    = -18.0
				sc_x = 0.90; sc_y = 1.18; leg_sc_x = 1.10
			elif t < 23:          # різкий удар вниз
				var p := float(t - 18) / 5.0
				body_rot = lerpf(-flip * 0.24,  flip * 0.22, p)
				head_rot = lerpf(-flip * 0.16,  flip * 0.14, p)
				off_y    = lerpf(-18.0, 10.0, p)
				sc_x     = lerpf(0.90, 1.32, p)
				sc_y     = lerpf(1.18, 0.72, p)
				leg_sc_x = lerpf(1.10, 1.14, p)
			else:                 # відновлення
				var p := clampf(float(t - 23) / 13.0, 0.0, 1.0)
				body_rot = lerpf(flip * 0.22, 0.0, p)
				head_rot = lerpf(flip * 0.14, 0.0, p)
				off_y    = lerpf(10.0, 0.0, p)
				sc_x     = lerpf(1.32, 1.0, p)
				sc_y     = lerpf(0.72, 1.0, p)
				leg_sc_x = lerpf(1.14, 1.0, p)

		"hurt":
			var flash := _frame % 3 != 0
			tint.a    = 1.0 if flash else 0.28
			var k     := maxf(0.0, 1.0 - float(t) / 10.0)
			body_rot  =  flip * 0.16 * k    # відскок-нахил корпусу
			head_rot  = -flip * 0.10 * k    # голова у протилежний бік
			off_x     = -flip * 9.0 * k
			sc_x      = 1.14 - k * 0.14
			sc_y      = 0.86 + k * 0.14

		"death":
			var fade  := maxf(0.0, 1.0 - float(t) / 55.0)
			tint      = Color(0.55, 0.30, 0.30, fade)
			var k     := minf(1.0, float(t) / 30.0)
			body_rot  =  flip * k * 0.55
			head_rot  =  flip * k * 0.40   # голова падає разом з корпусом
			off_y     = minf(16.0, float(t) * 0.34)

	# ── Розміри з урахуванням squash/stretch ──
	var dsw    := sw * sc_x
	var dsh    := sh * sc_y
	var dtop_y := (hh + off_y) - dsh * KNIGHT_FOOT_PCT

	# ── Малювання трьома шарами ──
	_draw_parts(dsw, dsh, dtop_y, body_rot, head_rot, leg_sc_x, off_x, tint)

# ── Puppet-анімація: 3 незалежних шари ────────────────────────────────────
#
#  ПОРЯДОК ШАРІВ (знизу вгору):
#    1. НОГИ   — без обертання, стабільна база
#    2. КОРПУС — обертається навколо стегон (HIP_FRAC)
#    3. ГОЛОВА — обертається навколо шиї (NECK_FRAC)
#
#  Формула pivot-обертання draw_set_transform:
#    T(p) = R(rot)*p + (pivot - R(rot)*pivot)
#    position.x = pivot_y * sin(rot)
#    position.y = pivot_y * (1 - cos(rot))      (pivot_x = 0 для центральної осі)
#
func _draw_parts(dsw: float, dsh: float, dtop_y: float,
				 body_rot: float, head_rot: float,
				 leg_sc_x: float, off_x: float, tint: Color) -> void:

	var kw := float(KNIGHT_W)
	var kh := float(KNIGHT_H)

	# ── Вісі шарнірів у локальних координатах ──
	var hip_y  := dtop_y + dsh * HIP_FRAC
	var neck_y := dtop_y + dsh * NECK_FRAC

	# ── 1. НОГИ (LEG_START..1.0) — нема обертання ──────────────────────────
	var src_legs  := Rect2(0.0, kh * LEG_START, kw, kh * (1.0 - LEG_START))
	var leg_dest_w := dsw * leg_sc_x
	var leg_dest_y := dtop_y + dsh * LEG_START
	var leg_dest_h := dsh * (1.0 - LEG_START)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if facing_right:
		draw_texture_rect_region(_k_tex,
			Rect2(off_x - leg_dest_w * 0.5, leg_dest_y, leg_dest_w, leg_dest_h),
			src_legs, false, tint)
	else:
		draw_texture_rect_region(_k_tex,
			Rect2(-off_x + leg_dest_w * 0.5, leg_dest_y, -leg_dest_w, leg_dest_h),
			src_legs, false, tint)

	# ── 2. КОРПУС (BODY_START..BODY_END) — обертання навколо стегон ─────────
	var src_body  := Rect2(0.0, kh * BODY_START, kw, kh * (BODY_END - BODY_START))
	var body_dest_y := dtop_y + dsh * BODY_START
	var body_dest_h := dsh * (BODY_END - BODY_START)

	# pivot = (0, hip_y) → position = (hip_y*sin, hip_y*(1-cos))
	var bpx := hip_y * sin(body_rot) + off_x
	var bpy := hip_y * (1.0 - cos(body_rot))
	draw_set_transform(Vector2(bpx, bpy), body_rot, Vector2.ONE)
	if facing_right:
		draw_texture_rect_region(_k_tex,
			Rect2(-dsw * 0.5, body_dest_y, dsw, body_dest_h),
			src_body, false, tint)
	else:
		draw_texture_rect_region(_k_tex,
			Rect2( dsw * 0.5, body_dest_y, -dsw, body_dest_h),
			src_body, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── 3. ГОЛОВА (0..HEAD_END) — обертання навколо шиї ────────────────────
	var src_head  := Rect2(0.0, 0.0, kw, kh * HEAD_END)
	var head_dest_h := dsh * HEAD_END

	# pivot = (0, neck_y) → position = (neck_y*sin, neck_y*(1-cos))
	var hpx := neck_y * sin(head_rot)
	var hpy := neck_y * (1.0 - cos(head_rot))
	draw_set_transform(Vector2(hpx, hpy), head_rot, Vector2.ONE)
	if facing_right:
		draw_texture_rect_region(_k_tex,
			Rect2(-dsw * 0.5, dtop_y, dsw, head_dest_h),
			src_head, false, tint)
	else:
		draw_texture_rect_region(_k_tex,
			Rect2( dsw * 0.5, dtop_y, -dsw, head_dest_h),
			src_head, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Запасний примітив ──────────────────────────────────────────────────────
func _draw_primitive_fallback() -> void:
	var hw  := enemy_size.x * 0.5
	var hh  := enemy_size.y * 0.5
	var dir := 1.0 if facing_right else -1.0
	if not is_alive:
		draw_rect(Rect2(-hw, -6, hw * 2, 14), Color(0.28, 0.18, 0.12, 0.5))
		return
	var body_c := Color(1.0, 0.28, 0.28) if hit_flash > 0 else Color(0.45, 0.28, 0.18)
	draw_rect(Rect2(-hw * 0.72, -hh * 0.5, hw * 1.44, hh * 1.5), body_c)
	draw_circle(Vector2(0.0, -hh * 0.72), hh * 0.30, Color(0.76, 0.58, 0.40))
	draw_line(Vector2(dir * hw * 0.7, -hh * 0.28),
		Vector2(dir * (hw + 36), -hh * 0.54), Color(0.75, 0.72, 0.64), 4.0)
#endregion
