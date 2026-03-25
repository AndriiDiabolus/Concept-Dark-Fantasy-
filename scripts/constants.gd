## constants.gd — Sabbath: Among Life and Death
## Autoload C — глобальні константи гри

extends Node

#region Фізика
const GRAVITY: float = 950.0
const JUMP_FORCE: float = -540.0
const TERMINAL_VELOCITY: float = 1400.0
#endregion

#region Дисплей
const VIEWPORT_WIDTH: int = 1920
const VIEWPORT_HEIGHT: int = 1080
const GROUND_Y: int = 700
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
#endregion

#region Вороги
const ENEMY_TYPES: Dictionary = {
	"pehota": {
		"name": "Пехота",
		"hp": 30, "damage": 6,
		"speed": 105.0, "attack_range": 60.0, "chase_range": 360.0,
		"attack_cooldown": 1.2, "size": Vector2(38, 68),
	},
	"musketeer": {
		"name": "Мушкетёр",
		"hp": 50, "damage": 15,
		"speed": 60.0, "attack_range": 380.0, "chase_range": 460.0,
		"attack_cooldown": 3.5, "size": Vector2(38, 68),
	},
	"piker": {
		"name": "Пикинёр",
		"hp": 80, "damage": 11,
		"speed": 55.0, "attack_range": 125.0, "chase_range": 240.0,
		"attack_cooldown": 2.2, "size": Vector2(42, 72),
	},
}
#endregion

#region Стани
enum STATE { PLAY, PAUSE, LOST, WON }
#endregion
