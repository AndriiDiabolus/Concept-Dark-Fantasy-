## debug_logger.gd — Автолог всех ошибок, warnings и сообщений
## Для быстрой отладки — весь вывод пишется в файл
## Использование: просто добавить в autoload как DebugLogger

extends Node

var log_file: FileAccess
var log_path: String = "user://debug.log"

func _ready() -> void:
	# Открываем файл на запись (перезаписываем каждый запуск)
	log_file = FileAccess.open(log_path, FileAccess.WRITE)

	if log_file == null:
		print("ERROR: Could not open log file at %s" % log_path)
		return

	print("✅ Debug logger started. Log file: %s" % log_path)
	log("✅ Debug logger started")
	log("Timestamp: %s" % Time.get_ticks_msec())
	log("")

	# Подключаем сигнал ошибок
	get_tree().node_added.connect(_on_node_added)

func _process(_delta: float) -> void:
	# Флушим файл каждый кадр чтобы видеть в реальном времени
	if log_file:
		log_file.flush()

func log(message: String) -> void:
	"""Логирует сообщение в файл"""
	if log_file:
		log_file.store_line("[%d] %s" % [Time.get_ticks_msec(), message])

func log_error(title: String, message: String) -> void:
	"""Логирует ошибку"""
	var formatted = "❌ ERROR [%s]: %s" % [title, message]
	print(formatted)
	log(formatted)

func log_warning(title: String, message: String) -> void:
	"""Логирует warning"""
	var formatted = "⚠️ WARNING [%s]: %s" % [title, message]
	print(formatted)
	log(formatted)

func log_info(title: String, message: String) -> void:
	"""Логирует информацию"""
	var formatted = "ℹ️ INFO [%s]: %s" % [title, message]
	print(formatted)
	log(formatted)

func log_debug(title: String, message: String) -> void:
	"""Логирует отладку"""
	var formatted = "🔧 DEBUG [%s]: %s" % [title, message]
	print(formatted)
	log(formatted)

func _on_node_added(node: Node) -> void:
	"""Логирует добавленные узлы (первые 100)"""
	pass  # Можно расширить если нужно

func get_log_content() -> String:
	"""Возвращает весь контент логов"""
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file:
		return file.get_as_text()
	return ""

func clear_log() -> void:
	"""Очищает лог"""
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file:
		log("✅ Log cleared")
