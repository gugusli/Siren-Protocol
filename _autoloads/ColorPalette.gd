extends Node
## Autoload: GameColorPalette (nombre en project.godot). No usar class_name para no ocultar el singleton.

## =========================
## AFTERSHOCK - Paleta de Colores
## Según GDD Visual v4
## =========================

# =========================
# COLORES PRIMARIOS DE MARCA
# =========================
const ROJO_ALERTA := Color("#CC0000")       # Logo, peligro crítico, vida crítica
const NEGRO_PROFUNDO := Color("#1A1A1A")    # Fondos principales de UI, overlays
const CIAN_ENERGIA := Color("#00D9FF")      # Resonancia, powerups, menús interactivos
const DORADO_SINERGIA := Color("#FFD700")   # Sinergias nivel 2, items legendarios
const PURPURA_MISTICO := Color("#9933FF")   # Sinergias nivel 3, items épicos

# =========================
# COLORES DE FEEDBACK Y ESTADOS
# =========================
const VERDE_SALUD := Color("#00FF66")       # Vida completa, curaciones, confirmaciones
const NARANJA_FUEGO := Color("#FF6600")     # Daño de fuego, explosiones
const AMARILLO_ADVERTENCIA := Color("#FFFF00")  # Áreas de peligro, alertas
const VIOLETA_TOXICO := Color("#9900FF")    # Veneno, corrosión, debuffs
const AZUL_ELECTRICO := Color("#00BFFF")    # Daño eléctrico, cadenas, aturdir
const ROJO_CRITICO := Color("#FF0033")      # Golpes críticos, daño masivo

# =========================
# PALETA DE RAREZA
# =========================
const RAREZA_COMUN := Color("#FFFFFF")      # Sin glow, 60% probabilidad
const RAREZA_RARO := Color("#0099FF")       # Glow azul sutil, 30%
const RAREZA_EPICO := Color("#9933FF")      # Glow púrpura intenso, 9%
const RAREZA_LEGENDARIO := Color("#FFD700") # Glow dorado animado, 1%

# =========================
# PALETA DE UI ESPECIALIZADA
# =========================
const UI_GRIS_OSCURO := Color("#2A2A2A")    # Fondo de paneles secundarios
const UI_GRIS_BORDE := Color("#444444")     # Bordes, separadores
const UI_GRIS_TEXTO := Color("#CCCCCC")     # Texto secundario
const UI_BLANCO_TEXTO := Color("#FFFFFF")   # Texto principal
const UI_OVERLAY := Color(0, 0, 0, 0.7)     # Overlays oscuros detrás de menús
const UI_GLOW_CIAN := Color(0, 0.85, 1, 0.4)  # Glow de botones hover

# =========================
# COLORES DE PERSONAJES
# =========================
const RECLUTA_PRIMARIO := Color("#3A3A3A")  # Grises oscuros
const RECLUTA_SECUNDARIO := Color("#00D9FF") # Cian brillante

const FORTALEZA_PRIMARIO := Color("#2A2A2A")  # Metal oscuro
const FORTALEZA_SECUNDARIO := Color("#FF6600") # Naranja llama

const VERTICE_PRIMARIO := Color("#1A1A1A")   # Negro profundo
const VERTICE_SECUNDARIO := Color("#9933FF")  # Púrpura

const REVERBERACION_PRIMARIO := Color("#E8E8E8")  # Blanco fantasmal
const REVERBERACION_SECUNDARIO := Color("#FFD700") # Dorado

const ECO_HUMANO := Color("#8B7355")         # Beige/marrón
const ECO_MUTADO := Color("#00D9FF")         # Cian brillante

# =========================
# FUNCIONES UTILIDAD
# =========================
static func get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"comun", "common": return RAREZA_COMUN
		"raro", "rare": return RAREZA_RARO
		"epico", "epic": return RAREZA_EPICO
		"legendario", "legendary": return RAREZA_LEGENDARIO
		_: return RAREZA_COMUN

static func get_health_color(health_percent: float) -> Color:
	if health_percent > 0.5:
		return VERDE_SALUD
	elif health_percent > 0.25:
		return AMARILLO_ADVERTENCIA
	else:
		return ROJO_ALERTA

static func get_damage_type_color(damage_type: String) -> Color:
	match damage_type.to_lower():
		"fuego", "fire": return NARANJA_FUEGO
		"electrico", "electric": return AZUL_ELECTRICO
		"veneno", "poison": return VIOLETA_TOXICO
		"hielo", "ice": return Color("#00BFFF")
		"critico", "critical": return ROJO_CRITICO
		_: return UI_BLANCO_TEXTO
