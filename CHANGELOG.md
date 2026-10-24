# Changelog

Formato obligatorio (lo valida `scripts/changelog-check.sh` en CI): una sección por versión, de la
más nueva a la más vieja, titulada `## [X.Y.Z] - AAAA-MM-DD`, con dos partes y al menos un ítem en
cada una:

- `### Para todos`: lo que se anuncia en el canal de novedades de Discord y va como notas del
  archivo en CurseForge. Para jugadores, sin tecnicismos.
- `### Técnico`: el detalle real del cambio, para quien mantiene el código. Va, junto con lo de
  arriba, en las notas del GitHub Release.

Al taggear `vX.Y.Z` la versión tiene que estar arriba de todo y coincidir con `## Version:` de los
`.toc`. La 0.2.0 es el inicio de este changelog: resume todo lo que hace el addon hasta ahí. Lo
anterior está en [docs/CHANGELOG-anterior.md](docs/CHANGELOG-anterior.md).

## [0.3.2] - 2026-10-24

### Para todos

- **Banco de la guild como en el juego**: el addon anota en qué casillero está cada ítem, así el sitio muestra cada pestaña igual que en el juego.
- **Tu balance, tus bolsas y tu banco ya no se anotan**: de oro e inventario, el addon solo anota los de la guild. Al entrar al juego borra lo que había anotado la versión anterior.

### Técnico

- `gb1` suma un cuarto campo con `casillero=ítem:cantidad,…` (1 a 98). El sitio (v0.6.0) entiende los dos formatos; sin ese campo acomoda los ítems en orden.
- Fuera `mo1` (balance) e `inv1` (bolsas, banco y banco de componentes) con sus eventos, y `AppSettings.lua` (ya no hace falta la casilla de la app). En `PLAYER_LOGIN` se borran de `RebirthTrackDB.data`.

## [0.3.1] - 2026-10-23

### Para todos

- **Tu balance, solo si querés**: el balance de tus personajes se anota únicamente si tenés la app Rebirth Track Uploader con la casilla **«Enviar mi balance»** activada. Sin la app, o si la desactivás, no se anota y se borra el que había. El balance del banco de la guild se anota igual.

### Técnico

- `AppSettings.lua` nuevo (en todos los `.toc`, antes de `Collect.lua`): `RebirthTrackApp = { balance = false }`; la app (v0.5.0) lo reescribe según su panel. `mo1` solo con `RebirthTrackApp.balance == true`; si no, en `PLAYER_LOGIN` se borra de `RebirthTrackDB.data`.

## [0.3.0] - 2026-10-23

### Para todos

- **Anota más del juego para el sitio**: tus profesiones (niveles, recetas y cooldowns), equipo, talentos, oro, bolsas y banco, reputaciones y misiones; de la subasta, solo lo que publicás y lo que comprás o vendés. En bandas y mazmorras, el botín y los buffs al empezar cada jefe, y el equipo del resto de la banda. De la guild, el banco (si lo abrís), las notas, el mensaje del día y el historial.
- **Con que algunos tengan la app alcanza**: profesiones, equipo y talentos se comparten entre los addons de la guild y los sube cualquiera que tenga la app. Lo privado (oro, bolsas, banco, subasta) no sale de tu PC más que por tu app.
- **`/rt datos`**: muestra en el chat qué hay anotado.
- Banco, correo, subasta y recetas solo se anotan cuando abrís esa ventana. Nunca lee tu chat.

### Técnico

- `Collect.lua` nuevo (en todos los `.toc`): líneas `tipo;dueño;hora;…` en `RebirthTrackDB.data[dueño][clave]` (último estado, la hora es la del último cambio) y `RebirthTrackDB.events` (hechos, hasta 1500). Detalle de cada tipo en el encabezado del archivo. Todo con detección de API y `pcall`: en la versión que no tiene una función, lo demás se sigue anotando.
- Canal de addons `RTK1`: `D;id;parte;partes;texto` (líneas de hasta ~16 KB en partes de 200) y `E;desde` al entrar (los demás responden con lo que cambió desde esa hora, sin repetir lo que ya mandó otro). Solo viajan `p1`, `sk1`, `r1`, `cd1`, `eq1` y `t1`; lo recibido se guarda con `@remitente;`. Cola a un mensaje por segundo.
- `m1` suma la nota pública y la de oficiales (si el rango la ve). El archivo principal comparte `db`, `send` y `regionCode` con `Collect.lua` por la tabla del addon. Los textos ya no llevan comillas.

## [0.2.2] - 2026-10-23

### Para todos

- **Arreglado en WoW Forever**: la app de CurseForge ya no lo marca como «posiblemente dañado (pertenece a Classic)» cuando lo instalás para Forever.

### Técnico

- WoW Forever carga `RebirthTrack_Camelot.toc` (sufijo del proyecto `WOW_PROJECT_CAMELOT`, el que reconoce el packager de BigWigs): nuevo `.toc` con `## Interface: 16001`. `RebirthTrack_Vanilla.toc` queda solo con 11508 (Classic Era): tener 16001 ahí hacía que CurseForge lo tomara como de Classic.

## [0.2.1] - 2026-10-23

### Para todos

- En CurseForge ahora figura como compatible con **WoW Forever**, así lo encontrás y lo instalás también desde ahí.

### Técnico

- `scripts/curseforge.sh` ya no saltea la interfaz 16001: CurseForge tiene el tipo «WoW Forever» (88568) con la versión 1.60.1, que es lo que da la conversión de 16001. Workflow manual de solo lectura `curseforge-versions` para consultar las versiones de juego de CurseForge.

## [0.2.0] - 2026-10-22

### Para todos

- **Tus bandas, registradas sin pensar**: al entrar a una banda o mazmorra prende solo el registro de combate del juego, y al salir te muestra un resumen (jefes, wipes, duración y jugadores). Con la app Rebirth Track Uploader, eso llega solo a rebirthknights.fun.
- **Vinculá tus personajes desde el juego**: botón «Vincular a Rebirth Track» en la ventana del personaje (o `/rt vincular`); queda a tu nombre en el sitio, verificado.
- **La guild completa en la web**: anota la lista de miembros y comparte por el canal de la guild quién usa el addon, así aparecen todos en el sitio aunque no tengan la app.
- **Replay con grupos**: guarda el grupo de banda de cada jugador para que el replay del sitio los agrupe bien.
- **Rangos para oficiales**: ventana con la lista de la guild y un botón por miembro para aplicar los ascensos o descensos que corresponden según Discord.
- **Cómodo**: ventana propia movible y redimensionable, botón en el minimapa, en español o inglés (`/rt idioma`).
- **Todas las versiones de WoW**, incluido **WoW Forever**.

### Técnico

- Lua sin dependencias, con `.toc` por versión (Mainline 120001, Mists 50501, TBC 20506/20505, Vanilla 11508 y Forever 16001). SavedVariables `RebirthTrackDB` con líneas versionadas que lee el sitio: `v1` (pedidos de vincular), `g1` (grupos de banda), `gi1`/`m1`/`k1` (guild, miembros y personajes anunciados por el canal de addons `RTK1`).
- `LoggingCombat` automático por tipo de instancia (en Forever los addons no pueden leer el registro de combate: esa parte se saltea sin errores).
- Ventana de Rangos: interpreta el código que copia el sitio y hace un `GuildPromote`/`GuildDemote` por clic, sin tocar al Guild Master.
- CI: con el tag `vX.Y.Z` corre las pruebas (`tests/run.lua`), valida este changelog, sube el zip a CurseForge con lo de «Para todos» como notas, arma el GitHub Release y lo anuncia en Discord (token OIDC de GitHub contra `/api/internal/releases`). El CDN de rebirthknights.fun, del que lo instala la app, se publica con `scripts/release.sh`.
