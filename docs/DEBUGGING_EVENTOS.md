# Guía de Debugging de Eventos Especiales

## Problemas Comunes

### Evento no se activa
**Síntoma:** DirectorAI emite la señal pero nada pasa.

**Verificar:**
1. ¿La escena .tscn existe en `levels/events/`?
2. ¿El método `_activate_*_event()` está en DirectorAI?
3. ¿`trigger_special_event()` llama al método correcto?

**Fix:** Revisar errores en consola (Output / Debugger). Asegurarse de que la oleada actual sea >= MIN_WAVE_FOR_EVENT (3) y que haya pasado el cooldown de oleadas.

### Enemigos no spawean
**Síntoma:** El evento se activa pero no aparecen enemigos.

**Verificar:**
1. ¿WaveManager tiene las escenas de enemigos asignadas en el inspector?
2. ¿Los pools de enemigos están inicializados (PoolManager)?
3. ¿`_get_pool_key_for_scene()` retorna el key correcto?

**Fix:** Añadir prints para depurar:
```gdscript
print("Pool key: ", pool_key)
print("Has pool: ", PoolManager.has_pool(pool_key))
```

### Advertencias no se muestran
**Síntoma:** El evento funciona pero no hay warning visual en pantalla.

**Verificar:**
1. ¿El HUD tiene el método `show_event_warning()`?
2. ¿El HUD está en la escena Arena como hijo directo con nombre "HUD"?

**Fix:** Usar fallback en eventos (ya implementado):
```gdscript
if hud and hud.has_method("show_event_warning"):
    hud.show_event_warning(...)
else:
    print("⚠️ ADVERTENCIA: ", text)
```

### Performance baja durante eventos
**Síntoma:** FPS cae durante Artillery o Chaos.

**Verificar:**
1. ¿Los proyectiles/duplicados usan pooling donde sea posible?
2. ¿Las partículas están limitadas (MAX_SPARK_PARTICLES en VFXManager)?

**Fix:** Reducir `@export` en el evento (por ejemplo `projectile_spawn_rate`, `spawn_count` en Chaos).

### Rey de la Colina no completa
**Síntoma:** El jugador está en la zona pero la barra no sube o no termina.

**Verificar:**
1. ¿El jugador está dentro de `zone_radius` (150 px por defecto)?
2. ¿El HUD tiene el nodo `KingOfHillProgress` y el método `update_king_of_hill_progress()`?

**Fix:** Aumentar temporalmente `zone_radius` o `required_time` para probar.

### Caos: duplicados no aparecen
**Síntoma:** En ChaosEvent, al matar enemigos no spawnan clones.

**Verificar:**
1. ¿Los enemigos emiten la señal `enemy_died(enemy)` al morir?
2. ¿El evento está conectado a enemigos existentes con `_connect_existing_enemies()`?
3. ¿Los enemigos tienen `set_meta("spawn_scene", scene)` (por ejemplo desde WaveManager)?

**Fix:** Comprobar que Enemy.gd (y variantes) emiten `enemy_died.emit(self)` al morir y que tienen el meta `spawn_scene`.

## Ejecutar tests de eventos

- Crear una escena con un nodo raíz que tenga el script `res://tests/test_events.gd` y reproducir.
- O desde línea de comandos: `godot --path . --script tests/test_events.gd` (requiere que el proyecto tenga main scene o pasar una escena de prueba).

## Referencia rápida de archivos

| Evento        | Script                      | Escena .tscn                 |
|-------------|-----------------------------|------------------------------|
| Stampede    | levels/events/StampedeEvent.gd    | levels/events/StampedeEvent.tscn    |
| Elite Wave  | levels/events/EliteWaveEvent.gd   | levels/events/EliteWaveEvent.tscn   |
| Darkness    | levels/events/DarknessEvent.gd   | levels/events/DarknessEvent.tscn   |
| Artillery   | levels/events/ArtilleryRainEvent.gd | levels/events/ArtilleryRainEvent.tscn |
| King of Hill| levels/events/KingOfHillEvent.gd  | levels/events/KingOfHillEvent.tscn  |
| Chaos       | levels/events/ChaosEvent.gd      | levels/events/ChaosEvent.tscn      |

DirectorAI: `_autoloads/DirectorAI.gd` (métodos `_activate_*_event` y `trigger_special_event`).
