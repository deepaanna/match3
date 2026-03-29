class_name GameConfig
extends RefCounted

# Grid dimensions
const GRID_COLS: int = 8
const GRID_ROWS: int = 8
const CELL_SIZE: int = 60

# Board positioning (centered horizontally)
const BOARD_OFFSET_X: int = 30  # (540 - 8*60) / 2
const BOARD_OFFSET_Y: int = 240 # Top margin for HUD

# Animation timing (seconds)
const SWAP_DURATION: float = 0.2
const CLEAR_DURATION: float = 0.3
const FALL_DURATION_PER_CELL: float = 0.08
const FALL_MIN_DURATION: float = 0.1
const SPAWN_DURATION: float = 0.3
const CASCADE_DELAY: float = 0.05

# Scoring
const MATCH_BASE_SCORE: int = 50
const EXTRA_PIECE_BONUS: int = 25
const CASCADE_MULTIPLIER_INCREMENT: float = 0.5

# Booster thresholds
const MATCH_4_BOOSTER: int = 4        # Creates line clear
const MATCH_5_BOOSTER: int = 5        # Creates color bomb
const AREA_BOMB_RADIUS: int = 1       # 3×3 area (1 cell each direction)

# Booster scoring
const BOOSTER_CREATE_SCORE: int = 100
const BOOSTER_ACTIVATE_SCORE: int = 200

# Booster animation
const BOOSTER_CREATE_DURATION: float = 0.35

# Swipe detection
const MIN_SWIPE_DISTANCE: float = 25.0

# Visual
const PIECE_SCALE: float = 0.85  # Relative to cell size
const HIGHLIGHT_SCALE: float = 1.1
const HIGHLIGHT_PULSE_SPEED: float = 3.0

# Hint system
const HINT_IDLE_DELAY: float = 5.0  # Seconds before showing a hint
const HINT_PULSE_DURATION: float = 0.4

# Shuffle
const SHUFFLE_DURATION: float = 0.4

# Screen shake
const SHAKE_SMALL: float = 2.0
const SHAKE_MEDIUM: float = 4.0
const SHAKE_LARGE: float = 7.0
const SHAKE_DURATION: float = 0.25

# Victory detonation
const VICTORY_DETONATION_DELAY: float = 0.3  # Delay between each move→booster

# Tutorial hints
const TUTORIAL_HINT_FADE_IN: float = 0.4
const TUTORIAL_HINT_DISPLAY: float = 4.0  # How long the hint text stays visible
const TUTORIAL_HINT_FADE_OUT: float = 0.6
const TUTORIAL_HINT_COOLDOWN: float = 30.0  # Min seconds between hints
const TUTORIAL_PULSE_DURATION: float = 0.5

# Team panel layout
const TEAM_PANEL_Y: int = 730
const PORTRAIT_WIDTH: int = 150
const PORTRAIT_HEIGHT: int = 180
const PORTRAIT_SPACING: int = 15
