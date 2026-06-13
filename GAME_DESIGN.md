# Notebook Awakening — Game Design Doc

**Jam:** She Built This: Game Jam (powered by Sentry) · Theme: **Awakening**
**Deadline:** 14 jun 2026, 2:00 PM PT · **Dev:** solo, ~20-24h · **Engine:** Godot 4.5.1
**Entrega:** HTML5/WebGL jugable en navegador de itch.io (sin builds descargables)

## Concepto
Eres un stick figure garabateado en el margen de una hoja de cuaderno. **Despiertas** y te vuelves
consciente. Un lápiz gigante baja a dibujar sobre la página y su tinta te hace daño; sobrevives
mientras la hoja se llena. Una goma de borrar gigante aparece, persigue todo y abre tu salida.
Corres al borde, **saltas fuera de la página**, y el cuaderno se cierra detrás de ti.

## Decisiones cerradas (interrogatorio /grill-me)
| Rama | Decisión |
|------|----------|
| Perspectiva | Top-down (cenital), movimiento 8 direcciones, **sin gravedad**. Salto final = animación scripteada (Tween/AnimationPlayer), no física real. |
| Estructura | Supervivencia con score (= tiempo sobrevivido). Tras ~60-90s aparece la goma y se abre el borde de escape. Llegar al borde = **GANAS**. |
| Fin de partida | Cuaderno se cierra → pantalla final reutilizable para ganar (escapaste) y perder (te borraron), con mensaje distinto. |
| Modelo de daño | **3 vidas / salud**. Indicador = el stick figure se va borrando/desvaneciendo con cada golpe (sin HUD de corazones). I-frames + parpadeo tras hit. |
| Otros doodles | **Decoración/obstáculos estáticos**. Sin empujar ni esconderse (cortado por scope). |
| Lápiz | Su **sombra persigue** al jugador (más lento que tu carrera), se fija ~0.8-1s con flash inequívoco, luego baja y traza tinta. Sombra inofensiva; solo la tinta daña. |
| Tinta | **Persiste** como obstáculo permanente (presión creciente). |
| Goma | Persigue al jugador y **borra la tinta a su paso** (crea carriles seguros caóticos). Contacto = muerte. Su llegada abre el borde de escape. |
| Audio | Bibliotecas libres acreditadas (Freesound CC0, OpenGameArt, incompetech). **Sin IA.** Registrar todo en `CREDITS.txt`. |
| Arte | Dibujo digital simple (Krita/Photoshop), trazo tembloroso deliberado. **Sin IA.** |
| Sentry | Mínimo: snippet de Sentry **JavaScript** en el HTML shell del export (el SDK nativo no corre en web). |

## Decisiones menores tomadas por defecto (cámbialas si quieres)
- **Controles:** WASD **y** flechas (ambos). Sin más inputs.
- **Resolución:** 1280×720 (ya en project.godot). Embed de itch a 1280×720.
- **Render:** GL Compatibility (correcto para web). NO cambiar a Forward+.
- **Velocidades iniciales a tunear:** jugador 200 px/s · sombra del lápiz ~140 px/s (debe ser < jugador) · goma ~120 px/s al inicio, acelera lento.

## ⚠️ Riesgos técnicos resueltos
- ✅ Plantillas de export instaladas (`4.5.1.stable`, incluye web).
- ⚠️ **Exportar con "Thread Support" DESACTIVADO** (usa `web_nothreads_release`). Con threads, itch.io da pantalla negra por falta de cabeceras SharedArrayBuffer.
- Subir a itch como ZIP con `index.html` en la raíz; marcar "This file will be played in the browser".

## Presupuesto de tiempo sugerido (~22h)
1. **Core movement + cámara (2h):** CharacterBody2D top-down, WASD/flechas, hoja con límites.
2. **Lápiz + tinta (4h):** sombra que persigue → telegrafía → traza tinta persistente (Line2D/sprite) con colisión de daño.
3. **Salud + i-frames + feedback de borrado (2h).**
4. **Goma: persecución + borrar tinta + muerte (3h).**
5. **Estado de juego: timer/score, trigger de goma, apertura del borde (2h).**
6. **Cinemática final: salto + cuaderno se cierra + pantalla de mensaje (3h).**
7. **Arte: personaje, goma, lápiz, doodles de fondo, tinta (3h, en paralelo).**
8. **Audio + CREDITS.txt (1h).**
9. **Export web nothreads + prueba en itch + Sentry JS (2h).** ← reservar SÍ o SÍ.

## Cómo ganar (estrategia vs rúbrica)
- **Theme (Awakening):** clavado — la conciencia que despierta y escapa. Refuérzalo en intro y final.
- **Most Interesting Art Style (premio especial):** el doodle de cuaderno es perfecto; "interesante ≠ bonito". Tu mayor ventaja.
- **Visuals/Audio:** no entregues mudo. Música ambiente lo-fi + SFX de lápiz/papel/goma.
- **Gameplay/Fun:** el telegrafiado justo del lápiz es lo que decide esto. Playtest temprano.
