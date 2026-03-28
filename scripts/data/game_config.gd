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

# Swipe detection
const MIN_SWIPE_DISTANCE: float = 20.0

# Visual
const PIECE_SCALE: float = 0.85  # Relative to cell size
const HIGHLIGHT_SCALE: float = 1.1
const HIGHLIGHT_PULSE_SPEED: float = 3.0

# Team panel layout
const TEAM_PANEL_Y: int = 730
const PORTRAIT_WIDTH: int = 150
const PORTRAIT_HEIGHT: int = 180
const PORTRAIT_SPACING: int = 15
