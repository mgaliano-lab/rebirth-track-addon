-- Rebirth Track · Banco personal (solo local)
-- Al abrir el banco se anota qué hay en cada casillero del banco y de sus bolsas, y en su ventana
-- (botón «Banco personal» de la ventana del addon o /rt banco) se ve como en el banco: los
-- casilleros del banco, la fila de bolsas y cada bolsa abierta, con el tooltip del ítem.
--
-- NO se manda a nadie: va en RebirthTrackBank, que es por personaje (## SavedVariablesPerCharacter),
-- y el juego lo guarda en WTF/Account/<cuenta>/<reino>/<personaje>/SavedVariables/, que la app no
-- lee (solo sube WTF/Account/<cuenta>/SavedVariables/RebirthTrack.lua). Tampoco va por el canal.
--
-- RebirthTrackBank = { v = 1, at = hora, bagSlots = huecos de bolsa comprados, containers = {
--   { id = contenedor, slots = casilleros, name, icon, link (la bolsa), items = { [casillero] = {
--     id = ítem, n = cantidad, link, icon, q = calidad } } } } }
local ADDON, ns = ...
ns = ns or {}

local TEXTS = {
  es = {
    page = "Banco personal", bank = "Banco", bags = "Bolsas del banco",
    intro = "Lo que tenés en el banco, para verlo sin ir al banco. Se anota cada vez que lo abrís. Queda solo en tu PC: no va al sitio ni a la guild.",
    never = "Todavía no se anotó nada: abrí el banco una vez con este personaje.",
    when = "Anotado %s · %d de %d casilleros ocupados · %d ítems distintos",
    search = "Buscar…", count = "En el banco: %d", where = "%s, casillero %d",
    stale = "Anotado con una versión anterior del addon: abrí el banco una vez para verlo bien.",
    emptySlot = "Hueco de bolsa sin bolsa", locked = "Hueco de bolsa sin comprar", tab = "Pestaña %d", reagents = "Componentes",
    ago = { now = "recién", min = "hace %d min", h = "hace %d h", d = "hace %d días" },
    matches = "%d coinciden", clear = "Borrar la búsqueda",
    fAll = "Todo", fReagent = "Componentes", fGear = "Equipo", fConsumable = "Consumibles", fRequests = "Pedidos",
  },
  en = {
    page = "Personal bank", bank = "Bank", bags = "Bank bags",
    intro = "What's in your bank, to check it without going there. It's recorded every time you open it. It stays on your PC only: it isn't sent to the site or the guild.",
    never = "Nothing recorded yet: open the bank once with this character.",
    when = "Recorded %s · %d of %d slots used · %d different items",
    search = "Search…", count = "In the bank: %d", where = "%s, slot %d",
    stale = "Recorded with an older addon version: open the bank once to see it right.",
    emptySlot = "Bag slot without a bag", locked = "Bag slot not purchased", tab = "Tab %d", reagents = "Reagents",
    ago = { now = "just now", min = "%d min ago", h = "%d h ago", d = "%d days ago" },
    matches = "%d match", clear = "Clear the search",
    fAll = "All", fReagent = "Reagents", fGear = "Gear", fConsumable = "Consumables", fRequests = "Requests",
  },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; return (TEXTS[l] or TEXTS.es)[key] or TEXTS.es[key] end

-- ── Lectura del banco ────────────────────────────────────────────────────────────────────
local BANK = (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1
local REAGENTS = (Enum and Enum.BagIndex and Enum.BagIndex.Reagentbank) or REAGENTBANK_CONTAINER

local function numSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end
local function itemAt(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(bag, slot)
    if not i or not i.itemID then return nil end
    return { id = i.itemID, n = i.stackCount or 1, link = i.hyperlink, icon = i.iconFileID, q = i.quality }
  end
  if not GetContainerItemInfo then return nil end
  local icon, n, _, q, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
  if not icon then return nil end
  id = id or (link and tonumber(link:match("item:(%d+)")))
  if (not q or q < 0) and link and GetItemInfo then q = select(3, GetItemInfo(link)) end
  return { id = id, n = n or 1, link = link, icon = icon, q = q }
end

-- Bolsa puesta en un hueco del banco: su ítem (nombre, ícono).
local function bagItem(bag)
  local inv = (C_Container and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bag))
    or (ContainerIDToInventoryID and ContainerIDToInventoryID(bag))
  if not inv then return nil end
  local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
  local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
  return link, icon, link and link:match("%[(.-)%]")
end

-- Contenedores del banco según la versión:
--  · Classic: el banco (-1) y los huecos de bolsa (las bolsas van después de las propias).
--  · WoW Forever: el banco clásico (un banco y huecos de bolsa) pero con los números del banco nuevo:
--    lo del banco está en CharacterBankTab_1 y cada bolsa del banco en las «pestañas» siguientes; el
--    -1 existe pero viene vacío. (Visto en el juego: 32 casilleros vacíos en -1, los ítems en la 1.)
--  · Retail 11.2+: pestañas de verdad.
local FOREVER = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)
local function bankLayout()
  local E = Enum and Enum.BagIndex
  local tab1 = E and E.CharacterBankTab_1
  if tab1 and numSlots(tab1) > 0 then
    if FOREVER or numSlots(BANK) > 0 then
      local bags = {}
      for i = 1, 5 do bags[#bags + 1] = tab1 + i end
      return { main = tab1, bags = bags }
    end
    local tabs = {}
    for i = 0, 5 do tabs[#tabs + 1] = tab1 + i end
    return { tabs = tabs }
  end
  if numSlots(BANK) == 0 then return nil end -- el banco no está cargado
  local first = (E and E.BankBag_1) or ((NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1)
  local bags = {}
  for i = 0, (NUM_BANKBAGSLOTS or 7) - 1 do
    local id = first + i
    if id ~= BANK and id ~= REAGENTS then bags[#bags + 1] = id end
  end
  return { main = BANK, bags = bags }
end

local bankOpen = false
local function read(id)
  local n, items = numSlots(id), {}
  for s = 1, n do items[s] = itemAt(id, s) end
  return n, items
end
local function scan()
  if not bankOpen then return end
  local lay = bankLayout()
  if not lay then return end
  local containers = {}
  if lay.tabs then
    for i, id in ipairs(lay.tabs) do
      local n, items = read(id)
      containers[#containers + 1] = { id = id, slots = n, tab = i, items = items }
    end
  else
    local n, items = read(lay.main)
    containers[#containers + 1] = { id = lay.main, slots = n, main = true, items = items }
    for _, id in ipairs(lay.bags) do
      local bn, bitems = read(id)
      local c = { id = id, slots = bn, items = bitems }
      local ok, link, icon, name = pcall(bagItem, id)
      if ok then c.link, c.icon, c.name = link, icon, name end
      containers[#containers + 1] = c
    end
  end
  if REAGENTS and IsReagentBankUnlocked and IsReagentBankUnlocked() then
    local n, items = read(REAGENTS)
    if n > 0 then containers[#containers + 1] = { id = REAGENTS, slots = n, reagents = true, items = items } end
  end
  local bought = GetNumBankSlots and select(1, GetNumBankSlots()) or nil
  RebirthTrackBank = { v = 2, at = time(), bagSlots = bought, tabbed = lay.tabs and true or nil, containers = containers }
  if ns.refreshBank then ns.refreshBank() end
  if ns.refreshBankCraft then pcall(ns.refreshBankCraft) end
end
ns.scanBank = scan

local pending = false
local function scanSoon()
  if pending or not bankOpen then return end
  pending = true
  C_Timer.After(0.5, function() pending = false; pcall(scan) end)
end

-- ── Vista: como el banco del juego, con el kit «Obsidiana» (UI.lua) ────────────────────────
-- Arriba la búsqueda (resalta lo que coincide y apaga el resto), los filtros por tipo y el resumen;
-- abajo un bloque plano por contenedor con sus casilleros.
local SLOT, GAP, PAD, TOP = 34, 3, 8, 24
local page, content, scroll, header, search, chips
local buttons, blocks = {}, {}
local filter = "all"
local FILTERS = { { "all", "fAll" }, { "reagent", "fReagent" }, { "gear", "fGear" }, { "consumable", "fConsumable" }, { "requests", "fRequests" } }

local function ago(at)
  local m = math.floor((time() - at) / 60)
  local a = T("ago")
  if m < 2 then return a.now elseif m < 60 then return a.min:format(m) elseif m < 1440 then return a.h:format(math.floor(m / 60)) end
  return a.d:format(math.floor(m / 1440))
end

local function slotButton(parent)
  local U, C = ns.ui, ns.ui.C
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(SLOT, SLOT)
  -- El brillo dorado de lo que coincide con la búsqueda: un marco apenas más grande, por detrás.
  b.glow = U.tex(b, "BACKGROUND", C.gold, 0.35)
  b.glow:SetPoint("TOPLEFT", -2, 2); b.glow:SetPoint("BOTTOMRIGHT", 2, -2)
  b.glow:Hide()
  b.bg = U.fill(b, C.input, 1, "BORDER")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.edgeT = U.edge(b, C.line, 1, "OVERLAY")
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.item and self.item.link then
      GameTooltip:SetHyperlink(self.item.link)
      if self.total and self.total > (self.item.n or 1) then GameTooltip:AddLine(T("count"):format(self.total), 0.4, 0.8, 1) end
    elseif self.item and self.item.id and GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(self.item.id)
    elseif self.empty then
      GameTooltip:AddLine(self.empty, 1, 1, 1)
    else
      GameTooltip:Hide(); return
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Mayús + clic: el ítem al chat, como en el banco.
  b:SetScript("OnClick", function(self)
    if self.item and self.item.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(self.item.link) end
  end)
  return b
end

local used = 0
local function nextButton(parent)
  used = used + 1
  local b = buttons[used]
  if not b then b = slotButton(content); buttons[used] = b end
  b:SetParent(parent)
  b:ClearAllPoints()
  b:Show()
  return b
end

local function setBg(b, c, a) if b.bg.SetVertexColor then b.bg:SetVertexColor(c[1], c[2], c[3], a or 1) end end

-- Calidad del ítem: la anotada, o la que sabe el cliente.
local function qualityOf(item)
  if not item then return nil end
  if item.q and item.q >= 0 then return item.q end
  return item.id and ns.ui.itemQuality(item.id) or nil
end

local function fill(b, item, totals, emptyText)
  local U, C = ns.ui, ns.ui.C
  b.item, b.total, b.empty = item, item and totals[item.id], emptyText
  b.glow:Hide()
  if item then
    b.icon:SetTexture(item.icon or (item.id and U.itemIcon(item.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    b.icon:Show()
    b.count:SetText((item.n or 1) > 1 and tostring(item.n) or "")
    setBg(b, { 0.102, 0.114, 0.141 })
    local q = U.QUALITY[qualityOf(item) or 1] or U.QUALITY[1]
    b.edgeT:SetColor(q[1], q[2], q[3], 1)
  else
    b.icon:Hide(); b.count:SetText("")
    setBg(b, C.input)
    b.edgeT:SetColor(C.line[1], C.line[2], C.line[3], 1)
  end
end

-- Lo que el cliente sabe del ítem sin pedirlo al servidor: tipo, subtipo, hueco y clase.
local function itemInfo(id)
  if not id then return nil end
  local GI = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if GI then
    local _, typ, sub, loc, _, cls = GI(id)
    if typ or cls then return typ, sub, loc, cls end
  end
  if GetItemInfo then
    local _, _, _, _, _, typ, sub, _, loc, _, _, cls = GetItemInfo(id)
    return typ, sub, loc, cls
  end
end

-- Palabras de calidad (es y en) que también encuentra la búsqueda.
local QWORDS = {
  [0] = { "gris", "gray", "grey", "pobre", "poor" }, [1] = { "blanco", "white", "común", "comun", "common" },
  [2] = { "verde", "green", "poco común", "uncommon" }, [3] = { "azul", "blue", "raro", "rare" },
  [4] = { "épico", "epico", "epic", "morado", "purple" }, [5] = { "legendario", "legendary", "naranja", "orange" },
}

local function nameOf(item)
  return item.link and item.link:match("%[(.-)%]") or (GetItemInfo and item.id and GetItemInfo(item.id)) or ""
end

local function matchesTerm(item, term)
  if term == "" then return true end
  if not item then return false end
  if nameOf(item):lower():find(term, 1, true) then return true end
  local q = qualityOf(item)
  if #term >= 3 and q and QWORDS[q] then
    for _, w in ipairs(QWORDS[q]) do if w:sub(1, #term) == term then return true end end
  end
  local typ, sub = itemInfo(item.id)
  if typ and tostring(typ):lower():find(term, 1, true) then return true end
  if sub and tostring(sub):lower():find(term, 1, true) then return true end
  return false
end

local function requested(id)
  local R = ns._requests
  if not (R and R.forItem and id) then return false end
  local ok, list = pcall(R.forItem, id)
  return ok and type(list) == "table" and #list > 0
end

local function matchesFilter(item)
  if filter == "all" then return true end
  if not item or not item.id then return false end
  if filter == "requests" then return requested(item.id) end
  local _, _, loc, cls = itemInfo(item.id)
  if filter == "reagent" then return cls == 5 or cls == 7 end
  if filter == "gear" then return cls == 2 or cls == 4 or (cls == nil and loc ~= nil and loc ~= "") end
  if filter == "consumable" then return cls == 0 end
  return true
end

-- Bloque plano (fondo + borde de 1 px) con su etiqueta en mayúsculas.
local function block(i)
  local U, C = ns.ui, ns.ui.C
  local f = blocks[i]
  if not f then
    f = CreateFrame("Frame", nil, content)
    U.fill(f, C.sub, 1)
    U.edge(f, C.line, 1)
    f.title = U.label(f, "")
    f.title:SetPoint("TOPLEFT", PAD, -PAD)
    f.title:SetPoint("RIGHT", -PAD, 0)
    blocks[i] = f
  end
  f:ClearAllPoints()
  f:Show()
  return f
end
local function setTitle(f, text) f.title:SetText((text or ""):upper()) end

-- Arma un bloque con `slots` casilleros en `cols` columnas. `st` lleva el término, si hay un
-- criterio activo y cuántos casilleros coinciden.
local function grid(f, c, cols, totals, st)
  local rows = math.ceil(c.slots / cols)
  for s = 1, c.slots do
    local b = nextButton(f)
    local col, row = (s - 1) % cols, math.floor((s - 1) / cols)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + col * (SLOT + GAP), -TOP - row * (SLOT + GAP))
    local it = c.items[s]
    fill(b, it, totals)
    local ok = matchesTerm(it, st.term) and matchesFilter(it)
    b:SetAlpha(ok and 1 or 0.25)
    if st.active and ok and it then
      st.hits = st.hits + 1
      b.glow:Show()
      local g = ns.ui.C.gold
      b.edgeT:SetColor(g[1], g[2], g[3], 1)
    end
  end
  f.w, f.h = PAD * 2 + cols * (SLOT + GAP) - GAP, TOP + PAD + rows * (SLOT + GAP) - GAP
  f:SetSize(f.w, f.h)
end

local function updateChips()
  if not chips then return end
  for _, b in ipairs(chips) do
    b:SetLabel(T(b.labelKey))
    b:SetKind(b.key == filter and "on" or "off")
  end
end

function ns.refreshBank()
  if not page or not page:IsShown() then return end
  for _, b in ipairs(buttons) do b:Hide() end
  for _, f in ipairs(blocks) do f:Hide() end
  used = 0
  search.ph:SetText(T("search"))
  search.clear.tip = T("clear")
  page.intro:SetText(T("intro"))
  updateChips()
  local term = (search:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  search.clear:SetShown(term ~= "")
  local data = RebirthTrackBank
  if not data or not data.containers then
    header:SetText(T("never")); search.counter:SetText(""); content:SetHeight(10); return
  end

  local totals, distinct, full, total = {}, 0, 0, 0
  for _, c in ipairs(data.containers) do
    total = total + c.slots
    for s = 1, c.slots do
      local it = c.items[s]
      if it and it.id then
        if not totals[it.id] then distinct = distinct + 1 end
        totals[it.id] = (totals[it.id] or 0) + (it.n or 1)
        full = full + 1
      end
    end
  end
  local C = ns.ui.HEX
  header:SetText(T("when"):format(ago(data.at), full, total, distinct)
    .. ((data.v or 1) < 2 and ("\n|cff" .. C.amber .. T("stale") .. "|r") or ""))
  local st = { term = term, active = term ~= "" or filter ~= "all", hits = 0 }

  local width = math.max(300, (scroll:GetWidth() or 640) - 4)
  local x, y, rowH, n = 0, 0, 0, 0
  local function place(f)
    if x > 0 and x + f.w > width then x, y, rowH = 0, y + rowH + 10, 0 end
    f:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    x, rowH = x + f.w + 10, math.max(rowH, f.h)
  end

  -- Casilleros del banco (Classic: 24 en 6 columnas o 28 en 7) y la fila de huecos de bolsa.
  local bags = {}
  for _, c in ipairs(data.containers) do
    if c.main or (c.id == BANK and not data.tabbed) then
      n = n + 1
      local f = block(n)
      setTitle(f, T("bank"))
      grid(f, c, c.slots > 28 and 8 or (c.slots % 7 == 0 and 7 or 6), totals, st)
      place(f)
    elseif not c.reagents then
      bags[#bags + 1] = c
    end
  end
  if not data.tabbed and #bags > 0 then
    n = n + 1
    local f = block(n)
    setTitle(f, T("bags"))
    for i, c in ipairs(bags) do
      local b = nextButton(f)
      b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * (SLOT + GAP), -TOP)
      local locked = data.bagSlots and i > data.bagSlots
      fill(b, c.link and { link = c.link, icon = c.icon, n = 1 } or nil, {}, locked and T("locked") or T("emptySlot"))
      if locked then
        setBg(b, { 0.898, 0.282, 0.302 }, 0.18)
        b.edgeT:SetColor(0.353, 0.165, 0.176, 1)
      end
      b:SetAlpha(1)
    end
    f.w, f.h = PAD * 2 + #bags * (SLOT + GAP) - GAP, TOP + PAD + SLOT
    f:SetSize(f.w, f.h)
    place(f)
  end
  x, y, rowH = 0, y + rowH + 10, 0

  -- Cada bolsa abierta (4 columnas, como en el juego), las pestañas y los componentes.
  for _, c in ipairs(data.containers) do
    if not (c.main or (c.id == BANK and not data.tabbed)) and c.slots > 0 then
      n = n + 1
      local f = block(n)
      local name = c.reagents and T("reagents") or c.tab and T("tab"):format(c.tab) or c.name or "?"
      setTitle(f, name .. " · " .. c.slots)
      grid(f, c, (c.tab or c.reagents) and 7 or 4, totals, st)
      place(f)
    end
  end
  content:SetSize(width, y + rowH + 10)
  search.counter:SetText(st.active and T("matches"):format(st.hits) or "")
end

-- Ventana propia del addon (como Plan del personaje y Reparto de botín): se mueve arrastrando, Esc
-- la cierra y recuerda dónde quedó.
local function createPage()
  if page then return end
  local U, C = ns.ui, ns.ui.C
  page = U.window("RebirthTrackBankFrame", 700, 580, T("page"), {
    onMoved = function(self)
      local point, _, rel, x, y = self:GetPoint()
      local u = ns.db().ui or {}
      u.bank = { point = point, rel = rel, x = x, y = y }
      ns.db().ui = u
    end,
  })
  local pos = (ns.db().ui or {}).bank
  page:ClearAllPoints()
  page:SetPoint(pos and pos.point or "CENTER", UIParent, pos and pos.rel or "CENTER", pos and pos.x or 0, pos and pos.y or 0)
  page:Hide()
  local y = page.top

  -- Búsqueda: una fila entera, con la lupa, el contador de coincidencias y la × para borrarla.
  local sbar = CreateFrame("Frame", nil, page)
  sbar:SetPoint("TOPLEFT", 1, y); sbar:SetPoint("TOPRIGHT", -1, y); sbar:SetHeight(44)
  local sl = U.tex(sbar, "ARTWORK", C.line); sl:SetHeight(1); sl:SetPoint("BOTTOMLEFT"); sl:SetPoint("BOTTOMRIGHT")
  search = U.input(sbar, 600, 28, T("search"))
  search:SetPoint("LEFT", 12, 0); search:SetPoint("RIGHT", -12, 0)
  if search.SetTextInsets then search:SetTextInsets(28, 120, 0, 0) end
  search.ph:ClearAllPoints(); search.ph:SetPoint("LEFT", 28, 0)
  local mag = search:CreateTexture(nil, "OVERLAY")
  mag:SetSize(14, 14); mag:SetPoint("LEFT", 8, 0)
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  if mag.SetVertexColor then mag:SetVertexColor(C.gold[1], C.gold[2], C.gold[3]) end
  search.clear = U.iconButton(search, 18, "×", function()
    search:SetText(""); search:ClearFocus(); ns.refreshBank()
  end)
  search.clear:SetPoint("RIGHT", -5, 0)
  search.counter = U.font(search, "GameFontHighlightSmall", C.muted, "RIGHT")
  search.counter:SetPoint("RIGHT", search.clear, "LEFT", -8, 0)
  search:SetScript("OnTextChanged", function(self)
    if self.updatePlaceholder then self.updatePlaceholder(self) end
    ns.refreshBank()
  end)
  y = y - 44

  -- Filtros por tipo (chips) y el resumen de lo anotado.
  local fbar = CreateFrame("Frame", nil, page)
  fbar:SetPoint("TOPLEFT", 1, y); fbar:SetPoint("TOPRIGHT", -1, y); fbar:SetHeight(62)
  U.fill(fbar, C.sub, 1)
  local fl = U.tex(fbar, "ARTWORK", C.line); fl:SetHeight(1); fl:SetPoint("BOTTOMLEFT"); fl:SetPoint("BOTTOMRIGHT")
  chips = {}
  for i, def in ipairs(FILTERS) do
    local b = U.button(fbar, T(def[2]), "off", function(self) filter = self.key; ns.refreshBank() end)
    b.key, b.labelKey = def[1], def[2]
    if i == 1 then b:SetPoint("TOPLEFT", 12, -8) else b:SetPoint("LEFT", chips[i - 1], "RIGHT", 6, 0) end
    chips[i] = b
  end
  header = U.font(fbar, "GameFontHighlightSmall", C.muted, "LEFT")
  header:SetPoint("TOPLEFT", 12, -36); header:SetPoint("RIGHT", -12, 0)
  y = y - 62

  -- Pie: de dónde sale lo que se ve (solo en esta PC).
  local ft = U.footer(page, 40)
  page.intro = U.font(ft, "GameFontHighlightSmall", C.muted, "LEFT")
  page.intro:SetPoint("LEFT", 12, 0); page.intro:SetPoint("RIGHT", -12, 0)

  scroll = CreateFrame("ScrollFrame", "RebirthTrackBankScroll", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, y - 10)
  scroll:SetPoint("BOTTOMRIGHT", ft, "TOPRIGHT", -30, 8)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(640, 10)
  scroll:SetScrollChild(content)
  page:SetScript("OnShow", function()
    page.title:SetText(T("page"))
    -- Sin el módulo de pedidos (Requests.lua carga después de este archivo) no hay chip de pedidos.
    local req = chips[#chips]
    if req.key == "requests" then
      local has = ns._requests and ns._requests.forItem and true or false
      req:SetShown(has)
      if not has and filter == "requests" then filter = "all" end
    end
    ns.refreshBank()
  end)
end

-- /rt banco y el botón de la ventana del addon: abre o cierra la ventana.
function ns.openBank()
  createPage()
  if page:IsShown() then page:Hide() else page:Show(); ns.refreshBank() end
end

-- ── Eventos ──────────────────────────────────────────────────────────────────────────────
local ON = {
  BANKFRAME_OPENED = function() bankOpen = true; scanSoon() end,
  BANKFRAME_CLOSED = function() bankOpen = false end, -- cerrado ya no se puede leer: queda lo último
  PLAYERBANKSLOTS_CHANGED = scanSoon,
  PLAYERBANKBAGSLOTS_CHANGED = scanSoon,
  PLAYERREAGENTBANKSLOTS_CHANGED = scanSoon,
  BAG_UPDATE = function() scanSoon() end,
  BAG_UPDATE_DELAYED = function() scanSoon() end,
}
local f = CreateFrame("Frame")
for e in pairs(ON) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, e, ...) local fn = ON[e]; if fn then fn(...) end end)

-- Para las pruebas.
ns._bank = { scan = scan, page = function() return page end, used = function() return used end }
