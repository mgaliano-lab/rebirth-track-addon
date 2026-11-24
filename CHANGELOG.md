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

## [0.14.1] - 2026-11-24

### Para todos

- **Tiradas de botín en mazmorras**: cuando sale un ítem y el grupo tira dados, el addon anota quién eligió Necesidad, Codicia, Desencantar o Paso, qué número sacó cada uno y quién lo ganó (también lo verde). Se ve en el sitio, en Botín → «Tiradas en mazmorras» (por corrida) y en la ficha de cada personaje.
- **Ya no hace falta tener la app**: las tiradas y el botín de las instancias viajan de addon en addon por la guild hasta llegar a alguien que sí tenga la app, y de ahí al sitio. Alcanza con cruzarse conectado con otro de la guild que tenga el addon (dentro de los 14 días).

### Técnico

- `Collect.lua`: `rl1` y `lt1` se comparten por el canal (`D;…`) al anotarse. Lo recibido va a `events` con `@remitente;` una sola vez (índice `RebirthTrackDB.relay[línea] = cuándo se conoció`), y en cada `E;desde` se reenvía lo conocido después de `desde` (hasta 20 por pedido, sin repetir lo que otro mandó durante la espera). Se descarta lo de más de 14 días, lo del futuro y lo que no sea de un jugador; tope de 400 en el índice. Lo anotado con la 0.14.0 entra al índice la primera vez.
- El sitio ya lee `@remitente;` en cualquier línea y junta la misma tirada aunque llegue por varios caminos (web 0.9.60).
- Pruebas del reenvío en `tests/run.lua` (sale por el canal, guardado único, descartes, respuesta al `E;`, olvido a los 14 días).

## [0.14.0] - 2026-11-24

### Para todos

- **Tiradas de botín en mazmorras**: cuando sale un ítem y el grupo tira dados, el addon anota quién eligió Necesidad, Codicia, Desencantar o Paso, qué número sacó cada uno y quién lo ganó (también lo verde). Al subirlo con la app se ve en el sitio, por corrida de mazmorra y en la ficha de cada personaje.

### Técnico

- `Collect.lua`: nuevo evento `rl1` (instancia;dificultad;nombre;ítem;calidad;nombre del ítem;resultado w/p/?;ganador;su elección;su número;jefe;`quién:elección:número,…`), que se anota al cerrarse cada tirada. Se arma leyendo `CHAT_MSG_LOOT` con los textos globales del cliente (`LOOT_ROLL_NEED`, `LOOT_ROLL_ROLLED_*`, `LOOT_ROLL_WON*`, `LOOT_ROLL_ALL_PASSED`, `…_SELF`, `…_NO_SPAM_*`, etc.) en el idioma y el orden de argumentos del cliente (`fmtPattern` respeta `%2$s`); los más específicos se prueban primero. `START_LOOT_ROLL` abre la tirada (`GetLootRollItemLink`) y `ENCOUNTER_END` con éxito deja el jefe, que se asocia si la tirada empezó hasta 5 min después.
- Dos ítems iguales a la vez: cada elección y cada número van a la primera tirada abierta de ese ítem en la que esa persona no figura todavía. Una tirada sin cierre (te fuiste del grupo) se anota a los 15 min con resultado `?`. Solo dentro de mazmorras y bandas, calidad ≥ 2.
- Cada miembro del grupo con el addon anota la misma tirada; el sitio las junta en una.
- Prueba en `tests/run.lua` con los textos en español (uno con argumentos reordenados), todos pasan, ítems repetidos y tirada sin cierre.

## [0.13.5] - 2026-11-23

### Para todos

- **Punto flotando en la pantalla**: cuando alguien de la guild se conectaba, su punto del mapa aparecía en el medio de la pantalla aunque el mapa estuviera cerrado. Ahora solo se ve dentro del mapa.

### Técnico

- `Positions.lua`: `dot()` crea el marco oculto (en WoW un `CreateFrame` nuevo arranca visible y, sin anclas de HereBeDragons con el mapa cerrado, quedaba en el centro de `UIParent`); `drawPins()` oculta todos los puntos antes de volver a ponerlos. HereBeDragons los muestra al anclarlos al mapa abierto (`worldmapProviderPin:OnAcquired`).
- Prueba: con el mapa cerrado ningún punto queda visible.

## [0.13.4] - 2026-11-23

### Para todos

- **Pedidos en Forever**: el addon no reconocía tus propios pedidos (en Forever el juego no da el reino). Por eso «Mis pedidos» quedaba en 0, cada clic en «Solicitar a la Guild» creaba un pedido nuevo en vez de tildarse y los botones Trasladar, Vence, Resuelto y Cancelar no hacían nada. Ahora un clic pide, el siguiente cancela, y los botones funcionan.
- **Pedidos repetidos**: al abrir /rt pedidos (o al tildar un componente) se deja uno solo por persona y receta; los repetidos se cierran como cancelados.
- **Admins del sitio = GM**: los admins de rebirthknights.fun tienen en el addon los mismos permisos que el GM (revisar pedidos y armar la lista de revisores), aunque en la guild sean oficiales. Hace falta la app actualizada (escribe esa marca en Plans.lua).
- Si un botón de la ventana de pedidos no puede guardar, lo dice en el chat.

### Técnico

- `Requests.lua`: `full()` ya no deja «Nombre-» con el reino vacío (devuelve el nombre solo y limpia guiones de más); `short()`/`key()` toman lo que va antes del primer guion. Antes `full("Nombre-")` daba «Nombre--» y cada `build` sumaba otro: `key(r.who) ~= key(me())` (Mis pedidos, `mineFor`, el checkbox) y `accept` rechazaba el cambio por «otro pedidor». Las líneas viejas con guiones de más se reconocen igual.
- `dedupe()`: abiertos del mismo pedidor y receta (los propios, o todos si revisás) → queda el último tocado y los demás se cierran con `c;…;x`. Corre en `setItem` y al abrir la ventana.
- `isGM` suma los admins de la web: 5º campo `1` en las líneas de `RebirthTrackCouncil.players[juego]` (lo agrega la web 0.9.59; Council.lua ignora el campo). `isReviewer` incluye a `isGM`.
- Botones de la ventana con `pcall`: si fallan o el cambio no se guarda (`nil`), avisan en el chat; `refreshWin` declarado antes para que el refresco no quede en una global nula.
- `newId()` suma un contador y evita ids ya usados: dos pedidos en el mismo segundo podían chocar (1 en 256) y el segundo no se guardaba (también hacía fallar las pruebas de vez en cuando).
- Pruebas: Forever sin reino (líneas viejas con guiones, dedupe, cancelar con el botón, checkbox sin duplicar) y admin de la web como GM.

## [0.13.3] - 2026-11-23

### Para todos

- **Oficiales en cualquier rango**: si el juego te da permisos de oficial (escuchás el chat de oficiales o ves las notas de oficial), el addon te reconoce como oficial para los pedidos aunque tu rango no sea el 0 ni el 1: ves «Pendientes» y «Revisores» y tenés «Resuelto», «Cancelar», «Trasladar» y «Vence» en cada pedido.
- **«Solicitar a la Guild» se tilda siempre**: el checkbox al lado de cada componente pide el material con un clic y lo cancela con otro, aunque tengas una interfaz que cambia cómo se ven los checkboxes. Si algo falla, ahora lo dice en el chat.
- **/rt pedidos diag**: muestra tu rango, si el addon te ve como oficial y la receta elegida, para mandarlo si algo no anda.

### Técnico

- `Requests.lua`: `isReviewer` suma, además de los rangos del consejo (`RebirthTrackCouncil.ranks`, por defecto 0 y 1), los permisos propios del juego (`IsGuildLeader`/`IsGuildOfficer`/`C_GuildInfo.IsGuildOfficer`/`CanViewOfficerNote`/`CanEditOfficerNote`, todo con `pcall`); con ellos, el rango propio y los de arriba pasan a ser de oficial (`officerRanks`). El rango propio sale de `GetGuildInfo("player")`, sin esperar a que cargue la lista de la guild.
- Para que los demás acepten los cambios de ese oficial: los rangos con «escuchar chat de oficiales» de `GuildControlGetRankFlags(i)` (3er valor), solo si el rango 0 lo tiene y el más bajo no (hay clientes que ignoran el índice y devolverían lo mismo para todos).
- El checkbox alterna según el pedido guardado (`mineFor`) y no según `GetChecked()`: con el widget al revés, el clic «destildaba» un pedido inexistente y no se guardaba nada. El `OnClick` va en `pcall` y avisa en el chat si no hay receta, si no se pudo guardar o si hubo un error.
- `/rt pedidos diag` (`ns.requestsDiag`). La pestaña Revisores lista los rangos de oficial efectivos.
- Pruebas: oficial por permisos y por configuración de rangos (con el caso que ignora el índice), checkbox con el widget al revés, aviso sin receta y diagnóstico. El stub de `GetGuildInfo` devuelve el rango del personaje que la prueba simula.

## [0.13.2] - 2026-11-22

### Para todos

- **Pedidos: «Resuelto» o «Cancelado»**: el GM, los oficiales y los revisores pueden cerrar cualquier pedido de la guild marcándolo como resuelto (ya se consiguió el material) o como cancelado. Quien lo pidió también puede cerrar el suyo de las dos formas; destildarlo en la receta lo cancela.
- **Pestaña «Cerrados»** en /rt pedidos: lo resuelto, cancelado o vencido de los últimos 30 días, con su estado. Los revisores ven todos y pueden **Reabrir** uno en la guild; cada miembro ve los suyos.
- El cierre llega a todos los que tengan el addon y a la web, y lo que se cierre en la web llega al juego.

### Técnico

- `Requests.lua`: la línea `rq1` suma al final un campo opcional «cómo se cerró» (`x` cancelado, `r` resuelto), solo con estado `c`. Los addons anteriores lo ignoran y lo siguen viendo cerrado. `build` le hace lugar acortando la receta.
- `setStatus(r, "c", "r"|"x")`; reabrir (`g`) le saca el vencimiento si ya venció. Los permisos no cambian: los revisores cierran cualquiera y quien pidió, solo el suyo.
- Ventana: un cuarto botón por fila, la pestaña `closed` y los botones visibles alineados a la derecha sin huecos (la ventana pasa a 780 de ancho).
- Necesita la web 0.9.58 para guardar y mostrar el «cómo» (con la web anterior, el cierre se ve como «Cerrado»).
- Tests: resuelto y cancelado por un oficial, por quien pidió y por un miembro ajeno (rechazado), reabrir, cierre desde el sitio y los botones de la ventana.

## [0.13.1] - 2026-11-20

### Para todos

- **Plan › Talentos marca lo que ya aprendiste**: el árbol vuelve a cruzar lo gastado en el juego con el plan, como hacía la lista (antes salía todo en 0).
- **El árbol sale entero**: las tres ramas de la clase, cada talento en su lugar y con su ícono, aunque el plan esté pegado de antes y solo traiga lo planeado. Para eso usa el árbol de la clase que deja la app (sitio 0.9.57). Si no lo tiene, avisa que hay que volver a copiar el plan desde el sitio.
- Los íconos salen del juego cuando el talento es tuyo, así no quedan signos de pregunta.

### Técnico

- `Plan.lua`: `local _, token = UnitClass and UnitClass("player")` se quedaba solo con el primer valor (`token` siempre `nil`), así que el árbol armado con el plan nunca leía lo gastado. Ahora `sameClass()`.
- `planTrees()` completa un plan sin el árbol entero (sin talentos de rango 0 ni íconos) con `RebirthTrackTalents.games[juego][CLASE]` (líneas `B`/`T` de Plans.lua). Lo planeado se cruza primero por nombre (español o inglés) y por posición solo lo que no aparece por nombre. Dibuja todas las ramas, también las vacías. Sin el árbol de la clase, devuelve `partial` y la pestaña muestra el aviso.
- `traitNodes()` guarda el hechizo real del nodo y su textura; el ícono y la tooltip del árbol usan el nodo del juego que le corresponde.
- Test: plan pegado viejo de otro personaje de la misma clase con C_Traits de Forever (con y sin el árbol de la clase, y de otra clase).

## [0.13.0] - 2026-11-20

### Para todos

- **El addon le enseña a la web cómo es el juego de verdad**: anota el árbol de talentos real de tu clase y cómo son las recetas que ves en la ventana de la profesión (qué fabrican, cuántos, componentes y de qué color están a tu nivel), y lo comparte con la guild. Con eso la web corrige sola los talentos y las recetas de WoW Forever, que hoy vienen de otras fuentes y no siempre coinciden con el juego.

- **Se compra en el vendedor**: cuando lo que te falta para una receta lo vende un NPC, el addon te lo dice (en «Con lo del banco» de la ventana de profesión, en los materiales del Plan y en el detalle de Profesiones), con el vendedor, la zona y el precio. Lo aprende de los vendedores que abre cualquiera de la guild; los componentes de vendedor conocidos (hilos, tintes, especias, viales, fundentes…) ya vienen anotados.
- **Plan › Talentos como árbol siempre**: aunque el personaje con el que entrás sea de otra clase o el juego no dé los talentos (Forever), el plan se dibuja como árbol (cada talento en su fila y columna, con ícono, rango y flechas de requisito) en vez de una lista. **Plan › Legado** muestra el ícono de cada ventaja y, si el juego no deja leer tu Legado, lo planeado en lugar de «?». Sin caracteres rotos en «Próximo a tocar».
- **«Vincular» desaparece cuando el personaje ya está vinculado**: en su lugar queda la etiqueta «✓ Vinculado» (hace falta la app, que lo trae del sitio).

### Técnico

- `Vendors.lua` (nuevo): en `MERCHANT_SHOW`/`MERCHANT_UPDATE` anota lo de stock infinito y por oro (`RebirthTrackDB.vendors[ítem] = "precio;vendedor;zona;hora"`, precio por unidad) y lo manda por el canal (`V;ítem;precio;vendedor;zona`, solo lo nuevo o con otro precio, hasta 40 por vez); lo que llega se guarda si no se conocía. Lista fija de componentes de vendedor. `ns.vendorText(ítem)` lo usan BankCraft, Plan y Profesiones (y `U.icon` muestra `extra` en el tooltip).
- `Plan.lua`: lee los campos nuevos del plan (sitio 0.9.56: `T` con ícono y requisito, `L` con ícono, y los de rango 0). `planTrees()` arma las ramas con el plan cuando no se puede con `GetTalentInfo` o la clase no coincide (lo gastado, por hechizo o nombre, solo si es la misma clase); tooltip por hechizo. Legado: ícono del plan si el nodo no se leyó, y el rango planeado en vez de «?». «→» cambiado por «de»/«-» (Friz Quadrata no lo tiene).
- Vinculado: `RebirthTrackLinked` de Plans.lua (sitio 0.9.54) por versión; coincide por guid o por nombre y reino (en Forever, apellido). Sin «Vincular», Plan y Banco ocupan la fila de Personaje.
- `Collect.lua`: tipos nuevos que se comparten por el canal, uno por clave:
  - `tt1:<rama>` = `rama;CLASE;nombre;fila:columna:rango máx:id de talento:fila:columna del requisito:nombre:ícono,…` (todos los talentos de la rama, de `GetTalentInfo`/`GetTalentPrereqs`/`GetTalentLink`, al entrar).
  - `rd1:<profesión>` = `profesión;nivel;máx;id:ítem:mín:máx:dificultad:ítemxcantidad.…:nombre,…` (ventana de profesión y de «craft»; dificultad `o|y|g|r`). Si solo cambian los colores, se vuelve a mandar como mucho cada 10 puntos o una vez por hora.
- Lo procesa el sitio 0.9.53.
- Pruebas: `rd1` (componentes, dificultad, que se comparta y que un punto más no se reenvíe), `tt1`, vendedores (lo que se anota, lo limitado, el canal y la lista fija) y vinculado.

## [0.12.1] - 2026-11-20

### Para todos

- **Plan › Resumen › Materiales**: botones para ver los de una sola profesión («Todas» o cada una del plan) y **«Solo lo que falta»**, que saca los materiales de los niveles que ya pasaste (del paso en el que estás cuenta la parte que te queda). Queda elegido para la próxima vez.

### Técnico

- `Plan.lua`: `remainingMats()` suma los componentes de los pasos que terminan arriba del nivel actual (el paso a medias, proporcional) con el catálogo de `Professions.lua` (`ns.catalogReagents`). Si alguna receta no está en el catálogo, va el total de la ruta y se avisa. El filtro queda en `RebirthTrackDB.ui.planMats`.
- `refresh` declarado antes de `drawSummary` (lo usan los botones nuevos).

## [0.12.0] - 2026-11-20

### Para todos

- **Profesiones de la guild en el juego** (mosaico «Profesiones» o `/rt profesiones`), como la página de la web:
  - **Por profesión**: quién la tiene, con su barra de habilidad, cuántas recetas sabe y sus cooldowns («Transmutar: lista»), ordenado por nivel, recetas o nombre.
  - **Recetas de la guild**: todas las recetas de la profesión (las que no sabe nadie, en gris), con buscador, orden, nivel, personajes y «Solo adquiridas». Al elegir una ves el nivel que pide, los colores, los componentes (y cuántos tenés), cómo se consigue y quién la sabe hacer. «Pedir materiales» le pide a la guild lo que te falta.
  - **Clic derecho en un nombre**: susurrar, invitar al grupo o copiar el nombre.
  - El catálogo completo llega con la app; sin la app se ven las recetas que sabe alguien de la guild.
- **Tu posición se comparte siempre** con la guild (para el mapa del juego y el del sitio): ya no se puede apagar.
- En la ventana principal «Estado» pasó a ser un botón de abajo y «Vincular» va con lo tuyo.

### Técnico

- `Professions.lua` (nuevo): arma las profesiones con lo que llegó por el canal (`p1`, `sk1`, `r1:*`, `cd1:*` de `RebirthTrackDB.data`, solo personajes de la guild y de la misma versión) y el catálogo `RebirthTrackCatalog` de Plans.lua (sitio 0.9.51, `shared/addonCatalog.ts`). Limpia las listas mezcladas como `cleanRecipeList` del sitio (catálogo, venenos y mayoría de la guild). Menú propio para el clic derecho y los desplegables.
- `Requests.lua`: `ns.requestReagents(receta, componentes)` pide lo que falta de cada componente.
- Posición: `sharePos()` siempre es verdadero; sin el chip «Posición» ni la opción; `/rt posicion` solo avisa.
- Pruebas: profesiones de la guild (miembros, limpieza, filtros, sin catálogo, ventana y menú) y la posición siempre compartida.

## [0.11.4] - 2026-11-19

### Para todos

- **Los pedidos de materiales ahora le llegan al GM y a los oficiales.** En WoW Forever un pedido tildado en la receta se quedaba solo en la PC de quien lo hizo: el GM y los oficiales no lo veían en «Pendientes». Además, al conectarte ahora siempre recibís los pedidos abiertos de los que están conectados.

### Técnico

- `Requests.lua`: `key()` identifica por nombre sin reino. En Forever el reino del remitente de `CHAT_MSG_ADDON` no coincide con el de `GetNormalizedRealmName`, así que `onQ` descartaba los `Q;` de otros (`key(by) ~= key(sender)`). Las posiciones (`Collect.lua`) no comparan y por eso viajaban.
- `reply()` / `R;`: cada uno reenvía siempre sus pedidos abiertos al que entra; con solo `r.at > desde`, si el que entraba tenía cualquier cambio más nuevo, nunca recibía los anteriores.
- Pruebas: pedido de Forever con remitente de otro reino y puesta al día con «desde» más nuevo.

## [0.11.3] - 2026-11-19

### Para todos

Todo lo nuevo desde la 0.9.6 (las 0.10 y 0.11 se probaron antes con el GM):

- **Interfaz nueva en todas las ventanas**: fondos casi opacos que se leen sobre cualquier escenario, tablas con columnas, íconos de los ítems con el color de su calidad y barras de avance. La ventana que tocás pasa adelante y Esc las cierra a todas.
- **Ventana principal en mosaicos**: tu personaje y si se está registrando arriba, Mazmorras y Posición como botoncitos, y cada ventana del addon es un mosaico con ícono. «Pedidos» muestra cuántos esperan revisión. Al pasar el mouse por «Registrar» explica qué se registra.
- **Pedidos de materiales a la guild**: en la ventana de profesión, al lado de cada componente, tildá «Solicitar a la Guild» y elegí la cantidad (propone lo que te falta, descontando bolsas y banco). El GM, los oficiales y los revisores los trasladan a toda la guild desde «Pedidos de la guild» (`/rt pedidos`) o desde la web.
- Lo que pide la guild aparece en el tooltip del ítem («Requerido por la guild» y quién); **Alt+clic** abre los nombres para copiar, y te avisa al ir a vender o destruir algo que alguien necesita.
- **Plan del personaje**: los talentos como el árbol del juego y el Legado con sus 3 ramas (Aventura, Ingenio y Oficios).
- **Banco personal** con buscador que resalta lo que coincide y filtros (Componentes, Equipo, Consumibles, Pedidos).
- **Opciones** agrupadas, con «Opacidad del fondo» y para apagar los pedidos o lo del banco en las recetas. En combate se abren solas al terminar la pelea.

### Técnico

- `ns.openOptions()`: con `InCombatLockdown()` no llama a `Settings.OpenToCategory` (es protegida: `ADDON_ACTION_BLOCKED` con `OpenSettingsPanel()`); espera `PLAYER_REGEN_ENABLED` y reintenta. Texto `optCombat` (es/en).
- La ventana principal entra en `UISpecialFrames` (sin `noEsc`); al ocultarse guarda `ui.shown = false`.

## [0.11.2] - 2026-11-19

### Para todos

- Con varias ventanas del addon abiertas ya no se mezclan: la que tocás (o abrís) pasa adelante entera y las demás quedan detrás.

### Técnico

- `UI.lua`: todas las ventanas en la capa `HIGH` con `SetToplevel(true)` y `Raise()` al abrirlas, al hacer clic y al arrastrarlas (antes tenían capas distintas, MEDIUM/HIGH/DIALOG, y el mismo nivel, así que los botones de una se veían sobre la otra). Se ignora `opts.strata`.

## [0.11.1] - 2026-11-19

### Para todos

- Los botones de Mazmorras y Posición muestran bien la tilde cuando están prendidos (antes salía un cuadradito), y lo mismo en Rangos y en el Plan.
- El botón «Registrar» / «Detener» explica al pasar el mouse qué hace: qué se registra, cuándo se prende solo y cuándo lo sube la app.

### Técnico

- `UI.lua`: `ns.ui.ICON` (check, up, down, star, play) como texturas `|T…|t`; la fuente del juego no tiene ✓ ▲ ▼ ★ ▶. Reemplazados en la ventana principal, Rangos, Plan e Invitador («Canal »»).
- Tooltips `tRecStart` / `tRecStop` según el estado del registro.

## [0.11.0] - 2026-11-19

### Para todos

- **Interfaz nueva en todas las ventanas**: fondos casi opacos (se leen bien sobre cualquier escenario), franja de título, pestañas con contador, tablas con columnas y filas alternadas, íconos de los ítems con el borde de su calidad y barras de avance.
- **Ventana principal en mosaicos**: arriba tu personaje y si se está registrando, los interruptores como botoncitos (Mazmorras, Posición) y cada ventana del addon es un mosaico con ícono. «Pedidos» muestra cuántos esperan revisión.
- **Pedidos de la guild** en tabla: quién, receta, materiales con su ícono y cantidad (pasá el mouse para ver el ítem), estado, vencimiento y acciones.
- **Plan del personaje**: los talentos como el árbol del juego y el Legado con sus 3 ramas (Aventura, Ingenio y Oficios).
- **Banco personal** con buscador a todo el ancho que resalta lo que coincide, y filtros.
- **Opciones**: nueva «Opacidad del fondo» (80–100 %).

### Técnico

- `UI.lua` (nuevo, primero en los 6 `.toc`): kit visual «Obsidiana» en `ns.ui` (window, button con ancho según el texto, tabs, tableHeader/row, icon con calidad, pill, bar, dot, input, footer). Solo texturas `WHITE8x8`, sin `BackdropTemplate`. Opacidad en `settings.uiAlpha` (0.8–1, por defecto 0.96) y `ns.ui.refreshAlpha()`.
- Ventana principal reescrita (ancho fijo 340, sin redimensionar); `ns.refreshMain()` y `ns.requestsBadge()` para el contador de pedidos.
- Todas las ventanas pasan al kit; mismos textos de botones, datos y permisos.

## [0.10.1] - 2026-11-19

### Para todos

- **«Solicitar a la Guild» va por componente**: ahora el checkbox y la cantidad están al lado de cada material de la receta, no de la receta entera. Tildá solo lo que te falta; la cantidad propone lo que necesitás para hacerla una vez (descontando bolsas y banco) y la podés cambiar (Enter para guardar). Los materiales de una misma receta van juntos en un pedido; si destildás todos, se cierra.

### Técnico

- `Requests.lua`: el checkbox único de la receta (`RebirthTrackRequestBox`, «× N») se reemplaza por uno por componente (`RebirthTrackRequestPick1..n`, checkbox + EditBox numérico). Clásica: dentro de `TradeSkillReagentN` / `CraftReagentN` (arriba a la derecha). Nueva (Forever): al lado de `Name` de cada hueco de `SchematicForm.reagentSlots`, emparejado por `GetReagentSlotSchematic().reagents[1].itemID`.
- `setItem(receta, ítem, n|nil)` reemplaza a `request`/`missing`: suma, cambia o saca un ítem del pedido abierto de esa receta (crea uno `p` si no hay; lo cierra si queda vacío). El formato `rq1` y la web no cambian.

## [0.10.0] - 2026-11-19

### Para todos

- **Pedidos de materiales a la guild**: en la ventana de profesión, al lado de los componentes de la receta, tildá «Solicitar a la Guild» y elegí cuántas veces la querés hacer. Se pide solo lo que te falta (descuenta tus bolsas y tu banco). Destildalo cuando ya no lo necesites.
- **Panel «Pedidos de la guild»** (botón nuevo en la ventana o `/rt pedidos`), con pestañas: tus pedidos, los pendientes, los que ya están en la guild y los revisores. El GM y los oficiales revisan los pedidos y los trasladan a toda la guild, los cierran o les ponen vencimiento (por defecto no vencen). El GM puede sumar a otros personajes como revisores.
- Lo trasladado se ve en el tooltip del ítem (bolsas, banco, subasta, enlaces del chat): «Requerido por la guild» y quién. Con **Alt+clic** sobre el ítem se abren los nombres listos para copiar. Al abrir el vendedor o la subasta te avisa si llevás algo que pide la guild, y el cartel de destruir un ítem dice quién lo necesita.
- Los pedidos viajan entre los que tienen el addon y, con la app, llegan a la web (Profesiones › Requeridos de la guild), donde los oficiales también pueden trasladarlos.
- **Opciones nuevas** (Esc › Opciones › AddOns › Rebirth Track): apagar los pedidos a la guild y apagar lo del banco en las recetas («(+Banco n)» / «(+Parcial Banco)»). Las dos vienen prendidas.

### Técnico

- `Requests.lua` (nuevo, último en los 6 `.toc`): pedidos `rq1;id;quien pidió;creado;cambiado;estado(p|g|c);autor;vence;receta;ítem:cantidad,…` en `RebirthTrackDB.requests.lines[id]` y revisores `rv1;cambiado;GM;Nombre-Reino,…` en `RebirthTrackDB.requests.reviewers` (los sube la app). Por `RTK1`: `Q;` cambio propio (el remitente tiene que ser el autor), `W;` reenvío al que entra (vale si el autor podía), `Y;` revisores (solo del rango 0), `R;desde` al entrar. Gana la línea con `cambiado` más nuevo.
- Permisos: revisan el rango 0, los rangos del consejo (`RebirthTrackCouncil.ranks`, si no 0 y 1) y los revisores del GM. Quien pidió crea, cambia cantidades sin tocar estado ni vencimiento, y cierra. El autor `@web` solo vale desde `RebirthTrackRequests` (Plans.lua, por versión como `RebirthTrackCouncil`) o reenviado por un revisor; al cargarlo, un revisor lo reenvía con `Q;`.
- Tooltip con `TooltipDataProcessor.AddTooltipPostCall` (o `OnTooltipSetItem`), Alt+clic por `hooksecurefunc("HandleModifiedItemClick")` (WoW no deja escribir en el portapapeles: ventanita con un EditBox seleccionado), aviso en `MERCHANT_SHOW`/`AUCTION_HOUSE_SHOW` y texto extra en `StaticPopup_Show("DELETE_*")` con `GetCursorInfo`. La venta no se puede frenar sin ensuciar la interfaz protegida, por eso es un aviso.
- Versión de prueba: el tag `vX.Y.Z-pre` la sube solo al CDN (`scripts/release.sh --beta` → `addon/beta.json`) y como GitHub prerelease, sin CurseForge ni Discord. El sitio le da `beta.json` a la app de los admins y del GM. El tag `vX.Y.Z` pasa a `latest.json` el mismo zip que se probó.
- `BankCraft.lua`: `ns.recipeReagents(kind, index)` (componentes de la receta elegida, con el banco) y la opción `settings.bankCraft`. Opción `settings.requests`. Se olvidan los cerrados o vencidos hace más de 30 días (tope 400).

## [0.9.6] - 2026-11-17

### Para todos

- **Plan en Forever: talentos y Legado**: la ventana Plan ya compara tus talentos y tu Legado con el plan en WoW Forever: cuántos puntos van bien, cuál es el próximo a tocar y cuáles están fuera del plan. En la pestaña Legado, cada ventaja muestra cuántos puntos tenés (con «?» las que no se pudieron leer).
- Para que cruce bien, copiá otra vez el plan desde la web (o dejá que la app lo baje): los planes nuevos traen lo que hace falta para reconocer cada talento.

### Técnico

- `Plan.lua`: `talentState()` lee los talentos con `GetTalentInfo` (Classic) o, si no existe (Forever, visto con `/rt diag`: build 1.60.1, sin `GetNumTalentTabs`), con `C_ClassTalents.GetActiveConfigID` + `C_Traits` (`GetConfigInfo` → `GetTreeNodes` → `GetNodeInfo.ranksPurchased` → entrada → definición → `spellID`). Cada nodo se cruza con el plan por los hechizos de cada rango (`T;…;hechizos;inglés`, nuevo en la web 0.9.48) o por nombre (español o inglés).
- Legado: nodos de las configuraciones de `C_Traits.GetConfigIDBySystemID(1..80)` distintas de la de talentos, cruzados por nombre (`L;…;inglés`).
- `/rt diag` suma los nodos y puntos de talentos y de cada sistema de `C_Traits`, con nombres de muestra.

## [0.9.5] - 2026-11-17

### Para todos

- **Plan en Forever: profesiones**: la ventana Plan mostraba todas las profesiones «sin aprender» en WoW Forever, así que no comparaba el avance. Ahora lee tu nivel de cada profesión y marca en qué paso de la ruta estás.
- **Nuevo /rt diag**: muestra en el chat qué le deja ver el juego al addon de talentos y Legado. Forever no le muestra los talentos a los addons como el Classic de siempre; con lo que diga este comando se arma la comparación de talentos y Legado del Plan.

### Técnico

- `Plan.lua` `skillOf`: si no hay `GetSkillLineInfo` (Forever, motor nuevo), usa `GetProfessions` + `GetProfessionInfo`, por línea de habilidad (171, 164, 333…) o por nombre. Es el mismo respaldo que ya tenía `collectSkills` en `Collect.lua`.
- `/rt diag` (`ns.planDiag`): proyecto, build, si existen `GetNumTalentTabs`, `GetTalentInfo`, `C_ClassTalents`, `C_Traits`, `C_SpecializationInfo`… con una llamada de muestra, y los globales con «Talent», «Legacy» o «Trait». En producción no hay ningún `t1` de Forever: `collectTalents` nunca pudo leer ahí.

## [0.9.4] - 2026-11-17

### Para todos

- **Recetas con lo del banco en Forever**: en la 0.9.3 no aparecía nada en WoW Forever, porque su ventana de profesión es la nueva y no la clásica. Ahora «(+Banco n) (total)» y «(+Parcial Banco)» también salen ahí.
- **Versión a la vista**: la ventana del addon muestra la versión al lado del nombre («Rebirth Track v0.9.4»), para saber cuál tenés cargada en el juego.

### Técnico

- `BankCraft.lua`: soporte de `ProfessionsFrame` (motor de Retail, el de Forever). Las filas del `CraftingPage.RecipeList.ScrollBox` se recorren con `ForEachFrame` cada 0,25 s mientras la ventana está abierta (las filas se reciclan al bajar o buscar); la receta sale de `GetElementData():GetData().recipeInfo` y los componentes básicos de `C_TradeSkillUI.GetRecipeSchematic` (todas las calidades de un hueco suman), con el bolso por `C_Item.GetItemCount`. En Retail sigue apagado.
- `RebirthTrack.lua`: el título de la ventana suma `v<Version del .toc>`.

## [0.9.3] - 2026-11-17

### Para todos

- **Recetas con lo del banco**: en la ventana de tu profesión, cada receta te avisa si con lo que tenés en el banco podés hacer más. Por ejemplo, «[1] (+Banco 3) (4)» quiere decir que con el bolso hacés 1 y, trayendo lo del banco, 4. Con el mouse encima de «+Banco» ves qué componentes están en el banco.
- Si en el banco tenés solo una parte de lo que falta, dice «(+Parcial Banco)» y, con el mouse encima, qué ítem está en el banco y cuál te falta.
- Usa lo que anotó la ventana «Banco personal» la última vez que abriste el banco con ese personaje (sin abrirlo nunca, no aparece). Funciona en Classic, TBC/Anniversary y Forever.

### Técnico

- `BankCraft.lua` (nuevo): engancha `TradeSkillFrame_Update` y `CraftFrame_Update` (con `hooksecurefunc`, al cargar `Blizzard_TradeSkillUI`/`Blizzard_CraftUI` por `ADDON_LOADED`) y en cada fila (`TradeSkillSkillN`/`CraftN`, índice por `GetID`) cruza `Get*ReagentInfo` + `Get*ReagentItemLink` con los totales de `RebirthTrackBank`.
- `calc`: bolso = mín(⌊tengo/pido⌋), total = mín(⌊(tengo+banco)/pido⌋); si total > bolso, «(+Banco extra) (total)»; si no, «(+Parcial Banco)» cuando un componente del banco sirve para la próxima y falta otro. La etiqueta es un botón con tooltip; el clic pasa a la fila, y si no entra se achica el nombre.
- `Bank.lua`: al volver a anotar el banco, refresca las ventanas abiertas (`ns.refreshBankCraft`). Sin cambios en lo que se guarda ni en lo que se manda.

## [0.9.2] - 2026-11-17

### Para todos

- **Plan de Sastrería**: si tu juego en español llama «Costura» a Sastrería, el Plan ya encuentra tu nivel y muestra el avance.

### Técnico

- `Plan.lua`: «Costura» se suma a los nombres de `tailoring` en `PROF_NAMES` (lo que usa `skillOf` para leer el nivel con `GetSkillLineInfo`).

## [0.9.1] - 2026-11-17

### Para todos

- **Plan del personaje › Talentos como en el juego**: las tres ramas una al lado de la otra, con el ícono de cada talento en su lugar y las flechas de los requisitos. En cada talento ves lo que tenés contra lo planeado: verde listo, naranja a medias, dorado falta, rojo fuera del plan. El próximo a tocar se marca en blanco y, al pasar el mouse, aparece la tooltip del juego con lo planeado.
- Si el plan es de otra clase que el personaje con el que estás, se sigue viendo como lista.
- La ventana del plan es un poco más ancha para que entren las tres ramas.

### Técnico

- `Plan.lua`: `talentTrees()` lee las ramas con `GetTalentTabInfo`, `GetTalentInfo` (ícono, fila, columna, rango, máximo) y `GetTalentPrereqs`. `drawTalents()` arma con pools de frames las ramas y las celdas de 28 px cada 34 px, y las flechas como texturas en L.
- El árbol se dibuja solo si la clase del plan es la del personaje (`canDraw`); en cualquier otro caso queda la lista de antes. La ventana pasa de 440×500 a 500×520.
- Pruebas: dibuja las tres ramas, los estados de cada talento, la flecha del requisito, y vuelve a la lista con otra clase o en otra pestaña.

## [0.9.0] - 2026-11-16

### Para todos

- **Nuevo botón «Invitador»** en la ventana del addon (o `/rt invitar`): trae armado el mensaje para sumar gente a la guild, con lo mismo que dice la web (Horda, PvP y PvE en WoW Forever), la web y la invitación permanente al Discord.
- Con un clic lo **gritás** o lo **mandás al canal de Mundo**. Si usás otro canal, «Canal ▸» lo cambia entre los que tenés abiertos.
- Podés **editar el texto** antes de mandarlo: cada renglón sale como un mensaje. «Texto original» vuelve al de la web.
- **Invitar a la guild**: escribís el nombre (o seleccionás al personaje) y le llega la invitación, si tu rango puede invitar.
- Para que no te silencien por spam, el mismo envío se puede repetir cada 30 segundos. Los links salen como texto: en el chat del juego no se pueden clickear.

### Técnico

- `Recruit.lua` nuevo (en los 6 `.toc`, después de `Positions.lua`): `ns.openRecruit` / `ns.refreshRecruit`, botón `bRecruit` y comando `recruit` (`invitar`, `invitador`, `reclutar`, `invite`).
- El texto se parte en mensajes por renglón y, si pasa 255 bytes, por palabras; saca los `|` (en el chat arrancan un código de escape). Tope de 4 mensajes por envío.
- Todos los `SendChatMessage` (`YELL` o `CHANNEL` con el número del canal) van dentro del mismo `OnClick`: el envío a canales necesita un clic del jugador, y con un `C_Timer` no saldrían.
- `GetChannelList()` se lee de a tres (id, nombre, desactivado) o de a dos en clientes viejos. Por defecto se usa el primer canal que arranque con `world`, `mundo` o `global`; si se elige otro, se guarda por nombre en `settings.recruitChannel`, porque el número cambia.
- El texto propio queda en `settings.recruitText`; sin texto propio, el cuadro sigue al idioma y al nombre de la guild.
- La invitación usa `C_GuildInfo.Invite` si existe, y si no `GuildInvite`, con `CanGuildInvite` antes. El Discord es `discord.gg/Qvy8qeJmmv`: la API de Discord lo da sin vencimiento.
- Pruebas: partido de mensajes, elección y rotación del canal, anti-spam, grito, texto propio y restaurar, idioma, invitar por nombre, por objetivo y sin permiso.

## [0.8.3] - 2026-11-15

### Para todos

- **Arreglado el error al abrir «Posiciones de la guild»** (y al dibujar los puntos en el mapa) que trajo la 0.8.2.

### Técnico

- `SetLooping("RESTART")` no es un valor válido (solo `NONE`, `REPEAT`, `BOUNCE`) y cortaba `dot()` en Positions.lua:149. Ahora `REPEAT`, y todo el destello va en `pcall` (es adorno: si falla, el punto igual se ve); `SetScaleFrom/To` donde exista. El stub de pruebas valida `SetLooping` y se comprueba que el destello se arme.

## [0.8.2] - 2026-11-15

### Para todos

- **Puntos de la guild más visibles en el mapa**: más grandes, del color de la clase de cada uno y con borde oscuro, para que resalten sobre cualquier zona.
- **El botón «Mapa» de la lista de posiciones abre el mapa donde está esa persona** (antes el mapa volvía a tu zona) y su punto destella unos segundos.

### Técnico

- Punto de 16 px: círculo blanco (`TempPortraitAlphaMask`) teñido con `RAID_CLASS_COLORS` sobre un círculo negro, brillo y resaltado; destello con `AnimationGroup` (Alpha + Scale) desde la lista.
- `openMap`: abre con `ShowUIPanel(WorldMapFrame)` (o `ToggleWorldMap`) y recién después `SetMapID`, otra vez a los 0,1 s y 0,4 s porque al abrirse el mapa vuelve a la zona propia; cierra la lista. Prueba nueva.

## [0.8.1] - 2026-11-15

### Para todos

- **Banco personal en WoW Forever, ahora sí**: se ve tu banco y tus bolsas del banco como son. Antes aparecía un «Banco» vacío y tus cosas en una «Pestaña 1». Abrí el banco una vez para que se vuelva a anotar.

### Técnico

- En Forever el -1 trae casilleros vacíos: lo del banco está en `Enum.BagIndex.CharacterBankTab_1` y cada bolsa del banco en las siguientes. `bankLayout()`: con la pestaña 1 con casilleros, en Forever (o si además el -1 tiene casilleros) es banco = pestaña 1 + bolsas = 2..6; en Retail 11.2+, pestañas; si no, el banco clásico (-1 + `BankBag_1`…). Datos `v = 2`; lo anotado con la versión anterior avisa que hay que abrir el banco. Prueba con el caso visto en el juego.

## [0.8.0] - 2026-11-15

### Para todos

- **La guild en el mapa del juego**: cada miembro que comparte su posición aparece como un punto del color de su clase en el mapa del mundo, con su nombre, nivel y zona al pasar el mouse. No reemplaza tu mapa: se ve en el de Blizzard y en los addons de mapa que muestran puntos de otros addons (OpenMap, Mapster…). Se apaga desde las opciones o el botón «Puntos en el mapa».
- **La posición se manda como OpenMap**: cada 10 segundos mientras te movés y cada minuto si estás quieto (antes, una vez por minuto). Nada desde mazmorras ni bandas.
- **Botón «Posiciones de la guild»** en la ventana del addon (o `/rt posiciones`): la lista de todo lo que llegó, con zona, coordenadas, hace cuánto y un botón para verlo en el mapa, para comprobar que se esté sincronizando.
- **Banco personal arreglado en WoW Forever**: ahora se ve como es, con los casilleros del banco y los huecos de bolsa (los que compraste, con su bolsa, y los que no). Antes mostraba «pestañas» que Forever no tiene.
- **El banco es una ventana propia del addon**, como el Plan del personaje y el Reparto de botín: se abre con el botón «Banco personal» de la ventana del addon (o `/rt banco`), se mueve arrastrando y se cierra con Esc.

### Técnico

- `Positions.lua` nuevo: puntos con HereBeDragons-Pins 2.0 (`AddWorldMapIconMap`, `HBD_PINS_WORLDMAP_SHOW_WORLD`), un punto se va a los 150 s sin noticias (hora de llegada en la sesión, o la anotada si es más de 5 min más vieja). Librerías en `Libs/` (LibStub y CallbackHandler-1.0 de dominio público/BSD, HereBeDragons 2.18 BSD) cargadas antes que el addon.
- `collectPosition` con la cadencia de OpenMap (`Friends.lua`): mira cada 2 s, manda si se movió más de 0,002 cada 10 s y quieto cada 60 s (`put(..., force)` para refrescar la hora). No manda con 0,0 (el juego no sabe).
- `ns.onPeerPosition` (desde `putPeer`) marca cuándo se oyó a cada uno. Ventana `RebirthTrackPositionsFrame`, opción `settings.mapPins`, `/rt posiciones`.
- `bankBags(main)`: Forever corre en un cliente que define `Enum.BagIndex.CharacterBankTab_1` pero su banco es el clásico; las pestañas de Retail 11.2+ se usan solo si el banco (-1) no tiene casilleros. Las bolsas del banco arrancan en `Enum.BagIndex.BankBag_1` (o `NUM_TOTAL_EQUIPPED_BAG_SLOTS`/`NUM_BAG_SLOTS` + 1) y no se cuentan el banco ni los componentes. Pruebas para Forever y para Retail.
- La vista pasa de subpágina de las opciones a ventana `RebirthTrackBankFrame` (en `UISpecialFrames`, posición en `RebirthTrackDB.ui.bank`); el panel de opciones suma un botón «Banco personal». Se quita `ns.addOptionsPage`.

## [0.7.1] - 2026-11-15

### Para todos

- **Botón «Banco personal»** en la ventana del addon (la que abre el botón del minimapa): abre la vista del banco sin escribir `/rt banco`.

### Técnico

- Botón `bBank` en `createUI` (entre Reparto de botín y Rangos) que llama a `/rt banco`; textos en español e inglés y línea en la ayuda. Prueba en `tests/run.lua`.

## [0.7.0] - 2026-11-15

### Para todos

- **Banco personal**: cada vez que abrís el banco, el addon anota lo que hay y lo podés ver después sin ir al banco, en Esc › Opciones › AddOns › Rebirth Track › Banco personal o con `/rt banco`. Se ve como el banco del juego (casilleros, fila de bolsas y cada bolsa abierta), con el tooltip de cada ítem y un buscador. Queda solo en tu PC: no se manda al sitio ni a la guild.
- **Quién tiene el addon y la app**: el addon avisa a la guild qué versión tiene y si usás la app, y en el sitio (Miembros › Guild del juego) se marca quién tiene cada cosa y si está al día.

### Técnico

- `Bank.lua` nuevo: al abrir el banco (`BANKFRAME_OPENED` y los cambios mientras está abierto) lee el banco y sus bolsas con `C_Container` (o la API vieja), y en Retail 11.2+ las pestañas del banco del personaje y los componentes. Con el banco cerrado no se pisa lo anotado.
- Se guarda en `RebirthTrackBank` con `## SavedVariablesPerCharacter`: el juego lo escribe en `WTF/Account/<cuenta>/<reino>/<personaje>/SavedVariables/`, que la app no sube (solo `WTF/Account/*/SavedVariables/RebirthTrack.lua`). Ni `RebirthTrackDB` ni el canal `RTK1` lo llevan (lo cubre `tests/run.lua`).
- El anuncio `k1` suma dos campos al final: versión del addon (`## Version` vía `C_AddOns.GetAddOnMetadata`) y de la app (`RebirthTrackApp.version`, que el sitio agrega a `Plans.lua` con el `X-App-Version` de la app; vacío si no está). Los addons viejos guardan y reenvían los campos de más sin tocarlos.
- Vista como subpágina del panel de opciones (`ns.addOptionsPage`, `Settings.RegisterCanvasLayoutSubcategory` o `InterfaceOptions_AddCategory` con `parent`): grilla de 6 o 7 columnas, bolsas de 4, borde por calidad, cantidad, tooltip (`SetHyperlink`), mayús + clic al chat y búsqueda por nombre.

## [0.6.0] - 2026-11-15

### Para todos

- **Mapa de miembros**: el addon comparte con la guild dónde está tu personaje (zona y punto del mapa) para el mapa de miembros del sitio. Viene prendido; se apaga desde las opciones del addon, el botón «Posición» de la ventana o `/rt posicion`. Dentro de mazmorras y bandas solo se avisa en cuál estás.
- **Opciones en el menú del juego**: Rebirth Track aparece en Esc › Opciones › AddOns como los demás addons, con la posición, las mazmorras, el botón del minimapa, el idioma y accesos a la ventana y a vincular el personaje. También se abre con `/rt opciones`.

### Técnico

- Nuevo estado compartido `pos1` (`mapa;x;y;continente;x;y;zona;instancia;nombre del continente`, uiMapID y posición 0–1 con 3 decimales) en `Collect.lua`: se lee cada 60 s, al cambiar de zona y al entrar al mundo con `C_Map.GetBestMapForUnit` / `GetPlayerMapPosition`, y el continente subiendo por `parentMapID` hasta `Enum.UIMapType.Continent`. Viaja por el canal `RTK1` como los demás estados (solo si cambió). En instancias va `0;…;nombre;instanceID`; apagado, `off` (una vez) para que el sitio lo oculte.
- `settings.sharePos` (nil = prendido) con `ns.sharePos`; botón en la ventana, `/rt posicion [on|off]`.
- Panel de opciones con `Settings.RegisterCanvasLayoutCategory` + `RegisterAddOnCategory` (o `InterfaceOptions_AddCategory` en clientes viejos); `/rt opciones` lo abre. Pruebas nuevas en `tests/run.lua`.

## [0.5.3] - 2026-11-07

### Para todos

- **Recetas de profesiones**: arreglado que al pasar de una profesión a otra (por ejemplo de Peletería a Primeros auxilios) se anotaran las recetas de una como de la otra.
- **Registro de oro del banco de la guild**: al abrir el banco, el addon anota los depósitos, retiros, reparaciones y compras de pestañas (quién, cuánto y cuándo). En la web aparecen en la pestaña Balance, con lo que aportó cada uno.

### Técnico

- `readTradeSkill` (Classic): al cambiar de ventana el juego da la profesión nueva antes de cambiar la lista y, como `saveProfession` suma, la mezcla quedaba para siempre. Ahora lee dos veces (`snapTradeSkill`, con 0,5 s de diferencia, y descarta si `GetTradeSkillLine` cambia mientras lee) y solo anota si coinciden. Lo ya mezclado lo limpia la web al leer. Prueba nueva en `tests/run.lua`.
- Nuevo hecho `gm1` (`tipo;jugador;cobre`, dueño `guild:<nombre>`) desde `GetGuildBankMoneyTransaction`. Al abrir el banco se pide el registro de oro (`QueryGuildBankLog(MAX_GUILDBANK_TABS + 1)`) y se lee en `GUILDBANKLOG_UPDATE`. El juego da «hace cuánto»: cada lectura se empareja con lo ya anotado (mismo tipo, jugador y monto, a menos de 6 h, en `RebirthTrackDB.guildMoney`) y solo lo que sobra es nuevo, así dos depósitos iguales cuentan dos veces. Prueba nueva en `tests/run.lua`.

## [0.5.2] - 2026-11-05

### Para todos

- Arreglado el aviso de error «RebirthTrack ha intentado llamar a una función protegida» que podía aparecer al actualizarse la lista de la guild. Ahora, si el juego no deja leer la información de la guild, el addon simplemente la saltea y conserva la última que tenía.

### Técnico

- `collectGuildInfo` llamaba a `GetGuildRosterMOTD` y `GetGuildInfoText` desde un `C_Timer` (código del addon). En algunos clientes una es protegida: el juego dispara `ADDON_ACTION_BLOCKED` (no es un error de Lua, `pcall` no lo ataja). Ahora cada lectura marca cuál está llamando; si llega `ADDON_ACTION_BLOCKED`/`FORBIDDEN` de RebirthTrack durante la llamada, esa función se deja de llamar en la sesión y `gx1` conserva el valor anterior. Tampoco se lee en combate. Prueba nueva en `tests/run.lua`.

## [0.5.1] - 2026-11-05

### Para todos

- **WoW Forever**: el addon ahora manda tu nombre y apellido («Baldor Dwimorberg»), igual que los de la lista de la guild. Así la web te reconoce como un solo personaje aunque lo hayas vinculado con Battle.net o lo haya subido el addon.

### Técnico

- En Forever los personajes son «Nombre Apellido», únicos en la región: `GetUnitName("player", true)` y `GetGuildRosterInfo` lo dan junto. Nuevo `ns.splitSurname` / `ns.selfRealm`: el apellido viaja en el campo del reino de `p1`, `k1` y `m1` (el sitio lo guarda en ese lugar). Fuera de Forever no cambia nada (`GetRealmName()` y «Nombre-Reino» como antes).

## [0.5.0] - 2026-11-01

### Para todos

- **Reparto de botín por consejo (/rt reparto)**: al lootear un jefe, el master looter toca «Repartir» y a toda la banda le aparece cada ítem con lo que tiene puesto en esa ranura. Cada uno responde **BiS**, **Mejora**, **Off-spec**, **Transmog** o **Pasar**, con una nota si quiere.
- **El consejo vota**: oficiales y Guild Master (los rangos que diga la web) ven las respuestas ordenadas con la misma prioridad que rebirthknights.fun. Para cada uno se ve el rango, el botín recibido contra las raids asistidas y lo que ya sacó hoy. El master looter adjudica: en WoW Forever y Classic el addon entrega el ítem solo; en Retail avisa a quién comerciárselo. Lo que nadie pide va a desencantar o al banco.
- **Cada clase pide su armadura**: si el ítem es de placa y tu clase no usa placa (o tela, cuero o malla según el caso), solo podés pasar, salvo que el master looter lo abra a todos.
- **Todo queda en la web**: lo que cayó, las respuestas, los votos y a quién fue cada ítem se suben con la app (de cualquiera que la tenga) al historial de botín del sitio.
- Si el juego no deja mandar mensajes de addon en la banda, el master looter anuncia los ítems en el chat y se responde por susurro: «1 bis», «2 mejora una nota».

### Técnico

- `Council.lua` (nuevo, en todos los `.toc`): prefijo `RTLC` por el canal `RAID`/`PARTY`, con cola de envío propia en pausa en combate (y durante encuentros en Retail y Forever). Si `SendAddonMessage` devuelve un código distinto de 0 (o `false`) dos veces seguidas, pasa al modo de chat y susurros.
- Líneas nuevas en `RebirthTrackDB.council` (tope 4000), con el GUID del master looter como dueño: `lc1` reparto, `ld1` ítem, `lr1` respuesta con lo equipado (`id@ilvl`) y el ilvl que gana, `lv1` voto, `la1` adjudicación (`ml`, `trade`, `de` o `bank`), `lo1` abierto a todos y `lx1` cerrado. El estado se arma con esas líneas, así que sobrevive a un `/reload`. Quien llega tarde lo pide con `Q`.
- Validaciones de cada addon: las respuestas solo las da el propio jugador, los votos solo el consejo (rangos de `RebirthTrackCouncil.ranks`, por defecto 0 y 1, más el ML) y las adjudicaciones solo el ML. Una pieza de armadura de otro tipo solo admite «Pasar» (tipo principal por clase, `classID` 4 de `GetItemInfo`), salvo `lo1`.
- La prioridad (`ns.councilPriorityLess`) es la de `shared/lootPriority.ts` del sitio. Usa `RebirthTrackCouncil.players`, que llega en `Plans.lua`.
- Entrega con `GiveMasterLoot`/`GetMasterLootCandidate`; si el cadáver no está abierto, queda pendiente para el próximo `LOOT_OPENED`. `/rt reparto agregar [ítem]` suma ítems desde las bolsas (Retail) y `/rt reparto cerrar` cierra el reparto. Pruebas del flujo completo en `tests/run.lua`.

## [0.4.3] - 2026-11-01

### Para todos

- **Sin avisos al entrar al juego en Retail y WoW Forever**: ya no aparece el cartel «RebirthTrack se ha bloqueado de una acción disponible solo para la interfaz de usuario de Blizzard». Tampoco aparece el aviso «Error loading RebirthTrack/Plans.lua» cuando la app todavía no bajó tus planes. El registro de combate de las bandas se sigue grabando igual.

### Técnico

- Junta en una sola publicación los arreglos de la 0.4.1 y la 0.4.2: no se pide `COMBAT_LOG_EVENT_UNFILTERED` donde está restringido, y `Plans.lua` viene vacío con el addon. No hay cambios de código respecto de la 0.4.2.

## [0.4.2] - 2026-11-01

### Para todos

- **Sin el aviso «Error loading RebirthTrack/Plans.lua»**: el addon ya trae ese archivo, así que el aviso no aparece aunque la app todavía no haya bajado tus planes (por ejemplo, justo después de actualizar el addon o con la app cerrada).

### Técnico

- `RebirthTrack/Plans.lua` se incluye vacío, solo con comentarios. Los `.toc` lo cargan, pero lo escribía solo Rebirth Track Uploader, y si faltaba el juego tiraba `LUA_WARNING … Error loading RebirthTrack/Plans.lua`. Pasaba por ejemplo después de que una actualización por CurseForge reemplazara la carpeta. La app lo sigue pisando con los planes, porque `WritePlans` compara contra lo que hay en disco.
- Se sacó `RebirthTrack/Plans.lua` de `.gitignore` y de la exclusión del zip en `scripts/release.sh`.

## [0.4.1] - 2026-11-01

### Para todos

- **Sin el cartel de «acción bloqueada»**: en Retail y en WoW Forever ya no aparece al entrar al juego el aviso «RebirthTrack se ha bloqueado de una acción disponible solo para la interfaz de usuario de Blizzard». El registro de combate de las bandas se sigue grabando igual.

### Técnico

- `RebirthTrack.lua`: en Retail (12.0) y WoW Forever (`WOW_PROJECT_CAMELOT`) ya no se registra `COMBAT_LOG_EVENT_UNFILTERED`. Registrarlo dispara `ADDON_ACTION_FORBIDDEN`, y el `pcall` alrededor de `RegisterEvent` no lo evita (BugGrabber: `RebirthTrack.lua:360`, «UNKNOWN()»). Ahí no se cuentan los eventos y el resumen muestra «—» (`events.counted = false`).
- Una sola constante `RESTRICTED` para esto y para la pausa de mensajes de addon en instancias, que antes calculaba lo mismo por su cuenta.

## [0.4.0] - 2026-10-29

### Para todos

- **Tu plan en el juego (/rt plan)**: la ventana «Plan del personaje» muestra el plan que armaste en rebirthknights.fun contra tu avance real. Tiene pestañas de **Resumen**, **Profesiones** (el paso de la ruta que te toca según tu habilidad y los materiales que ya tenés en bolsas y banco), **Talentos** (cuáles tenés, cuáles faltan y el próximo a tocar) y **Legado**.
- Llega solo si tenés la app (los personajes que vinculaste en la web, al entrar o con /reload). Sin la app: en la web tocá «⚔ Para el addon» y en el juego **/rt plan → Pegar plan → Leer**.

### Técnico

- `Plan.lua`: lee bloques RTP1 (`shared/planText.ts` del sitio) con CRC-32 propio (librería `bit` de WoW o aritmética), de `RebirthTrackDB.plans` (pegados) y de `RebirthTrackPlans` (`Plans.lua`, que escribe la app; va en el `.toc` y no viene en el zip). Elige el del personaje por nombre y reino.
- Avance con la API del juego: `GetSkillLineInfo`, `GetTalentInfo` (rama, fila y columna como en el sitio), `GetItemCount(item, true)` y `UnitLevel`. Se refresca con `SKILL_LINES_CHANGED`, `CHARACTER_POINTS_CHANGED`, `BAG_UPDATE_DELAYED` y `PLAYER_LEVEL_UP`.
- Comando `/rt plan` (`planes`, `plans`) y botón «Plan del personaje» en la ventana principal; pruebas en `tests/run.lua` con un texto generado por el sitio.

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
