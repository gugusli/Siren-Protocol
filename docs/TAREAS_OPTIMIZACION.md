# Tareas de optimización – AFTERSHOCK

Tareas adicionales de optimización y alineación con el GDD (post-mejora del menú).

---

## 1. Object pooling obligatorio (GDD §11.3)

- **Objetivo:** Pool para balas, enemigos, partículas y drops.
- **Acciones:** Revisar `bullet.tscn`, `BouncingBullet.tscn`, enemigos en `entities/enemies/`, `EnemyDeathFX.tscn` y drops (gemas, pociones). Centralizar en un `PoolManager` o uso de `MultiMesh`/reutilización de nodos en lugar de `instance()`/`queue_free()` constante.
- **Criterio de éxito:** Sin instanciar/liberar en cada disparo/muerte; reutilización de instancias.

---

## 2. HUD in-game según GDD (§2.5)

- **Objetivo:** HUD de gameplay alineado con el GDD (esquina superior izquierda/derecha, centro superior, esquina inferior derecha).
- **Acciones:** En `ui/hud/hud.tscn` y `hud.gd`: barra de vida con degradado verde → amarillo (<50%) → rojo (<25%), números HP, nivel; timer de oleada con pulso <10 s; número de oleada; ícono Director IA (verde/amarillo/rojo); indicadores de sinergia activa (32×32, glow dorado/arcoíris); cooldown de habilidad en círculo radial.
- **Criterio de éxito:** Todos los elementos descritos en el GDD presentes y con estilo HUD militar-cyberpunk.

---

## 3. Pantalla de selección de mejoras (§2.5)

- **Objetivo:** Pantalla de 3 cartas de mejora según GDD.
- **Acciones:** En `UpgradeMenu.tscn`/`UpgradeMenu.gd`: layout horizontal, cartas 280×400 px, espaciado 40 px; borde por rareza (gris/azul/púrpura/dorado); cabecera con ícono 64×64 y gradiente de rareza; texto “NIVEL X → Y” si aplica; descripción con números en verde/rojo; banner “¡SINERGIA DISPONIBLE!” cuando corresponda; hover: elevación 5 px, borde brillante, partículas de color.
- **Criterio de éxito:** Diseño y comportamiento de cartas según GDD, con feedback visual en hover.

---

## 4. Director de IA y eventos de oleada (§8)

- **Objetivo:** Dificultad adaptativa y eventos especiales.
- **Acciones:** En `DirectorAI.gd`: usar métricas (vida %, tiempo sin hit, kills/s, % pantalla cubierta, sinergias) para intensificar/aliviar/mantener; spawn de élites y cantidad de enemigos según estado. Implementar eventos: Estampida de Corredores, Lluvia de Artillería, Rey de la Colina, Oscuridad Total, Oleada de Élite, con activación cada 3–5 oleadas.
- **Criterio de éxito:** Dificultad que reacciona al rendimiento del jugador y al menos 2–3 eventos especiales jugables.

---

## 5. Rendimiento y VFX (§11.2, §2.6)

- **Objetivo:** 60 FPS estables en mid-range (Snapdragon 665, Apple A11).
- **Acciones:** Límite máximo de partículas simultáneas; desactivar o reducir calidad de partículas en opciones gráficas; evitar crear decenas de instancias de VFX por segundo; revisar `VFXManager` y efectos de impacto/crítico/explosión para reutilizar nodos o usar `GPUParticles2D` con límites; test en dispositivo real o emulador mid-range.
- **Criterio de éxito:** Sin caídas sostenidas por debajo de 60 FPS en escenas de combate denso en target devices.

---

*Generado tras mejora del menú principal y música. Prioridad sugerida: 1 → 2 → 3 → 4 → 5 (o en paralelo según equipo).*
