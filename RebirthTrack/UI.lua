-- Rebirth Track · Kit visual «Obsidiana»
-- Todas las ventanas del addon se arman con estas piezas: fondo casi opaco (lo elige el jugador en
-- Opciones, 80–100 %, por defecto 96 %), franja de título, pestañas planas con contador, botones que
-- se miden con su texto (nunca se sale), filas de tabla alternadas, íconos de ítem con el borde de su
-- calidad, etiquetas de estado y barras. Solo texturas planas (WHITE8x8): se ve igual en todas las
-- versiones del juego y no depende de BackdropTemplate.
local ADDON, ns = ...
ns = ns or {}

local U = {}
ns.ui = U

local WHITE = "Interface\\Buttons\\WHITE8x8"
local C = {
  bg = { 0.051, 0.059, 0.078 }, strip = { 0.086, 0.102, 0.133 }, sub = { 0.071, 0.082, 0.110 },
  line = { 0.165, 0.184, 0.227 }, border = { 0.42, 0.333, 0.153 }, rowAlt = { 0.067, 0.078, 0.106 },
  hover = { 0.106, 0.125, 0.188 }, btn = { 0.110, 0.125, 0.161 }, btnLine = { 0.227, 0.251, 0.302 },
  gold = { 0.949, 0.757, 0.306 }, action = { 0.788, 0.588, 0.180 }, text = { 0.902, 0.910, 0.925 },
  muted = { 0.541, 0.565, 0.616 }, green = { 0.373, 0.831, 0.608 }, amber = { 0.941, 0.714, 0.310 },
  red = { 1, 0.478, 0.494 }, input = { 0.039, 0.047, 0.063 },
}
U.C = C
-- Símbolos como texturas: la fuente del juego (Friz Quadrata) no trae ✓ ▲ ▼ ★ ▶ y salen como cuadraditos.
local function glyph(path, size, r, g, b)
  size = size or 14
  if r then return ("|T%s:%d:%d:0:0:16:16:0:16:0:16:%d:%d:%d|t"):format(path, size, size, r, g, b) end
  return ("|T%s:%d:%d:0:0|t"):format(path, size, size)
end
U.glyph = glyph
U.ICON = {
  check = glyph("Interface\\Buttons\\UI-CheckBox-Check", 16),
  up = glyph("Interface\\Buttons\\Arrow-Up-Up", 14),
  down = glyph("Interface\\Buttons\\Arrow-Down-Up", 14),
  star = glyph("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", 12),
  play = glyph("Interface\\ChatFrame\\ChatFrameExpandArrow", 12),
}
U.HEX = { gold = "f2c14e", muted = "8a909d", green = "5fd49b", amber = "f0b64f", red = "ff7a7e", text = "e6e8ec" }

-- Opacidad del fondo elegida en Opciones (0.8–1).
function U.alpha()
  local d = ns.db and ns.db()
  local a = d and d.settings and tonumber(d.settings.uiAlpha)
  return math.min(1, math.max(0.8, a or 0.96))
end

local function tex(frame, layer, c, a)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(WHITE)
  if t.SetVertexColor then t:SetVertexColor(c[1], c[2], c[3], a or 1) end
  return t
end
U.tex = tex

-- Fondo liso en todo el frame.
function U.fill(frame, c, a, layer)
  local t = tex(frame, layer or "BACKGROUND", c, a)
  t:SetAllPoints(frame)
  return t
end

-- Borde de 1 px (cuatro texturas). Devuelve una tabla con :SetColor(r, g, b, a).
function U.edge(frame, c, a, layer)
  local e = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = tex(frame, layer or "BORDER", c, a)
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT", frame, side .. "LEFT", 0, 0); t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", 0, 0); t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, 0); t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 0); t:SetWidth(1)
    end
    e[#e + 1] = t
  end
  function e.SetColor(_, r, g, b, al) for _, t in ipairs(e) do if t.SetVertexColor then t:SetVertexColor(r, g, b, al or 1) end end end
  return e
end

-- Línea horizontal de separación debajo de `y` (negativo) dentro de `frame`.
function U.hline(frame, y, inset)
  local t = tex(frame, "ARTWORK", C.line)
  t:SetHeight(1)
  t:SetPoint("TOPLEFT", inset or 0, y); t:SetPoint("TOPRIGHT", -(inset or 0), y)
  return t
end

function U.font(parent, template, c, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  if c and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3]) end
  if justify and fs.SetJustifyH then fs:SetJustifyH(justify) end
  return fs
end

-- Etiqueta de sección en mayúsculas chiquitas.
function U.label(parent, text)
  local fs = U.font(parent, "GameFontNormalSmall", C.muted, "LEFT")
  fs:SetText(text and text:upper() or "")
  return fs
end

local function textWidth(fs) return (fs and fs.GetStringWidth and fs:GetStringWidth()) or 0 end
U.textWidth = textWidth

-- ── Ventana ──────────────────────────────────────────────────────────────────────────────
-- U.window("RebirthTrackXFrame", w, h, título, { point, noClose, onClose })
-- Deja .header (franja de 32 px), .title, .close y .top = -33 (donde empieza el contenido).
local HEADER = 32
U.HEADER = HEADER
function U.window(name, w, h, title, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(w, h)
  -- Todas las ventanas del addon en la misma capa y «de primer nivel»: la que tocás (o abrís) pasa
  -- adelante entera, con todo lo de adentro, y las otras quedan detrás sin mezclarse.
  f:SetFrameStrata("HIGH")
  if f.SetToplevel then f:SetToplevel(true) end
  f:SetClampedToScreen(true)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if self.Raise then self:Raise() end; self:StartMoving() end)
  f:SetScript("OnMouseDown", function(self) if self.Raise then self:Raise() end end)
  if f.HookScript then f:HookScript("OnShow", function(self) if self.Raise then self:Raise() end end) end
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); if opts.onMoved then opts.onMoved(self) end end)
  local p = opts.point or { "CENTER", 0, 40 }
  f:SetPoint(p[1], UIParent, p[1], p[2] or 0, p[3] or 0)
  f.bg = U.fill(f, C.bg, U.alpha())
  f.edge = U.edge(f, C.border, 1)
  f.header = CreateFrame("Frame", nil, f)
  f.header:SetPoint("TOPLEFT", 1, -1); f.header:SetPoint("TOPRIGHT", -1, -1); f.header:SetHeight(HEADER)
  U.fill(f.header, C.strip, 1)
  local hl = tex(f.header, "ARTWORK", C.line); hl:SetHeight(1)
  hl:SetPoint("BOTTOMLEFT", 0, 0); hl:SetPoint("BOTTOMRIGHT", 0, 0)
  f.title = U.font(f.header, "GameFontNormal", C.gold, "LEFT")
  f.title:SetPoint("LEFT", 12, 0)
  f.title:SetText(title or "")
  if not opts.noClose then
    f.close = U.iconButton(f.header, 22, "×", function() f:Hide(); if opts.onClose then opts.onClose() end end)
    f.close:SetPoint("RIGHT", -6, 0)
  end
  f.top = -(HEADER + 1)
  if name and UISpecialFrames and not opts.noEsc then table.insert(UISpecialFrames, name) end
  -- La opacidad se puede cambiar en Opciones con la ventana abierta.
  function f.applyAlpha() if f.bg.SetVertexColor then f.bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], U.alpha()) end end
  U.windows = U.windows or {}
  U.windows[#U.windows + 1] = f
  return f
end

function U.refreshAlpha() for _, w in ipairs(U.windows or {}) do pcall(w.applyAlpha) end end

-- Barra de abajo (para paginado y acciones). Devuelve el frame; el contenido se ancla a él.
function U.footer(win, h)
  local ft = CreateFrame("Frame", nil, win)
  ft:SetPoint("BOTTOMLEFT", 1, 1); ft:SetPoint("BOTTOMRIGHT", -1, 1); ft:SetHeight(h or 36)
  U.fill(ft, C.sub, 1)
  local t = tex(ft, "ARTWORK", C.line); t:SetHeight(1); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT")
  return ft
end

-- ── Botones ──────────────────────────────────────────────────────────────────────────────
-- kind: nil (secundario), "pri" (acción dorada), "dng" (rojo), "on"/"off" (interruptor tipo chip).
-- El ancho sale del texto (+20 px), con `min` como mínimo, salvo que se fije con :SetWidth.
local KIND = {
  pri = { bg = C.action, line = { 0.878, 0.690, 0.290 }, text = { 0.09, 0.075, 0.04 } },
  dng = { bg = { 0.118, 0.078, 0.086 }, line = { 0.353, 0.165, 0.176 }, text = C.red },
  on = { bg = { 0.10, 0.20, 0.16 }, line = { 0.18, 0.42, 0.29 }, text = C.green },
  off = { bg = C.strip, line = C.btnLine, text = C.muted },
}
function U.button(parent, text, kind, onClick, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(opts.h or 22)
  b.bgT = U.fill(b, C.btn, 1)
  b.edgeT = U.edge(b, C.btnLine, 1)
  b.fs = U.font(b, opts.font or "GameFontHighlightSmall", C.text, "CENTER")
  b.fs:SetPoint("CENTER", 0, 0)
  b.min, b.fixed = opts.min or 0, opts.w
  function b.SetKind(self, k)
    self.kind = k
    local s = KIND[k] or { bg = C.btn, line = C.btnLine, text = C.text }
    if self.bgT.SetVertexColor then self.bgT:SetVertexColor(s.bg[1], s.bg[2], s.bg[3], 1) end
    self.edgeT:SetColor(s.line[1], s.line[2], s.line[3], 1)
    if self.fs.SetTextColor then self.fs:SetTextColor(s.text[1], s.text[2], s.text[3]) end
  end
  function b.SetLabel(self, t)
    self.fs:SetText(t or "")
    self.text = t or "" -- (para las pruebas: el texto del botón)
    if self.fixed then self:SetWidth(self.fixed)
    else self:SetWidth(math.max(self.min, math.ceil(textWidth(self.fs)) + 20)) end
  end
  b.SetText = b.SetLabel
  b.GetText = function(self) return self.fs:GetText() end
  b:SetScript("OnEnter", function(self)
    if self.edgeT then self.edgeT:SetColor(C.gold[1], C.gold[2], C.gold[3], 1) end
    if self.tip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip, 1, 1, 1, true); GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function(self) self:SetKind(self.kind); if self.tip then GameTooltip:Hide() end end)
  if onClick then b:SetScript("OnClick", onClick) end
  b:SetKind(kind)
  b:SetLabel(text)
  local enable = b.SetEnabled
  function b.SetEnabled(self, on)
    if enable then enable(self, on) end
    self:SetAlpha(on and 1 or 0.4)
  end
  return b
end

-- Botón cuadrado con un símbolo (‹ › × …).
function U.iconButton(parent, size, glyph, onClick)
  local b = U.button(parent, glyph, nil, onClick, { w = size, h = size, font = "GameFontNormal" })
  return b
end

-- ── Pestañas ─────────────────────────────────────────────────────────────────────────────
-- U.tabs(win, y, { { key, label }, … }, onSelect): planas, con subrayado dorado y contador.
function U.tabs(parent, y, list, onSelect)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetPoint("TOPLEFT", 1, y); bar:SetPoint("TOPRIGHT", -1, y); bar:SetHeight(30)
  U.fill(bar, C.sub, 1)
  local t = tex(bar, "ARTWORK", C.line); t:SetHeight(1); t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT")
  bar.items, bar.byKey = {}, {}
  for _, it in ipairs(list) do
    local b = CreateFrame("Button", nil, bar)
    b:SetHeight(30)
    b.key = it[1]
    b.fs = U.font(b, "GameFontHighlightSmall", C.muted, "LEFT"); b.fs:SetPoint("LEFT", 10, 0)
    b.n = U.font(b, "GameFontHighlightSmall", C.muted, "LEFT"); b.n:SetPoint("LEFT", b.fs, "RIGHT", 6, 0)
    b.line = tex(b, "ARTWORK", C.gold); b.line:SetHeight(2); b.line:SetPoint("BOTTOMLEFT", 4, 0); b.line:SetPoint("BOTTOMRIGHT", -4, 0)
    b:SetScript("OnClick", function(self) if self.enabled ~= false then onSelect(self.key) end end)
    bar.items[#bar.items + 1] = b; bar.byKey[it[1]] = b
    b.label = it[2]
  end
  function bar.Update(_, active, counts, enabled, labels)
    local x = 6
    for _, b in ipairs(bar.items) do
      b.enabled = not enabled or enabled[b.key] ~= false
      b.fs:SetText((labels and labels[b.key]) or b.label or b.key)
      local n = counts and counts[b.key]
      b.n:SetText(n and tostring(n) or "")
      local on = b.key == active
      local c = on and C.gold or (b.enabled and C.text or C.line)
      if b.fs.SetTextColor then b.fs:SetTextColor(c[1], c[2], c[3]) end
      local hot = counts and counts.hot == b.key and (n or 0) > 0
      local nc = hot and C.amber or C.muted
      if b.n.SetTextColor then b.n:SetTextColor(nc[1], nc[2], nc[3]) end
      b.line:SetShown(on)
      local w = math.ceil(textWidth(b.fs) + (n and (textWidth(b.n) + 6) or 0)) + 20
      b:SetWidth(w)
      b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0)
      x = x + w + 2
    end
  end
  return bar
end

-- ── Tabla ────────────────────────────────────────────────────────────────────────────────
-- cols = { { key, w, label, justify } } (w = 0: lo que sobra). U.columns(row o header, cols, width)
-- calcula las x de cada columna.
function U.columns(cols, width)
  local fixed, flex = 0, 0
  for _, c in ipairs(cols) do if (c[2] or 0) > 0 then fixed = fixed + c[2] else flex = flex + 1 end end
  local rest = math.max(40, (width - fixed) / math.max(1, flex))
  local x, out = 0, {}
  for _, c in ipairs(cols) do
    local w = (c[2] or 0) > 0 and c[2] or rest
    out[c[1]] = { x = x, w = w, justify = c[4] or "LEFT" }
    x = x + w
  end
  return out
end

function U.tableHeader(parent, cols, width, y)
  local h = CreateFrame("Frame", nil, parent)
  h:SetPoint("TOPLEFT", 1, y); h:SetPoint("TOPRIGHT", -1, y); h:SetHeight(22)
  U.fill(h, C.sub, 1)
  local t = tex(h, "ARTWORK", C.line); t:SetHeight(1); t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT")
  local pos = U.columns(cols, width)
  h.cells = {}
  for _, c in ipairs(cols) do
    local fs = U.font(h, "GameFontNormalSmall", C.muted, c[4] or "LEFT")
    local p = pos[c[1]]
    fs:SetPoint("LEFT", 8 + p.x, 0); fs:SetWidth(p.w - 8)
    fs:SetText((c[3] or ""):upper())
    h.cells[c[1]] = fs
  end
  h.pos = pos
  return h
end

-- Fila: fondo alternado y resaltado con el mouse. `i` decide el alternado.
function U.row(parent, h, i)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(h)
  r.bgT = U.fill(r, C.rowAlt, (i % 2 == 0) and 1 or 0)
  r.alt = (i % 2 == 0)
  local t = tex(r, "ARTWORK", { 0.102, 0.118, 0.153 }); t:SetHeight(1); t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT")
  r:SetScript("OnEnter", function(self) if self.bgT.SetVertexColor then self.bgT:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 1) end; if self.onEnter then self.onEnter(self) end end)
  r:SetScript("OnLeave", function(self) if self.bgT.SetVertexColor then self.bgT:SetVertexColor(C.rowAlt[1], C.rowAlt[2], C.rowAlt[3], self.alt and 1 or 0) end; GameTooltip:Hide() end)
  return r
end

-- ── Piezas visuales ──────────────────────────────────────────────────────────────────────
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 0.9, 0.9, 0.9 }, { 0.12, 1, 0 }, { 0.18, 0.56, 0.91 }, { 0.71, 0.34, 1 }, { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 } }
U.QUALITY = QUALITY

local function itemIcon(id)
  if C_Item and C_Item.GetItemIconByID then local i = C_Item.GetItemIconByID(id); if i then return i end end
  if GetItemIcon then return GetItemIcon(id) end
  return nil
end
local function itemQuality(id)
  if C_Item and C_Item.GetItemQualityByID then local q = C_Item.GetItemQualityByID(id); if q then return q end end
  if GetItemInfo then local _, _, q = GetItemInfo(id); return q end
  return nil
end
U.itemIcon, U.itemQuality = itemIcon, itemQuality

-- Ícono de ítem con el borde de su calidad y la cantidad en la esquina; tooltip del ítem.
function U.icon(parent, size)
  local f = CreateFrame("Button", nil, parent)
  f:SetSize(size, size)
  U.fill(f, { 0.102, 0.114, 0.141 }, 1)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetPoint("TOPLEFT", 1, -1); f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  if f.tex.SetTexCoord then f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  f.edgeT = U.edge(f, QUALITY[1], 1, "OVERLAY")
  f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  f.count:SetPoint("BOTTOMRIGHT", -1, 1)
  function f.SetItem(self, id, n, texture)
    self.id = id
    self.tex:SetTexture(texture or (id and itemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local q = QUALITY[(id and itemQuality(id)) or 1] or QUALITY[1]
    self.edgeT:SetColor(q[1], q[2], q[3], 1)
    self.count:SetText((n and n > 1) and tostring(n) or "")
  end
  f:SetScript("OnEnter", function(self)
    if not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.id) else GameTooltip:SetHyperlink("item:" .. self.id) end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end

-- Etiqueta de estado: kind = "pend", "guild", "closed", "exp", "ok".
local PILL = {
  pend = { { 0.88, 0.64, 0.23 }, C.amber }, guild = { { 0.30, 0.76, 0.54 }, C.green }, ok = { { 0.30, 0.76, 0.54 }, C.green },
  closed = { { 0.24, 0.26, 0.30 }, C.muted }, exp = { { 0.9, 0.28, 0.30 }, C.red },
}
function U.pill(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetHeight(16)
  p.bgT = U.fill(p, C.line, 0.2)
  p.fs = U.font(p, "GameFontHighlightSmall", C.text, "CENTER"); p.fs:SetPoint("CENTER", 0, 0)
  function p.Set(self, text, kind)
    local s = PILL[kind] or PILL.closed
    if self.bgT.SetVertexColor then self.bgT:SetVertexColor(s[1][1], s[1][2], s[1][3], 0.18) end
    if self.fs.SetTextColor then self.fs:SetTextColor(s[2][1], s[2][2], s[2][3]) end
    self.fs:SetText(text or "")
    self:SetWidth(math.ceil(textWidth(self.fs)) + 14)
  end
  return p
end

-- Barra de progreso.
function U.bar(parent, w, h)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(w, h or 6)
  U.fill(b, { 0.137, 0.157, 0.204 }, 1)
  b.fillT = tex(b, "ARTWORK", C.green)
  b.fillT:SetPoint("TOPLEFT"); b.fillT:SetPoint("BOTTOMLEFT")
  function b.SetValue(self, frac, c)
    frac = math.max(0, math.min(1, frac or 0))
    self.fillT:SetWidth(math.max(0.001, (self:GetWidth() or w) * frac))
    self.fillT:SetShown(frac > 0)
    c = c or C.green
    if self.fillT.SetVertexColor then self.fillT:SetVertexColor(c[1], c[2], c[3], 1) end
  end
  return b
end

-- Color de clase de un personaje de la guild (por nombre, con o sin reino).
local classCache, classAt = {}, 0
function U.classOf(name)
  if not name or name == "" then return nil end
  local now = GetTime and GetTime() or 0
  if now - classAt > 30 and GetNumGuildMembers and GetGuildRosterInfo then
    classAt = now
    classCache = {}
    for i = 1, GetNumGuildMembers() or 0 do
      local n, _, _, _, _, _, _, _, _, _, cls = GetGuildRosterInfo(i)
      if n and cls then classCache[n:lower()] = cls; classCache[(n:gsub("%-.*$", "")):lower()] = cls end
    end
  end
  return classCache[name:lower()] or classCache[(name:gsub("%-.*$", "")):lower()]
end
function U.classColor(cls)
  local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
  if c then return { c.r, c.g, c.b } end
  return C.text
end

-- Punto de color (clase, en vivo). Redondo con la máscara del retrato si el cliente la tiene.
function U.dot(parent, size, c)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size, size)
  t:SetTexture(WHITE)
  if t.SetMask then pcall(t.SetMask, t, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  if c and t.SetVertexColor then t:SetVertexColor(c[1], c[2], c[3], 1) end
  function t.SetColor(self, cc) if self.SetVertexColor then self:SetVertexColor(cc[1], cc[2], cc[3], 1) end end
  return t
end

-- Campo de texto con el estilo de la casa.
function U.input(parent, w, h, placeholder)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w, h or 22)
  e:SetAutoFocus(false)
  e:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  if e.SetTextInsets then e:SetTextInsets(8, 8, 0, 0) end
  U.fill(e, C.input, 1)
  e.edgeT = U.edge(e, C.btnLine, 1)
  e.ph = U.font(e, "GameFontHighlightSmall", C.muted, "LEFT"); e.ph:SetPoint("LEFT", 8, 0); e.ph:SetText(placeholder or "")
  local function upd(self) self.ph:SetShown((self:GetText() or "") == "" and not (self.HasFocus and self:HasFocus())) end
  e:SetScript("OnEditFocusGained", function(self) self.edgeT:SetColor(C.gold[1], C.gold[2], C.gold[3], 1); upd(self) end)
  e:SetScript("OnEditFocusLost", function(self) self.edgeT:SetColor(C.btnLine[1], C.btnLine[2], C.btnLine[3], 1); upd(self) end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e.updatePlaceholder = upd
  if e.HookScript then e:HookScript("OnTextChanged", upd) end
  return e
end
