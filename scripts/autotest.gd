## autotest.gd — Автоматические тесты для проверки функциональности

extends Node

var test_results: Array = []
var test_log_path: String = "user://autotest_results.txt"

func _ready() -> void:
	print("🧪 AUTOTEST SUITE STARTED")
	print("")

	# Запускаем все тесты
	test_player_initialization()
	test_enemy_spawn()
	test_player_movement()
	test_player_attack()
	test_blocking()
	test_damage()

	# Сохраняем результаты
	_save_results()

	print("")
	print("✅ AUTOTEST COMPLETE")
	_print_summary()

func test_player_initialization() -> void:
	"""Тест инициализации игрока"""
	var player = get_tree().get_first_child_in_group("player") if has_meta("player") else null

	if player == null:
		_log_test("Player Initialization", false, "Player not found in scene")
		return

	var has_hp = player.has_meta("current_hp") or player.get("current_hp") != null
	var has_position = player.global_position != Vector2.ZERO

	_log_test("Player Initialization", has_hp and has_position,
		"HP: %s, Position: %v" % [player.get("current_hp", "?"), player.global_position])

func test_enemy_spawn() -> void:
	"""Тест спавна врагов"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var spawned = enemies.size() > 0

	_log_test("Enemy Spawn", spawned, "Enemies spawned: %d" % enemies.size())

func test_player_movement() -> void:
	"""Тест движения игрока"""
	# Это нельзя полностью протестировать в headless, но проверяем что функция существует
	var player = get_tree().root.get_child(0)
	if player.has_method("_update_movement"):
		_log_test("Player Movement", true, "Movement method exists")
	else:
		_log_test("Player Movement", false, "Movement method not found")

func test_player_attack() -> void:
	"""Тест атаки игрока"""
	var player = get_tree().root.get_child(0)
	if player.has_method("_on_attack_input"):
		_log_test("Player Attack", true, "Attack method exists")
	else:
		_log_test("Player Attack", false, "Attack method not found")

func test_blocking() -> void:
	"""Тест блока"""
	var player = get_tree().root.get_child(0)
	var has_blocking_var = player.get("is_blocking") != null
	_log_test("Player Block", has_blocking_var, "Blocking variable exists: %s" % has_blocking_var)

func test_damage() -> void:
	"""Тест получения урона"""
	var player = get_tree().root.get_child(0)
	if player.has_method("take_damage"):
		var initial_hp = player.get("current_hp", 0)
		player.take_damage(10)
		var final_hp = player.get("current_hp", 0)
		var damage_applied = initial_hp > final_hp
		_log_test("Damage System", damage_applied,
			"HP: %d → %d (damage applied: %s)" % [initial_hp, final_hp, damage_applied])
	else:
		_log_test("Damage System", false, "take_damage method not found")

func _log_test(name: String, passed: bool, details: String) -> void:
	"""Логирует результат теста"""
	var status = "✅ PASS" if passed else "❌ FAIL"
	var log_line = "%s | %s | %s" % [status, name, details]
	print(log_line)
	test_results.append({
		"name": name,
		"passed": passed,
		"details": details
	})

func _save_results() -> void:
	"""Сохраняем результаты в файл"""
	var file = FileAccess.open(test_log_path, FileAccess.WRITE)
	if file:
		for result in test_results:
			var line = "%s: %s - %s" % [
				"PASS" if result.passed else "FAIL",
				result.name,
				result.details
			]
			file.store_line(line)

func _print_summary() -> void:
	"""Выводим итоги тестирования"""
	var passed = test_results.filter(func(x): return x.passed).size()
	var total = test_results.size()
	var percentage = (passed * 100) / total if total > 0 else 0

	print("")
	print("📊 TEST SUMMARY: %d/%d passed (%d%%)" % [passed, total, percentage])
	print("Log saved to: %s" % test_log_path)
