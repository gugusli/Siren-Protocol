# Revisión Fase 1 – Vertical Slice (código)

Revisión del código frente al plan [fase-1-vertical-slice](c:\Users\Estudiante\.cursor\plans\fase-1-vertical-slice_72e1a562.plan.md).  
Objetivo: confirmar que la Fase 1 está completa a nivel código antes de iniciar Fase 2.

---

## ✅ Completado y verificado

### 1. Sinergias (Fase 1)
- **Ráfaga Mortal (deadly_burst)**: `bullet.gd` — contador `_pierced_enemies_count`, multiplicador hasta 1.60.
- **Escudo Adaptativo (adaptive_shield)**: `Damageable.gd` señal `shield_broken` y callback; `player.gd` `_on_shield_broken` y regen ×3 durante 5 s.
- **Congelación Profunda (deep_freeze)**: `Enemy.gd` `is_frozen`, `frozen_remaining`, `apply_freeze()`, `_break_freeze()` con AoE; `bullet.gd` aplica congelación en críticos a enemigos ralentizados.
- **Reflejo Mortal (deadly_reflex)**: `player.gd` `post_dash_crit_shots` y `consume_post_dash_crit()`; `bullet.gd` fuerza crítico cuando consume.
- **Drenaje Tóxico (toxic_drain)**: `Damageable.gd` `notify_dot_damage` para veneno; cura 20% al jugador.
- **Frecuencia Libre (infinite_ammo)**: `player.gd` en `shoot()` 10% de disparo “gratis”.
- **Reacción en Cadena (artilleria_infernal)**: `bullet.gd` `_apply_explosion` con 40% de segunda explosión.
- **Vampirismo Crítico (vampirismo_mejorado)**: `bullet.gd` curación ×3 en críticos con lifesteal.
- **HUD y Códice**: badges de sinergias, `discovered_synergies` y `_save_discovered_synergy()` en `UpgradeManager`; `CollectionScreen` usa `discovered_synergies`.

### 2. Personajes
- **VÉRTICE**: Dash Mortal, invisibilidad 1 s, backstab en `bullet.gd`. *(Falta burst de daño en área tras el dash; ver apartado de gaps.)*
- **FORTALEZA**: Escudo que anula daño (`preprocess_damage` → 0), VFX de escudo. *(Falta daño reflejado al atacante; ver gaps.)*
- **RECLUTA**: Adaptabilidad en `player.gd` (`_recluta_check_adaptabilidad()`), test en `tests/test_recluta.gd`.

### 3. Oleadas y modo VS
- **WaveManager**: `vertical_slice_mode` → `max_waves = 10`, `boss_wave = 10`; lógica de oleadas y spawn de boss.
- **Seis eventos**: DirectorAI + escenas Stampede, ArtilleryRain, KingOfHill, Darkness, EliteWave, Chaos; tests en `test_events.gd`.
- **Nota**: En `Arena.tscn` el nodo WaveManager no tiene `vertical_slice_mode = true`; por defecto sigue el modo largo. Para VS hay que activarlo en editor o desde código.

### 4. Boss – El Primer Sedimento
- **Script propio**: `entities/enemies/bosses/boss.gd` extiende `CharacterBody2D` (no Enemy), con `Damageable` propio.
- **Fase 1 / Fase 2**: Transición al 50% HP, `_enter_phase_2()`, VFX de transición.
- **Ataques**: Puñetazos de área (`_perform_ground_punch`), ráfagas de energía cada 5 s en Fase 2 (`_perform_energy_burst`).
- **Integración**: `_on_died()` llama a `DirectorAI.register_kill()` y `GameManager.add_kill("BOSS_PRIMER_SEDIMENTO")`.
- **Gap crítico**: El boss no emite ninguna señal que el WaveManager espere, por lo que la oleada no se completa y no se dispara victoria (ver gaps).

### 5. Señales de SEREN
- **SerenManager**: `run_index`, `should_show_workshop_run3_message()`, `is_perfect_run()` (usa `damage_taken`), `seren_log_created`.
- **GameManager**: `current_session["damage_taken"]`, `current_session["run_index"]`, `mark_player_damage_taken()`; sesión se reinicia con `run_index` incrementado.
- **Player**: `_on_health_changed` llama a `GameManager.mark_player_damage_taken()` cuando recibe daño.
- **Taller**: Mensaje run 3 y run perfecta en `WorkshopScreen`; etiqueta SEREN en HUD.
- **Gap**: Las variables `first_boss_message_shown` y `first_run_codex_unlocked` en SerenManager no están conectadas a ninguna UI ni flujo (Señal #5 y entrada de códice primera run).

### 6. Audio
- **Buses**: `audio_bus_layout.tres` con Master, Music, SFX_Gameplay, SFX_UI, SirenFrequency.
- **AudioManager**: `siren_player` en bus SirenFrequency, `SIREN_FREQUENCY` (null hasta tener .wav), `UI_SOUNDS` (ui_confirm, seren_signal).

### 7. Build
- **project.godot**: `[export] presets = Windows Desktop, macOS, Linux/X11`.

---

## ⚠️ Gaps y correcciones recomendadas antes de Fase 2

### Crítico – Victoria al matar al boss
**Problema**: El boss no tiene la señal `enemy_died`. El WaveManager solo conecta `_on_enemy_died` cuando `enemy.has_signal("enemy_died")`, así que al morir el boss nunca se decrementa `enemies_alive` ni se llama a `on_wave_completed()` → no se dispara `GameManager.set_victory()`.

**Recomendación**: En `entities/enemies/bosses/boss.gd`:
1. Declarar `signal enemy_died(enemy: Node)`.
2. En `_on_died()`, antes de `queue_free()`, emitir `enemy_died.emit(self)`.

Así el WaveManager podrá conectar la señal al instanciar el boss y la victoria se registrará correctamente.

---

### Importante – VÉRTICE: burst de daño en área
**Plan (§3)**: “Ejecutar inmediatamente un burst de daño en área (reutilizando patrón de `_ability_pulso_resonancia()`)” tras el dash.

**Estado**: En `Vertice.gd`, `use_ability()` solo hace dash + invisibilidad; no hay daño en área.

**Recomendación**: Tras terminar el dash (y opcionalmente tras la invisibilidad), llamar a una función tipo `_burst_after_dash()` que reutilice el patrón de `_ability_pulso_resonancia()` en `player.gd` (query circular, daño, knockback) en la posición actual de VÉRTICE.

---

### Importante – FORTALEZA: daño reflejado
**Plan (§3)**: “Durante la ventana de escudo activo (…) aplicar daño de retorno al atacante”.

**Estado**: `Fortaleza.gd` solo anula daño con `preprocess_damage` → 0; no hay reflejo.

**Recomendación**: En el flujo donde se aplica el daño al jugador (p. ej. en `Damageable.take_damage` o en el Hitbox que golpea al jugador), si el padre es Fortaleza y el escudo está activo, aplicar daño al atacante (obtener su `Damageable` o nodo con vida y llamar a `take_damage`). Puede requerir pasar “atacante” al flujo de daño (Hurtbox/callback).

---

### Opcional – Boss: núcleo como punto débil (×3 daño recibido)
**Plan (§5)**: “Núcleo expuesto como punto débil: recibir daño con multiplicador ×3”.

**Estado**: En Fase 2 el boss aplica ×3 en sus ráfagas al jugador; no hay un Hurtbox/núcleo en el boss que reciba ×3 del jugador.

**Recomendación**: En Fase 2, que los impactos del jugador al boss (o a un Hurtbox hijo “núcleo”) apliquen un multiplicador ×3 al daño (en el script del boss o en el flujo de daño del bullet cuando el objetivo es el boss en Fase 2).

---

### Configuración VS por defecto
**Estado**: En `Arena.tscn`, el nodo WaveManager no tiene `vertical_slice_mode = true`.

**Recomendación**: Para que la demo sea 10 oleadas + boss sin tocar el editor: en `Arena.gd` o al iniciar partida, si se desea modo VS por defecto, asignar `get_node("WaveManager").vertical_slice_mode = true`, o marcar el checkbox en la escena Arena.

---

### Señales SEREN #5 y primera run (códice)
**Estado**: `SerenManager` tiene `first_boss_message_shown` y `first_run_codex_unlocked` pero no se usan en Taller ni en Códice.

**Recomendación**:
- **Señal #5**: Antes del primer combate con el boss (p. ej. al spawnear el boss o al entrar en oleada 10), si `!SerenManager.first_boss_message_shown`, mostrar en Taller “SEREN: El proceso avanza.” y marcar `first_boss_message_shown = true`.
- **Primera run**: Al terminar la primera run (victoria o derrota), si `!SerenManager.first_run_codex_unlocked`, desbloquear la entrada de códice correspondiente (GDD §10.4) y marcar `first_run_codex_unlocked = true`.

---

### Señal #3 – Los Marcados
El plan menciona variantes de fragmentos/gemas “Marcados” (4 tipos) y entrada de códice. No se ha comprobado en esta revisión si existen esas variantes ni la entrada; conviene verificarlo en contenido/escenas si forma parte del VS.

---

## Resumen

| Área           | Estado   | Acción recomendada                                      |
|----------------|----------|---------------------------------------------------------|
| Sinergias      | OK       | Ninguna                                                 |
| HUD / Códice   | OK       | Ninguna                                                 |
| RECLUTA        | OK       | Ninguna                                                 |
| Oleadas / 6 eventos | OK | Activar `vertical_slice_mode` para demo VS              |
| Boss           | Parcial  | Añadir `enemy_died` en boss; opcional ×3 en núcleo     |
| SEREN          | Parcial  | Conectar first_boss y first_run a Taller/Códice        |
| VÉRTICE        | Parcial  | Añadir burst en área tras dash                          |
| FORTALEZA      | Parcial  | Añadir daño reflejado con escudo activo                 |
| Audio / Build  | OK       | Ninguna                                                 |

**Conclusión**: La Fase 1 está casi completa a nivel código. Para arrancar la Fase 2 con buena base, es **recomendable** corregir al menos el **gap crítico del boss** (señal `enemy_died`) para que la victoria en la oleada 10 funcione. El resto son mejoras de fidelidad al plan y se pueden priorizar según tiempo.
