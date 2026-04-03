# Refactorización del Menú Principal - Theme-Based UI

## Objetivo alcanzado
Toda la estética visual del menú (colores, bordes, glow, hover, pressed, focus) está ahora controlada exclusivamente por el Theme `aftershock_menu_theme.tres`, eliminando overrides manuales en GDScript.

---

## Cambios técnicos

### 1. Theme (`ui/theme/aftershock_menu_theme.tres`)

**Estructura:**
```
Theme
├── Button (base genérico)
│   ├── colors/font_color: blanco
│   ├── colors/font_outline_color: negro
│   ├── constants/outline_size: 2
│   └── font_sizes/font_size: 20
│
├── ButtonPrimary (variación para botón principal)
│   ├── base_type: "Button"
│   ├── styles/normal: rojo #CC0000, shadow rojo 0.45 alpha
│   ├── styles/hover: cian #00D9FF, shadow cian 0.6 alpha
│   ├── styles/pressed: rojo oscuro
│   └── font_size: 24
│
└── ButtonSecondary (variación para botones secundarios)
	├── base_type: "Button"
	├── styles/normal: gris oscuro, shadow sutil
	├── styles/hover: cian #00D9FF, shadow cian 0.4 alpha
	├── styles/pressed: gris muy oscuro
	└── font_size: 18
```

**Decisiones de diseño:**
- **Esquinas afiladas** (`corner_radius: 2`): estética militar/técnica.
- **Bordes gruesos** (4px principal, 2px secundarios): presencia visual fuerte.
- **Shadow como glow**: `shadow_offset: (0, 0)` para efecto de resplandor energético.
- **Colores GDD**: rojo alerta (#CC0000), cian energía (#00D9FF), negro profundo (#1A1A1A).

---

### 2. Escena (`MainMenu.tscn`)

**Antes:**
- 14 SubResources (4 StyleBoxFlat inline + gradientes/partículas)
- Cada botón con 8+ `theme_override_*` (colors, constants, font_sizes, styles)
- ~400 líneas de configuración visual repetida

**Después:**
- 8 SubResources (solo gradientes/partículas ambientales)
- Cada botón con 1 línea: `theme_type_variation = &"ButtonPrimary"` o `&"ButtonSecondary"`
- Theme asignado al nodo `MainControl` (herencia automática)
- ~250 líneas (reducción del 37%)

**Ventajas:**
- Cambios visuales en un solo lugar (`.tres`)
- Reutilizable en otros menús (CharacterSelect, Workshop, etc.)
- Sin duplicación de StyleBox

---

### 3. Script (`MainMenu.gd`)

**Eliminado (66 líneas):**
- Creación de `style_hover_red: StyleBoxFlat` (líneas 59-81)
- Overrides en `_on_button_hover` (líneas 312-314)
- Creación/asignación de `style_gray` en `_on_button_exit` (líneas 323-341)
- Pulso del glow del borde en `_process` (líneas 230-236)

**Mantenido:**
- Animaciones: scale, modulate, scan line, glitch, boot sequence
- Lógica: cambio de escenas, actualización de HUD, estados
- Música: `AudioManager.play_menu_music()`
- Glow del título (animación de outline_color)

**Resultado:**
- ~330 líneas (antes: ~450)
- Código más legible y mantenible
- Separación clara: lógica vs. estética

---

## Uso del Theme en otros menús

Para aplicar el mismo estilo en otros menús:

```gdscript
# En CharacterSelect.tscn, WorkshopScreen.tscn, etc.
[node name="RootControl" type="Control"]
theme = ExtResource("res://ui/theme/aftershock_menu_theme.tres")

[node name="PrimaryButton" type="Button"]
theme_type_variation = &"ButtonPrimary"

[node name="SecondaryButton" type="Button"]
theme_type_variation = &"ButtonSecondary"
```

---

## Mejoras futuras (opcional)

1. **Animación del glow en Theme:** Godot no soporta animación de StyleBox en Theme nativo. Si se desea un pulso del glow sin código, se podría:
   - Usar un shader en el botón (modular shadow_color)
   - O mantener la animación de modulate en script (actual)

2. **Variaciones adicionales:**
   - `ButtonDanger` (rojo intenso para acciones destructivas)
   - `ButtonDisabled` (gris apagado para botones bloqueados)
   - `ButtonSuccess` (verde para confirmaciones)

3. **Extensión a Labels/Panels:**
   - Definir `LabelTitle`, `LabelSubtitle`, `LabelHUD` en el Theme
   - Eliminar `theme_override_*` de Title, SubTitle, HUD_Decorativo

---

*Refactorización completada. El menú ahora sigue el patrón Theme-First de Godot.*
