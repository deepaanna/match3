class_name PieceData
extends RefCounted

enum PieceType {
	NONE = -1,
	BIGFOOT = 0,
	MOTHMAN = 1,
	NESSIE = 2,
	CHUPACABRA = 3,
	YETI = 4,
	JERSEY_DEVIL = 5,
}

const PIECE_COUNT: int = 6

const PIECE_COLORS: Dictionary = {
	PieceType.BIGFOOT: Color(0.55, 0.35, 0.17),       # Brown
	PieceType.MOTHMAN: Color(0.85, 0.15, 0.15),       # Red
	PieceType.NESSIE: Color(0.15, 0.40, 0.85),        # Blue
	PieceType.CHUPACABRA: Color(0.20, 0.75, 0.20),    # Green
	PieceType.YETI: Color(0.90, 0.92, 0.95),          # White
	PieceType.JERSEY_DEVIL: Color(0.55, 0.20, 0.75),  # Purple
}

const PIECE_NAMES: Dictionary = {
	PieceType.BIGFOOT: "Bigfoot",
	PieceType.MOTHMAN: "Mothman",
	PieceType.NESSIE: "Nessie",
	PieceType.CHUPACABRA: "Chupacabra",
	PieceType.YETI: "Yeti",
	PieceType.JERSEY_DEVIL: "Jersey Devil",
}


static func get_color(piece_type: int) -> Color:
	if PIECE_COLORS.has(piece_type):
		return PIECE_COLORS[piece_type]
	return Color.WHITE


static func get_piece_name(piece_type: int) -> String:
	if PIECE_NAMES.has(piece_type):
		return PIECE_NAMES[piece_type]
	return "Unknown"
