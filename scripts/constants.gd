## constants.gd — Sabbath: Among Life and Death
## Autoload C — глобальні константи гри

extends Node

#region Дебаг
const DEBUG_HITBOX: bool = true
#endregion

#region Фізика
const GRAVITY: float = 950.0
const JUMP_FORCE: float = -540.0
const TERMINAL_VELOCITY: float = 1400.0
#endregion

#region Дисплей
const VIEWPORT_WIDTH: int = 1600
const VIEWPORT_HEIGHT: int = 900
const GROUND_Y: int = 600
#endregion

#region Гравець
const PLAYER_SPEED: float = 230.0
const PLAYER_HP_MAX: int = 150
const PLAYER_SIZE: Vector2 = Vector2(40, 72)
const PLAYER_ATTACK_DAMAGE: Array = [8, 8, 14]
const PLAYER_ATTACK_SPEED: Array = [0.30, 0.35, 0.50]
const PLAYER_ATTACK_RANGE: float = 95.0
const PLAYER_BLOCK_DAMAGE_REDUCTION: float = 0.35
const PLAYER_DODGE_CHANCE: float = 0.05
const PLAYER_OBSESSION_DURATION: float = 20.0
const PLAYER_OBSESSION_COOLDOWN: float = 120.0
const PLAYER_OBSESSION_RECOVERY: float = 2.0
const PLAYER_OBSESSION_FILL_PER_ATTACK: float = 8.0   # ~12 ударов на уровень
const PLAYER_OBSESSION_FILL_PER_DAMAGE: float = 5.0   # урон тоже заряжает
const PLAYER_OBSESSION_LEVELS: int = 3
const PLAYER_OBSESSION_LEVEL_THRESHOLD: float = 100.0
const PLAYER_DASH_SPEED: float = 650.0
const PLAYER_DASH_DURATION: float = 0.18
const PLAYER_DASH_INVINCIBLE: float = 0.18
const PLAYER_DASH_COOLDOWN: float = 1.2
#endregion

#region Вороги
const ENEMY_TYPES: Dictionary = {
	"pehota": {
		"name": "Пехота",
		"hp": 30, "damage": 6,
		"speed": 105.0, "attack_range": 60.0, "chase_range": 360.0,
		"attack_cooldown": 1.2, "size": Vector2(38, 68),
		"sprite_dir": "knight_weak", "tint": Color(1.0, 1.0, 1.0),
	},
	"musketeer": {
		"name": "Мушкетёр",
		"hp": 50, "damage": 15,
		"speed": 60.0, "attack_range": 380.0, "chase_range": 460.0,
		"attack_cooldown": 3.5, "size": Vector2(38, 68),
		"sprite_dir": "knight_weak", "tint": Color(0.70, 0.82, 1.0),
	},
	"piker": {
		"name": "Пикинёр",
		"hp": 80, "damage": 11,
		"speed": 55.0, "attack_range": 125.0, "chase_range": 240.0,
		"attack_cooldown": 2.2, "size": Vector2(42, 72),
		"sprite_dir": "knight_medium", "tint": Color(1.0, 1.0, 1.0),
	},

	# ── Рицарі: 3 рівні складності ──────────────────────────────────────
	"knight_weak": {
		"name": "Рицар-новачок",
		"hp": 60, "damage": 10,
		"speed": 88.0, "attack_range": 70.0, "chase_range": 380.0,
		"attack_cooldown": 2.2, "size": Vector2(42, 76),
		"sprite_dir": "knight_weak",
		"tint": Color(1.0, 1.0, 1.0),
	},
	"knight_medium": {
		"name": "Рицар",
		"hp": 140, "damage": 22,
		"speed": 105.0, "attack_range": 75.0, "chase_range": 420.0,
		"attack_cooldown": 1.8, "size": Vector2(44, 78),
		"sprite_dir": "knight_medium",
		"tint": Color(1.0, 1.0, 1.0),
	},
	"knight_strong": {
		"name": "Рицар-чемпіон",
		"hp": 260, "damage": 40,
		"speed": 78.0, "attack_range": 80.0, "chase_range": 360.0,
		"attack_cooldown": 1.5, "size": Vector2(48, 82),
		"sprite_dir": "knight_strong",
		"tint": Color(1.0, 1.0, 1.0),
	},
}
#endregion

#region Стани
enum STATE { SPLASH, MENU, PLAY, PAUSE, LOST, WON }
#endregion
