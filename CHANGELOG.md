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
