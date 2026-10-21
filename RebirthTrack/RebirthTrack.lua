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

-- ── Vincular el personaje a la cuenta de Rebirth Track ─────────────────────────────────────
-- WoW no deja que un addon se conecte a internet: el pedido queda anotado en RebirthTrackDB.links
-- y Rebirth Track Uploader (la app de la PC, ya vinculada a tu Discord) lo manda al sitio cuando el
-- juego guarda (al /reload o al salir). Formato: v1|región|reino|nombre|clase|nivel|guid|proyecto|build|hora
local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
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
  say(("|cff3fbf3f%s-%s|r anotado para vincular. La app lo sube al sitio cuando el juego guarde (al recargar o al salir)."):format(name, realm))
  StaticPopup_Show("REBIRTHTRACK_LINK_RELOAD")
end

StaticPopupDialogs["REBIRTHTRACK_LINK_RELOAD"] = {
  text = "Rebirth Track: personaje anotado para vincular a tu cuenta.\n\n¿Recargar la interfaz ahora para que la app lo suba ya?",
  button1 = "Recargar ahora", button2 = "Después",
  OnAccept = function() ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

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

-- ── Ventana del addon ───────────────────────────────────────────────────────────────────
-- Chica, se puede mover (arrastrando el título) y cerrar; recuerda dónde estaba y si estaba abierta.
-- /rt mostrar (show) la vuelve a abrir; /rt ayuda (help) la abre con la explicación.
local HELP = table.concat({
  "|cffe3a42cQué hace|r",
  "Al entrar a una banda o mazmorra prende el registro de combate avanzado del juego. Rebirth Track Uploader (la app de tu PC) sube esos registros a rebirthknights.fun.",
  "",
  "|cffe3a42cBotones|r",
  "• |cffffffffVincular personaje|r: lo asocia a tu usuario de Discord en el sitio (reino, región, clase y versión). La app lo manda cuando el juego guarda: al recargar o salir.",
  "• |cffffffffEstado|r: si el registro está prendido y qué se anotó.",
  "• |cffffffffRegistrar / Detener|r: a mano, si querés registrar fuera de una instancia.",
  "• |cffffffffMazmorras|r: incluir o no las mazmorras (vienen incluidas).",
  "",
  "|cffe3a42cComandos|r (español o inglés)",
  "/rt mostrar · show   /rt ocultar · hide",
  "/rt vincular · link   /rt estado · status",
  "/rt registrar · start   /rt detener · stop",
  "/rt mazmorras · dungeons   /rt borrar · reset",
  "/rt minimapa · minimap (mostrar u ocultar el botón)",
  "/rt ayuda · help",
}, "\n")

local ui
local function ui_db()
  local d = db()
  d.ui = d.ui or { shown = true }
  return d.ui
end

local function refreshUI()
  if not ui then return end
  ui.rec:SetText(session and "Detener registro" or "Registrar ahora")
  ui.dun:SetText("Mazmorras: " .. (db().settings.dungeons and "|cff3fbf3fsí|r" or "|cffff4040no|r"))
  ui.state:SetText(LoggingCombat() and "|cff3fbf3fRegistrando|r" .. (session and session.instance and (" · " .. session.instance.name) or "") or "|cff999999Registro apagado|r")
end

local function showHelp(on)
  ui.helpOn = on
  ui.help:SetShown(on)
  for _, b in ipairs(ui.buttons) do b:SetShown(not on) end
  ui.state:SetShown(not on)
  ui.back:SetShown(on)
  ui:SetHeight(on and 420 or 222)
end

local function createUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "RebirthTrackFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ui:SetSize(230, 222)
  ui:SetFrameStrata("MEDIUM")
  ui:SetClampedToScreen(true)
  ui:SetMovable(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    local u = ui_db()
    u.point, u.rel, u.x, u.y = point, rel, x, y
  end)
  if ui.SetBackdrop then
    ui:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
  local u = ui_db()
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
  close:SetScript("OnClick", function() ui:Hide(); ui_db().shown = false; say("ventana cerrada: /rt mostrar para volver a abrirla.") end)

  ui.state = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.state:SetPoint("TOP", title, "BOTTOM", 0, -6)

  ui.buttons = {}
  local function button(text, tip, onClick)
    local b = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    b:SetSize(190, 24)
    b:SetPoint("TOP", 0, -48 - #ui.buttons * 28)
    b:SetText(text)
    b:SetScript("OnClick", function() onClick(); refreshUI() end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(ui.buttons, b)
    return b
  end
  button("Vincular personaje", "Asocia este personaje a tu usuario de Discord en rebirthknights.fun (/rt vincular).", linkCharacter)
  button("Estado", "Muestra en el chat si el registro está prendido y qué se anotó (/rt estado).", function() status() end)
  ui.rec = button("Registrar ahora", "Prende o apaga el registro a mano (/rt registrar · /rt detener).", function()
    if session then stopSession("manual") else startSession("manual") end
  end)
  ui.dun = button("Mazmorras", "Incluir o no las mazmorras (/rt mazmorras).", function()
    db().settings.dungeons = not db().settings.dungeons
    checkZone()
  end)
  button("Ayuda", "Cómo se usa (/rt ayuda).", function() showHelp(true) end)

  ui.help = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.help:SetPoint("TOPLEFT", 16, -34)
  ui.help:SetPoint("RIGHT", -14, 0)
  ui.help:SetJustifyH("LEFT")
  ui.help:SetText(HELP)
  ui.back = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.back:SetSize(100, 22)
  ui.back:SetPoint("BOTTOM", 0, 12)
  ui.back:SetText("Volver")
  ui.back:SetScript("OnClick", function() showHelp(false) end)

  showHelp(false)
  refreshUI()
  return ui
end

local function openUI(help)
  createUI()
  ui:Show()
  ui_db().shown = true
  showHelp(help and true or false)
  refreshUI()
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
    GameTooltip:AddLine("Clic: abrir o cerrar la ventana", 1, 1, 1)
    GameTooltip:AddLine("Clic derecho: vincular este personaje", 1, 1, 1)
    GameTooltip:AddLine("Arrastrar: moverlo · /rt minimapa: ocultarlo", 0.7, 0.7, 0.7)
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
}

SLASH_REBIRTHTRACK1 = "/rt"
SLASH_REBIRTHTRACK2 = "/rebirthtrack"
SlashCmdList.REBIRTHTRACK = function(msg)
  local word = (msg or ""):lower():match("^%s*(%S*)")
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
    say("mazmorras " .. (db().settings.dungeons and "INCLUIDAS" or "excluidas") .. ".")
    checkZone()
  elseif cmd == "minimap" then
    ui_db().minimap = ui_db().minimap == false
    if mm then mm:SetShown(ui_db().minimap) end
    say("botón del minimapa " .. (ui_db().minimap and "visible" or "oculto (/rt minimapa para mostrarlo)") .. ".")
  elseif cmd == "reset" then
    db().sessions = {}
    say("sesiones borradas.")
  else
    say("no conozco «" .. word .. "». Probá /rt ayuda (o /rt help).")
  end
  refreshUI()
end
