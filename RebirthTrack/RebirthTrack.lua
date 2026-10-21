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
}

SLASH_REBIRTHTRACK1 = "/rt"
SLASH_REBIRTHTRACK2 = "/rebirthtrack"
SlashCmdList.REBIRTHTRACK = function(msg)
  local word, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
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
