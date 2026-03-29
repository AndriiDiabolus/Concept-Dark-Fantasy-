## enemy.gd — Ворог-рицар | AI + sprite-sheet анімація
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
var _base_tint: Color = Color.WHITE

var patrol_dir: int = -1
var patrol_walked: float = 0.0
const PATROL_RANGE: float = 200.0

var _ai_state: String = "patrol"
var _frame: int = 0

#region Спрайт — sprite-sheet анімація
var _sheets: Dictionary = {}   # "idle" → Texture2D, "run" → Texture2D, …

# Кількість кадрів у кожній анімації (CraftPix 128×128)
const ANIM_FRAMES: Dictionary = {
	"idle":    4, "run":    7, "walk":   8,
	"attack0": 5, "attack1":4, "attack2":4,
	"jump":    6, "hurt":   2, "death":  6,
	"defend":  4,
}
# Кадрів за секунду для кожної анімації
const ANIM_FPS: Dictionary = {
	"idle":     8, "run":   12, "walk":  10,
	"attack0":  5, "attack1": 5, "attack2": 5,
	"jump":    10, "hurt":  10, "death":   8,
	"defend":   6,
}
# Кадр нанесення удару для кожної атак-анімації
const ANIM_IMPACT_FRAME: Dictionary = {
	"attack0": 3, "attack1": 2, "attack2": 2,
}
# Параметри захисту та стрибка
const DEFEND_DURATION:    float = 2.0   # секунд тримає щит
const DEFEND_COOLDOWN_T:  float = 3.0   # перезарядка захисту
const DEFEND_POWER_MULT:  float = 3.0   # множник потужного удару після щиту
# CraftPix: кадр 128×128, персонаж займає нижні ~63px
const BASE_FRAME_H: float = 128.0
# Цільова висота всього canvas на екрані → персонаж виходить ~78px
const KNIGHT_RENDER_H: float = 160.0

var _k_anim:           String = "idle"
var _k_anim_t:         int    = 0
var _anim_start_frame: int    = 0
var _k_combo:          int    = 0
var _attack_hit_fired: bool   = false
var _pending_power_mult: float = 1.0  # множник для наступного удару

# Захист
var is_defending:    bool  = false
var defend_timer:    float = 0.0
var defend_cooldown: float = 0.0

#endregion

signal died(enemy)

# ──────────────────────────────────────────────
func setup(type: String, player: Node2D) -> void:
	enemy_type = type
	enemy_data = C.ENEMY_TYPES[type]
	enemy_size = enemy_data["size"]
	current_hp = enemy_data["hp"]
	_base_tint = enemy_data.get("tint", Color.WHITE)
	target = player
	add_to_group("enemies")
	set_process(true)
	_load_sheets()
	print("👹 %s | HP:%d DMG:%d" % [enemy_data["name"], current_hp, enemy_data["damage"]])

func _load_sheets() -> void:
	var dir: String = enemy_data.get("sprite_dir", "knight_weak")
	var b: String   = "res://assets/sprites/" + dir + "/"
	for anim in ANIM_FRAMES.keys():
		var path: String = b + str(anim) + ".png"
		if ResourceLoader.exists(path):
			_sheets[anim] = load(path)

func _process(delta: float) -> void:
	if not is_alive:
		_k_anim_t += 1
		queue_redraw()
		if _k_anim_t > 80:
			set_process(false)
		return
	_update_timers(delta)
	_apply_gravity(delta)
	_update_ai(delta)
	_update_k_anim()
	_check_attack_anim()
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
	if is_telegraphing or is_defending: velocity.x = 0.0; return
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
			# Захист: раз на DEFEND_COOLDOWN_T, ~1.5% шанс за кадр
			elif defend_cooldown <= 0 and attack_cooldown <= 0 and randf() < 0.20:
				_start_defend()
			elif attack_cooldown <= 0:
				_start_telegraph()

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
	is_telegraphing   = true
	attack_cooldown   = enemy_data["attack_cooldown"]
	_attack_hit_fired = false

func _start_defend() -> void:
	is_defending  = true
	defend_timer  = DEFEND_DURATION
	defend_cooldown = DEFEND_COOLDOWN_T
	velocity.x    = 0.0


func _do_attack() -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive: return
	# Прямокутник удару від краю ворога
	var dir  := 1 if facing_right else -1
	var arange := float(enemy_data["attack_range"])
	var ar := Rect2(
		global_position.x + dir * (enemy_size.x * 0.5),
		global_position.y - enemy_size.y * 0.5,
		float(dir) * arange,
		enemy_size.y
	)
	if ar.size.x < 0:
		ar.position.x += ar.size.x
		ar.size.x     = -ar.size.x
	# Хертбокс гравця
	var pr := Rect2(target.global_position - C.PLAYER_SIZE * 0.5, C.PLAYER_SIZE)
	if not ar.intersects(pr):
		_pending_power_mult = 1.0
		return
	var dmg := int(float(enemy_data["damage"]) * _pending_power_mult)
	_pending_power_mult = 1.0
	target.take_damage(dmg)
	_k_combo = (_k_combo + 1) % 3
#endregion

#region Шкода
func take_damage(dmg: int) -> void:
	if not is_alive: return
	if is_defending:
		hit_flash = 0.06   # мінімальний відблиск — удар заблоковано
		return
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
	get_tree().create_timer(1.2).timeout.connect(queue_free)
#endregion

#region Таймери
func _update_timers(delta: float) -> void:
	if attack_cooldown > 0:   attack_cooldown   -= delta
	if hit_flash > 0:         hit_flash         -= delta
	if defend_cooldown > 0:   defend_cooldown   -= delta
	# Захист закінчився → потужний удар
	if is_defending:
		defend_timer -= delta
		if defend_timer <= 0:
			is_defending        = false
			_pending_power_mult = DEFEND_POWER_MULT
			attack_cooldown     = 0.0
			_start_telegraph()

# Анімація-driven атака: хит на impact-кадрі, кінець на останньому кадрі
func _check_attack_anim() -> void:
	if not is_telegraphing or not _k_anim.begins_with("attack"): return
	var fps: int        = ANIM_FPS.get(_k_anim, 10)
	var frame_count: int = ANIM_FRAMES.get(_k_anim, 4)
	var elapsed: int    = _frame - _anim_start_frame
	var cur_frame: int  = int(float(elapsed) / (60.0 / float(fps)))
	# Нанести удар рівно на impact-кадрі (один раз)
	var impact: int = ANIM_IMPACT_FRAME.get(_k_anim, frame_count - 1)
	if cur_frame >= impact and not _attack_hit_fired:
		_attack_hit_fired = true
		_do_attack()
	# Завершити telegraph коли анімація закінчилась
	if cur_frame >= frame_count:
		is_telegraphing   = false
		_attack_hit_fired = false
#endregion

#region Стан анімації
func _update_k_anim() -> void:
	var want: String
	if hit_flash > 0.05:
		want = "hurt"
	elif is_defending:
		want = "defend"
	elif is_telegraphing:
		want = "attack%d" % _k_combo
	elif not is_on_ground:
		want = "jump"
	elif absf(velocity.x) > float(enemy_data.get("speed", 80.0)) * 0.6:
		want = "run"
	elif absf(velocity.x) > 8.0:
		want = "walk"
	else:
		want = "idle"
	if want != _k_anim:
		_k_anim           = want
		_anim_start_frame = _frame
		_attack_hit_fired = false
#endregion

# ══════════════════════════════════════════════
#region Відмалювання
func _draw() -> void:
	var hh     := enemy_size.y * 0.5
	var hp_pct := float(current_hp) / float(enemy_data["hp"]) if current_hp > 0 else 0.0

	if not _sheets.is_empty():
		_draw_sprite()
	else:
		_draw_primitive_fallback()

	# HP-полоска
	if is_alive:
		var btop := -hh - 14.0
		draw_rect(Rect2(-36.0, btop, 72.0,          4), Color(0.08, 0.08, 0.08))
		draw_rect(Rect2(-36.0, btop, 72.0 * hp_pct, 4), Color(0.85, 0.15, 0.15))

	# Телеграф-сяйво
	if is_telegraphing:
		var glow := sin(_frame * 0.5) * 0.5 + 0.5
		var col  := Color(1.0, 0.65, 0.0, glow * 0.5) if _pending_power_mult > 1.0 \
			else Color(1.0, 0.08, 0.08, glow * 0.28)
		draw_circle(Vector2.ZERO, hh * 1.15, col)

	# Захист — щит + індикатор накопиченої сили
	if is_defending:
		var sdir    := 1.0 if facing_right else -1.0
		var pulse   := sin(_frame * 0.18) * 0.3 + 0.7
		draw_circle(Vector2(sdir * 22, 0), 24, Color(0.25, 0.55, 1.0, pulse * 0.55))
		draw_circle(Vector2(sdir * 22, 0), 16, Color(0.55, 0.80, 1.0, pulse * 0.45))
		# Кругова шкала накопичення потужного удару
		var pct := 1.0 - (defend_timer / DEFEND_DURATION)
		draw_arc(Vector2.ZERO, hh * 0.75, -PI * 0.5, -PI * 0.5 + pct * TAU,
			32, Color(1.0, 0.75, 0.0, 0.9), 3.0)


	# Дебаг хітбоксів
	if C.DEBUG_HITBOX:
		# Хертбокс (синій) — власний collision rect
		var hb := Rect2(-enemy_size.x * 0.5, -enemy_size.y * 0.5, enemy_size.x, enemy_size.y)
		draw_rect(hb, Color(0.0, 0.6, 1.0, 0.15), true)
		draw_rect(hb, Color(0.0, 0.6, 1.0, 0.9), false)
		# Хітбокс атаки (червоний) — зона ураження
		var adir := 1 if facing_right else -1
		var arange := float(enemy_data.get("attack_range", 70.0))
		var ab := Rect2(adir * (enemy_size.x * 0.5), -enemy_size.y * 0.5,
			float(adir) * arange, enemy_size.y)
		if ab.size.x < 0:
			ab.position.x += ab.size.x
			ab.size.x = -ab.size.x
		draw_rect(ab, Color(1.0, 0.15, 0.15, 0.15), true)
		draw_rect(ab, Color(1.0, 0.15, 0.15, 0.9), false)

# ── Sprite-sheet відмалювання ──────────────────────────────────────────────
func _draw_sprite() -> void:
	# Визначаємо ключ анімації (attack0/1 — різні стилі удару)
	var anim_key := _k_anim
	# Фолбек: якщо анімація не завантажена — намагаємося idle
	var tex: Texture2D = _sheets.get(anim_key)
	if tex == null: tex = _sheets.get("idle")
	if tex == null: return

	var frame_count: int   = ANIM_FRAMES.get(anim_key, 1)
	var fps: int           = ANIM_FPS.get(anim_key, 10)
	var elapsed: int   = _frame - _anim_start_frame
	var raw_idx: int   = int(float(elapsed) / (60.0 / float(fps)))
	# Атак і defend — один раз (тримаємо останній кадр), решта — цикл
	var one_shot := _k_anim.begins_with("attack") or _k_anim == "defend"
	var frame_idx: int = mini(raw_idx, frame_count - 1) if one_shot else raw_idx % frame_count

	var fw: int   = tex.get_width() / frame_count   # ширина одного кадру
	var fh: int   = tex.get_height()                # висота одного кадру

	# Масштаб: KNIGHT_RENDER_H / BASE_FRAME_H — стабільний між анімаціями
	var sc: float = KNIGHT_RENDER_H / BASE_FRAME_H
	var dw: float = fw * sc
	var dh: float = fh * sc

	var src: Rect2 = Rect2(frame_idx * fw, 0, fw, fh)

	# Tint
	var tint := _base_tint
	if hit_flash > 0:
		tint = Color(1.0, 0.28, 0.28, 1.0)
	if anim_key == "death":
		var fade := maxf(0.0, 1.0 - float(_k_anim_t) / 55.0)
		tint = Color(_base_tint.r * 0.6, _base_tint.g * 0.35, _base_tint.b * 0.35, fade)
	if anim_key == "hurt":
		tint.a = 1.0 if _frame % 3 != 0 else 0.30

	# Ноги = низ collision box = +hh у локальних координатах
	# global_position = центр хітбоксу, тому спрайт зміщуємо вниз на hh
	var fy: float = enemy_size.y * 0.5
	# Фліп через src (як у гравця) — dest завжди центрований на x=0
	if not facing_right:
		src = Rect2(src.position.x + src.size.x, src.position.y, -src.size.x, src.size.y)
	draw_texture_rect_region(tex,
		Rect2(-dw * 0.5, fy - dh, dw, dh), src, tint, false)

# ── Запасний примітив (якщо спрайти не завантажені) ───────────────────────
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
