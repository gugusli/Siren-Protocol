# Guía Completa de Eventos Especiales (GDD §8.3)

## 1. STAMPEDE (Estampida)
**Dificultad:** ⭐⭐⭐☆☆

**Descripción:** 30-40 enemigos rápidos spawean desde los bordes en círculo (radio ~700 px). Velocidad x1.5.

**Estrategia del jugador:**
- Mantener movimiento circular.
- Usar armas AoE.
- No quedarse quieto.

**Balance:**
- Reducir dificultad: `enemy_count_max = 30`, `speed_multiplier = 1.2`
- Aumentar dificultad: `enemy_count_max = 50`, `speed_multiplier = 1.8`

---

## 2. ELITE WAVE (Oleada de Élite)
**Dificultad:** ⭐⭐⭐⭐☆

**Descripción:** 3-5 enemigos élites (más HP y daño). Mix aleatorio de tipos (estándar, rápido, tanque, artillero, explosivo).

**Estrategia del jugador:**
- Enfocarse en uno a la vez.
- Usar críticos y burst damage.
- Mantener distancia.

**Balance:**
- Reducir: `elite_count_max = 3`
- Aumentar: `elite_count_max = 7`

---

## 3. DARKNESS (Oscuridad Total)
**Dificultad:** ⭐⭐⭐⭐☆

**Descripción:** Visibilidad reducida (luz del jugador ~30%) y spawns “invisibles” durante ~30 s.

**Estrategia del jugador:**
- Movimiento cauteloso.
- Confiar en audio y bordes de pantalla.
- Atacar defensivamente.

**Balance:**
- Reducir: `duration = 20`, `spawn_invisible = false`
- Aumentar: `duration = 45`, `light_reduction = 0.2`

---

## 4. ARTILLERY RAIN (Lluvia de Artillería)
**Dificultad:** ⭐⭐⭐☆☆

**Descripción:** Proyectiles caen en zona marcada con círculos rojos. Artilleros estáticos en los bordes.

**Estrategia del jugador:**
- Mirar el suelo y esquivar círculos.
- Eliminar artilleros para reducir presión.

**Balance:**
- Reducir: `warning_time = 2.0`, `damage_per_projectile = 30`
- Aumentar: `projectile_spawn_rate` más bajo (más impactos), `damage_per_projectile = 70`

---

## 5. KING OF THE HILL (Rey de la Colina)
**Dificultad:** ⭐⭐⭐☆☆

**Descripción:** Permanecer 15 s dentro de la zona dorada. Recompensa: fragmentos de resonancia.

**Estrategia del jugador:**
- Limpiar enemigos antes de entrar.
- Defender la zona.
- Aceptar daño si hace falta para mantener posición.

**Balance:**
- Reducir: `required_time = 10`, `zone_radius = 200`
- Aumentar: `required_time = 20`, `zone_radius = 100`

---

## 6. CHAOS DUPLICATION (Caos)
**Dificultad:** ⭐⭐⭐⭐⭐

**Descripción:** Cada enemigo que muere genera 2 duplicados débiles (50% HP). Duración ~30 s.

**Estrategia del jugador:**
- Daño en área y burst en grupos.
- Evitar matar uno a uno.
- Control de multitudes prioritario.

**Balance:**
- Reducir: `spawn_count = 1`, `duplicate_health_mult = 0.3`
- Aumentar: `spawn_count = 3`, `duplicate_health_mult = 0.7`

---

## Configuración en proyecto

- Valores por defecto están en los `@export` de cada script en `levels/events/`.
- Valores de referencia para balance: `config/events_balance.json`.
- Activación: DirectorAI (`_autoloads/DirectorAI.gd`) elige evento cada 3–5 oleadas según probabilidad.
