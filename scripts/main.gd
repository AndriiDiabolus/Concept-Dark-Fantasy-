## main.gd — Sabbath: Among Life and Death
## Сайд-скроллер-платформер: фізика, камера, рівні, HUD

extends Node2D

#region Стан гри
var current_state: int = C.STATE.PLAY
var current_level: int = 0
var level_timer: float = 0.0
#endregion

#region Ноди
var player: Node2D
var camera: Camera2D
var enemies: Array[Node2D] = []
#endregion

#region Рівень
var current_platforms: Array = []
var level_width: float = 3600.0
var level_name: String = ""
#endregion

# ──────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("🎮 Sabbath v0.2 — Platformer")
	_setup_scene()
	load_level(0)
	# Захват фокуса окна — без этого клавиши не работают из редактора
	await get_tree().process_frame
	get_window().grab_focus()

# ──────────────────────────────────────────────
#region Ініціалізація сцени
func _setup_scene() -> void:
	# Гравець
	if get_node_or_null("Player") == null:
		player = Node2D.new()
		player.name = "Player"
		add_child(player)
		var ps = load("res://scripts/player.gd")
		player.set_script(ps)
		player.position = Vector2(150, C.GROUND_Y - 40)
		player.player_died.connect(_on_player_died)
	else:
		player = get_node("Player")

	# Камера
	if get_node_or_null("Camera2D") == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
		camera.make_current()
	else:
		camera = get_node("Camera2D")
	camera.global_position = Vector2(C.VIEWPORT_WIDTH / 2.0, C.VIEWPORT_HEIGHT / 2.0)
#endregion

# ──────────────────────────────────────────────
#region Завантаження рівня
func load_level(idx: int) -> void:
	current_level = idx
	level_timer = 0.0
	current_state = C.STATE.PLAY

	# Очищаємо ворогів
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

	var data := _get_level_data(idx)
	current_platforms = data["platforms"]
	level_width       = data["width"]
	level_name        = data["name"]

	# Ресет гравця
	if player:
		player.global_position = Vector2(150, C.GROUND_Y - C.PLAYER_SIZE.y * 0.5)
		player.velocity = Vector2.ZERO
		player.pressed_keys.clear()

	# Спавн ворогів
	for ed in data["enemies"]:
		_spawn_enemy(ed["type"], Vector2(ed["x"], ed["y"]))

	print("📍 Уровень %d: %s | Врагов: %d" % [idx + 1, level_name, enemies.size()])

func _get_level_data(idx: int) -> Dictionary:
	var gnd := float(C.GROUND_Y)
	match idx:
		0:  # Сечь — Руины
			return {
				"name": "Сечь — Руины",
				"width": 3600.0,
				"platforms": [
					Rect2(0,    gnd,       3600, 400),   # земля
					Rect2(320,  gnd - 140, 200,  22),
					Rect2(650,  gnd - 220, 170,  22),
					Rect2(960,  gnd - 150, 210,  22),
					Rect2(1280, gnd - 260, 180,  22),
					Rect2(1600, gnd - 180, 200,  22),
					Rect2(1950, gnd - 250, 170,  22),
					Rect2(2280, gnd - 160, 210,  22),
					Rect2(2650, gnd - 220, 180,  22),
					Rect2(3000, gnd - 150, 200,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 550,  "y": gnd - 34},
					{"type": "pehota",    "x": 950,  "y": gnd - 34},
					{"type": "pehota",    "x": 1350, "y": gnd - 34},
					{"type": "pehota",    "x": 1800, "y": gnd - 34},
					{"type": "pehota",    "x": 2300, "y": gnd - 34},
					{"type": "pehota",    "x": 2800, "y": gnd - 34},
					{"type": "pehota",    "x": 3200, "y": gnd - 34},
				],
			}
		1:  # Сожжённые Сёла
			return {
				"name": "Сожжённые Сёла",
				"width": 4200.0,
				"platforms": [
					Rect2(0,    gnd,       4200, 400),
					Rect2(250,  gnd - 160, 180,  22),
					Rect2(580,  gnd - 240, 160,  22),
					Rect2(900,  gnd - 160, 200,  22),
					Rect2(1250, gnd - 270, 180,  22),
					Rect2(1600, gnd - 190, 200,  22),
					Rect2(1980, gnd - 260, 170,  22),
					Rect2(2350, gnd - 180, 200,  22),
					Rect2(2750, gnd - 240, 180,  22),
					Rect2(3150, gnd - 170, 200,  22),
					Rect2(3600, gnd - 240, 180,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 400,  "y": gnd - 34},
					{"type": "musketeer", "x": 750,  "y": gnd - 34},
					{"type": "pehota",    "x": 1100, "y": gnd - 34},
					{"type": "piker",     "x": 1500, "y": gnd - 36},
					{"type": "musketeer", "x": 1900, "y": gnd - 34},
					{"type": "pehota",    "x": 2400, "y": gnd - 34},
					{"type": "piker",     "x": 2900, "y": gnd - 36},
					{"type": "musketeer", "x": 3400, "y": gnd - 34},
					{"type": "pehota",    "x": 3900, "y": gnd - 34},
				],
			}
		2:  # Подступы к Замку
			return {
				"name": "Подступы к Замку",
				"width": 4800.0,
				"platforms": [
					Rect2(0,    gnd,       4800, 400),
					Rect2(200,  gnd - 150, 160,  22),
					Rect2(480,  gnd - 260, 160,  22),
					Rect2(760,  gnd - 370, 160,  22),
					Rect2(1100, gnd - 190, 200,  22),
					Rect2(1450, gnd - 280, 180,  22),
					Rect2(1850, gnd - 190, 200,  22),
					Rect2(2250, gnd - 280, 170,  22),
					Rect2(2650, gnd - 190, 200,  22),
					Rect2(3100, gnd - 280, 180,  22),
					Rect2(3550, gnd - 190, 200,  22),
					Rect2(4050, gnd - 280, 180,  22),
					Rect2(4450, gnd - 190, 200,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 400,  "y": gnd - 34},
					{"type": "piker",     "x": 800,  "y": gnd - 36},
					{"type": "musketeer", "x": 1200, "y": gnd - 34},
					{"type": "pehota",    "x": 1650, "y": gnd - 34},
					{"type": "piker",     "x": 2100, "y": gnd - 36},
					{"type": "musketeer", "x": 2600, "y": gnd - 34},
					{"type": "pehota",    "x": 3100, "y": gnd - 34},
					{"type": "piker",     "x": 3600, "y": gnd - 36},
					{"type": "musketeer", "x": 4100, "y": gnd - 34},
					{"type": "pehota",    "x": 4500, "y": gnd - 34},
				],
			}
		3:  # Цитадель
			return {
				"name": "Цитадель",
				"width": 5500.0,
				"platforms": [
					Rect2(0,    gnd,       5500, 400),
					Rect2(280,  gnd - 170, 180,  22),
					Rect2(600,  gnd - 270, 160,  22),
					Rect2(950,  gnd - 180, 200,  22),
					Rect2(1350, gnd - 280, 180,  22),
					Rect2(1750, gnd - 190, 200,  22),
					Rect2(2150, gnd - 280, 170,  22),
					Rect2(2550, gnd - 190, 200,  22),
					Rect2(2950, gnd - 280, 180,  22),
					Rect2(3350, gnd - 190, 200,  22),
					Rect2(3750, gnd - 280, 180,  22),
					Rect2(4150, gnd - 190, 200,  22),
					Rect2(4550, gnd - 280, 180,  22),
					Rect2(4950, gnd - 190, 200,  22),
				],
				"enemies": [
					{"type": "pehota",    "x": 500,  "y": gnd - 34},
					{"type": "musketeer", "x": 850,  "y": gnd - 34},
					{"type": "piker",     "x": 1250, "y": gnd - 36},
					{"type": "pehota",    "x": 1700, "y": gnd - 34},
					{"type": "musketeer", "x": 2100, "y": gnd - 34},
					{"type": "piker",     "x": 2550, "y": gnd - 36},
					{"type": "pehota",    "x": 3000, "y": gnd - 34},
					{"type": "musketeer", "x": 3450, "y": gnd - 34},
					{"type": "piker",     "x": 3900, "y": gnd - 36},
					{"type": "pehota",    "x": 4350, "y": gnd - 34},
					{"type": "musketeer", "x": 4800, "y": gnd - 34},
					{"type": "piker",     "x": 5200, "y": gnd - 36},
				],
			}
		_:
			return {"name": "???", "width": 3600.0, "platforms": [Rect2(0, float(C.GROUND_Y), 3600, 400)], "enemies": []}
#endregion

# ──────────────────────────────────────────────
#region Спавн ворогів
func _spawn_enemy(type: String, pos: Vector2) -> void:
	var e := Node2D.new()
	e.name = "Enemy_%s_%d" % [type, enemies.size()]
	add_child(e)
	var es = load("res://scripts/enemy.gd")
	e.set_script(es)
	e.global_position = pos
	e.setup(type, player)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
#endregion

# ──────────────────────────────────────────────
#region Колізія (платформер)
func resolve_collision(pos: Vector2, char_size: Vector2, move_delta: Vector2) -> Dictionary:
	var new_pos   := pos + move_delta
	var hw        := char_size.x * 0.5
	var hh        := char_size.y * 0.5
	var on_ground := false

	for plat_v in current_platforms:
		var plat    := plat_v as Rect2
		var prev_bottom := pos.y + hh
		var new_bottom  := new_pos.y + hh
		var plat_top    := plat.position.y

		if prev_bottom <= plat_top + 2.0 and new_bottom >= plat_top:
			var left  := new_pos.x - hw
			var right := new_pos.x + hw
			if right > plat.position.x and left < plat.position.x + plat.size.x:
				new_pos.y = plat_top - hh
				on_ground = true

	# Межі рівня (горизонтальні)
	new_pos.x = clampf(new_pos.x, hw + 5.0, level_width - hw - 5.0)

	return {"pos": new_pos, "on_ground": on_ground}
#endregion

# ──────────────────────────────────────────────
#region Game Loop
func _process(delta: float) -> void:
	match current_state:
		C.STATE.PLAY:
			level_timer += delta
			_update_camera()
			_check_win()
		_:
			pass
	queue_redraw()

func _update_camera() -> void:
	if not player or not camera:
		return
	var half_w := C.VIEWPORT_WIDTH / 2.0
	var half_h := C.VIEWPORT_HEIGHT / 2.0
	var target_x := clampf(player.global_position.x, half_w, level_width - half_w)
	camera.global_position.x = lerpf(camera.global_position.x, target_x, 0.14)
	camera.global_position.y = half_h

func _check_win() -> void:
	var alive_count := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive:
			alive_count += 1
	if alive_count == 0 and not enemies.is_empty():
		current_state = C.STATE.WON
		get_tree().paused = true
#endregion

# ──────────────────────────────────────────────
#region Ввід
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode

	# Системні клавіші
	if key == KEY_ESCAPE:
		if current_state == C.STATE.PAUSE:
			get_tree().paused = false
			current_state = C.STATE.PLAY
		elif current_state == C.STATE.PLAY:
			get_tree().paused = true
			current_state = C.STATE.PAUSE
		return
	if key == KEY_ENTER:
		if current_state == C.STATE.LOST:
			get_tree().paused = false
			load_level(current_level)
		elif current_state == C.STATE.WON:
			get_tree().paused = false
			var next := current_level + 1
			if next < 4:
				load_level(next)
			else:
				load_level(0)  # повтор з початку
		return

	# Передаємо гравцеві
	if not player or current_state != C.STATE.PLAY:
		return
	if event.pressed:
		player.pressed_keys[key] = true
		if not event.echo:
			if key == KEY_W:
				player.do_jump()
			elif key == KEY_SPACE and not player.is_blocking:
				player.do_attack()
			elif key == KEY_V:
				player.do_obsession()
	else:
		player.pressed_keys.erase(key)
#endregion

# ──────────────────────────────────────────────
#region Колбеки
func _on_player_died() -> void:
	current_state = C.STATE.LOST
	get_tree().paused = true

func _on_enemy_died(enemy: Node2D) -> void:
	enemies.erase(enemy)
#endregion

# ──────────────────────────────────────────────
#region Відмалювання
func _draw() -> void:
	var cx := camera.global_position.x if camera else C.VIEWPORT_WIDTH / 2.0
	var ox := cx - C.VIEWPORT_WIDTH / 2.0  # ліва межа камери у світових координатах
	var oy := 0.0

	_draw_background(ox, oy)
	_draw_platforms()
	_draw_hud(ox, oy)

	match current_state:
		C.STATE.PAUSE: _draw_overlay(ox, oy, "ПАУЗА",   Color(0.0, 0.0, 0.0, 0.55), "Нажми ESC чтобы продолжить")
		C.STATE.LOST:  _draw_overlay(ox, oy, "ГИБЕЛЬ",  Color(0.35, 0.0, 0.0, 0.65), "Нажми Enter чтобы повторить")
		C.STATE.WON:   _draw_overlay(ox, oy, "ПОБЕДА",  Color(0.0, 0.18, 0.0, 0.60), "Нажми Enter для следующего уровня")

func _draw_background(ox: float, _oy: float) -> void:
	var vw := float(C.VIEWPORT_WIDTH)
	var vh := float(C.VIEWPORT_HEIGHT)

	# Небо — темний градієнт (Castlevania/Berserk атмосфера)
	draw_rect(Rect2(ox, 0, vw, vh * 0.55), Color(0.03, 0.02, 0.08))
	draw_rect(Rect2(ox, vh * 0.35, vw, vh * 0.40), Color(0.07, 0.03, 0.04))

	# Місяць
	var moon_x := ox + vw * 0.80
	draw_circle(Vector2(moon_x, 85), 48, Color(0.92, 0.88, 0.78, 0.18))
	draw_circle(Vector2(moon_x, 85), 42, Color(0.95, 0.92, 0.82))

	# Далекий силует руїн (паралакс 0.18)
	var px := ox * 0.18
	var ruin_color := Color(0.07, 0.04, 0.06)
	for i in range(8):
		var rx := px + i * 480.0 + fmod(float(i) * 137.0, 200.0)
		var rh := 120.0 + fmod(float(i) * 53.0, 80.0)
		draw_rect(Rect2(rx, float(C.GROUND_Y) - rh, 60, rh), ruin_color)
		# Вікна
		draw_rect(Rect2(rx + 10, float(C.GROUND_Y) - rh + 20, 12, 16), Color(0.20, 0.14, 0.08, 0.6))
		draw_rect(Rect2(rx + 38, float(C.GROUND_Y) - rh + 20, 12, 16), Color(0.20, 0.14, 0.08, 0.6))

	# Середній план — дерева/колони (паралакс 0.45)
	var mx := ox * 0.45
	var tree_c := Color(0.06, 0.04, 0.05)
	for i in range(12):
		var tx := mx + i * 320.0 + fmod(float(i) * 97.0, 160.0)
		var th := 80.0 + fmod(float(i) * 41.0, 60.0)
		draw_rect(Rect2(tx, float(C.GROUND_Y) - th, 18, th), tree_c)
		draw_circle(Vector2(tx + 9, float(C.GROUND_Y) - th - 20), 28, tree_c)

	# Туман/серпанок над землею
	draw_rect(Rect2(ox, float(C.GROUND_Y) - 55, vw, 55), Color(0.12, 0.06, 0.08, 0.28))
	draw_rect(Rect2(ox, float(C.GROUND_Y) - 30, vw, 30), Color(0.15, 0.08, 0.10, 0.18))

func _draw_platforms() -> void:
	for plat_v in current_platforms:
		var plat    := plat_v as Rect2
		var is_ground := plat.size.y > 50  # земля vs платформа

		if is_ground:
			# Земля — темний камінь
			draw_rect(plat, Color(0.14, 0.10, 0.08))
			draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 6), Color(0.22, 0.16, 0.12))
			# Текстура тріщин (псевдо)
			var nx := int(plat.size.x / 80)
			for i in range(nx):
				var cx2 := plat.position.x + i * 80 + 30
				draw_line(Vector2(cx2, plat.position.y + 8), Vector2(cx2 + 12, plat.position.y + 20), Color(0.10, 0.07, 0.05), 1.0)
		else:
			# Платформа — кам'яна плита
			draw_rect(plat, Color(0.24, 0.18, 0.14))
			# Верхній край (яскравіший)
			draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 4), Color(0.36, 0.27, 0.20))
			# Бічні тіні
			draw_rect(Rect2(plat.position.x, plat.position.y, 4, plat.size.y), Color(0.18, 0.13, 0.10))
			draw_rect(Rect2(plat.position.x + plat.size.x - 4, plat.position.y, 4, plat.size.y), Color(0.18, 0.13, 0.10))

func _draw_hud(ox: float, oy: float) -> void:
	if not player:
		return
	var font := ThemeDB.fallback_font
	var pad  := 24.0

	# === HP ПОЛОСКА ===
	var hp_pct  := float(player.current_hp) / float(C.PLAYER_HP_MAX)
	var bar_w   := 220.0
	var bar_h   := 18.0
	var bar_x   := ox + pad
	var bar_y   := oy + pad

	draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), Color(0.04, 0.03, 0.06))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.06, 0.06))
	draw_rect(Rect2(bar_x, bar_y, bar_w * hp_pct, bar_h), Color(0.78, 0.14, 0.14))
	draw_string(font, Vector2(bar_x + 4, bar_y + 13), "ХП %d / %d" % [player.current_hp, C.PLAYER_HP_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# === ШКАЛА ОДЕРЖИМОСТІ ===
	var obs_max := float(C.PLAYER_OBSESSION_LEVEL_THRESHOLD * C.PLAYER_OBSESSION_LEVELS)
	var obs_pct: float = float(player.obsession_fill) / obs_max
	var ob_y    := bar_y + bar_h + 8
	var ob_w    := bar_w

	draw_rect(Rect2(bar_x - 2, ob_y - 2, ob_w + 4, 12), Color(0.04, 0.03, 0.06))
	draw_rect(Rect2(bar_x, ob_y, ob_w, 10), Color(0.12, 0.06, 0.18))
	draw_rect(Rect2(bar_x, ob_y, ob_w * obs_pct, 10), Color(0.65, 0.10, 1.0))
	# Мітки рівнів одержимості
	for i in range(1, C.PLAYER_OBSESSION_LEVELS):
		var lx := bar_x + ob_w * float(i) / float(C.PLAYER_OBSESSION_LEVELS)
		draw_rect(Rect2(lx - 1, ob_y, 2, 10), Color(0.04, 0.03, 0.06))
	draw_string(font, Vector2(bar_x + 4, ob_y + 9), "Одержимость  Уровень %d / %d" % [player.obsession_level, C.PLAYER_OBSESSION_LEVELS], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.80, 0.60, 1.0))

	# === РІВЕНЬ ТА ЧАС ===
	var mins := int(level_timer) / 60
	var secs := int(level_timer) % 60
	var time_str := "%02d:%02d" % [mins, secs]
	draw_string(font, Vector2(ox + float(C.VIEWPORT_WIDTH) - 160, oy + 36), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.80, 0.78, 0.65))
	draw_string(font, Vector2(ox + float(C.VIEWPORT_WIDTH) / 2.0 - 120, oy + 36), level_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.70, 0.60, 0.50))

	# === ПОДСКАЗКИ (только уровень 1) ===
	if current_level == 0 and level_timer < 12.0:
		draw_string(font, Vector2(ox + float(C.VIEWPORT_WIDTH) / 2.0 - 180, oy + float(C.VIEWPORT_HEIGHT) - 50),
			"A/D — движение   W — прыжок   Space — атака   R — блок   V — одержимость",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.72, 0.60, 0.9))

	# === DEBUG (временно) ===
	var a := Input.is_key_pressed(KEY_A)
	var d := Input.is_key_pressed(KEY_D)
	var w := Input.is_key_pressed(KEY_W)
	var dbg := "A:%s D:%s W:%s | кадр:%d" % [
		"▮" if a else "▯", "▮" if d else "▯", "▮" if w else "▯", int(level_timer * 60)
	]
	draw_string(font, Vector2(ox + 24, oy + 80), dbg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.0, 0.9))

func _draw_overlay(ox: float, oy: float, title: String, bg: Color, hint: String) -> void:
	var font := ThemeDB.fallback_font
	var vw   := float(C.VIEWPORT_WIDTH)
	var vh   := float(C.VIEWPORT_HEIGHT)
	draw_rect(Rect2(ox, oy, vw, vh), bg)

	var tx := ox + vw / 2.0 - 160
	var ty := oy + vh / 2.0
	draw_string(font, Vector2(tx, ty - 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color.WHITE)
	draw_string(font, Vector2(tx, ty + 36), hint,  HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.80, 0.78, 0.65))
#endregion
