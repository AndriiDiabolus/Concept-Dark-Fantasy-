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
var dash_cooldown: float = 0.0
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_dir: int = 0
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
var _prev_w: bool = false
var _prev_space: bool = false
var _prev_v: bool = false
var _prev_shift_a: bool = false
var _prev_shift_d: bool = false
#endregion

#region Анімація
var _frame: int = 0
# Спрайт демона (Nightborne)
var _nb_tex: Texture2D = null
var _nb_anim: String = "idle"
var _nb_anim_frame: int = 0
var _nb_anim_timer: float = 0.0
var _nb_hurt_t: float = 0.0

const NB_ANIMS: Dictionary = {
	"idle":   {"row": 0, "frames": 9,  "fps": 10.0},
	"run":    {"row": 1, "frames": 6,  "fps": 12.0},
	"attack": {"row": 2, "frames": 12, "fps": 20.0},
	"hurt":   {"row": 3, "frames": 5,  "fps": 14.0},
	"death":  {"row": 4, "frames": 23, "fps": 10.0},
}
const NB_FRAME_W: int = 80
const NB_FRAME_H: int = 80
const NB_SCALE: float  = 1.8
#endregion

signal player_died
signal hp_changed(hp)

func _ready() -> void:
	set_process(true)
	_nb_tex = load("res://assets/sprites/nightborne.png")
	print("🗡️ Яромир готов | HP:%d" % current_hp)

func _process(delta: float) -> void:
	if not is_alive:
		return
	_update_timers(delta)

	# Одиночные нажатия через Input API (работает в отдельном окне)
	var cur_w     := Input.is_key_pressed(KEY_W)
	var cur_space := Input.is_key_pressed(KEY_SPACE)
	var cur_v     := Input.is_key_pressed(KEY_V)
	var cur_shift := Input.is_key_pressed(KEY_SHIFT)
	var cur_a     := Input.is_key_pressed(KEY_A)  or pressed_keys.has(KEY_A)
	var cur_d     := Input.is_key_pressed(KEY_D)  or pressed_keys.has(KEY_D)
	var cur_sa    := cur_shift and cur_a
	var cur_sd    := cur_shift and cur_d
	if cur_w     and not _prev_w:     do_jump()
	if cur_space and not _prev_space: do_attack()
	if cur_v     and not _prev_v:     do_obsession()
	if cur_sa    and not _prev_shift_a: do_dash(-1)
	if cur_sd    and not _prev_shift_d: do_dash(1)
	_prev_w = cur_w; _prev_space = cur_space; _prev_v = cur_v
	_prev_shift_a = cur_sa; _prev_shift_d = cur_sd

	_handle_input()
	_apply_gravity(delta)
	_apply_movement(delta)
	_update_obsession(delta)
	if obsession_active:
		_update_nb_anim(delta)
	if current_hp <= 0 and is_alive:
		is_alive = false
		player_died.emit()
	_frame += 1
	queue_redraw()

#region Ввод
func _handle_input() -> void:
	is_blocking = (Input.is_key_pressed(KEY_R) or pressed_keys.has(KEY_R)) and is_on_ground and not obsession_active
#endregion

#region Физика и движение
func _apply_gravity(delta: float) -> void:
	if not is_on_ground:
		velocity.y += C.GRAVITY * delta
		velocity.y = minf(velocity.y, C.TERMINAL_VELOCITY)

func _apply_movement(delta: float) -> void:
	if is_dashing:
		# Рывок: фиксированная скорость, нельзя прервать
		velocity.x = dash_dir * C.PLAYER_DASH_SPEED
		is_moving = true
	else:
		var h := 0
		if Input.is_key_pressed(KEY_D) or pressed_keys.has(KEY_D): h += 1
		if Input.is_key_pressed(KEY_A) or pressed_keys.has(KEY_A): h -= 1

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

func do_dash(dir: int) -> void:
	if dash_cooldown > 0 or is_blocking or is_dashing:
		return
	is_dashing = true
	dash_dir = dir
	dash_timer = C.PLAYER_DASH_DURATION
	dash_cooldown = C.PLAYER_DASH_COOLDOWN
	facing_right = dir > 0
	print("💨 Рывок %s" % ("вправо" if dir > 0 else "влево"))
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
	print("💜 ОДЕРЖИМОСТЬ активирована! Стадия деградации: %d" % degrade_stage)

func take_damage(dmg: int) -> void:
	if not is_alive or is_recovering or is_dashing:
		return
	if randf() < C.PLAYER_DODGE_CHANCE:
		print("✨ Уклонение!")
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
	if dash_cooldown > 0:   dash_cooldown   -= delta
	if _nb_hurt_t > 0:      _nb_hurt_t      -= delta
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
#endregion

#region Анімація Nightborne
func _update_nb_anim(delta: float) -> void:
	# Визначаємо потрібну анімацію
	var want: String
	if attack_timer > 0:
		want = "attack"
	elif _nb_hurt_t > 0:
		want = "hurt"
	elif is_moving and is_on_ground:
		want = "run"
	else:
		want = "idle"

	# Скидаємо кадр при зміні анімації
	if want != _nb_anim:
		_nb_anim = want
		_nb_anim_frame = 0
		_nb_anim_timer = 0.0

	# Крокуємо по кадрах
	var anim: Dictionary = NB_ANIMS[_nb_anim]
	_nb_anim_timer += delta
	var spf: float = 1.0 / float(anim["fps"])
	while _nb_anim_timer >= spf:
		_nb_anim_timer -= spf
		_nb_anim_frame += 1
		if _nb_anim_frame >= int(anim["frames"]):
			_nb_anim_frame = 0
			# attack не зациклюємо — повертаємось в idle
			if _nb_anim == "attack":
				_nb_anim = "idle"
				break
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

	if obsession_active:
		_draw_demon()
	else:
		_draw_cossack()

# ── Нормальний стан — Козак ──────────────────────────────
func _draw_cossack() -> void:
	var dir   := 1.0 if facing_right else -1.0
	var alpha := 0.4 if (is_recovering and _frame % 8 < 4) else 1.0
	if is_dashing:
		alpha = 0.7 if (_frame % 4 < 2) else 1.0

	var skin  := Color(0.82, 0.65, 0.46, alpha)
	var armor := Color(0.20, 0.16, 0.10, alpha)
	var cloth := Color(0.40, 0.30, 0.18, alpha)
	var sword := Color(0.80, 0.78, 0.68, alpha)
	var leg_a := sin(_frame * 0.35) * 9.0 if (is_moving and is_on_ground) else 0.0
	var bob   := absf(sin(_frame * 0.35)) * 1.5 if (is_moving and is_on_ground) else 0.0

	# Ноги + чоботи
	draw_rect(Rect2(-10, 14 + leg_a * 0.5, 9, 22), armor)
	draw_rect(Rect2(1,   14 - leg_a * 0.5, 9, 22), armor)
	draw_rect(Rect2(-11, 30 + leg_a * 0.5, 11, 8), Color(0.14, 0.09, 0.05, alpha))
	draw_rect(Rect2(0,   30 - leg_a * 0.5, 11, 8), Color(0.14, 0.09, 0.05, alpha))
	# Тулуб
	draw_rect(Rect2(-13, -14, 26, 30), armor)
	draw_rect(Rect2(-11, -12, 22, 24), cloth)
	draw_rect(Rect2(-13, 13, 26, 5), Color(0.24, 0.17, 0.07, alpha))
	# Голова
	draw_circle(Vector2(0, -28 - bob), 12, skin)
	draw_rect(Rect2(-6, -26 - bob, 12, 3), Color(0.18, 0.09, 0.04, alpha))
	draw_circle(Vector2(5.0 * dir, -30 - bob), 2.5, Color(0.08, 0.04, 0.02, alpha))
	draw_rect(Rect2(-10, -44 - bob, 20, 14), Color(0.08, 0.06, 0.04, alpha))
	draw_rect(Rect2(-8,  -46 - bob, 16,  5), Color(0.52, 0.10, 0.10, alpha))
	# Рука + зброя
	draw_rect(Rect2(dir * 10 - 5, -10, 10, 18), skin)
	if attack_timer > 0:
		draw_line(Vector2(dir * 14, -8), Vector2(dir * (14 + C.PLAYER_ATTACK_RANGE * 0.85), -28), sword, 5.0)
	else:
		draw_line(Vector2(dir * 14, 5), Vector2(dir * 20, 22), sword, 4.0)
	# Щит
	if is_blocking:
		draw_circle(Vector2(-dir * 20, 0), 16, Color(0.28, 0.38, 0.85, 0.88))
		draw_circle(Vector2(-dir * 20, 0), 13, Color(0.18, 0.25, 0.65, 0.88))
		draw_rect(Rect2(-dir * 23 - 3, -6, 6, 12), Color(0.85, 0.78, 0.40, 0.9))
		draw_rect(Rect2(-dir * 26, -3, 12, 6),     Color(0.85, 0.78, 0.40, 0.9))
	# Деградація — фіолетова рука (передвісник)
	if degrade_stage >= 1:
		draw_rect(Rect2(-dir * 14, -8, 10, 16), Color(0.65, 0.1, 0.9, 0.45))
	# Рывок
	if is_dashing:
		var dp := sin(_frame * 0.5) * 0.3 + 0.7
		draw_circle(Vector2.ZERO, 38, Color(0.2, 0.6, 1.0, dp * 0.28))
		draw_circle(Vector2.ZERO, 55, Color(0.1, 0.4, 0.9, dp * 0.10))
	# HP
	var hp_pct := float(current_hp) / float(C.PLAYER_HP_MAX)
	draw_rect(Rect2(-22, -56, 44, 5),          Color(0.10, 0.10, 0.10))
	draw_rect(Rect2(-22, -56, 44 * hp_pct, 5), Color(0.15, 0.85, 0.30))

# ── Демонічний стан — Nightborne спрайт ──────────────────
func _draw_demon() -> void:
	var alpha := 0.4 if (is_recovering and _frame % 8 < 4) else 1.0
	if is_dashing:
		alpha = 0.7 if (_frame % 4 < 2) else 1.0
	var pulse  := sin(_frame * 0.14) * 0.4 + 0.6

	# ── Аура під спрайтом ──
	draw_circle(Vector2.ZERO, 72, Color(0.05, 0.0, 0.12, pulse * 0.30 * alpha))
	draw_circle(Vector2.ZERO, 48, Color(0.12, 0.0, 0.22, pulse * 0.38 * alpha))

	# ── Спрайт Nightborne ──
	if _nb_tex != null:
		var anim: Dictionary = NB_ANIMS[_nb_anim]
		var col: int = _nb_anim_frame % int(anim["frames"])
		var src  := Rect2(
			col * NB_FRAME_W,
			int(anim["row"]) * NB_FRAME_H,
			NB_FRAME_W,
			NB_FRAME_H
		)
		# Фліп при повороті вліво
		if not facing_right:
			src.position.x += src.size.x
			src.size.x = -src.size.x

		var sw := NB_FRAME_W * NB_SCALE
		var sh := NB_FRAME_H * NB_SCALE
		# Центрування: ноги на y=+36 (половина хітбоксу)
		var dest := Rect2(-sw * 0.5, -sh + 36.0, sw, sh)
		draw_texture_rect_region(_nb_tex, dest, src, Color(1, 1, 1, alpha))

	# ── Орбітальні частки поверх спрайта ──
	for pi2 in range(5):
		var pa := float(pi2) / 5.0 * TAU + float(_frame) * 0.09
		var pr := 46.0 + sin(float(_frame) * 0.15 + float(pi2)) * 7.0
		draw_circle(Vector2(cos(pa)*pr, sin(pa)*pr*0.45),
			2.5, Color(0.65, 0.0, 0.95, pulse * 0.60 * alpha))

	# ── Рывок ──
	if is_dashing:
		var dp := sin(_frame * 0.5) * 0.3 + 0.7
		draw_circle(Vector2.ZERO, 42, Color(0.4, 0.0, 0.8, dp * 0.32))
		draw_circle(Vector2.ZERO, 60, Color(0.2, 0.0, 0.6, dp * 0.14))

	# ── HP (фіолетовий у демон-режимі) ──
	var hp_pct := float(current_hp) / float(C.PLAYER_HP_MAX)
	draw_rect(Rect2(-22, -82, 44, 5),          Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(-22, -82, 44 * hp_pct, 5), Color(0.55, 0.0, 0.85))
#endregion
