-- Rebirth Track · F0 (medición)
-- Al entrar a una banda: activa el registro de combate avanzado (CVar advancedCombatLogging) y
-- /combatlog, y anota la sesión en RebirthTrackDB: instancia, grupo, encuentros y cuántos eventos
-- de combate hubo por tipo y por minuto. Al salir, apaga el registro si lo prendió el addon.
-- El juego escribe RebirthTrackDB a disco al hacer /reload, al desloguear o al desconectarse.

local ADDON, ns = ...
ns = ns or {} -- lo comparten los archivos del addon (Collect.lua)
local MAX_SESSIONS = 20
local PREFIX = "|cffe3a42cRebirth Track|r: "

local f = CreateFrame("Frame")
local session -- sesión en curso (tabla dentro de RebirthTrackDB.sessions)
local startedLogging = false -- si el /combatlog lo prendimos nosotros

-- Retail (12.0) y WoW Forever (WOW_PROJECT_CAMELOT) restringen a los addons: no pueden pedir el
-- registro de combate (COMBAT_LOG_EVENT_UNFILTERED) y no mandan mensajes de addon en instancias.
local RESTRICTED = WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1) or WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)

local function say(msg) print(PREFIX .. msg) end

-- ── Textos en español (por defecto) e inglés ───────────────────────────────────────────
-- El idioma se elige con el botón ES/EN de la ventana o /rt idioma (language) y queda guardado.
local TEXTS = {
  es = {
    recording = "registrando |cffffffff%s|r (%s) · registro de combate avanzado %s.",
    ACTIVE = "|cff3fbf3fACTIVO|r", INACTIVE = "|cffff4040INACTIVO|r",
    hm = "%d h %02d min", m = "%d min",
    sumLine = "%s |cffffffff%s|r · %s · %d jugadores · %s eventos de combate",
    noBosses = "  sin encuentros con jefes.",
    bosses = "  jefes: |cff3fbf3f%d muertos|r, |cffff4040%d wipes|r",
    more = "  ... y %d más",
    uploadedBy = "  El registro de combate lo sube la app Rebirth Track Uploader (si está abierta) a rebirthknights.fun.",
    summaryOf = "Resumen de", recordingTitle = "Registrando", lastRaid = "Última banda:",
    reloadToSave = "Hacé /reload o salí del juego para que WoW guarde el resumen en disco.",
    leftInstance = "salió de la instancia",
    linked = "|cff3fbf3f%s-%s|r anotado para vincular. La app lo sube al sitio cuando el juego guarde (al recargar o al salir).",
    linkPopup = "Rebirth Track: personaje anotado para vincular a tu cuenta.\n\n¿Recargar la interfaz ahora para que la app lo suba ya?",
    reloadNow = "Recargar ahora", later = "Después",
    statusLine = "registro de combate %s · modo avanzado %s",
    ON = "|cff3fbf3fPRENDIDO|r", off = "apagado", yes = "|cff3fbf3fsí|r", no = "|cffff4040no|r",
    noneYet = "todavía no se registró ninguna banda.",
    stop = "Detener registro", start = "Registrar ahora", dungeons = "Mazmorras: ",
    stateOn = "|cff3fbf3fRegistrando|r", stateOff = "|cff999999Registro apagado|r",
    closed = "ventana cerrada: /rt mostrar para volver a abrirla.",
    bLink = "Vincular personaje", tLink = "Asocia este personaje a tu usuario de Discord en rebirthknights.fun (/rt vincular).",
    bStatus = "Estado", tStatus = "Muestra en el chat si el registro está prendido y qué se anotó (/rt estado).",
    tRec = "Prende o apaga el registro a mano (/rt registrar · /rt detener).",
    tRecStart = "Registrar ahora: prende el registro de combate del juego (el archivo WoWCombatLog.txt, en modo avanzado) y empieza a anotar dónde estás: la banda o mazmorra, quiénes van en el grupo, los jefes que se pelean y cuánto dura. La app lo sube al sitio cuando el juego guarda (al hacer /reload o al salir).\n\nAl entrar a una banda se prende solo; usalo si no arrancó o si querés registrar algo fuera de una banda. (/rt registrar)",
    tRecStop = "Detener: apaga el registro de combate y cierra lo que se anotó de esta banda o mazmorra. La app lo sube cuando el juego guarda (al hacer /reload o al salir). Si saliste de la instancia, se detiene solo. (/rt detener)",
    bDungeons = "Mazmorras", tDungeons = "Incluir o no las mazmorras (/rt mazmorras).",
    position = "Posición: ", tPos = "Compartir o no dónde está tu personaje con la guild, para el mapa del juego y el del sitio (/rt posicion).",
    posSay = "posición %s.", shared = "|cff3fbf3fCOMPARTIDA|r con la guild", notShared = "sin compartir",
    optIntro = "Registra tus bandas y mazmorras y comparte con la guild lo que sirve para el sitio (rebirthknights.fun). La app de tu PC lo sube cuando el juego guarda: al hacer /reload o al salir.",
    optPos = "Compartir mi posición con la guild", optPosTip = "Cada minuto avisa por el canal de addons de la guild en qué zona y en qué punto del mapa está tu personaje, para el mapa de miembros del sitio. Dentro de instancias va solo la instancia. Apagado, el sitio deja de mostrarte.",
    optDungeons = "Registrar también las mazmorras", optDungeonsTip = "Prende el registro de combate al entrar a mazmorras, no solo a bandas.",
    optMinimap = "Mostrar el botón del minimapa", optMinimapTip = "El botón redondo del minimapa que abre la ventana.",
    optOpen = "Abrir la ventana", optLangTip = "Idioma del addon",
    bHelp = "Ayuda", tHelp = "Cómo se usa (/rt ayuda).", bOptions = "Opciones",
    optGroupLog = "Registro y guild", optGroupUI = "Interfaz", optAlpha = "Opacidad del fondo",
    optAlphaTip = "Qué tan opaco es el fondo de las ventanas del addon (80–100 %, por defecto 96 %).",
    sPerson = "Personaje", sGuild = "Guild", chipDun = "Mazmorras", chipPos = "Posición", recStart = "Registrar", recStop = "Detener",
    stOn = "Registrando", stOff = "Registro apagado",
    tlPlan = "Plan", tlBank = "Banco", tlStatus = "Estado", tlLoot = "Reparto", tlRequests = "Pedidos", tlPositions = "Posiciones",
    tlRecruit = "Invitador", tlRanks = "Rangos", tlLink = "Vincular",
    bLoot = "Reparto de botín", tLoot = "El reparto por consejo: responder por los ítems del jefe y, si sos del consejo, votar (/rt reparto).",
    bPlan = "Plan del personaje", tPlan = "Tu plan del sitio (ruta de profesión, talentos y Legado) contra tu avance real (/rt plan).",
    bRanks = "Rangos (oficiales)", tRanksBtn = "Aplicar los rangos de la guild que sugiere el sitio (/rt rangos).",
    bRecruit = "Invitador", tRecruit = "Mensaje para sumar gente a la guild (web y Discord): gritarlo o mandarlo al canal de Mundo, e invitar a la guild (/rt invitar).",
    bPositions = "Posiciones de la guild", tPositions = "Lista de las posiciones que llegaron por el canal (zona, coordenadas y hace cuánto) para ver que se esté sincronizando (/rt posiciones).",
    optPins = "Mostrar a la guild en el mapa del juego", optPinsTip = "Un punto del color de su clase por cada miembro que comparte su posición, en el mapa del mundo (el de Blizzard o el addon de mapa que uses). No reemplaza tu mapa.",
    bBank = "Banco personal", tBank = "Lo que tenés en el banco, sin ir al banco (/rt banco). Se anota cada vez que lo abrís y queda solo en tu PC.",
    bRequests = "Pedidos de la guild", tRequests = "Materiales que pide la gente de la guild para sus recetas. El GM, los oficiales y los revisores los trasladan a toda la guild (/rt pedidos).",
    optRequests = "Pedidos de materiales a la guild", optRequestsTip = "«Solicitar a la Guild» en las recetas, los pedidos por el canal de la guild, «Requerido por» en el tooltip de los ítems y los avisos al vender o destruir. Apagado, el addon no muestra ni reenvía pedidos.",
    optBankCraft = "Mostrar lo del banco en las recetas", optBankCraftTip = "En la ventana de profesión, «(+Banco n) (total)» y «(+Parcial Banco)» al lado de cada receta, con lo que anotó tu banco personal.",
    back = "Volver", tLang = "Cambiar el idioma a inglés (/rt idioma en).",
    mmOpen = "Clic: abrir o cerrar la ventana", mmLink = "Clic derecho: vincular este personaje",
    mmMove = "Arrastrar: moverlo · /rt minimapa: ocultarlo", tResize = "Arrastrar para cambiar el tamaño",
    dungeonsSay = "mazmorras %s.", included = "INCLUIDAS", excluded = "excluidas",
    mmSay = "botón del minimapa %s.", visible = "visible", hidden = "oculto (/rt minimapa para mostrarlo)",
    resetSay = "sesiones borradas.", unknown = "no conozco «%s». Probá /rt ayuda (o /rt help).",
    langSay = "idioma: español.",
    dataSay = "datos anotados: %d personajes tuyos, %d de la guild (recibidos por el canal del addon), %d profesiones y %d eventos. La app los sube cuando el juego guarda (/reload o al salir).",
    help = {
      "|cffe3a42cQué hace|r",
      "Al entrar a una banda o mazmorra prende el registro de combate avanzado del juego. Rebirth Track Uploader (la app de tu PC) sube esos registros a rebirthknights.fun.",
      "",
      "|cffe3a42cBotones|r",
      "• |cffffffffVincular personaje|r: lo asocia a tu usuario de Discord en el sitio (reino, región, clase y versión). La app lo manda cuando el juego guarda: al recargar o salir.",
      "• |cffffffffEstado|r: si el registro está prendido y qué se anotó.",
      "• |cffffffffRegistrar / Detener|r: a mano, si querés registrar fuera de una instancia.",
      "• |cffffffffMazmorras|r: incluir o no las mazmorras (vienen incluidas).",
      "• |cffffffffBanco personal|r: lo que tenés en el banco, sin ir al banco (queda solo en tu PC).",
      "• |cffffffffPedidos de la guild|r: tildá «Solicitar a la Guild» en una receta para pedir lo que te falta. El GM y los oficiales lo trasladan a la guild y, desde ahí, el tooltip del ítem muestra quién lo necesita (Alt+clic para copiar los nombres).",
      "• |cffffffffPosición|r: compartir o no dónde está tu personaje con la guild, para el mapa del sitio (viene compartida).",
      "• |cffffffffES / EN|r: idioma del addon.",
      "",
      "|cffe3a42cGuild|r",
      "Anota la lista de miembros de la guild y la comparte por el canal de addons con los demás que tengan Rebirth Track. Con que uno solo tenga la app, todos aparecen en el sitio; cada uno pide vincular su personaje en rebirthknights.fun.",
      "",
      "|cffe3a42cComandos|r (español o inglés)",
      "/rt mostrar · show",
      "/rt ocultar · hide",
      "/rt vincular · link",
      "/rt estado · status",
      "/rt registrar · start",
      "/rt detener · stop",
      "/rt mazmorras · dungeons",
      "/rt posicion · position (compartir o no)",
      "/rt posiciones · positions (lista de la guild)",
      "/rt invitar · invite (invitador: mensaje de reclutamiento e invitar a la guild)",
      "/rt opciones · options (Esc › Opciones › AddOns)",
      "/rt banco · bank (ventana con lo que tenés en el banco)",
      "/rt pedidos · requests (pedidos de materiales de la guild)",
      "/rt borrar · reset",
      "/rt minimapa · minimap",
      "/rt idioma · language (es / en)",
      "/rt plan · plan del personaje",
      "/rt reparto · reparto de botín (agregar [ítem] · cerrar)",
      "/rt datos · data",
      "/rt ayuda · help",
    },
  },
  en = {
    recording = "recording |cffffffff%s|r (%s) · advanced combat logging %s.",
    ACTIVE = "|cff3fbf3fON|r", INACTIVE = "|cffff4040OFF|r",
    hm = "%d h %02d min", m = "%d min",
    sumLine = "%s |cffffffff%s|r · %s · %d players · %s combat events",
    noBosses = "  no boss encounters.",
    bosses = "  bosses: |cff3fbf3f%d killed|r, |cffff4040%d wipes|r",
    more = "  ... and %d more",
    uploadedBy = "  The combat log is uploaded to rebirthknights.fun by the Rebirth Track Uploader app (if it is running).",
    summaryOf = "Summary of", recordingTitle = "Recording", lastRaid = "Last raid:",
    reloadToSave = "Type /reload or log out so WoW saves the summary to disk.",
    leftInstance = "left the instance",
    linked = "|cff3fbf3f%s-%s|r queued for linking. The app uploads it when the game saves (on reload or logout).",
    linkPopup = "Rebirth Track: character queued for linking to your account.\n\nReload the UI now so the app uploads it right away?",
    reloadNow = "Reload now", later = "Later",
    statusLine = "combat logging %s · advanced mode %s",
    ON = "|cff3fbf3fON|r", off = "off", yes = "|cff3fbf3fyes|r", no = "|cffff4040no|r",
    noneYet = "no raid recorded yet.",
    stop = "Stop recording", start = "Record now", dungeons = "Dungeons: ",
    stateOn = "|cff3fbf3fRecording|r", stateOff = "|cff999999Logging off|r",
    closed = "window closed: /rt show to open it again.",
    bLink = "Link character", tLink = "Links this character to your Discord user on rebirthknights.fun (/rt link).",
    bStatus = "Status", tStatus = "Shows in chat whether logging is on and what was recorded (/rt status).",
    tRec = "Turn logging on or off manually (/rt start · /rt stop).",
    tRecStart = "Record now: turns on the game's combat log (the WoWCombatLog.txt file, in advanced mode) and starts noting where you are: the raid or dungeon, who's in the group, the bosses you fight and how long it takes. The app uploads it to the site when the game saves (on /reload or when you log out).\n\nIt turns on by itself when you enter a raid; use this if it didn't start or to record something outside a raid. (/rt start)",
    tRecStop = "Stop: turns off the combat log and closes what was noted for this raid or dungeon. The app uploads it when the game saves (on /reload or when you log out). Leaving the instance stops it by itself. (/rt stop)",
    bDungeons = "Dungeons", tDungeons = "Include dungeons or not (/rt dungeons).",
    position = "Position: ", tPos = "Share where your character is with the guild, for the site's map (/rt position).",
    posSay = "position %s.", shared = "|cff3fbf3fSHARED|r with the guild", notShared = "not shared",
    optIntro = "Records your raids and dungeons and shares with the guild what the site (rebirthknights.fun) uses. The app on your PC uploads it when the game saves: on /reload or logout.",
    optPos = "Share my position with the guild", optPosTip = "Every minute it tells the guild addon channel which zone and where on the map your character is, for the site's member map. Inside instances only the instance is sent. Off, the site stops showing you.",
    optDungeons = "Also record dungeons", optDungeonsTip = "Turns combat logging on in dungeons too, not only raids.",
    optMinimap = "Show the minimap button", optMinimapTip = "The round minimap button that opens the window.",
    optOpen = "Open the window", optLangTip = "Addon language",
    bHelp = "Help", tHelp = "How to use it (/rt help).", bOptions = "Options",
    optGroupLog = "Logging and guild", optGroupUI = "Interface", optAlpha = "Background opacity",
    optAlphaTip = "How opaque the addon windows' background is (80–100 %, 96 % by default).",
    sPerson = "Character", sGuild = "Guild", chipDun = "Dungeons", chipPos = "Position", recStart = "Record", recStop = "Stop",
    stOn = "Recording", stOff = "Logging off",
    tlPlan = "Plan", tlBank = "Bank", tlStatus = "Status", tlLoot = "Loot", tlRequests = "Requests", tlPositions = "Positions",
    tlRecruit = "Recruit", tlRanks = "Ranks", tlLink = "Link",
    bLoot = "Loot council", tLoot = "Council loot: answer for the boss items and, if you're on the council, vote (/rt loot).",
    bPlan = "Character plan", tPlan = "Your plan from the site (profession route, talents and Legacy) against your real progress (/rt plan).",
    bRanks = "Ranks (officers)", tRanksBtn = "Apply the guild ranks the site suggests (/rt ranks).",
    bRecruit = "Recruiter", tRecruit = "Message to bring people into the guild (website and Discord): yell it or send it to the World channel, and invite to the guild (/rt invite).",
    bPositions = "Guild positions", tPositions = "List of the positions that arrived over the channel (zone, coordinates and how long ago) to check it's syncing (/rt positions).",
    optPins = "Show the guild on the game's map", optPinsTip = "A class-coloured dot for each member sharing their position, on the world map (Blizzard's or whatever map addon you use). It doesn't replace your map.",
    bBank = "Personal bank", tBank = "What's in your bank, without going there (/rt bank). Recorded every time you open it; stays on your PC only.",
    bRequests = "Guild requests", tRequests = "Materials guild members need for their recipes. The GM, officers and reviewers promote them to the whole guild (/rt requests).",
    optRequests = "Guild material requests", optRequestsTip = "«Request from the Guild» on recipes, requests over the guild channel, «Needed by» on item tooltips and the warnings when selling or destroying. Off, the addon neither shows nor relays requests.",
    optBankCraft = "Show bank items on recipes", optBankCraftTip = "In the profession window, «(+Bank n) (total)» and «(+Partial Bank)» next to each recipe, from what your personal bank recorded.",
    back = "Back", tLang = "Switch the language to Spanish (/rt language es).",
    mmOpen = "Click: open or close the window", mmLink = "Right-click: link this character",
    mmMove = "Drag: move it · /rt minimap: hide it", tResize = "Drag to resize",
    dungeonsSay = "dungeons %s.", included = "INCLUDED", excluded = "excluded",
    mmSay = "minimap button %s.", visible = "visible", hidden = "hidden (/rt minimap to show it)",
    resetSay = "sessions cleared.", unknown = "unknown command «%s». Try /rt help (or /rt ayuda).",
    langSay = "language: English.",
    dataSay = "recorded data: %d of your characters, %d from the guild (received over the addon channel), %d professions and %d events. The app uploads them when the game saves (/reload or logout).",
    help = {
      "|cffe3a42cWhat it does|r",
      "When you enter a raid or dungeon it turns on the game's advanced combat logging. Rebirth Track Uploader (the app on your PC) uploads those logs to rebirthknights.fun.",
      "",
      "|cffe3a42cButtons|r",
      "• |cffffffffLink character|r: links it to your Discord user on the site (realm, region, class and version). The app sends it when the game saves: on reload or logout.",
      "• |cffffffffStatus|r: whether logging is on and what was recorded.",
      "• |cffffffffRecord / Stop|r: manually, if you want to record outside an instance.",
      "• |cffffffffDungeons|r: include dungeons or not (included by default).",
      "• |cffffffffPersonal bank|r: what's in your bank, without going there (stays on your PC).",
      "• |cffffffffGuild requests|r: tick «Request from the Guild» on a recipe to ask for what you're missing. The GM and officers promote it to the guild, and from then on the item tooltip shows who needs it (Alt+click to copy the names).",
      "• |cffffffffPosition|r: share where your character is with the guild, for the site's map (shared by default).",
      "• |cffffffffES / EN|r: addon language.",
      "",
      "|cffe3a42cGuild|r",
      "Records the guild member list and shares it over the addon channel with everyone else running Rebirth Track. If just one member has the app, everyone shows up on the site; each player requests linking their character on rebirthknights.fun.",
      "",
      "|cffe3a42cCommands|r (English or Spanish)",
      "/rt show · mostrar",
      "/rt hide · ocultar",
      "/rt link · vincular",
      "/rt status · estado",
      "/rt start · registrar",
      "/rt stop · detener",
      "/rt dungeons · mazmorras",
      "/rt position · posicion (share or not)",
      "/rt positions · posiciones (guild list)",
      "/rt invite · invitar (recruiter: recruiting message and guild invite)",
      "/rt options · opciones (Esc › Options › AddOns)",
      "/rt bank · banco (window with what's in your bank)",
      "/rt requests · pedidos (guild material requests)",
      "/rt reset · borrar",
      "/rt minimap · minimapa",
      "/rt language · idioma (es / en)",
      "/rt plan · character plan",
      "/rt loot · loot council (add [item] · close)",
      "/rt data · datos",
      "/rt help · ayuda",
    },
  },
}
local function lang()
  local s = RebirthTrackDB and RebirthTrackDB.settings
  return (s and TEXTS[s.lang or ""]) and s.lang or "es"
end
local function L(key) return TEXTS[lang()][key] or TEXTS.es[key] or key end

local function db()
  RebirthTrackDB = RebirthTrackDB or {}
  RebirthTrackDB.sessions = RebirthTrackDB.sessions or {}
  RebirthTrackDB.settings = RebirthTrackDB.settings or {}
  -- Desde 0.0.3 las mazmorras se registran por defecto (la app ya las sube); /rt dungeons las apaga.
  local s = RebirthTrackDB.settings
  if (s.v or 0) < 3 then s.dungeons, s.v = true, 3 end
  return RebirthTrackDB
end
ns.db = db
-- Posición compartida con la guild: prendida salvo que el jugador la apague.
local function sharePos() return db().settings.sharePos ~= false end
local function setSharePos(on)
  db().settings.sharePos = on and true or false
  if ns.collectPosition then ns.collectPosition() end
end
ns.sharePos = sharePos
ns.lang = lang
ns.say = say

local function advancedOn() return GetCVar("advancedCombatLogging") == "1" end

-- El encabezado del archivo (COMBAT_LOG_VERSION … ADVANCED_LOG_ENABLED) se escribe al prender el
-- registro: si estaba prendido sin el modo avanzado, se apaga y se vuelve a prender.
local function enableLogging()
  local wasAdvanced = advancedOn()
  if not wasAdvanced then SetCVar("advancedCombatLogging", "1") end
  if LoggingCombat() then
    if not wasAdvanced then LoggingCombat(false); LoggingCombat(true) end
  else
    LoggingCombat(true)
    startedLogging = true
  end
end

local function disableLogging()
  if startedLogging and LoggingCombat() then LoggingCombat(false) end
  startedLogging = false
end

local function snapshotRoster()
  if not session then return end
  local function add(unit, subgroup)
    local guid = UnitGUID(unit)
    if not guid or session.roster[guid] then return end
    local name, realm = UnitName(unit)
    local _, class = UnitClass(unit)
    session.roster[guid] = {
      name = name, realm = (realm and realm ~= "") and realm or GetRealmName(),
      class = class, level = UnitLevel(unit), subgroup = subgroup, firstSeen = time(),
    }
  end
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local _, _, subgroup = GetRaidRosterInfo(i)
      add("raid" .. i, subgroup)
    end
  else
    add("player", 1)
    for i = 1, GetNumSubgroupMembers() do add("party" .. i, 1) end
  end
end

-- Grupos de banda (el registro de combate no los trae): al entrar a la instancia y en cada jefe se
-- anota "g1;hora;GUID=grupo,GUID=grupo…" en RebirthTrackDB.groups, y la app lo sube al sitio para
-- agrupar a los jugadores en el replay. Sin «|» a propósito: WoW lo escapa al guardar.
local MAX_GROUPS = 300
local function snapshotGroups()
  local members = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local _, _, subgroup = GetRaidRosterInfo(i)
      local guid = UnitGUID("raid" .. i)
      if guid and subgroup then members[#members + 1] = guid .. "=" .. subgroup end
    end
  else
    for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
      local guid = UnitGUID(unit)
      if guid then members[#members + 1] = guid .. "=1" end
    end
  end
  if #members == 0 then return end
  local d = db()
  d.groups = d.groups or {}
  table.insert(d.groups, "g1;" .. time() .. ";" .. table.concat(members, ","))
  while #d.groups > MAX_GROUPS do table.remove(d.groups, 1) end
end

local function startSession(reason)
  if session then return end
  local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = GetInstanceInfo()
  local _, build, _, interface = GetBuildInfo()
  enableLogging()
  session = {
    reason = reason,
    project = WOW_PROJECT_ID, build = build, interface = interface,
    instance = { name = name, type = instanceType, id = instanceID, difficultyID = difficultyID, difficulty = difficultyName, maxPlayers = maxPlayers },
    startedAt = time(), endedAt = nil,
    advanced = advancedOn(), startedLogging = startedLogging,
    roster = {}, encounters = {},
    events = { total = 0, byType = {}, perMinute = {}, counted = not RESTRICTED },
  }
  local s = db().sessions
  table.insert(s, session)
  while #s > MAX_SESSIONS do table.remove(s, 1) end
  snapshotRoster()
  snapshotGroups()
  say(L("recording"):format(name or "?", difficultyName or "", advancedOn() and L("ACTIVE") or L("INACTIVE")))
end

local function fmtDuration(sec)
  sec = math.max(0, math.floor(sec))
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  if h > 0 then return L("hm"):format(h, m) end
  return L("m"):format(m)
end

local function fmtNumber(n)
  local s = tostring(math.floor(n))
  while true do
    local r, k = s:gsub("^(%d+)(%d%d%d)", "%1.%2")
    s = r
    if k == 0 then break end
  end
  return s
end

-- Resumen de lo registrado en la sesión (al salir de la banda y con /rt status).
local function summary(sess, title)
  local finished = sess.endedAt or time()
  local players, kills, wipes = 0, 0, 0
  for _ in pairs(sess.roster) do players = players + 1 end
  for _, e in ipairs(sess.encounters) do
    if e.kill then kills = kills + 1 elseif e.finish then wipes = wipes + 1 end
  end
  say(L("sumLine"):format(
    title, sess.instance.name or "?", fmtDuration(finished - sess.startedAt), players, sess.events.counted == false and "—" or fmtNumber(sess.events.total)))
  if #sess.encounters == 0 then
    say(L("noBosses"))
  else
    say(L("bosses"):format(kills, wipes))
    for i, e in ipairs(sess.encounters) do
      if i > 12 then say(L("more"):format(#sess.encounters - 12)) break end
      local res = e.kill and "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14|t" or (e.finish and "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14|t" or "|TInterface\\RAIDFRAME\\ReadyCheck-Waiting:14|t")
      local dur = e.finish and (" (%s)"):format(fmtDuration(e.finish - e.start)) or ""
      say(("  %s %s%s"):format(res, e.name or "?", dur))
    end
  end
  say(L("uploadedBy"))
end

local function stopSession(why)
  if not session then return end
  session.endedAt = time()
  session.endReason = why
  summary(session, L("summaryOf"))
  say(L("reloadToSave"))
  session = nil
  disableLogging()
end

local function wanted()
  local _, instanceType = GetInstanceInfo()
  return instanceType == "raid" or (instanceType == "party" and db().settings.dungeons)
end

local function checkZone()
  if wanted() then
    startSession("auto")
  elseif session and session.reason == "auto" then
    stopSession("left")
  end
end

f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON then db() end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(1, checkZone) -- GetInstanceInfo tarda un instante en actualizarse
  elseif event == "GROUP_ROSTER_UPDATE" then
    snapshotRoster()
  elseif event == "ENCOUNTER_START" and session then
    local id, name, difficultyID, size = ...
    table.insert(session.encounters, { id = id, name = name, difficultyID = difficultyID, size = size, start = time() })
    snapshotRoster()
    snapshotGroups()
  elseif event == "ENCOUNTER_END" and session then
    local id, _, _, _, success = ...
    for i = #session.encounters, 1, -1 do
      local e = session.encounters[i]
      if e.id == id and not e.finish then e.finish = time(); e.kill = success == 1; break end
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and session then
    local ok, _, sub = pcall(CombatLogGetCurrentEventInfo)
    if not ok or not sub then return end
    local ev = session.events
    ev.total = ev.total + 1
    ev.byType[sub] = (ev.byType[sub] or 0) + 1
    local minute = math.floor((time() - session.startedAt) / 60)
    ev.perMinute[minute + 1] = (ev.perMinute[minute + 1] or 0) + 1
  end
end)

-- Donde está restringido no se pide el registro de combate: pedirlo ya dispara el cartel «se ha
-- bloqueado de una acción disponible solo para la interfaz de Blizzard» (ADDON_ACTION_FORBIDDEN), y
-- pcall no lo evita. Ahí no se cuentan los eventos; el archivo del registro lo sigue escribiendo el juego.
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
  "ENCOUNTER_START", "ENCOUNTER_END", not RESTRICTED and "COMBAT_LOG_EVENT_UNFILTERED" or nil }) do
  pcall(f.RegisterEvent, f, e)
end

-- ── Vincular el personaje a la cuenta de Rebirth Track ─────────────────────────────────────
-- WoW no deja que un addon se conecte a internet: el pedido queda anotado en RebirthTrackDB.links
-- y Rebirth Track Uploader (la app de la PC, ya vinculada a tu Discord) lo manda al sitio cuando el
-- juego guarda (al /reload o al salir). Formato: v1|región|reino|nombre|clase|nivel|guid|proyecto|build|hora
local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }

-- ── Guild: lista de miembros y anuncios por el canal de addons ─────────────────────────────
-- El juego le muestra a cada miembro la lista completa de la guild (nombre, rango, nivel, clase,
-- última conexión): el addon la anota en RebirthTrackDB.guild y la app de cualquiera que la tenga la
-- sube al sitio, así quedan anunciados todos los miembros aunque no tengan ni la app ni el addon.
-- Además, por el canal de addons de la guild (prefijo RTK1) cada addon anuncia su personaje y los
-- que se vinculan; los demás lo guardan y lo sube cualquiera que tenga la app. Solo se anuncia: la
-- vinculación con Discord se pide en el sitio (y la aprueba un admin).
-- Lo guardado va sin «|» (WoW lo escapa) y sin «;» en los textos (es el separador):
--   info     "gi1;guild;reino;región;proyecto;hora"
--   members  "m1;nombre;reino;clase;nivel;rango;nombre del rango;guid;segundos desde la última conexión"
--   known    "k1;hora;S|L;región;reino;nombre;clase;nivel;guid;proyecto;versión del addon;versión de la app"
--            (S = se anunció, L = pidió vincular; las versiones desde la 0.7.0, la de la app vacía si no la tiene)
-- Por el canal: "H;hora más nueva que tengo" (al entrar) y "K;…" (un personaje, mismos campos que known).
local COMM = "RTK1"
local MAX_KNOWN, MAX_REPLY = 1000, 60
local function clean(s) return (tostring(s or ""):gsub("[|;\n\"]", " ")) end
local function regionCode() return REGIONS[GetCurrentRegion and GetCurrentRegion() or 1] or "us" end
ns.regionCode = regionCode

-- WoW Forever: los personajes son «Nombre Apellido», únicos en la región y sin reino a la vista.
-- GetUnitName(unidad, true) y la lista de la guild lo dan junto ("Baldor Dwimorberg"). El sitio
-- guarda el apellido en el lugar del reino, así que en Forever se manda el apellido como «reino».
local function splitSurname(full)
  if type(full) ~= "string" then return nil, nil end
  return full:match("^(%S+) (.+)$")
end
ns.splitSurname = splitSurname
local function selfRealm()
  local _, surname = splitSurname(GetUnitName and GetUnitName("player", true))
  return surname or GetRealmName()
end
ns.selfRealm = selfRealm
local function split(s)
  local out = {}
  for part in (s .. ";"):gmatch("([^;]*);") do out[#out + 1] = part end
  return out
end

local function guildDB()
  local d = db()
  d.guild = d.guild or {}
  d.guild.known = d.guild.known or {}
  return d.guild
end

-- Índice de los personajes conocidos (guid → posición en known) y cuándo se oyó cada uno por el canal.
local knownIdx, heardAt
local function keyOf(f) return f[9] ~= "" and f[9] or (f[5] .. "-" .. f[6]) end
local function index()
  if knownIdx then return knownIdx end
  knownIdx, heardAt = {}, {}
  for i, rec in ipairs(guildDB().known) do knownIdx[keyOf(split(rec))] = i end
  return knownIdx
end

-- Guarda un personaje si es nuevo o más reciente. f son los campos de "k1;…" (f[1] = "k1").
local function remember(f)
  local ts, level = tonumber(f[2]), tonumber(f[8])
  if #f < 10 or not ts or not level or (f[3] ~= "S" and f[3] ~= "L") or f[6] == "" or f[5] == "" then return false end
  if f[9] ~= "" and not f[9]:match("^Player%-[%w%-]+$") then return false end
  local g, idx = guildDB(), index()
  local key = keyOf(f)
  local at = idx[key]
  if at then
    local old = split(g.known[at])
    if (tonumber(old[2]) or 0) >= ts then return false end
    if old[3] == "L" then f[3] = "L" end -- quien pidió vincular queda marcado
    g.known[at] = table.concat(f, ";")
  else
    table.insert(g.known, table.concat(f, ";"))
    idx[key] = #g.known
    if #g.known > MAX_KNOWN then table.remove(g.known, 1); knownIdx = nil end
  end
  return true
end

-- Versión de este addon (del .toc) y de la app: Rebirth Track Uploader la deja en Plans.lua
-- (RebirthTrackApp) junto con los planes, así que si está, la app está instalada y en uso.
local function addonVersion()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return clean(get and get(ADDON, "Version") or "")
end
local function appVersion()
  local v = type(RebirthTrackApp) == "table" and RebirthTrackApp.version
  return type(v) == "string" and v:match("^%d+%.%d+%.%d+$") or ""
end
ns.addonVersion, ns.appVersion = addonVersion, appVersion

local function selfRecord(kind)
  local _, class = UnitClass("player")
  return { "k1", time(), kind, regionCode(), clean(selfRealm()), clean(UnitName("player")), class or "",
    UnitLevel("player") or 0, UnitGUID("player") or "", WOW_PROJECT_ID or 0, addonVersion(), appVersion() }
end

-- Cola de envío: de a un mensaje cada medio segundo (el juego limita los mensajes de addons) y en
-- pausa durante el combate; en Retail también dentro de instancias, donde Blizzard los restringe.
local queue, pumping = {}, false
local function paused()
  if InCombatLockdown and InCombatLockdown() then return true end
  return RESTRICTED and IsInInstance and IsInInstance() and true or false
end
local function rawSend(msg)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(COMM, msg, "GUILD")
  elseif SendAddonMessage then SendAddonMessage(COMM, msg, "GUILD") end
end
local pump
function pump()
  if #queue == 0 then pumping = false; return end
  if paused() then C_Timer.After(5, pump); return end
  rawSend(table.remove(queue, 1))
  C_Timer.After(1, pump)
end
local function send(msg)
  if not IsInGuild() or #queue >= 600 then return end
  queue[#queue + 1] = msg
  if not pumping then pumping = true; C_Timer.After(0, pump) end
end
ns.send = send

local function announce(f)
  remember(f)
  send("K;" .. table.concat(f, ";", 2))
end

local function newestKnown()
  local newest = 0
  for _, rec in ipairs(guildDB().known) do newest = math.max(newest, tonumber(split(rec)[2]) or 0) end
  return newest
end

-- Alguien entró y dijo hasta qué hora tiene datos: tras una espera al azar se le mandan (por el
-- canal, así lo ven todos) los que tenga más nuevos, salvo los que ya mandó otro mientras tanto.
local function reply(since)
  local asked = GetTime and GetTime() or time()
  C_Timer.After(1 + math.random() * 4, function()
    local sent = 0
    for _, rec in ipairs(guildDB().known) do
      local f = split(rec)
      local key = keyOf(f)
      if (tonumber(f[2]) or 0) > since and not ((heardAt or {})[key] and heardAt[key] >= asked) then
        send("K;" .. table.concat(f, ";", 2))
        sent = sent + 1
        if sent >= MAX_REPLY then break end
      end
    end
  end)
end

local function onAddonMessage(prefix, msg, channel, sender)
  if prefix ~= COMM or channel ~= "GUILD" or type(msg) ~= "string" then return end
  if sender and Ambiguate and Ambiguate(sender, "none") == UnitName("player") then return end
  local kind, rest = msg:match("^(%a);(.*)$")
  if kind == "K" then
    local f = split("k1;" .. rest)
    index()
    if remember(f) then heardAt[keyOf(f)] = GetTime and GetTime() or time() end
  elseif kind and ns.onComm and ns.onComm[kind] then -- datos (Collect.lua)
    ns.onComm[kind](rest, sender or "")
  elseif kind == "H" then
    local since = tonumber(rest)
    if since and newestKnown() > since then reply(since) end
  end
end

-- Foto de la lista de miembros (como mucho una por minuto; el juego avisa con GUILD_ROSTER_UPDATE).
local rosterAt = 0
local function requestRoster()
  if not IsInGuild() then return end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
end
local function lastOnline(i)
  if not GetGuildRosterLastOnline then return 0 end
  local y, m, d, h = GetGuildRosterLastOnline(i)
  return ((((y or 0) * 365 + (m or 0) * 30 + (d or 0)) * 24) + (h or 0)) * 3600
end
local function snapshotGuild()
  if not IsInGuild() or time() - rosterAt < 60 then return end
  local guildName = GetGuildInfo("player")
  local n = GetNumGuildMembers()
  if not guildName or not n or n == 0 then return end
  rosterAt = time()
  local home = GetRealmName()
  local homeKey = GetNormalizedRealmName and GetNormalizedRealmName() or home:gsub("[%s%-']", "")
  local members = {}
  for i = 1, n do
    local full, rankName, rankIndex, level, _, _, note, officerNote, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
    if full then
      local name, realm = splitSurname(full) -- Forever: «Nombre Apellido»
      if not realm then
        name, realm = full:match("^([^%-]+)%-(.+)$")
        if not realm or realm == homeKey then realm = home end
      end
      members[#members + 1] = table.concat({ "m1", clean(name or full), clean(realm), class or "", level or 0, rankIndex or 0,
        clean(rankName), guid or "", online and 0 or lastOnline(i), clean(note),
        (CanViewOfficerNote and CanViewOfficerNote()) and clean(officerNote) or "" }, ";")
    end
  end
  local g = guildDB()
  local info = table.concat({ "gi1", clean(guildName), clean(home), regionCode(), WOW_PROJECT_ID or 0, time() }, ";")
  if g.info and split(g.info)[2] ~= clean(guildName) then g.known, knownIdx = {}, nil end -- otra guild: lo anunciado era de la anterior
  g.info, g.members = info, members
end

local gf = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CHAT_MSG_ADDON" }) do gf:RegisterEvent(e) end
gf:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then
    onAddonMessage(...)
  elseif event == "GUILD_ROSTER_UPDATE" then
    snapshotGuild()
  elseif event == "PLAYER_GUILD_UPDATE" then
    requestRoster()
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(COMM)
    elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(COMM) end
    -- La guild tarda unos segundos en cargarse después de entrar.
    C_Timer.After(10, function()
      if not IsInGuild() then return end
      requestRoster()
      send("H;" .. newestKnown())
      announce(selfRecord("S"))
    end)
    if C_Timer.NewTicker then C_Timer.NewTicker(300, requestRoster) end
  end
end)

local function linkCharacter()
  local name = UnitName("player")
  local realm = GetRealmName()
  local _, class = UnitClass("player")
  local build = select(1, GetBuildInfo())
  local region = REGIONS[GetCurrentRegion and GetCurrentRegion() or 1] or "us"
  local rec = table.concat({ "v1", region, realm, name, class or "", UnitLevel("player") or 0, UnitGUID("player") or "",
    WOW_PROJECT_ID or 0, build or "", time() }, "|")
  local d = db()
  d.links = d.links or {}
  for i = #d.links, 1, -1 do -- uno por personaje: el último pedido reemplaza al anterior
    if d.links[i]:find("|" .. realm .. "|" .. name .. "|", 1, true) then table.remove(d.links, i) end
  end
  table.insert(d.links, rec)
  if IsInGuild() then announce(selfRecord("L")) end -- los demás lo anotan como miembro (no lo vinculan)
  say(L("linked"):format(name, realm))
  local p = StaticPopupDialogs["REBIRTHTRACK_LINK_RELOAD"] -- textos en el idioma elegido
  p.text, p.button1, p.button2 = L("linkPopup"), L("reloadNow"), L("later")
  StaticPopup_Show("REBIRTHTRACK_LINK_RELOAD")
end

StaticPopupDialogs["REBIRTHTRACK_LINK_RELOAD"] = {
  text = "", button1 = "", button2 = "",
  OnAccept = function() ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function status()
  say(L("statusLine"):format(LoggingCombat() and L("ON") or L("off"), advancedOn() and L("yes") or L("no")))
  if session then
    summary(session, L("recordingTitle"))
  else
    local last = db().sessions[#db().sessions]
    if last then summary(last, L("lastRaid")) else say(L("noneYet")) end
  end
end

-- ── Ventana del addon ───────────────────────────────────────────────────────────────────
-- Estilo «Obsidiana» (UI.lua), en mosaicos: arriba el personaje con el estado del registro y su
-- botón, los interruptores como chips, y cada ventana del addon es un mosaico con ícono (y contador,
-- como los pedidos pendientes). La ayuda reemplaza los mosaicos. Recuerda posición y si estaba
-- abierta. /rt mostrar (show) la vuelve a abrir; /rt ayuda (help) la abre con la explicación.
local UI_W, UI_H = 340, 424
local TILE_H = 62

local ui
local function ui_db()
  local d = db()
  d.ui = d.ui or { shown = true }
  return d.ui
end

local function refreshUI()
  if not ui then return end
  local U, C = ns.ui, ns.ui.C
  ui.rec:SetKind(session and nil or "pri")
  ui.rec:SetLabel(session and L("recStop") or L("recStart"))
  ui.rec.tip = session and L("tRecStop") or L("tRecStart")
  ui.dun.tip, ui.pos.tip = L("tDungeons"), L("tPos")
  local dun, pos = db().settings.dungeons and true or false, sharePos() and true or false
  ui.dun:SetKind(dun and "on" or "off"); ui.dun:SetLabel((dun and ns.ui.ICON.check or "") .. L("chipDun"))
  ui.pos:SetKind(pos and "on" or "off"); ui.pos:SetLabel((pos and ns.ui.ICON.check or "") .. L("chipPos"))
  ui.pos:ClearAllPoints(); ui.pos:SetPoint("LEFT", ui.dun, "RIGHT", 6, 0)
  if ns.refreshOptions then ns.refreshOptions() end
  if ns.refreshRecruit then ns.refreshRecruit() end
  local on = LoggingCombat()
  ui.live:SetColor(on and C.green or C.muted)
  ui.state:SetText(on and ("|cff" .. U.HEX.green .. L("stOn") .. "|r" .. (session and session.instance and ("|cff" .. U.HEX.muted .. " · " .. session.instance.name .. "|r") or ""))
    or ("|cff" .. U.HEX.muted .. L("stOff") .. "|r"))
  local name, cls = UnitName("player"), select(2, UnitClass("player"))
  local cc = U.classColor(cls)
  ui.name:SetText(name or "")
  if ui.name.SetTextColor then ui.name:SetTextColor(cc[1], cc[2], cc[3]) end
  ui.sub:SetText((UnitLevel and UnitLevel("player") or "") .. " · " .. (UnitClass("player") or ""))
  if ui.portrait and SetPortraitTexture then pcall(SetPortraitTexture, ui.portrait, "player") end
  ui.lang:SetLabel(lang() == "es" and "EN" or "ES")
  ui.lang.tip = L("tLang")
  for _, t in ipairs(ui.tiles) do
    t.fs:SetText(L(t.label)); t.text = L(t.label)
    local n = t.badge and t.badge() or 0
    t.bd:SetShown(n > 0); t.bdText:SetText(n > 0 and tostring(n) or "")
  end
  ui.secMe:SetText(L("sPerson"):upper()); ui.secGuild:SetText(L("sGuild"):upper())
  ui.helpBtn:SetLabel(L("bHelp")); ui.optBtn:SetLabel(L("bOptions"))
  ui.optBtn:ClearAllPoints(); ui.optBtn:SetPoint("RIGHT", -10, 0)
  ui.helpBtn:ClearAllPoints(); ui.helpBtn:SetPoint("RIGHT", ui.optBtn, "LEFT", -6, 0)
  ui.back:SetLabel(L("back"))
  ui.help:SetText(table.concat(L("help"), "\n"))
  ui.helpText:SetHeight((ui.help:GetStringHeight() or 0) + 8)
end
ns.refreshMain = function() pcall(refreshUI) end

local function showHelp(on)
  ui.helpOn = on
  ui.scroll:SetShown(on)
  ui.back:SetShown(on)
  ui.body:SetShown(not on)
end

local function createUI()
  if ui then return ui end
  local U, C = ns.ui, ns.ui.C
  local u = ui_db()
  ui = U.window("RebirthTrackFrame", UI_W, UI_H, "Rebirth Track", {
    noEsc = true,
    point = { u.point or "CENTER", u.x or 300, u.y or 120 },
    onMoved = function(self) local point, _, _, x, y = self:GetPoint(); local d = ui_db(); d.point, d.x, d.y = point, x, y end,
    onClose = function() ui_db().shown = false; say(L("closed")) end,
  })
  local logo = ui.header:CreateTexture(nil, "OVERLAY")
  logo:SetSize(18, 18); logo:SetPoint("LEFT", 10, 0); logo:SetTexture("Interface\\AddOns\\RebirthTrack\\icon")
  ui.title:ClearAllPoints(); ui.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  ui.ver = U.font(ui.header, "GameFontHighlightSmall", C.muted, "LEFT"); ui.ver:SetPoint("LEFT", ui.title, "RIGHT", 6, 0)
  ui.ver:SetText(addonVersion() ~= "" and ("v" .. addonVersion()) or "")
  -- Selector de idioma: muestra el idioma al que cambia.
  ui.lang = U.button(ui.header, "EN", nil, function()
    db().settings.lang = lang() == "es" and "en" or "es"
    say(L("langSay"))
    refreshUI()
  end, { w = 30 })
  ui.lang:SetPoint("RIGHT", ui.close, "LEFT", -4, 0)

  -- Todo lo que no es la ayuda.
  ui.body = CreateFrame("Frame", nil, ui)
  ui.body:SetPoint("TOPLEFT", 0, ui.top); ui.body:SetPoint("BOTTOMRIGHT", 0, 37)

  -- Personaje y registro.
  ui.portrait = ui.body:CreateTexture(nil, "ARTWORK")
  ui.portrait:SetSize(40, 40); ui.portrait:SetPoint("TOPLEFT", 12, -10)
  local ring = U.dot(ui.body, 44, C.border); ring:SetDrawLayer("BACKGROUND"); ring:SetPoint("CENTER", ui.portrait, "CENTER", 0, 0)
  ui.name = U.font(ui.body, "GameFontNormal", C.text, "LEFT"); ui.name:SetPoint("TOPLEFT", ui.portrait, "TOPRIGHT", 10, -2)
  ui.sub = U.font(ui.body, "GameFontHighlightSmall", C.muted, "LEFT"); ui.sub:SetPoint("LEFT", ui.name, "RIGHT", 6, 0)
  ui.live = U.dot(ui.body, 8, C.green); ui.live:SetPoint("TOPLEFT", ui.name, "BOTTOMLEFT", 0, -7)
  ui.state = U.font(ui.body, "GameFontHighlightSmall", C.text, "LEFT"); ui.state:SetPoint("LEFT", ui.live, "RIGHT", 6, 0)
  ui.state:SetPoint("RIGHT", ui.body, "RIGHT", -90, 0)
  ui.rec = U.button(ui.body, "", nil, function()
    if session then stopSession("manual") else startSession("manual") end
    refreshUI()
  end, { min = 70 })
  ui.rec:SetPoint("TOPRIGHT", -12, -18)

  -- Interruptores como chips.
  ui.dun = U.button(ui.body, "", "on", function() db().settings.dungeons = not db().settings.dungeons; checkZone(); refreshUI() end)
  ui.dun:SetPoint("TOPLEFT", 12, -60); ui.dun.tip = L("tDungeons")
  ui.pos = U.button(ui.body, "", "off", function() setSharePos(not sharePos()); refreshUI() end)
  ui.pos.tip = L("tPos")
  U.hline(ui.body, -92, 0)

  -- Mosaicos.
  local function slash(cmd) return function() SlashCmdList.REBIRTHTRACK(cmd) end end
  ui.tiles = {}
  local tileW = math.floor((UI_W - 24 - 12) / 3)
  local function tile(label, icon, tipKey, onClick, x, y, badge)
    local t = CreateFrame("Button", nil, ui.body)
    t:SetSize(tileW, TILE_H)
    t:SetPoint("TOPLEFT", 12 + x * (tileW + 6), y)
    t.bgT = U.fill(t, { 0.078, 0.090, 0.118 }, 1)
    t.edgeT = U.edge(t, C.line, 1)
    t.ic = t:CreateTexture(nil, "ARTWORK"); t.ic:SetSize(26, 26); t.ic:SetPoint("TOP", 0, -9); t.ic:SetTexture(icon)
    if t.ic.SetTexCoord then t.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    t.fs = U.font(t, "GameFontHighlightSmall", C.text, "CENTER"); t.fs:SetPoint("BOTTOM", 0, 8); t.fs:SetWidth(tileW - 8)
    if t.fs.SetWordWrap then t.fs:SetWordWrap(false) end
    t.bd = CreateFrame("Frame", nil, t); t.bd:SetSize(18, 16); t.bd:SetPoint("TOPRIGHT", -4, -4)
    U.fill(t.bd, C.action, 1)
    t.bdText = U.font(t.bd, "GameFontHighlightSmall", { 0.09, 0.075, 0.04 }, "CENTER"); t.bdText:SetPoint("CENTER", 0, 0)
    t.bd:Hide()
    t.label, t.badge = label, badge
    t:SetScript("OnClick", function() onClick(); refreshUI() end)
    t:SetScript("OnEnter", function(self)
      self.edgeT:SetColor(C.border[1], C.border[2], C.border[3], 1)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L(tipKey), 1, 1, 1, true); GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self) self.edgeT:SetColor(C.line[1], C.line[2], C.line[3], 1); GameTooltip:Hide() end)
    ui.tiles[#ui.tiles + 1] = t
    return t
  end
  ui.secMe = U.label(ui.body, ""); ui.secMe:SetPoint("TOPLEFT", 12, -102)
  tile("tlPlan", "Interface\\Icons\\INV_Misc_Book_09", "tPlan", slash("plan"), 0, -118)
  tile("tlBank", "Interface\\Icons\\INV_Misc_Bag_08", "tBank", slash("banco"), 1, -118)
  tile("tlStatus", "Interface\\Icons\\INV_Misc_PocketWatch_01", "tStatus", function() status() end, 2, -118)
  ui.secGuild = U.label(ui.body, ""); ui.secGuild:SetPoint("TOPLEFT", 12, -190)
  tile("tlLoot", "Interface\\Icons\\INV_Misc_Coin_01", "tLoot", slash("reparto"), 0, -206)
  tile("tlRequests", "Interface\\Icons\\INV_Crate_01", "tRequests", slash("pedidos"), 1, -206, function() return ns.requestsBadge and ns.requestsBadge() or 0 end)
  tile("tlPositions", "Interface\\Icons\\INV_Misc_Map_01", "tPositions", slash("posiciones"), 2, -206)
  tile("tlRecruit", "Interface\\Icons\\Ability_Warrior_BattleShout", "tRecruit", slash("invitar"), 0, -274)
  tile("tlRanks", "Interface\\Icons\\INV_BannerPVP_02", "tRanksBtn", slash("rangos"), 1, -274)
  tile("tlLink", "Interface\\Icons\\INV_Misc_Key_03", "tLink", linkCharacter, 2, -274)

  -- Pie: versión, ayuda y opciones.
  local ft = U.footer(ui, 36)
  ui.helpBtn = U.button(ft, "", nil, function() showHelp(true) end)
  ui.helpBtn.tip = L("tHelp")
  ui.optBtn = U.button(ft, "", nil, function() if ns.openOptions then ns.openOptions() end end)
  ui.back = U.button(ft, "", "pri", function() showHelp(false) end)
  ui.back:SetPoint("LEFT", 10, 0)

  -- Ayuda: texto largo dentro de un área con scroll.
  ui.scroll = CreateFrame("ScrollFrame", "RebirthTrackHelpScroll", ui, "UIPanelScrollFrameTemplate")
  ui.scroll:SetPoint("TOPLEFT", 12, ui.top - 8)
  ui.scroll:SetPoint("BOTTOMRIGHT", -30, 44)
  ui.helpText = CreateFrame("Frame", nil, ui.scroll)
  ui.helpText:SetSize(UI_W - 50, 400)
  ui.scroll:SetScrollChild(ui.helpText)
  ui.help = ui.helpText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.help:SetPoint("TOPLEFT", 2, -2)
  ui.help:SetWidth(UI_W - 54)
  ui.help:SetJustifyH("LEFT")
  ui.help:SetJustifyV("TOP")
  if ui.help.SetWordWrap then ui.help:SetWordWrap(true) end

  refreshUI()
  showHelp(false)
  return ui
end

local function openUI(help)
  createUI()
  ui:Show()
  ui_db().shown = true
  refreshUI()
  showHelp(help and true or false)
end

-- ── Botón en el minimapa ─────────────────────────────────────────────────────────────────
-- Clic: abre/cierra la ventana · arrastrar: lo mueve alrededor del minimapa · /rt minimapa lo oculta.
local ICON = "Interface\\AddOns\\RebirthTrack\\icon"
local mm
local function placeMinimap(angle)
  local r = (Minimap:GetWidth() / 2) + 6
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end
local function createMinimapButton()
  if mm or not Minimap then return end
  mm = CreateFrame("Button", "RebirthTrackMinimapButton", Minimap)
  mm:SetSize(31, 31)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mm:RegisterForDrag("LeftButton")
  local icon = mm:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(ICON)
  local border = mm:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then linkCharacter(); return end
    if ui and ui:IsShown() then ui:Hide(); ui_db().shown = false else openUI(false) end
  end)
  mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      local a = math.atan2(cy / s - my, cx / s - mx)
      ui_db().minimapAngle = a
      placeMinimap(a)
    end)
  end)
  mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Rebirth Track")
    GameTooltip:AddLine(L("mmOpen"), 1, 1, 1)
    GameTooltip:AddLine(L("mmLink"), 1, 1, 1)
    GameTooltip:AddLine(L("mmMove"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeMinimap(ui_db().minimapAngle or math.rad(200))
  mm:SetShown(ui_db().minimap ~= false)
end

-- ── Panel en Esc › Opciones › AddOns ──────────────────────────────────────────────────────
-- Las mismas opciones que la ventana, en la pestaña de AddOns del juego como los demás addons.
-- Retail y los clientes nuevos usan Settings.RegisterCanvasLayoutCategory; los viejos,
-- InterfaceOptions_AddCategory. /rt opciones lo abre.
local options, optionsCategory
-- Dos columnas de paneles planos (sin marco de ventana: vive dentro del lienzo de Blizzard).
local OPT_PW, OPT_GAP, OPT_ROW, OPT_ALPHA_H = 290, 12, 30, 46

local function setAlphaText(pct)
  if not options or not options.alphaPct then return end
  options.alphaPct:SetText(pct .. " %")
  local frac = (pct - 80) / 20
  if options.alphaFill then
    options.alphaFill:SetWidth(math.max(0.001, (OPT_PW - 24) * math.max(0, math.min(1, frac))))
  end
end

local function refreshOptions()
  if not options then return end
  options.intro:SetText(L("optIntro"))
  local v = addonVersion()
  options.version:SetText(v ~= "" and ("v" .. v) or "")
  options.groupLog:SetText(L("optGroupLog"):upper())
  options.groupUI:SetText(L("optGroupUI"):upper())
  for _, c in ipairs(options.checks) do c:SetChecked(c.get() and true or false); c.label:SetText(L(c.key)) end
  options.alphaLabel:SetText(L("optAlpha"))
  local pct = math.floor(ns.ui.alpha() * 100 + 0.5)
  options.syncing = true
  if options.alpha and options.alpha.SetValue then options.alpha:SetValue(pct) end
  options.syncing = false
  setAlphaText(pct)
  options.open:SetLabel(L("optOpen"))
  options.link:SetLabel(L("bLink"))
  options.bank:SetLabel(L("bBank"))
  options.lang:SetLabel(lang() == "es" and "English" or "Español")
end
ns.refreshOptions = refreshOptions

local function createOptions()
  if options then return end
  local U, C = ns.ui, ns.ui.C
  options = CreateFrame("Frame", "RebirthTrackOptions", UIParent)
  options.name = "Rebirth Track"
  options:Hide()
  local logo = options:CreateTexture(nil, "ARTWORK")
  logo:SetSize(28, 28)
  logo:SetPoint("TOPLEFT", 16, -14)
  logo:SetTexture(ICON)
  local title = U.font(options, "GameFontNormalLarge", C.gold, "LEFT")
  title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  title:SetText("Rebirth Track")
  options.version = U.font(options, "GameFontHighlightSmall", C.muted, "LEFT")
  options.version:SetPoint("LEFT", title, "RIGHT", 8, 0)
  options.intro = U.font(options, "GameFontHighlightSmall", C.text, "LEFT")
  options.intro:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
  options.intro:SetWidth(OPT_PW * 2 + OPT_GAP)

  -- Etiqueta de sección + panel plano debajo, en la columna `col` (0 o 1).
  local function group(col, h)
    local lbl = U.label(options, "")
    lbl:SetPoint("TOPLEFT", options.intro, "BOTTOMLEFT", col * (OPT_PW + OPT_GAP), -16)
    local p = CreateFrame("Frame", nil, options)
    p:SetSize(OPT_PW, h)
    p:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
    U.fill(p, C.sub, 1)
    U.edge(p, C.line, 1)
    p.n = 0
    return lbl, p
  end
  local LOG_H, UI_H2 = 4 * OPT_ROW, 2 * OPT_ROW + OPT_ALPHA_H
  local logLbl, logP = group(0, LOG_H)
  local uiLbl, uiP = group(1, UI_H2)
  options.groupLog, options.groupUI = logLbl, uiLbl

  options.checks = {}
  local function check(panel, key, tipKey, get, set)
    local y = -panel.n * OPT_ROW
    if panel.n > 0 then U.hline(panel, y, 1) end
    panel.n = panel.n + 1
    local c = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", 6, y - 3)
    c.label = U.font(panel, "GameFontHighlight", C.text, "LEFT")
    c.label:SetPoint("LEFT", c, "RIGHT", 4, 0)
    c.label:SetWidth(OPT_PW - 44)
    if c.label.SetWordWrap then c.label:SetWordWrap(false) end
    c.key, c.get = key, get
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); refreshUI(); refreshOptions() end)
    c:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L(tipKey), 1, 1, 1, true); GameTooltip:Show() end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(options.checks, c)
    return c
  end
  check(logP, "optDungeons", "optDungeonsTip", function() return db().settings.dungeons end,
    function(on) db().settings.dungeons = on; checkZone() end)
  check(logP, "optPos", "optPosTip", sharePos, setSharePos)
  check(logP, "optPins", "optPinsTip", function() return db().settings.mapPins ~= false end,
    function(on) db().settings.mapPins = on; if ns.refreshPositions then ns.refreshPositions() end end)
  check(logP, "optRequests", "optRequestsTip", function() return db().settings.requests ~= false end,
    function(on) db().settings.requests = on end)
  check(uiP, "optMinimap", "optMinimapTip", function() return ui_db().minimap ~= false end,
    function(on) ui_db().minimap = on; if mm then mm:SetShown(on) end end)
  check(uiP, "optBankCraft", "optBankCraftTip", function() return db().settings.bankCraft ~= false end,
    function(on) db().settings.bankCraft = on; if ns.refreshBankCraft then pcall(ns.refreshBankCraft) end end)

  -- Opacidad del fondo de las ventanas (80–100 %): se guarda como 0.8–1 y se aplica en el acto.
  local ay = -uiP.n * OPT_ROW
  U.hline(uiP, ay, 1)
  options.alphaLabel = U.font(uiP, "GameFontHighlight", C.text, "LEFT")
  options.alphaLabel:SetPoint("TOPLEFT", 12, ay - 8)
  options.alphaLabel:SetWidth(OPT_PW - 80)
  if options.alphaLabel.SetWordWrap then options.alphaLabel:SetWordWrap(false) end
  options.alphaPct = U.font(uiP, "GameFontHighlight", C.gold, "RIGHT")
  options.alphaPct:SetPoint("TOPRIGHT", -12, ay - 8)
  options.alphaPct:SetWidth(50)
  local track = U.tex(uiP, "ARTWORK", C.line)
  track:SetHeight(4)
  track:SetPoint("TOPLEFT", 12, ay - 32); track:SetPoint("TOPRIGHT", -12, ay - 32)
  options.alphaFill = U.tex(uiP, "ARTWORK", C.action)
  options.alphaFill:SetHeight(4)
  options.alphaFill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
  local ok, s = pcall(CreateFrame, "Slider", nil, uiP)
  if ok and s then
    s:SetHeight(16)
    s:SetPoint("LEFT", track, "LEFT", 0, 0); s:SetPoint("RIGHT", track, "RIGHT", 0, 0)
    if s.SetOrientation then s:SetOrientation("HORIZONTAL") end
    if s.SetMinMaxValues then s:SetMinMaxValues(80, 100) end
    if s.SetValueStep then s:SetValueStep(1) end
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    if s.EnableMouse then s:EnableMouse(true) end
    if s.SetThumbTexture then
      local thumb = U.tex(s, "OVERLAY", C.gold)
      thumb:SetSize(8, 14)
      s:SetThumbTexture(thumb)
    end
    s:SetScript("OnValueChanged", function(_, value)
      local pct = math.floor((tonumber(value) or 96) + 0.5)
      pct = math.max(80, math.min(100, pct))
      setAlphaText(pct)
      if options.syncing then return end
      db().settings.uiAlpha = pct / 100
      if U.refreshAlpha then U.refreshAlpha() end
    end)
    s:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L("optAlphaTip"), 1, 1, 1, true); GameTooltip:Show() end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    options.alpha = s
  end

  local function button(kind, onClick)
    return U.button(options, "", kind, function() onClick(); refreshUI(); refreshOptions() end, { h = 24 })
  end
  options.open = button("pri", function() openUI(false) end)
  options.open:SetPoint("TOPLEFT", logP, "BOTTOMLEFT", 0, -14)
  options.link = button(nil, linkCharacter)
  options.link:SetPoint("LEFT", options.open, "RIGHT", 8, 0)
  options.bank = button(nil, function() if ns.openBank then ns.openBank() end end)
  options.bank:SetPoint("LEFT", options.link, "RIGHT", 8, 0)
  options.lang = button(nil, function() db().settings.lang = lang() == "es" and "en" or "es"; say(L("langSay")) end)
  options.lang:SetPoint("TOPRIGHT", uiP, "TOPRIGHT", 0, -(LOG_H + 14))

  options:SetScript("OnShow", refreshOptions)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    optionsCategory = Settings.RegisterCanvasLayoutCategory(options, options.name)
    Settings.RegisterAddOnCategory(optionsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(options)
  end
  refreshOptions()
end

function ns.openOptions()
  createOptions()
  if optionsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(optionsCategory.GetID and optionsCategory:GetID() or optionsCategory.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(options); InterfaceOptionsFrame_OpenToCategory(options) -- la 1.ª vez no baja hasta el panel
  end
end

local uf = CreateFrame("Frame")
uf:RegisterEvent("PLAYER_LOGIN")
uf:RegisterEvent("PLAYER_ENTERING_WORLD")
uf:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    createUI()
    createMinimapButton()
    createOptions()
    if ui_db().shown == false then ui:Hide() end
  end
  C_Timer.After(1.5, refreshUI)
end)

-- Comandos en español o inglés.

-- ── Rangos de la guild (oficiales) ───────────────────────────────────────────────────────────
-- El sitio arma un código con el rango que le toca a cada uno según sus roles de Discord
-- (Miembros › Guild del juego › «Copiar para el addon»): «RTR1:Nombre=2,Otro=4». Se pega en esta
-- ventana (o /rt rangos RTR1:…) y la lista de la guild muestra, en cada miembro que tiene que
-- cambiar, un botón propio. Cada clic hace un solo ascenso o descenso con GuildPromote/GuildDemote,
-- que es lo que el juego permite: nada se aplica solo ni en lote.
local RT = {
  es = {
    title = "Rangos de la guild", paste = "Pegá acá lo que copiaste del sitio (Miembros › Guild del juego › Copiar para el addon):",
    read = "Leer", none = "|cff3fbf3fTodos tienen el rango que les toca.|r", noCode = "Pegá el código del sitio para ver qué cambiar.",
    noPerm = "necesitás ser oficial o Guild Master para cambiar rangos.", bad = "el código no es válido: copialo de nuevo del sitio.",
    pending = "%d por cambiar · un clic por paso", missing = "no está en la guild", ok = "",
    promote = "Subir a %s", demote = "Bajar a %s", done = "%s: %s → %s.", onlyChanges = "Solo los que cambian",
    colWho = "Jugador", colNow = "Ahora", colTo = "Le toca", foot = "Primero los que cambian, después los que están bien.",
  },
  en = {
    title = "Guild ranks", paste = "Paste what you copied from the site (Members › In-game guild › Copy for the addon):",
    read = "Read", none = "|cff3fbf3fEveryone has the right rank.|r", noCode = "Paste the site's code to see what to change.",
    noPerm = "you need to be an officer or Guild Master to change ranks.", bad = "the code isn't valid: copy it again from the site.",
    pending = "%d to change · one click per step", missing = "not in the guild", ok = "",
    promote = "Promote to %s", demote = "Demote to %s", done = "%s: %s → %s.", onlyChanges = "Only the ones that change",
    colWho = "Player", colNow = "Now", colTo = "Should be", foot = "The ones that change first, then the ones that are fine.",
  },
}
local function RL(k) return (RT[lang()] or RT.es)[k] or RT.es[k] end

local function parseRanks(code)
  local body = code and code:match("RTR1:(%S+)")
  if not body then return nil end
  local out, n = {}, 0
  for name, rank in body:gmatch("([^,=]+)=(%d+)") do out[name] = tonumber(rank); n = n + 1 end
  return n > 0 and out or nil
end

local function rankName(idx) return GuildControlGetRankName and GuildControlGetRankName(idx + 1) or ("#" .. idx) end
local function rerequestRoster() if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end end

-- La guild del juego con el rango que le toca a cada uno según el código: primero los que tienen que
-- cambiar, después los que están bien y al final los del código que ya no están en la guild.
local function rankRows(want)
  local rows, seen = {}, {}
  for i = 1, GetNumGuildMembers() do
    local full, _, rankIndex, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
    if full then
      local short = full:match("^[^-]+")
      seen[short] = true
      local target = want and want[short]
      -- El Guild Master (0) no se toca: ni se asciende a nadie a GM ni se lo baja.
      local change = target and target > 0 and rankIndex > 0 and target ~= rankIndex
      table.insert(rows, { name = short, full = full, rank = rankIndex, to = change and target or nil, online = online, class = class })
    end
  end
  for name in pairs(want or {}) do if not seen[name] then table.insert(rows, { name = name, missing = true }) end end
  local order = function(r) return r.to and 0 or r.missing and 2 or 1 end
  table.sort(rows, function(a, b) if order(a) ~= order(b) then return order(a) < order(b) end return a.name < b.name end)
  return rows
end

local rk, ROW_H = nil, 28
local RK_W, RK_H, RK_PASTE, RK_FOOT = 440, 520, 92, 28
local RK_LIST_W = RK_W - 24 -- lo que deja la barra de scroll
local RK_COLS = { { "who", 0, "" }, { "now", 96, "" }, { "arrow", 18, "" }, { "to", 96, "" }, { "act", 124, "", "RIGHT" } }
local function rankCode() return db().rankCode end

-- Un paso para ese miembro (ascender = índice más chico). Lo dispara el clic en su botón.
local function stepRank(row)
  local up = row.to < row.rank
  if (up and not CanGuildPromote()) or (not up and not CanGuildDemote()) then say(RL("noPerm")); return end
  if up then GuildPromote(row.full) else GuildDemote(row.full) end
  say(RL("done"):format(row.name, rankName(row.rank), rankName(up and row.rank - 1 or row.rank + 1)))
  rerequestRoster()
end

-- Botón «Bajar a …» en ámbar: el kit no trae ese color, se pinta encima del secundario.
local function amberKind(b)
  local base, C = b.SetKind, ns.ui.C
  function b.SetKind(self, k)
    if k ~= "amber" then return base(self, k) end
    self.kind = k
    if self.bgT.SetVertexColor then self.bgT:SetVertexColor(0.16, 0.13, 0.07, 1) end
    self.edgeT:SetColor(0.478, 0.353, 0.118, 1)
    if self.fs.SetTextColor then self.fs:SetTextColor(C.amber[1], C.amber[2], C.amber[3]) end
  end
end

local function rankLine(i)
  local U, C = ns.ui, ns.ui.C
  local pos = rk.pos
  local line = U.row(rk.list, ROW_H, i)
  line:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H); line:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
  line.dot = U.dot(line, 10, C.text); line.dot:SetPoint("LEFT", 8 + pos.who.x, 0)
  line.name = U.font(line, "GameFontHighlightSmall", C.text, "LEFT"); line.name:SetPoint("LEFT", line.dot, "RIGHT", 6, 0)
  line.name:SetWidth(pos.who.w - 24)
  if line.name.SetWordWrap then line.name:SetWordWrap(false) end
  line.now = U.pill(line); line.now:SetPoint("LEFT", 8 + pos.now.x, 0)
  line.miss = U.font(line, "GameFontHighlightSmall", C.muted, "LEFT"); line.miss:SetPoint("LEFT", 8 + pos.now.x, 0)
  line.miss:SetWidth(pos.now.w + pos.arrow.w + pos.to.w - 8)
  line.arrow = U.font(line, "GameFontHighlightSmall", C.green, "CENTER"); line.arrow:SetPoint("LEFT", 8 + pos.arrow.x - 4, 0); line.arrow:SetWidth(pos.arrow.w)
  line.to = U.font(line, "GameFontHighlightSmall", C.green, "LEFT"); line.to:SetPoint("LEFT", 8 + pos.to.x, 0); line.to:SetWidth(pos.to.w - 8)
  if line.to.SetWordWrap then line.to:SetWordWrap(false) end
  line.btn = U.button(line, "", "on", function(b) if b.row then b:SetEnabled(false); stepRank(b.row) end end)
  amberKind(line.btn)
  line.btn:SetPoint("RIGHT", -8, 0)
  line.state = U.font(line, "GameFontHighlightSmall", C.green, "RIGHT"); line.state:SetPoint("RIGHT", -12, 0)
  return line
end

local function refreshRanks()
  if not rk then return end
  local U, C = ns.ui, ns.ui.C
  rk.title:SetText(RL("title")); rk.hint:SetText(RL("paste")); rk.read:SetLabel(RL("read")); rk.onlyLbl:SetText(RL("onlyChanges"))
  rk.foot:SetText(RL("foot"))
  rk.head.cells.who:SetText(RL("colWho"):upper()); rk.head.cells.now:SetText(RL("colNow"):upper()); rk.head.cells.to:SetText(RL("colTo"):upper())
  local want = rankCode() and parseRanks(rankCode())
  local rows, pending = rankRows(want), 0
  for _, r in ipairs(rows) do if r.to then pending = pending + 1 end end
  if not want then
    rk.status:SetText("|cff" .. U.HEX.muted .. RL("noCode") .. "|r")
  elseif pending > 0 then
    local txt = RL("pending"):format(pending)
    local a, b = txt:match("^(.-)( · .*)$")
    rk.status:SetText(a and ("|cff" .. U.HEX.amber .. a .. "|r|cff" .. U.HEX.muted .. b .. "|r") or ("|cff" .. U.HEX.amber .. txt .. "|r"))
  else
    rk.status:SetText(RL("none"))
  end
  local shown = {}
  for _, r in ipairs(rows) do if not db().rankOnlyChanges or r.to or r.missing then table.insert(shown, r) end end
  for i, r in ipairs(shown) do
    local line = rk.rows[i]
    if not line then line = rankLine(i); rk.rows[i] = line end
    local c = r.missing and C.muted or U.classColor(r.class or U.classOf(r.name))
    line.dot:SetColor(c)
    line.name:SetText(r.name)
    if line.name.SetTextColor then line.name:SetTextColor(c[1], c[2], c[3]) end
    line.btn.row = r.to and r or nil
    if r.missing then
      line.now:Hide(); line.miss:SetText(RL("missing")); line.miss:Show()
      line.arrow:SetText(""); line.to:SetText("")
    else
      line.miss:SetText(""); line.miss:Hide()
      line.now:Set(rankName(r.rank), "closed"); line.now:Show()
      if r.to then
        local up = r.to < r.rank
        local tc = up and C.green or C.amber
        line.arrow:SetText(up and ns.ui.ICON.up or ns.ui.ICON.down)
        if line.arrow.SetTextColor then line.arrow:SetTextColor(tc[1], tc[2], tc[3]) end
        line.to:SetText(rankName(r.to))
        if line.to.SetTextColor then line.to:SetTextColor(tc[1], tc[2], tc[3]) end
      else
        line.arrow:SetText("")
        line.to:SetText(want and want[r.name] and "—" or "")
        if line.to.SetTextColor then line.to:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end
      end
    end
    if r.to then
      local up = r.to < r.rank
      line.btn:SetKind(up and "on" or "amber")
      line.btn:SetLabel((up and RL("promote") or RL("demote")):format(rankName(up and r.rank - 1 or r.rank + 1)))
      line.btn:SetEnabled(true); line.btn:Show(); line.state:SetText("")
    else
      line.btn:SetLabel(""); line.btn:Hide()
      line.state:SetText((want and not r.missing and want[r.name]) and U.ICON.check or "")
    end
    line:Show()
  end
  for i = #shown + 1, #rk.rows do rk.rows[i].btn.row = nil; rk.rows[i].btn:SetLabel(""); rk.rows[i]:Hide() end
  rk.list:SetHeight(math.max(1, #shown * ROW_H))
end

local function loadRanks(code)
  if not parseRanks(code) then say(RL("bad")); return false end
  db().rankCode = code
  rerequestRoster()
  refreshRanks()
  return true
end

local function openRanks(code)
  if not rk then
    local U, C = ns.ui, ns.ui.C
    rk = U.window("RebirthTrackRanksFrame", RK_W, RK_H, "", { point = { "CENTER", 0, 0 } })
    local y = rk.top
    -- Zona de pegado: indicación, el código + «Leer» y la línea de estado con el filtro.
    local paste = CreateFrame("Frame", nil, rk)
    paste:SetPoint("TOPLEFT", 1, y); paste:SetPoint("TOPRIGHT", -1, y); paste:SetHeight(RK_PASTE)
    U.fill(paste, C.sub, 1)
    U.hline(paste, -RK_PASTE + 1)
    rk.hint = U.font(paste, "GameFontHighlightSmall", C.muted, "LEFT")
    rk.hint:SetPoint("TOPLEFT", 11, -10); rk.hint:SetPoint("TOPRIGHT", -11, -10)
    rk.read = U.button(paste, "", "pri", function() loadRanks(rk.code:GetText() or "") end)
    rk.read:SetPoint("TOPRIGHT", -11, -36)
    rk.code = U.input(paste, 300, 22, "RTR1:…")
    rk.code:SetPoint("TOPLEFT", 11, -36); rk.code:SetPoint("RIGHT", rk.read, "LEFT", -6, 0)
    if rk.code.SetMaxLetters then rk.code:SetMaxLetters(0) end
    rk.code:SetScript("OnEnterPressed", function(e) loadRanks(e:GetText() or ""); e:ClearFocus() end)
    rk.status = U.font(paste, "GameFontHighlightSmall", C.text, "LEFT"); rk.status:SetPoint("TOPLEFT", 11, -70)
    rk.onlyLbl = U.font(paste, "GameFontHighlightSmall", C.text, "RIGHT"); rk.onlyLbl:SetPoint("TOPRIGHT", -11, -70)
    rk.only = CreateFrame("CheckButton", nil, paste, "UICheckButtonTemplate"); rk.only:SetSize(22, 22)
    rk.only:SetPoint("RIGHT", rk.onlyLbl, "LEFT", -2, 0)
    rk.only:SetChecked(db().rankOnlyChanges and true or false)
    rk.only:SetScript("OnClick", function(b) db().rankOnlyChanges = b:GetChecked() and true or false; refreshRanks() end)
    if rk.status.SetPoint then rk.status:SetPoint("RIGHT", rk.only, "LEFT", -8, 0) end
    if rk.status.SetWordWrap then rk.status:SetWordWrap(false) end
    y = y - RK_PASTE
    -- La tabla: encabezado fijo y las filas con scroll.
    rk.head = U.tableHeader(rk, RK_COLS, RK_LIST_W, y)
    rk.pos = rk.head.pos
    local ft = U.footer(rk, RK_FOOT)
    rk.foot = U.font(ft, "GameFontHighlightSmall", C.muted, "LEFT"); rk.foot:SetPoint("LEFT", 11, 0); rk.foot:SetPoint("RIGHT", -11, 0)
    rk.scroll = CreateFrame("ScrollFrame", "RebirthTrackRanksScroll", rk, "UIPanelScrollFrameTemplate")
    rk.scroll:SetPoint("TOPLEFT", 1, y - 22); rk.scroll:SetPoint("BOTTOMRIGHT", -23, RK_FOOT + 1)
    rk.list = CreateFrame("Frame", nil, rk.scroll); rk.list:SetSize(RK_LIST_W, 1)
    rk.scroll:SetScrollChild(rk.list)
    rk.rows = {}
    rk:RegisterEvent("GUILD_ROSTER_UPDATE"); rk:SetScript("OnEvent", function() if rk:IsShown() then refreshRanks() end end)
  end
  if code and code ~= "" then rk.code:SetText(code); loadRanks(code) else rk.code:SetText(rankCode() or "") end
  if rk.code.updatePlaceholder then rk.code:updatePlaceholder() end
  rk:Show()
  rerequestRoster()
  refreshRanks()
end

local COMMANDS = {
  mostrar = "show", abrir = "show", show = "show", open = "show",
  ocultar = "hide", cerrar = "hide", hide = "hide", close = "hide",
  ayuda = "help", help = "help", ["?"] = "help",
  vincular = "link", link = "link",
  estado = "status", status = "status",
  registrar = "start", empezar = "start", iniciar = "start", start = "start",
  detener = "stop", parar = "stop", stop = "stop",
  mazmorras = "dungeons", dungeons = "dungeons",
  posicion = "position", ["posición"] = "position", position = "position", ubicacion = "position", mapa = "position",
  opciones = "options", options = "options", config = "options",
  banco = "bank", bank = "bank",
  pedidos = "requests", pedido = "requests", requests = "requests", request = "requests", requeridos = "requests",
  posiciones = "positions", positions = "positions", ubicaciones = "positions",
  invitar = "recruit", invitador = "recruit", reclutar = "recruit", recruit = "recruit", invite = "recruit",
  borrar = "reset", reset = "reset",
  minimapa = "minimap", minimap = "minimap",
  idioma = "lang", language = "lang", lang = "lang",
  rangos = "ranks", ranks = "ranks",
  plan = "plan", planes = "plan", plans = "plan",
  reparto = "loot", botin = "loot", ["botín"] = "loot", loot = "loot", council = "loot", consejo = "loot",
  datos = "data", data = "data",
  diag = "diag", diagnostico = "diag", ["diagnóstico"] = "diag",
}

SLASH_REBIRTHTRACK1 = "/rt"
SLASH_REBIRTHTRACK2 = "/rebirthtrack"
SlashCmdList.REBIRTHTRACK = function(msg)
  local word, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
  -- /rt rangos RTR1:…: el código lleva nombres con mayúsculas, se toma tal cual.
  local raw = (msg or ""):match("^%s*%S+%s+(%S+)")
  local cmd = word == "" and "toggle" or COMMANDS[word]
  if cmd == "toggle" then
    if ui and ui:IsShown() then status() else openUI(false) end
  elseif cmd == "show" then openUI(false)
  elseif cmd == "hide" then if ui then ui:Hide() end; ui_db().shown = false
  elseif cmd == "help" then openUI(true)
  elseif cmd == "link" then linkCharacter()
  elseif cmd == "status" then status()
  elseif cmd == "start" then startSession("manual")
  elseif cmd == "stop" then stopSession("manual")
  elseif cmd == "dungeons" then
    db().settings.dungeons = not db().settings.dungeons
    say(L("dungeonsSay"):format(db().settings.dungeons and L("included") or L("excluded")))
    checkZone()
  elseif cmd == "position" then
    local on = (arg == "on" or arg == "si" or arg == "sí") or (arg ~= "off" and arg ~= "no" and not sharePos())
    setSharePos(on)
    say(L("posSay"):format(on and L("shared") or L("notShared")))
  elseif cmd == "positions" then
    if ns.openPositions then ns.openPositions() end
  elseif cmd == "diag" then
    if ns.planDiag then ns.planDiag() end
  elseif cmd == "recruit" then
    if ns.openRecruit then ns.openRecruit() end
  elseif cmd == "bank" then
    if ns.openBank then ns.openBank() end
  elseif cmd == "requests" then
    if ns.openRequests then ns.openRequests() end
  elseif cmd == "options" then
    if ns.openOptions then ns.openOptions() end
  elseif cmd == "minimap" then
    ui_db().minimap = ui_db().minimap == false
    if mm then mm:SetShown(ui_db().minimap) end
    say(L("mmSay"):format(ui_db().minimap and L("visible") or L("hidden")))
  elseif cmd == "reset" then
    db().sessions = {}
    say(L("resetSay"))
  elseif cmd == "ranks" then openRanks(raw)
  elseif cmd == "plan" then if ns.openPlan then ns.openPlan((msg or ""):match("^%s*%S+%s+(.+)$")) end
  elseif cmd == "loot" then if ns.openCouncil then ns.openCouncil((msg or ""):match("^%s*%S+%s+(.+)$")) end
  elseif cmd == "data" then
    if ns.dataSummary then say(L("dataSay"):format(ns.dataSummary())) end
  elseif cmd == "lang" then
    local want = (arg == "en" or arg == "english" or arg == "ingles" or arg == "inglés") and "en"
      or (arg == "es" or arg == "spanish" or arg == "español" or arg == "espanol") and "es"
      or (lang() == "es" and "en" or "es")
    db().settings.lang = want
    say(L("langSay"))
  else
    say(L("unknown"):format(word))
  end
  refreshUI()
end
