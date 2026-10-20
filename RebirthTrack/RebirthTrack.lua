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

local function db()
  RebirthTrackDB = RebirthTrackDB or {}
  RebirthTrackDB.sessions = RebirthTrackDB.sessions or {}
  RebirthTrackDB.settings = RebirthTrackDB.settings or { dungeons = false }
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
  say(("registrando |cffffffff%s|r (%s) · registro de combate avanzado %s."):format(
    name or "?", difficultyName or "", advancedOn() and "|cff3fbf3fACTIVO|r" or "|cffff4040INACTIVO|r"))
end

local function fmtDuration(sec)
  sec = math.max(0, math.floor(sec))
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  if h > 0 then return ("%d h %02d min"):format(h, m) end
  return ("%d min"):format(m)
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
  say(("%s |cffffffff%s|r · %s · %d jugadores · %s eventos de combate"):format(
    title, sess.instance.name or "?", fmtDuration(finished - sess.startedAt), players, fmtNumber(sess.events.total)))
  if #sess.encounters == 0 then
    say("  sin encuentros con jefes.")
  else
    say(("  jefes: |cff3fbf3f%d muertos|r, |cffff4040%d wipes|r"):format(kills, wipes))
    for i, e in ipairs(sess.encounters) do
      if i > 12 then say(("  ... y %d más"):format(#sess.encounters - 12)) break end
      local res = e.kill and "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14|t" or (e.finish and "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14|t" or "|TInterface\\RAIDFRAME\\ReadyCheck-Waiting:14|t")
      local dur = e.finish and (" (%s)"):format(fmtDuration(e.finish - e.start)) or ""
      say(("  %s %s%s"):format(res, e.name or "?", dur))
    end
  end
  say("  El registro de combate lo sube la app Rebirth Track Uploader (si está abierta) a rebirthknights.fun.")
end

local function stopSession(why)
  if not session then return end
  session.endedAt = time()
  session.endReason = why
  summary(session, "Resumen de")
  say("Hacé /reload o salí del juego para que WoW guarde el resumen en disco.")
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
    stopSession("salió de la instancia")
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
  elseif event == "ENCOUNTER_END" and session then
    local id, _, _, _, success = ...
    for i = #session.encounters, 1, -1 do
      local e = session.encounters[i]
      if e.id == id and not e.finish then e.finish = time(); e.kill = success == 1; break end
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and session then
    local _, sub = CombatLogGetCurrentEventInfo()
    local ev = session.events
    ev.total = ev.total + 1
    ev.byType[sub] = (ev.byType[sub] or 0) + 1
    local minute = math.floor((time() - session.startedAt) / 60)
    ev.perMinute[minute + 1] = (ev.perMinute[minute + 1] or 0) + 1
  end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
  "ENCOUNTER_START", "ENCOUNTER_END", "COMBAT_LOG_EVENT_UNFILTERED" }) do
  f:RegisterEvent(e)
end

SLASH_REBIRTHTRACK1 = "/rt"
local function status()
  say(("registro de combate %s · modo avanzado %s"):format(
    LoggingCombat() and "|cff3fbf3fPRENDIDO|r" or "apagado", advancedOn() and "|cff3fbf3fsí|r" or "|cffff4040no|r"))
  if session then
    summary(session, "Registrando")
  else
    local last = db().sessions[#db().sessions]
    if last then summary(last, "Última banda:") else say("todavía no se registró ninguna banda.") end
  end
end

SlashCmdList.REBIRTHTRACK = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "start" then
    startSession("manual")
  elseif cmd == "stop" then
    stopSession("manual")
  elseif cmd == "status" or cmd == "estado" or cmd == "" then
    status()
  elseif cmd == "dungeons" or cmd == "mazmorras" then
    db().settings.dungeons = not db().settings.dungeons
    say("mazmorras " .. (db().settings.dungeons and "INCLUIDAS" or "excluidas") .. ".")
    checkZone()
  elseif cmd == "reset" then
    db().sessions = {}
    say("sesiones borradas.")
  else
    say("comandos: /rt status · /rt start · /rt stop · /rt dungeons (incluir mazmorras) · /rt reset")
  end
end
