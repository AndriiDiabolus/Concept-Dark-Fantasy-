## main.gd — Sabbath - among life and death
## Main game controller
## Handles: game states, level management, UI, events

extends Node2D

## Game State
var current_state: int = C.STATE.SPLASH
var current_level: int = 0
var player_hp: int = C.PLAYER_HP_MAX

## References
var player: Node2D
var camera: Camera2D
var ui_layer: CanvasLayer

## Lifecycle
func _ready() -> void:
	_setup_input()
	_init_game()

func _process(delta: float) -> void:
	match current_state:
		C.STATE.SPLASH:
			pass
		C.STATE.PLAY:
			_update_play(delta)
		C.STATE.PAUSE:
			pass
		C.STATE.BOSS:
			_update_boss(delta)
		C.STATE.LOST:
			pass
		C.STATE.WON:
			pass
		C.STATE.CUTSCENE:
			pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_tree().paused = !get_tree().paused
			current_state = C.STATE.PAUSE if get_tree().paused else C.STATE.PLAY

## Initialization
func _setup_input() -> void:
	# Create input map if needed
	if not InputMap.has_action(C.INPUT_MOVE_UP):
		InputMap.add_action(C.INPUT_MOVE_UP)
		InputMap.action_add_key_event(C.INPUT_MOVE_UP, InputEventKey.new() if KEY_W else KEY_W)

func _init_game() -> void:
	print("🎮 Sabbath - among life and death v0.1.0")
	print("Loading Level 1...")
	load_level(0)

## Level Management
func load_level(level_idx: int) -> void:
	current_level = level_idx
	var level_data = C.LEVELS[level_idx]
	print("📍 Loading: %s" % level_data.name)

	# TODO: Load level scene
	# TODO: Spawn player
	# TODO: Spawn enemy waves

	current_state = C.STATE.PLAY

## Game Updates
func _update_play(delta: float) -> void:
	# TODO: Update game logic per frame
	pass

func _update_boss(delta: float) -> void:
	# TODO: Update boss fight logic
	pass

## Player Callbacks
func on_player_attack_hit(damage: int) -> void:
	print("💥 Attack hit! Damage: %d" % damage)

func on_player_took_damage(damage: int) -> void:
	player_hp -= damage
	print("❤️ Player HP: %d" % player_hp)
	if player_hp <= 0:
		_on_player_died()

func _on_player_died() -> void:
	print("💀 Game Over!")
	current_state = C.STATE.LOST

## Debug
func _print_game_state() -> void:
	print("=== GAME STATE ===")
	print("Level: %d" % current_level)
	print("State: %s" % C.STATE.keys()[current_state])
	print("Player HP: %d / %d" % [player_hp, C.PLAYER_HP_MAX])
