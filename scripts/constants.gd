## constants.gd — Sabbath - among life and death
## Global autoload for all game constants
## Access from anywhere: C.PLAYER_SPEED, C.ENEMIES, etc.

extends Node

#region Display & Viewport
const VIEWPORT_WIDTH = 1920
const VIEWPORT_HEIGHT = 1080
const CELL_SIZE = 32  # pixel grid
#endregion

#region Player (Yaromir)
const PLAYER_SPEED = 150  # pixels/sec
const PLAYER_ACCELERATION = 500
const PLAYER_HP_MAX = 100
const PLAYER_SIZE = Vector2(48, 64)

const PLAYER_ATTACK_DAMAGE = [5, 5, 8]  # [hit1, hit2, finisher]
const PLAYER_ATTACK_SPEED = [0.3, 0.4, 0.5]  # seconds per hit
const PLAYER_ATTACK_COMBO_COOLDOWN = 1.0  # sec before next combo

const PLAYER_BLOCK_DAMAGE_REDUCTION = 0.5  # 50% less damage
const PLAYER_BLOCK_SPEED_REDUCTION = 0.75  # 75% of normal speed while blocking

const PLAYER_DODGE_CHANCE = 0.05  # 5% per attack = 1/20
const PLAYER_DODGE_COOLDOWN = 0.5  # sec after dodge before next one

const PLAYER_OBSESSION_DURATION = 20.0  # seconds
const PLAYER_OBSESSION_COOLDOWN = 120.0  # seconds (2 min)
const PLAYER_OBSESSION_RECOVERY = 2.0  # sec on knees after
const PLAYER_OBSESSION_DAMAGE_MULTIPLIER = 2.0  # 2x damage
const PLAYER_OBSESSION_SPEED_MULTIPLIER = 1.5  # 1.5x speed
const PLAYER_OBSESSION_DEFENSE_REDUCTION = 0.75  # 25% less defense

const PLAYER_OBSESSION_FILL_PER_ATTACK = 1.0  # per successful combo
const PLAYER_OBSESSION_FILL_PER_DAMAGE = 0.5  # per damage received
const PLAYER_OBSESSION_LEVELS = 3  # max 3 levels
const PLAYER_OBSESSION_LEVEL_THRESHOLD = 100  # per level

const PLAYER_OBSESSION_DASH_DISTANCE = 3.0 * CELL_SIZE  # 3 cells = 96 pixels
const PLAYER_OBSESSION_DASH_COOLDOWN = 1.0  # sec between dashes
const PLAYER_OBSESSION_DASH_INVULNERABILITY = 0.2  # sec while dashing

const PLAYER_WALL_CLIMB_SPEED = 100  # pixels/sec (slower than running)
#endregion

#region Enemies - Types
const ENEMY_TYPES = {
	"pehota": {  # Footman (Polish)
		"name": "Pehota",
		"hp": 25,
		"damage": 4,
		"attack_speed": 0.8,  # sec per attack
		"speed": 120,  # pixels/sec
		"size": Vector2(40, 56),
		"chase_range": 150,  # pixels to detect player
		"attack_range": 40,
		"armor": 0.0,  # no armor reduction
		"xp": 10,
		"obsession_loot": 1.0,
		"behavior": "aggressive_melee",  # rushes at player
		"attacks": [
			{"damage": 4, "telegraphs": 0.5, "knockback": 20},
			{"damage": 4, "telegraphs": 0.4, "knockback": 20},
			{"damage": 5, "telegraphs": 0.6, "knockback": 40},  # finisher
		]
	},

	"musketeer": {  # Ranged shooter
		"name": "Musketeer",
		"hp": 45,
		"damage": 10,  # ranged shot damage
		"melee_damage": 3,
		"attack_speed": 3.0,  # sec per shot (includes reload)
		"reload_time": 3.0,
		"speed": 80,  # slower unit
		"size": Vector2(40, 56),
		"chase_range": 200,
		"attack_range": 300,  # 6-8 cells in pixels
		"armor": 0.0,
		"xp": 20,
		"obsession_loot": 1.5,
		"behavior": "ranged_keep_distance",
		"reload_vulnerable": true,  # 3 sec weakness after shot
		"attacks": [
			{"type": "shoot", "damage": 10, "telegraphs": 1.0, "range": 300, "knockback": 50},
			{"type": "melee", "damage": 3, "telegraphs": 0.3, "range": 40},  # knife if close
		]
	},

	"piker": {  # Tank with polearm
		"name": "Piker",
		"hp": 70,
		"damage": 8,
		"attack_speed": 2.0,
		"speed": 60,  # very slow
		"size": Vector2(44, 64),
		"chase_range": 100,
		"attack_range": 120,  # 2-3 cells
		"armor": 0.5,  # 50% armor reduction
		"xp": 30,
		"obsession_loot": 2.0,
		"behavior": "tank_hold_ground",
		"attacks": [
			{"type": "horizontal_sweep", "damage": 8, "telegraphs": 1.5, "range": 120, "knockback": 60},
			{"type": "side_thrust", "damage": 8, "telegraphs": 1.0, "range": 100, "knockback": 40},
		]
	}
}
#endregion

#region Boss - Prince (Князь)
const BOSS_PRINCE = {
	"name": "Polish Prince-Sorcerer",
	"phases": 4,

	"phase_1": {  # Охрана (Guard)
		"hp": 60,
		"damage": 6,
		"attack_speed": 0.8,
		"has_guards": true,
		"guard_count": 3,
		"attacks": [
			{"type": "sword_overhead", "damage": 6, "telegraphs": 0.5},
			{"type": "sword_sweep", "damage": 6, "telegraphs": 0.4},
			{"type": "shield_bash", "damage": 5, "telegraphs": 0.6, "knockback": 60},
		]
	},

	"phase_2": {  # Конница (Cavalry with lance)
		"hp": 50,
		"damage": 20,  # lance damage - potentially fatal
		"attack_speed": 3.0,  # charge cooldown
		"has_horse": true,
		"horse_hp": 60,
		"charge_damage": 20,
		"charge_telegraphs": 2.0,
		"charge_range": 400,
		"attacks": [
			{"type": "lance_charge", "damage": 20, "telegraphs": 2.0, "range": 400, "knockback": 80},
			{"type": "trample", "damage": 5, "telegraphs": 0.5, "range": 80},
		]
	},

	"phase_3": {  # Охрана вернулась (Guards return, stronger)
		"hp": 40,
		"damage": 8,
		"attack_speed": 0.6,  # faster
		"has_guards": true,
		"guard_count": 3,
		"guard_hp": 40,
		"attacks": [
			{"type": "sword_combo_4", "damage": 8, "telegraphs": 0.3},
			{"type": "sword_finisher", "damage": 10, "telegraphs": 0.6, "knockback": 80},
			{"type": "jump_back", "telegraphs": 0.5, "range": 100},
		]
	},

	"phase_4": {  # Дуэль (Duel - final)
		"hp": 50,
		"damage": 10,
		"attack_speed": 0.5,  # faster combo
		"critical_hp_percent": 0.05,  # at 5% HP, obsession becomes uncontrollable
		"attacks": [
			{"type": "combo_5", "damage": 8, "telegraphs": 0.4},
			{"type": "backstab_teleport", "damage": 12, "telegraphs": 0.7, "knockback": 100},
			{"type": "lightning_bolt", "damage": 10, "telegraphs": 1.0, "range": 500},
			{"type": "magic_jump", "damage": 8, "telegraphs": 1.5, "range": 180},
		]
	}
}
#endregion

#region Controls
const INPUT_MOVE_UP = "move_up"
const INPUT_MOVE_DOWN = "move_down"
const INPUT_MOVE_LEFT = "move_left"
const INPUT_MOVE_RIGHT = "move_right"
const INPUT_ATTACK = "attack"
const INPUT_BLOCK = "block"
const INPUT_OBSESSION = "obsession"
const INPUT_INTERACT = "interact"
const INPUT_PAUSE = "pause"
#endregion

#region Audio
const AUDIO_VOLUME_MASTER = -5.0  # dB
const AUDIO_VOLUME_MUSIC = -10.0
const AUDIO_VOLUME_SFX = -5.0
#endregion

#region Visual & FX
const DEGRADE_COLOR_STAGE_1 = Color(0.8, 0.6, 1.0)  # Purple tint (light)
const DEGRADE_COLOR_STAGE_2 = Color(0.9, 0.4, 0.9)  # Purple tint (medium)
const DEGRADE_COLOR_STAGE_3 = Color(1.0, 0.2, 0.8)  # Purple tint (dark)

const OBSESSION_GLOW_COLOR = Color(1.0, 0.0, 1.0, 0.7)  # Bright magenta
const OBSESSION_AURA_SIZE = 40  # pixels

const ENEMY_HIT_FLASH = 0.1  # sec
const KNOCKBACK_FRICTION = 0.95  # deceleration
#endregion

#region Levels
const LEVELS = [
	{
		"name": "Level 1 - Zich (Ruins)",
		"enemy_waves": [
			[{"type": "pehota", "count": 2}],
			[{"type": "pehota", "count": 1}],
			[{"type": "pehota", "count": 3}],
		],
		"target_time": 360,  # 6 minutes
	},
	{
		"name": "Level 2 - Villages",
		"enemy_waves": [
			[{"type": "pehota", "count": 2}],
			[{"type": "musketeer", "count": 1}, {"type": "pehota", "count": 2}],
			[{"type": "musketeer", "count": 2}, {"type": "pehota", "count": 1}],
		],
		"target_time": 600,  # 10 minutes
	},
	{
		"name": "Level 3 - Approach",
		"enemy_waves": [
			[{"type": "piker", "count": 1}, {"type": "pehota", "count": 2}],
			[{"type": "pehota", "count": 2}, {"type": "musketeer", "count": 1}],
			[{"type": "piker", "count": 1}, {"type": "musketeer", "count": 1}, {"type": "pehota", "count": 1}],
		],
		"cannons": true,
		"target_time": 720,  # 12 minutes
	},
	{
		"name": "Level 4 - Citadel",
		"sublocs": [
			{
				"name": "Inner Courtyard",
				"waves": [
					[{"type": "pehota", "count": 3}],
					[{"type": "musketeer", "count": 2}, {"type": "pehota", "count": 2}],
				]
			},
			{
				"name": "Stables",
				"waves": [
					[{"type": "piker", "count": 2}, {"type": "pehota", "count": 1}],
					[{"type": "piker", "count": 1}, {"type": "musketeer", "count": 1}, {"type": "pehota", "count": 1}],
				]
			},
			{
				"name": "Citadel",
				"waves": [
					[{"type": "musketeer", "count": 3}, {"type": "pehota", "count": 2}],
					[{"type": "piker", "count": 1}, {"type": "musketeer", "count": 2}, {"type": "pehota", "count": 1}],
				]
			},
			{
				"name": "Prince's Chambers",
				"boss": "prince",
				"boss_phases": 4,
			}
		],
		"target_time": 1200,  # 20 minutes
	}
]
#endregion

#region Game States
enum STATE { SPLASH, PLAY, PAUSE, BOSS, LOST, WON, CUTSCENE }
#endregion

#region Difficulty
const DIFFICULTY_MULTIPLIERS = {
	"easy": 0.75,
	"normal": 1.0,
	"hard": 1.25,
	"nightmare": 1.5,
}
#endregion
