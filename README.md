# Addon Rebirth Track — F0 (medición)

Addon de la guild **Rebirth Knights** para [Rebirth Track](https://rebirthknights.fun). Por ahora el
addon **no sube nada** (no puede: los addons de WoW no tienen acceso a internet):

- prende el registro de combate avanzado al entrar a una banda o mazmorra;
- anota la sesión;
- sirve para medir qué datos deja el juego y cuántos.

## 1. Instalar

1. Copiá la carpeta `RebirthTrack/` (o descomprimí `RebirthTrack-f0.zip`) en la carpeta de AddOns
   de cada versión que juegues.
   - Windows: `C:\Program Files (x86)\World of Warcraft\<versión>\Interface\AddOns\`
   - Mac: `/Applications/World of Warcraft/<versión>/Interface/AddOns/`

   La carpeta de cada versión es:

   | Versión | Carpeta |
   |---|---|
   | Retail | `_retail_` |
   | Era y WoW Forever | `_classic_era_` |
   | Anniversary | `_anniversary_` |
   | MoP Classic | `_classic_` |

2. En la pantalla de personajes → **AddOns**, que figure *Rebirth Track*.
   - Si aparece "desactualizado", tildá **Cargar AddOns desactualizados**.
   - El número de interfaz real se ve en el juego con:
     ```
     /dump (select(4, GetBuildInfo()))
     ```
     Pasámelo y lo ajusto en el `.toc`.

## 2. Usar

- Al entrar a una banda dice en el chat *"registrando Karazhan… registro de combate avanzado
  ACTIVO"*. Al salir, cierra la sesión y apaga el registro (si lo había prendido él).
- Comandos:

  | Comando | Qué hace |
  |---|---|
  | `/rt` | Abre la ventana del addon (si ya está abierta, muestra el estado). |
  | `/rt mostrar` · `show` / `/rt ocultar` · `hide` | Abre o cierra la ventana (se puede mover y recuerda dónde quedó). |
  | `/rt ayuda` · `help` | Abre la ventana con la explicación de cómo usarlo. |
  | `/rt vincular` · `link` | Vincula el personaje a tu usuario de Discord en el sitio (la app lo sube al recargar o salir). |
  | `/rt estado` · `status` | Estado: registro prendido, modo avanzado, eventos, personajes, encuentros. |
  | `/rt registrar` · `start` / `/rt detener` · `stop` | Sesión manual en cualquier lado (para probar en el mundo). |
  | `/rt mazmorras` · `dungeons` | Prende o apaga el registro en mazmorras (desde 0.0.3 vienen prendidas). |
  | `/rt borrar` · `reset` | Borra las sesiones guardadas. |
  | `/rt minimapa` · `minimap` | Muestra u oculta el botón del minimapa (clic: ventana · clic derecho: vincular · arrastrar: mover). |

- El juego escribe lo anotado en
  `WTF/Account/<CUENTA>/SavedVariables/RebirthTrack.lua` **recién al hacer `/reload`, al salir o al
  desconectarse**.

## 3. Medir (una noche de raid)

Antes de entrar, en la PC donde jugás:

1. **Ritmo de volcado del log.** Dejá corriendo el vigilador en PowerShell durante la raid. Anota
   cada vez que el juego escribe el archivo y cuántos bytes:
   ```
   powershell -ExecutionPolicy Bypass -File tools\vigilar-log.ps1 -Logs "C:\Program Files (x86)\World of Warcraft\_anniversary_\Logs"
   ```
   Genera `vigilar-log.csv`.
2. **Jugar la raid** normal. Al terminar, `/rt` (anotá lo que dice) y `/reload`.
3. **Analizar el log**, con [Node.js](https://nodejs.org) instalado (en esa PC, o copiando el
   archivo a otra):
   ```
   node tools\medir-log.mjs "C:\...\Logs\WoWCombatLog-102426_210000.txt"
   ```
   Muestra:
   - tamaño y MB por hora;
   - cuánto pesaría un lote de 3 min comprimido;
   - si el modo avanzado quedó activo;
   - encuentros (kill/wipe y duración);
   - eventos más frecuentes;
   - **cada cuánto hay posición de cada jugador** (mediana, p90, p99).

## 4. Qué mandarme

- [ ] La salida de `medir-log.mjs` (o con `--json`).
- [ ] `vigilar-log.csv`.
- [ ] `RebirthTrack.lua` de SavedVariables.
- [ ] Versión jugada y el número de `/dump (select(4, GetBuildInfo()))`.
- [ ] Si se puede, el mismo ejercicio en otra versión (Forever sale el 2026-11-04).

Con eso cerramos la F0 y respondemos:
- ¿El log llega a disco seguido, o en ráfagas grandes? Define si el lote de 3 min es "casi en
  vivo".
- ¿Cuánto pesa una noche y un lote? Define el almacenamiento.
- ¿Cada cuánto hay posición de cada jugador? Define si el mapa de movimiento vale la pena.
- ¿Las tres versiones Classic escriben el mismo formato? Define si el parser es uno solo.

La subida de los registros la hace la app
[Rebirth Track Uploader](https://github.com/mgaliano-lab/rebirth-track-uploader), que además
instala y actualiza este addon sola.

## Publicar una versión

1. Subí `## Version:` en **todos** los `RebirthTrack/*.toc` y agregá la sección `## X.Y.Z` en
   `CHANGELOG.md` (español + inglés): sin ella CI no publica.
2. CurseForge: pusheá el tag `vX.Y.Z`. El workflow `release` corre las pruebas, arma el zip y lo sube a
   [CurseForge](https://legacy.curseforge.com/wow/addons/rebirth-track) (proyecto 1757092) y a un
   GitHub Release, con la sección del changelog como notas. Necesita el secret `CF_API_TOKEN`
   (token de https://legacy.curseforge.com/account/api-tokens).
3. CDN del sitio: corré `scripts/release.sh` (con `AWS_PROFILE=mgaliano`). Arma dos zip:
   - el de instalar, con `RebirthTrack/` en la raíz;
   - el de herramientas.

   Los sube a `ast.rebirthknights.fun/addon/` y actualiza `latest.json`, que es lo que ofrece la
   pantalla de Raids. Una versión ya publicada no se pisa.

## Pruebas

`lua tests/run.lua` corre el addon con una simulación mínima de la API de WoW (ventana, botones, comandos y que `/rt` quede registrado).
