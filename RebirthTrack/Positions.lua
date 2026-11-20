-- Rebirth Track · Posiciones de la guild en el mapa del juego
-- Las posiciones que comparte el addon de cada miembro (pos1, ver Collect.lua) se ven como puntos del
-- color de su clase en el mapa del mundo. No reemplaza ningún mapa: los puntos se ponen con
-- HereBeDragons-Pins, la librería que usan Questie o TomTom, así que se ven en el mapa de Blizzard y
-- en los addons de mapa que la muestran (OpenMap, Mapster, Leatrix Maps…). Como OpenMap, un punto se
-- va si su dueño no avisa nada en 150 s (dejó de jugar o entró a una instancia).
-- Además, la ventana «Posiciones de la guild» (botón de la ventana del addon o /rt posiciones) lista
-- todo lo anotado, con coordenadas, zona y hace cuánto, para ver que se esté sincronizando.
local ADDON, ns = ...
ns = ns or {}

local DOT = 16 -- px del punto en el mapa
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask" -- círculo blanco: toma el color de la clase
local GONE_AFTER = 150 -- s sin noticias: el punto se va del mapa (como OpenMap)
local CLOCK_SLACK = 300 -- s de diferencia tolerada entre los relojes de dos PCs
local REF = "RebirthTrack"

local TEXTS = {
  es = {
    title = "Posiciones de la guild", you = "vos", channel = "por el canal", off = "no comparte", instance = "en una instancia",
    intro = "Lo que llegó por el canal de la guild (y lo tuyo). Cada addon avisa cada 10 s mientras se mueve y cada minuto si está quieto; nada desde mazmorras ni bandas.",
    summary = "%d anotadas · %d en el mapa ahora (avisaron hace menos de %d s)",
    sharing = "Tu posición: %s", on = "compartida", 
    recorded = "anotadas", liveNow = "en vivo",
    colPlayer = "Jugador", colZone = "Zona", colCoord = "Coord.", colSeen = "Visto",
    none = "Todavía no llegó ninguna posición. Se necesita que otros miembros tengan el addon (0.6.0 o más nuevo) y estén conectados.",
    map = "Mapa", pins = "Puntos en el mapa", ago = { s = "hace %d s", m = "hace %d min", h = "hace %d h", d = "hace %d días" },
    tipMap = "Abre el mapa del mundo en esa zona.", tipPins = "Mostrar u ocultar los puntos de la guild en el mapa del juego.",
    level = "nivel %d",
  },
  en = {
    title = "Guild positions", you = "you", channel = "over the channel", off = "not sharing", instance = "in an instance",
    intro = "What arrived over the guild channel (and yours). Each addon reports every 10 s while moving and every minute while still; nothing from dungeons or raids.",
    summary = "%d recorded · %d on the map now (reported less than %d s ago)",
    sharing = "Your position: %s", on = "shared", 
    recorded = "recorded", liveNow = "live",
    colPlayer = "Player", colZone = "Zone", colCoord = "Coords", colSeen = "Seen",
    none = "No position has arrived yet. Other members need the addon (0.6.0 or newer) and to be online.",
    map = "Map", pins = "Dots on the map", ago = { s = "%d s ago", m = "%d min ago", h = "%d h ago", d = "%d days ago" },
    tipMap = "Opens the world map on that zone.", tipPins = "Show or hide the guild's dots on the game's map.",
    level = "level %d",
  },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; return (TEXTS[l] or TEXTS.es)[key] or TEXTS.es[key] end

local function split(s)
  local out = {}
  for part in (s .. ";"):gmatch("([^;]*);") do out[#out + 1] = part end
  return out
end
local function me() return UnitGUID("player") end
local function settings() return ns.db().settings end
local function pinsOn() return settings().mapPins ~= false end

-- Cuándo se oyó a cada uno en esta sesión (GetTime): mejor que la hora del juego de su PC, que puede
-- estar corrida. Después de un /reload, hasta que vuelva a avisar, vale la hora anotada.
local heard = {}
function ns.onPeerPosition(owner)
  heard[owner] = GetTime()
  if ns.refreshPositions then ns.refreshPositions() end
end

-- Nombre y clase de cada GUID: su ficha (p1), la lista de la guild (m1) o los anuncios (k1).
local function people()
  local d = ns.db()
  local out = {}
  for owner, c in pairs(d.data or {}) do
    local p1 = c.p1 and split((c.p1:gsub("^@[^;]*;", "", 1)))
    if p1 then out[owner] = { name = p1[4], realm = p1[5], class = p1[8], level = tonumber(p1[10]) } end
  end
  local g = d.guild or {}
  for _, rec in ipairs(g.members or {}) do
    local f = split(rec)
    if f[8] and f[8] ~= "" and not out[f[8]] then out[f[8]] = { name = f[2], realm = f[3], class = f[4], level = tonumber(f[5]) } end
  end
  for _, rec in ipairs(g.known or {}) do
    local f = split(rec)
    if f[9] and f[9] ~= "" and not out[f[9]] then out[f[9]] = { name = f[6], realm = f[5], class = f[7], level = tonumber(f[8]) } end
  end
  return out
end

-- Todas las posiciones anotadas, la más nueva primero.
local function positions()
  local who, list, mine = people(), {}, me()
  for owner, c in pairs(ns.db().data or {}) do
    local line = c.pos1
    if line and owner:match("^Player%-") then
      local via = line:match("^@([^;]*);")
      local f = split((line:gsub("^@[^;]*;", "", 1)))
      local at = tonumber(f[3]) or 0
      local p = { owner = owner, at = at, via = via, self = owner == mine, who = who[owner] or {} }
      if f[4] == "off" then p.off = true
      else
        p.map, p.x, p.y = tonumber(f[4]), tonumber(f[5]), tonumber(f[6])
        p.zone, p.instance = f[10] or "", (tonumber(f[11]) or 0) > 0
        p.cont = f[12] or ""
      end
      -- Hace cuánto: cuándo se oyó en esta sesión (el reloj de su PC puede estar corrido), salvo que la
      -- hora anotada diga que es mucho más vieja (otro addon reenvió una posición vieja al entrar).
      local stamp = math.max(0, time() - at)
      local fresh = heard[owner] and (GetTime() - heard[owner])
      p.age = (fresh and stamp <= fresh + CLOCK_SLACK) and fresh or stamp
      p.live = not p.off and not p.instance and p.map and p.map > 0 and p.age <= GONE_AFTER
      list[#list + 1] = p
    end
  end
  table.sort(list, function(a, b) return a.age < b.age end)
  return list
end
ns.guildPositions = positions

local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.9, 0.85, 0.7
end
local function ago(s)
  local a = T("ago")
  s = math.floor(s)
  if s < 60 then return a.s:format(s) elseif s < 3600 then return a.m:format(math.floor(s / 60)) elseif s < 86400 then return a.h:format(math.floor(s / 3600)) end
  return a.d:format(math.floor(s / 86400))
end
local function fullName(p) return (p.who.name or "?") .. ((p.who.realm and p.who.realm ~= "" and ns.splitSurname and p.who.realm ~= GetRealmName()) and (" " .. p.who.realm) or "") end

-- ── Puntos en el mapa del mundo ──────────────────────────────────────────────────────────
local Pins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
local dots = {}

local function dot(owner)
  local d = dots[owner]
  if d then return d end
  -- Un círculo lleno del color de la clase con borde oscuro (resalta sobre cualquier mapa) y un
  -- destello para cuando se lo busca desde la lista.
  d = CreateFrame("Button", nil, UIParent)
  d:SetSize(DOT, DOT)
  d.ring = d:CreateTexture(nil, "BACKGROUND")
  d.ring:SetTexture(CIRCLE); d.ring:SetVertexColor(0, 0, 0, 0.95)
  d.ring:SetPoint("CENTER"); d.ring:SetSize(DOT, DOT)
  d.tex = d:CreateTexture(nil, "ARTWORK")
  d.tex:SetTexture(CIRCLE)
  d.tex:SetPoint("CENTER"); d.tex:SetSize(DOT - 5, DOT - 5)
  d.shine = d:CreateTexture(nil, "OVERLAY")
  d.shine:SetTexture(CIRCLE); d.shine:SetVertexColor(1, 1, 1, 0.55)
  d.shine:SetPoint("CENTER", -1.5, 1.5); d.shine:SetSize(4, 4)
  d:SetHighlightTexture(CIRCLE, "ADD")
  d.ping = d:CreateTexture(nil, "BACKGROUND", nil, -1)
  d.ping:SetTexture(CIRCLE); d.ping:SetPoint("CENTER"); d.ping:SetSize(DOT * 3, DOT * 3); d.ping:SetAlpha(0)
  -- El destello es solo adorno: si una versión del juego no tiene algo de esto, el punto igual se ve.
  pcall(function()
    local ag = d:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha"); a:SetTarget(d.ping); a:SetFromAlpha(0.9); a:SetToAlpha(0); a:SetDuration(0.9)
    local sc = ag:CreateAnimation("Scale"); sc:SetTarget(d.ping); sc:SetDuration(0.9)
    if sc.SetScaleFrom then sc:SetScaleFrom(0.3, 0.3); sc:SetScaleTo(1, 1) else sc:SetScale(0.2, 0.2) end
    ag:SetLooping("REPEAT") -- NONE, REPEAT o BOUNCE
    d.pingAnim = ag
  end)
  d:SetScript("OnEnter", function(self)
    local p = self.p
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(fullName(p), classColor(p.who.class))
    if p.who.level then GameTooltip:AddLine(T("level"):format(p.who.level), 1, 1, 1) end
    GameTooltip:AddLine(p.zone or "", 1, 1, 1)
    GameTooltip:AddLine(ago(p.age), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  d:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dots[owner] = d
  return d
end

-- Destella el punto de alguien unos segundos (botón «Mapa» de la lista).
local function ping(owner)
  local d = dots[owner]
  if not (d and d.pingAnim) then return end
  d.ping:SetVertexColor(d.tex:GetVertexColor())
  pcall(d.pingAnim.Play, d.pingAnim)
  C_Timer.After(4, function() pcall(d.pingAnim.Stop, d.pingAnim); d.ping:SetAlpha(0) end)
end

local function drawPins()
  if not Pins then return end
  Pins:RemoveAllWorldMapIcons(REF)
  if not pinsOn() then return end
  for _, p in ipairs(positions()) do
    -- Lo propio no: el mapa ya muestra tu flecha.
    if p.live and not p.self then
      local d = dot(p.owner)
      d.p = p
      d.tex:SetVertexColor(classColor(p.who.class))
      Pins:AddWorldMapIconMap(REF, d, p.map, p.x, p.y, HBD_PINS_WORLDMAP_SHOW_WORLD or 3)
    end
  end
end

-- ── Ventana: la lista ────────────────────────────────────────────────────────────────────
local win, rows = nil, {}
local ROW_H = 26
local W, H = 640, 460
local INNER = W - 2
-- Columnas de la tabla: Jugador (lo que sobra), Zona, Coord. (a la derecha), Visto y el botón «Mapa».
local function cols()
  return { { "name", 0, T("colPlayer") }, { "zone", 170, T("colZone") }, { "xy", 84, T("colCoord"), "RIGHT" },
    { "age", 104, T("colSeen") }, { "map", 66, "" } }
end

-- Abre el mapa del mundo en la zona de alguien. Al abrirse, el mapa vuelve solo a la zona de uno
-- (y algunos addons de mapa lo mueven después): se elige la zona una vez abierto y otra vez un
-- instante después. La lista se cierra para que no tape el mapa y el punto destella.
local function openMap(p)
  if not p.map or p.map == 0 or not WorldMapFrame then return end
  local function go()
    pcall(function() if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(p.map) end end)
    drawPins()
    ping(p.owner)
  end
  if win then win:Hide() end
  if not WorldMapFrame:IsShown() then
    local ok = pcall(function()
      if ShowUIPanel then ShowUIPanel(WorldMapFrame) elseif ToggleWorldMap then ToggleWorldMap() end
    end)
    if not ok and ToggleWorldMap then pcall(ToggleWorldMap) end
  end
  go()
  C_Timer.After(0.1, go)
  C_Timer.After(0.4, go)
end

local function row(i)
  local r = rows[i]
  if r then return r end
  local U = ns.ui
  local pos = U.columns(cols(), INNER)
  r = U.row(win.child, ROW_H, i)
  r:SetWidth(INNER)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  local function cell(key, template, c, justify, pad)
    local q = pos[key]
    local fs = U.font(r, template or "GameFontHighlightSmall", c or U.C.text, justify or "LEFT")
    fs:SetPoint("LEFT", 8 + q.x + (pad or 0), 0); fs:SetWidth(q.w - 16 - (pad or 0))
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
  end
  r.cls = U.dot(r, 10, U.C.text); r.cls:SetPoint("LEFT", 8 + pos.name.x, 0)
  r.name = cell("name", "GameFontNormalSmall", nil, "LEFT", 16)
  r.zone = cell("zone")
  r.xy = cell("xy", nil, nil, "RIGHT")
  r.live = U.dot(r, 7, U.C.green); r.live:SetPoint("LEFT", 8 + pos.age.x, 0)
  r.age = cell("age", nil, U.C.muted, "LEFT", 12)
  r.map = U.button(r, T("map"), nil, function(self) if self.p then openMap(self.p) end end, { h = 18 })
  r.map:SetPoint("RIGHT", -8, 0)
  r.map.tip = T("tipMap")
  rows[i] = r
  return r
end

local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end

function ns.refreshPositions()
  drawPins()
  if not win or not win:IsShown() then return end
  local U = ns.ui
  win.title:SetText(T("title"))
  win.intro:SetText(T("intro"))
  win.pins:SetKind(pinsOn() and "on" or "off")
  win.pins:SetLabel(T("pins"))
  win.pins.tip = T("tipPins")
  for key, fs in pairs(win.thead.cells or {}) do
    for _, c in ipairs(cols()) do if c[1] == key then fs:SetText((c[3] or ""):upper()) end end
  end
  local list = positions()
  local live = 0
  for _, p in ipairs(list) do if p.live and not p.self then live = live + 1 end end
  local X = U.HEX
  win.counts:SetText(("|cff%s%d|r |cff%s%s|r    |cff%s%d|r |cff%s%s|r"):format(X.text, #list, X.muted, T("recorded"), X.green, live, X.muted, T("liveNow")))
  win.strip.tipText = T("summary"):format(#list, live, GONE_AFTER)
  win.sharing:SetText(T("sharing"):format(T("on")))
  for _, r in ipairs(rows) do r:Hide() end
  win.none:SetShown(#list == 0)
  win.none:SetText(T("none"))
  local dash = "|cff" .. X.muted .. "—|r"
  for i, p in ipairs(list) do
    local r = row(i)
    r:Show()
    local cc = U.classColor(p.who.class)
    r.cls:SetColor(cc)
    r.name:SetText("|cff" .. hex(cc) .. fullName(p) .. "|r" .. (p.self and (" |cff" .. X.muted .. "(" .. T("you") .. ")|r") or ""))
    if p.off then r.zone:SetText("|cff" .. X.muted .. T("off") .. "|r"); r.xy:SetText(dash)
    elseif p.instance then r.zone:SetText("|cff" .. X.muted .. p.zone .. " (" .. T("instance") .. ")|r"); r.xy:SetText(dash)
    else r.zone:SetText(p.zone); r.xy:SetText(p.x and string.format("%.1f, %.1f", p.x * 100, p.y * 100) or dash) end
    r.live:SetShown(p.live and true or false)
    r.age:SetText(ago(p.age))
    local ac = p.live and U.C.text or U.C.muted
    if r.age.SetTextColor then r.age:SetTextColor(ac[1], ac[2], ac[3]) end
    r.map.p = p
    r.map:SetLabel(T("map"))
    r.map.tip = T("tipMap")
    r.map:SetShown(not p.off and not p.instance and p.map and p.map > 0)
  end
  win.child:SetHeight(math.max(1, #list * ROW_H))
end

local function create()
  local U = ns.ui
  win = U.window("RebirthTrackPositionsFrame", W, H, T("title"), { point = { "CENTER", 0, 0 } })
  -- Interruptor de los puntos del mapa, en la franja del título (chip verde prendido, gris apagado).
  win.pins = U.button(win.header, T("pins"), pinsOn() and "on" or "off", function() settings().mapPins = not pinsOn(); ns.refreshPositions() end)
  win.pins.tip = T("tipPins")
  if win.close then win.pins:SetPoint("RIGHT", win.close, "LEFT", -6, 0) else win.pins:SetPoint("RIGHT", -6, 0) end
  -- Franja de resumen: cuántas anotadas, cuántas en vivo y si la tuya se comparte.
  local y = win.top
  win.strip = CreateFrame("Frame", nil, win)
  win.strip:SetPoint("TOPLEFT", 1, y); win.strip:SetPoint("TOPRIGHT", -1, y); win.strip:SetHeight(30)
  U.fill(win.strip, U.C.sub, 1)
  U.hline(win.strip, -29)
  win.strip:EnableMouse(true)
  win.strip:SetScript("OnEnter", function(self)
    if not self.tipText then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(self.tipText, 1, 1, 1, true); GameTooltip:Show()
  end)
  win.strip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  win.counts = U.font(win.strip, "GameFontHighlightSmall", U.C.text, "LEFT"); win.counts:SetPoint("LEFT", 12, 0)
  win.sharing = U.font(win.strip, "GameFontHighlightSmall", U.C.green, "RIGHT"); win.sharing:SetPoint("RIGHT", -12, 0)
  y = y - 30
  -- Qué es esto (chiquito, gris).
  win.intro = U.font(win, "GameFontHighlightSmall", U.C.muted, "LEFT")
  win.intro:SetPoint("TOPLEFT", 12, y - 8); win.intro:SetPoint("RIGHT", -12, 0)
  y = y - 48
  -- La tabla.
  win.thead = U.tableHeader(win, cols(), INNER, y)
  y = y - 22
  local scroll = CreateFrame("ScrollFrame", "RebirthTrackPositionsScroll", win)
  scroll:SetPoint("TOPLEFT", 1, y); scroll:SetPoint("BOTTOMRIGHT", -1, 1)
  win.child = CreateFrame("Frame", nil, scroll); win.child:SetSize(INNER, 1)
  scroll:SetScrollChild(win.child)
  if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = (self.GetVerticalScrollRange and self:GetVerticalScrollRange()) or 0
    local cur = (self.GetVerticalScroll and self:GetVerticalScroll()) or 0
    self:SetVerticalScroll(math.max(0, math.min(max, cur - (delta or 0) * ROW_H * 2)))
  end)
  win.none = U.font(win.child, "GameFontHighlightSmall", U.C.muted, "LEFT")
  win.none:SetPoint("TOPLEFT", 12, -10); win.none:SetWidth(INNER - 24)
  win:Hide() -- (en WoW un marco nuevo arranca visible)
  win:SetScript("OnShow", ns.refreshPositions)
end

-- /rt posiciones y el botón de la ventana del addon: abre o cierra la lista.
function ns.openPositions()
  if not win then create() end
  if win:IsShown() then win:Hide() else win:Show(); ns.refreshPositions() end
end

-- Cada 5 s, con el mapa o la lista abiertos: los puntos que pasaron los 150 s se van y la lista se
-- pone al día (la hora de «hace cuánto»).
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  if C_Timer.NewTicker then
    C_Timer.NewTicker(5, function()
      if (WorldMapFrame and WorldMapFrame:IsShown()) or (win and win:IsShown()) then pcall(ns.refreshPositions) end
    end)
  end
  pcall(drawPins)
end)

-- Para las pruebas.
ns._positions = { positions = positions, drawPins = drawPins, dots = dots, window = function() return win end, rows = function() return rows end }
