-- Rebirth Track · F0 (medición)
-- Al entrar a una banda: activa el registro de combate avanzado (CVar advancedCombatLogging) y
-- /combatlog, y anota la sesión en RebirthTrackDB: instancia, grupo, encuentros y cuántos eventos
-- de combate hubo por tipo y por minuto. Al salir, apaga el registro si lo prendió el addon.
-- El juego escribe RebirthTrackDB a disco al hacer /reload, al desloguear o al desconectarse.

local ADDON = ...
local MAX_SESSIONS = 20
local PREFIX = "|cffe3a42cRebirth Track|r: "

local f = CreateFrame("Frame")
local session -- sesión en curso (tabla dentro de RebirthTrackDB.sessions)
local startedLogging = false -- si el /combatlog lo prendimos nosotros

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
    bDungeons = "Mazmorras", tDungeons = "Incluir o no las mazmorras (/rt mazmorras).",
    bHelp = "Ayuda", tHelp = "Cómo se usa (/rt ayuda).",
    bRanks = "Rangos (oficiales)", tRanksBtn = "Aplicar los rangos de la guild que sugiere el sitio (/rt rangos).",
    back = "Volver", tLang = "Cambiar el idioma a inglés (/rt idioma en).",
    mmOpen = "Clic: abrir o cerrar la ventana", mmLink = "Clic derecho: vincular este personaje",
    mmMove = "Arrastrar: moverlo · /rt minimapa: ocultarlo", tResize = "Arrastrar para cambiar el tamaño",
    dungeonsSay = "mazmorras %s.", included = "INCLUIDAS", excluded = "excluidas",
    mmSay = "botón del minimapa %s.", visible = "visible", hidden = "oculto (/rt minimapa para mostrarlo)",
    resetSay = "sesiones borradas.", unknown = "no conozco «%s». Probá /rt ayuda (o /rt help).",
    langSay = "idioma: español.",
    help = {
      "|cffe3a42cQué hace|r",
      "Al entrar a una banda o mazmorra prende el registro de combate avanzado del juego. Rebirth Track Uploader (la app de tu PC) sube esos registros a rebirthknights.fun.",
      "",
      "|cffe3a42cBotones|r",
      "• |cffffffffVincular personaje|r: lo asocia a tu usuario de Discord en el sitio (reino, región, clase y versión). La app lo manda cuando el juego guarda: al recargar o salir.",
      "• |cffffffffEstado|r: si el registro está prendido y qué se anotó.",
      "• |cffffffffRegistrar / Detener|r: a mano, si querés registrar fuera de una instancia.",
      "• |cffffffffMazmorras|r: incluir o no las mazmorras (vienen incluidas).",
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
      "/rt borrar · reset",
      "/rt minimapa · minimap",
      "/rt idioma · language (es / en)",
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
    bDungeons = "Dungeons", tDungeons = "Include dungeons or not (/rt dungeons).",
    bHelp = "Help", tHelp = "How to use it (/rt help).",
    bRanks = "Ranks (officers)", tRanksBtn = "Apply the guild ranks the site suggests (/rt ranks).",
    back = "Back", tLang = "Switch the language to Spanish (/rt language es).",
    mmOpen = "Click: open or close the window", mmLink = "Right-click: link this character",
    mmMove = "Drag: move it · /rt minimap: hide it", tResize = "Drag to resize",
    dungeonsSay = "dungeons %s.", included = "INCLUDED", excluded = "excluded",
    mmSay = "minimap button %s.", visible = "visible", hidden = "hidden (/rt minimap to show it)",
    resetSay = "sessions cleared.", unknown = "unknown command «%s». Try /rt help (or /rt ayuda).",
    langSay = "language: English.",
    help = {
      "|cffe3a42cWhat it does|r",
      "When you enter a raid or dungeon it turns on the game's advanced combat logging. Rebirth Track Uploader (the app on your PC) uploads those logs to rebirthknights.fun.",
      "",
      "|cffe3a42cButtons|r",
      "• |cffffffffLink character|r: links it to your Discord user on the site (realm, region, class and version). The app sends it when the game saves: on reload or logout.",
      "• |cffffffffStatus|r: whether logging is on and what was recorded.",
      "• |cffffffffRecord / Stop|r: manually, if you want to record outside an instance.",
      "• |cffffffffDungeons|r: include dungeons or not (included by default).",
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
      "/rt reset · borrar",
      "/rt minimap · minimapa",
      "/rt language · idioma (es / en)",
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
    events = { total = 0, byType = {}, perMinute = {} },
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
    title, sess.instance.name or "?", fmtDuration(finished - sess.startedAt), players, fmtNumber(sess.events.total)))
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

-- WoW Forever (y Retail 12.0) no dejan a los addons leer el registro de combate: el evento se
-- registra con pcall para que el resto del addon ande igual (el archivo lo sigue escribiendo el juego).
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
  "ENCOUNTER_START", "ENCOUNTER_END", "COMBAT_LOG_EVENT_UNFILTERED" }) do
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
--   known    "k1;hora;S|L;región;reino;nombre;clase;nivel;guid;proyecto"  (S = se anunció, L = pidió vincular)
-- Por el canal: "H;hora más nueva que tengo" (al entrar) y "K;…" (un personaje, mismos campos que known).
local COMM = "RTK1"
local MAX_KNOWN, MAX_REPLY = 1000, 60
local function clean(s) return (tostring(s or ""):gsub("[|;\n]", " ")) end
local function regionCode() return REGIONS[GetCurrentRegion and GetCurrentRegion() or 1] or "us" end
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

local function selfRecord(kind)
  local _, class = UnitClass("player")
  return { "k1", time(), kind, regionCode(), clean(GetRealmName()), clean(UnitName("player")), class or "",
    UnitLevel("player") or 0, UnitGUID("player") or "", WOW_PROJECT_ID or 0 }
end

-- Cola de envío: de a un mensaje cada medio segundo (el juego limita los mensajes de addons) y en
-- pausa durante el combate; en Retail también dentro de instancias, donde Blizzard los restringe.
local queue, pumping = {}, false
local function paused()
  if InCombatLockdown and InCombatLockdown() then return true end
  -- Retail y WoW Forever (WOW_PROJECT_CAMELOT) restringen los mensajes de addons en instancias.
  local restricted = WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1) or WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)
  return restricted and IsInInstance and IsInInstance() and true or false
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
  C_Timer.After(0.5, pump)
end
local function send(msg)
  if not IsInGuild() or #queue >= 200 then return end
  queue[#queue + 1] = msg
  if not pumping then pumping = true; C_Timer.After(0, pump) end
end

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
    local full, rankName, rankIndex, level, _, _, _, _, online, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i)
    if full then
      local name, realm = full:match("^([^%-]+)%-(.+)$")
      if not realm or realm == homeKey then realm = home end
      members[#members + 1] = table.concat({ "m1", clean(name or full), clean(realm), class or "", level or 0, rankIndex or 0,
        clean(rankName), guid or "", online and 0 or lastOnline(i) }, ";")
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
-- Se puede mover (arrastrando), cerrar y cambiar de tamaño (esquina inferior derecha); los botones
-- se estiran con el ancho y la ayuda va en un área con scroll. Recuerda posición, tamaño y si estaba
-- abierta. /rt mostrar (show) la vuelve a abrir; /rt ayuda (help) la abre con la explicación.
local MIN_W, MIN_H, MAX_W, MAX_H = 220, 230, 600, 700
local BTN_TOP, BTN_STEP = 52, 28

local ui, layout
local function ui_db()
  local d = db()
  d.ui = d.ui or { shown = true }
  return d.ui
end

local function refreshUI()
  if not ui then return end
  ui.rec:SetText(session and L("stop") or L("start"))
  ui.dun:SetText(L("dungeons") .. (db().settings.dungeons and L("yes") or L("no")))
  ui.state:SetText(LoggingCombat() and L("stateOn") .. (session and session.instance and (" · " .. session.instance.name) or "") or L("stateOff"))
  ui.lang:SetText(lang() == "es" and "EN" or "ES")
  for _, b in ipairs(ui.buttons) do b:SetText(b.label and L(b.label) or b:GetText()) end
  ui.back:SetText(L("back"))
  ui.help:SetText(table.concat(L("help"), "\n"))
  layout()
end

-- Alto mínimo para que entren todos los botones; la ventana nunca queda más chica que su contenido.
local function minHeight() return BTN_TOP + #ui.buttons * BTN_STEP + 14 end

function layout()
  if not ui then return end
  local w = ui:GetWidth()
  for _, b in ipairs(ui.buttons) do b:SetWidth(math.max(120, w - 36)) end
  ui.helpText:SetWidth(math.max(100, w - 58))
  ui.help:SetWidth(math.max(100, w - 58))
  ui.helpText:SetHeight((ui.help:GetStringHeight() or 0) + 8)
end

local function showHelp(on)
  ui.helpOn = on
  ui.scroll:SetShown(on)
  for _, b in ipairs(ui.buttons) do b:SetShown(not on) end
  ui.state:SetShown(not on)
  ui.back:SetShown(on)
  local u = ui_db()
  local h = math.max(u.h or 0, minHeight())
  if on then h = math.max(h, u.helpH or 380) end
  ui:SetHeight(math.min(h, MAX_H))
  layout()
end

local function setMinMax(frame)
  if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
  elseif frame.SetMinResize then frame:SetMinResize(MIN_W, MIN_H); frame:SetMaxResize(MAX_W, MAX_H) end
end

local function createUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "RebirthTrackFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  local u = ui_db()
  ui:SetSize(math.max(u.w or 240, MIN_W), math.max(u.h or MIN_H, MIN_H))
  ui:SetFrameStrata("MEDIUM")
  ui:SetClampedToScreen(true)
  ui:SetMovable(true)
  ui:SetResizable(true)
  setMinMax(ui)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    local d = ui_db()
    d.point, d.rel, d.x, d.y = point, rel, x, y
  end)
  ui:SetScript("OnSizeChanged", layout)
  if ui.SetBackdrop then
    ui:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
  ui:SetPoint(u.point or "CENTER", UIParent, u.rel or "CENTER", u.x or 300, u.y or 120)

  local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 8, -14)
  title:SetText("Rebirth Track")
  local logo = ui:CreateTexture(nil, "OVERLAY")
  logo:SetSize(18, 18)
  logo:SetPoint("RIGHT", title, "LEFT", -4, 0)
  logo:SetTexture("Interface\\AddOns\\RebirthTrack\\icon")
  local close = CreateFrame("Button", nil, ui, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() ui:Hide(); ui_db().shown = false; say(L("closed")) end)

  local function tip(frame, key)
    frame:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(L(key), 1, 1, 1, true); GameTooltip:Show() end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- Selector de idioma (arriba a la izquierda): muestra el idioma al que cambia.
  ui.lang = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.lang:SetSize(34, 20)
  ui.lang:SetPoint("TOPLEFT", 10, -9)
  ui.lang:SetScript("OnClick", function()
    db().settings.lang = lang() == "es" and "en" or "es"
    say(L("langSay"))
    refreshUI()
  end)
  tip(ui.lang, "tLang")

  ui.state = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.state:SetPoint("TOPLEFT", 16, -34)
  ui.state:SetPoint("TOPRIGHT", -16, -34)
  ui.state:SetJustifyH("CENTER")

  ui.buttons = {}
  local function button(label, tipKey, onClick)
    local b = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    b:SetHeight(24)
    b:SetWidth(200)
    b:SetPoint("TOP", 0, -BTN_TOP - #ui.buttons * BTN_STEP)
    b.label = label
    b:SetText(label and L(label) or "")
    b:SetScript("OnClick", function() onClick(); refreshUI() end)
    tip(b, tipKey)
    table.insert(ui.buttons, b)
    return b
  end
  button("bLink", "tLink", linkCharacter)
  button("bStatus", "tStatus", function() status() end)
  ui.rec = button(nil, "tRec", function()
    if session then stopSession("manual") else startSession("manual") end
  end)
  ui.dun = button(nil, "tDungeons", function()
    db().settings.dungeons = not db().settings.dungeons
    checkZone()
  end)
  button("bRanks", "tRanksBtn", function() SlashCmdList.REBIRTHTRACK("rangos") end)
  button("bHelp", "tHelp", function() showHelp(true) end)

  -- Ayuda: texto largo dentro de un área con scroll que ocupa el alto disponible.
  ui.scroll = CreateFrame("ScrollFrame", "RebirthTrackHelpScroll", ui, "UIPanelScrollFrameTemplate")
  ui.scroll:SetPoint("TOPLEFT", 14, -34)
  ui.scroll:SetPoint("BOTTOMRIGHT", -32, 42)
  ui.helpText = CreateFrame("Frame", nil, ui.scroll)
  ui.helpText:SetSize(180, 400)
  ui.scroll:SetScrollChild(ui.helpText)
  ui.help = ui.helpText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.help:SetPoint("TOPLEFT", 2, -2)
  ui.help:SetJustifyH("LEFT")
  ui.help:SetJustifyV("TOP")
  if ui.help.SetWordWrap then ui.help:SetWordWrap(true) end

  ui.back = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.back:SetSize(100, 22)
  ui.back:SetPoint("BOTTOM", 0, 14)
  ui.back:SetScript("OnClick", function() showHelp(false) end)

  -- Agarre para cambiar el tamaño (esquina inferior derecha); guarda el tamaño de cada vista.
  local grip = CreateFrame("Button", nil, ui)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -6, 6)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() ui:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    ui:StopMovingOrSizing()
    local d = ui_db()
    d.w = math.floor(ui:GetWidth())
    if ui.helpOn then d.helpH = math.floor(ui:GetHeight()) else d.h = math.max(math.floor(ui:GetHeight()), minHeight()) end
    showHelp(ui.helpOn)
  end)
  tip(grip, "tResize")

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

local uf = CreateFrame("Frame")
uf:RegisterEvent("PLAYER_LOGIN")
uf:RegisterEvent("PLAYER_ENTERING_WORLD")
uf:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    createUI()
    createMinimapButton()
    if ui_db().shown == false then ui:Hide() end
  end
  C_Timer.After(1.5, refreshUI)
end)

-- Comandos en español o inglés.

-- ── Rangos de la guild (oficiales) ───────────────────────────────────────────────────────────
-- El sitio arma un código con el rango que le toca a cada uno según sus roles de Discord
-- (Miembros › Guild del juego › «Copiar para el addon»): «RTR1:Nombre=2,Otro=4». Pegado en el chat
-- (/rt rangos RTR1:…) o en este panel, el addon muestra quién está en otro rango y aplica un paso por
-- clic: el juego no deja que un addon cambie rangos solo, cada ascenso o descenso necesita un clic.
local RT = {
  es = {
    title = "Rangos de la guild", paste = "Código del sitio (Miembros › Guild del juego › Copiar para el addon):",
    read = "Leer", apply = "Aplicar siguiente", none = "|cff3fbf3fTodos tienen el rango que les toca.|r",
    noPerm = "necesitás ser oficial o Guild Master para cambiar rangos.", bad = "el código no es válido: copialo de nuevo del sitio.",
    pending = "%d cambios pendientes:", missing = "%s: no está en la guild", done = "%s: %s → %s.",
  },
  en = {
    title = "Guild ranks", paste = "Code from the site (Members › In-game guild › Copy for the addon):",
    read = "Read", apply = "Apply next", none = "|cff3fbf3fEveryone has the right rank.|r",
    noPerm = "you need to be an officer or Guild Master to change ranks.", bad = "the code isn't valid: copy it again from the site.",
    pending = "%d pending changes:", missing = "%s: not in the guild", done = "%s: %s → %s.",
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

-- Quién no tiene el rango que le toca (y en qué rango está), según la lista de la guild del juego.
local function pendingRanks(want)
  local have, list = {}, {}
  for i = 1, GetNumGuildMembers() do
    local full, _, rankIndex = GetGuildRosterInfo(i)
    if full then have[full:match("^[^-]+")] = { full = full, rank = rankIndex } end
  end
  for name, target in pairs(want or {}) do
    local m = have[name]
    if not m then table.insert(list, { name = name, missing = true })
    elseif m.rank ~= target and target > 0 then table.insert(list, { name = name, full = m.full, from = m.rank, to = target }) end
  end
  table.sort(list, function(a, b) return (a.missing and 1 or 0) < (b.missing and 1 or 0) or ((a.missing and 1 or 0) == (b.missing and 1 or 0) and a.name < b.name) end)
  return list
end

local rk
local function ranksDB() local d = db(); return d end
local function refreshRanks()
  if not rk then return end
  local list = pendingRanks(ranksDB().rankCode and parseRanks(ranksDB().rankCode))
  local lines = {}
  local actionable = 0
  for _, p in ipairs(list) do
    if p.missing then table.insert(lines, "|cff999999" .. RL("missing"):format(p.name) .. "|r")
    else actionable = actionable + 1; table.insert(lines, ("|cffffffff%s|r: %s → |cffe3a42c%s|r"):format(p.name, rankName(p.from), rankName(p.to))) end
  end
  rk.list:SetText(ranksDB().rankCode and (actionable > 0 and (RL("pending"):format(actionable) .. "\n" .. table.concat(lines, "\n")) or (RL("none") .. (#lines > 0 and ("\n" .. table.concat(lines, "\n")) or ""))) or "")
  rk.apply:SetEnabled(actionable > 0)
  rk.title:SetText(RL("title")); rk.hint:SetText(RL("paste")); rk.read:SetText(RL("read")); rk.apply:SetText(RL("apply"))
end

local function loadRanks(code)
  if not parseRanks(code) then say(RL("bad")); return false end
  ranksDB().rankCode = code
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
  refreshRanks()
  return true
end

-- Un paso hacia el rango que le toca al primero de la lista (ascender = índice más chico).
local function applyNextRank()
  for _, p in ipairs(pendingRanks(parseRanks(ranksDB().rankCode or ""))) do
    if not p.missing then
      local up = p.to < p.from
      if (up and not CanGuildPromote()) or (not up and not CanGuildDemote()) then say(RL("noPerm")); return end
      if up then GuildPromote(p.full) else GuildDemote(p.full) end
      say(RL("done"):format(p.name, rankName(p.from), rankName(up and p.from - 1 or p.from + 1)))
      if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
      return
    end
  end
end

local function openRanks(code)
  if not rk then
    rk = CreateFrame("Frame", "RebirthTrackRanksFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    rk:SetSize(360, 320)
    rk:SetPoint("CENTER")
    rk:SetMovable(true); rk:EnableMouse(true); rk:RegisterForDrag("LeftButton")
    rk:SetScript("OnDragStart", rk.StartMoving); rk:SetScript("OnDragStop", rk.StopMovingOrSizing)
    if rk.SetBackdrop then rk:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } }) end
    rk.title = rk:CreateFontString(nil, "OVERLAY", "GameFontNormal"); rk.title:SetPoint("TOP", 0, -14)
    local close = CreateFrame("Button", nil, rk, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
    rk.hint = rk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); rk.hint:SetPoint("TOPLEFT", 16, -36); rk.hint:SetPoint("TOPRIGHT", -16, -36); rk.hint:SetJustifyH("LEFT")
    rk.code = CreateFrame("EditBox", nil, rk, "InputBoxTemplate"); rk.code:SetSize(240, 22); rk.code:SetPoint("TOPLEFT", 22, -62); rk.code:SetAutoFocus(false)
    rk.read = CreateFrame("Button", nil, rk, "UIPanelButtonTemplate"); rk.read:SetSize(70, 22); rk.read:SetPoint("LEFT", rk.code, "RIGHT", 8, 0)
    rk.read:SetScript("OnClick", function() loadRanks(rk.code:GetText() or "") end)
    rk.list = rk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); rk.list:SetPoint("TOPLEFT", 16, -96); rk.list:SetPoint("BOTTOMRIGHT", -16, 46); rk.list:SetJustifyH("LEFT"); rk.list:SetJustifyV("TOP")
    rk.apply = CreateFrame("Button", nil, rk, "UIPanelButtonTemplate"); rk.apply:SetSize(160, 24); rk.apply:SetPoint("BOTTOM", 0, 14)
    rk.apply:SetScript("OnClick", function() applyNextRank() end)
    rk:RegisterEvent("GUILD_ROSTER_UPDATE"); rk:SetScript("OnEvent", function() refreshRanks() end)
  end
  if code and code ~= "" then rk.code:SetText(code); loadRanks(code) end
  rk:Show()
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
  borrar = "reset", reset = "reset",
  minimapa = "minimap", minimap = "minimap",
  idioma = "lang", language = "lang", lang = "lang",
  rangos = "ranks", ranks = "ranks",
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
  elseif cmd == "minimap" then
    ui_db().minimap = ui_db().minimap == false
    if mm then mm:SetShown(ui_db().minimap) end
    say(L("mmSay"):format(ui_db().minimap and L("visible") or L("hidden")))
  elseif cmd == "reset" then
    db().sessions = {}
    say(L("resetSay"))
  elseif cmd == "ranks" then openRanks(raw)
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
