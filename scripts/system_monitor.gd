## system_monitor.gd — Полный мониторинг состояния проекта
## Логирует всё в JSON для быстрой диагностики

extends Node

var report_path: String = "user://system_report.json"
var report: Dictionary = {}

func _ready() -> void:
	print("📊 System Monitor initialized")

	# Инициализируем отчёт
	report = {
		"timestamp": Time.get_ticks_msec(),
		"godot_version": Engine.get_version_info().string,
		"project_name": ProjectSettings.get_setting("application/config/name"),
		"errors": [],
		"warnings": [],
		"performance": {},
		"scenes": {},
		"nodes_count": 0,
	}

	_update_report()
	_save_report()

func _process(_delta: float) -> void:
	# Обновляем отчёт каждые 5 секунд
	if Engine.get_process_frames() % 300 == 0:
		_update_report()
		_save_report()

func _update_report() -> void:
	"""Собираем информацию о системе"""

	# Производительность
	report["performance"] = {
		"fps": Engine.get_frames_per_second(),
		"frame_count": Engine.get_process_frames(),
		"memory_used_mb": OS.get_static_memory_usage() / 1024.0 / 1024.0,
		"memory_peak_mb": OS.get_static_memory_peak_usage() / 1024.0 / 1024.0,
	}

	# Информация о сцене
	var current_scene = get_tree().current_scene
	if current_scene:
		report["scenes"] = {
			"current": current_scene.name,
			"nodes_count": _count_nodes(current_scene),
			"tree_string": current_scene.get_tree().get_edited_scene_root().name if current_scene.get_tree().get_edited_scene_root() else "unknown",
		}

	# Время обновления
	report["last_update"] = Time.get_ticks_msec()

func _count_nodes(node: Node) -> int:
	"""Рекурсивно считаем все узлы"""
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _save_report() -> void:
	"""Сохраняем отчёт в JSON"""
	var json_string = JSON.stringify(report)

	var file = FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		print("✅ System report saved to: %s" % report_path)
	else:
		print("❌ Could not save system report")

func add_error(title: String, message: String) -> void:
	"""Добавляем ошибку в отчёт"""
	report["errors"].append({
		"time": Time.get_ticks_msec(),
		"title": title,
		"message": message,
	})
	print("❌ ERROR [%s]: %s" % [title, message])

func add_warning(title: String, message: String) -> void:
	"""Добавляем warning в отчёт"""
	report["warnings"].append({
		"time": Time.get_ticks_msec(),
		"title": title,
		"message": message,
	})
	print("⚠️ WARNING [%s]: %s" % [title, message])

func get_report() -> Dictionary:
	"""Возвращаем текущий отчёт"""
	return report
