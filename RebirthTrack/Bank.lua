-- Rebirth Track · Banco personal (solo local)
-- Al abrir el banco se anota qué hay en cada casillero del banco y de sus bolsas, y en
-- Esc › Opciones › AddOns › Rebirth Track › Banco personal (o /rt banco) se ve como en el banco:
-- los casilleros del banco, la fila de bolsas y cada bolsa abierta, con el tooltip del ítem.
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
    emptySlot = "Hueco de bolsa sin bolsa", locked = "Hueco de bolsa sin comprar", tab = "Pestaña %d", reagents = "Componentes",
    ago = { now = "recién", min = "hace %d min", h = "hace %d h", d = "hace %d días" },
  },
  en = {
    page = "Personal bank", bank = "Bank", bags = "Bank bags",
    intro = "What's in your bank, to check it without going there. It's recorded every time you open it. It stays on your PC only: it isn't sent to the site or the guild.",
    never = "Nothing recorded yet: open the bank once with this character.",
    when = "Recorded %s · %d of %d slots used · %d different items",
    search = "Search…", count = "In the bank: %d", where = "%s, slot %d",
    emptySlot = "Bag slot without a bag", locked = "Bag slot not purchased", tab = "Tab %d", reagents = "Reagents",
    ago = { now = "just now", min = "%d min ago", h = "%d h ago", d = "%d days ago" },
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

-- Contenedores del banco según la versión: Classic (casilleros + bolsas), Retail viejo (+ componentes)
-- y Retail 11.2+ (pestañas del banco del personaje).
local function bankBags()
  local out = {}
  local tabs = Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1
  if tabs then
    for i = 0, 5 do out[#out + 1] = { id = tabs + i, tab = i + 1 } end
    return out, true
  end
  local first = (NUM_BAG_SLOTS or 4) + 1
  for i = 0, (NUM_BANKBAGSLOTS or 7) - 1 do out[#out + 1] = { id = first + i } end
  return out, false
end

local bankOpen = false
local function scan()
  if not bankOpen then return end
  local main = numSlots(BANK)
  local bags, tabbed = bankBags()
  if main == 0 and not tabbed then return end -- el banco no está cargado
  local containers = {}
  if main > 0 then
    local items = {}
    for s = 1, main do items[s] = itemAt(BANK, s) end
    containers[#containers + 1] = { id = BANK, slots = main, items = items }
  end
  for _, b in ipairs(bags) do
    local n = numSlots(b.id)
    local c = { id = b.id, slots = n, tab = b.tab, items = {} }
    if not b.tab then c.link, c.icon, c.name = bagItem(b.id) end
    for s = 1, n do c.items[s] = itemAt(b.id, s) end
    containers[#containers + 1] = c
  end
  if REAGENTS and IsReagentBankUnlocked and IsReagentBankUnlocked() then
    local n, items = numSlots(REAGENTS), {}
    for s = 1, n do items[s] = itemAt(REAGENTS, s) end
    if n > 0 then containers[#containers + 1] = { id = REAGENTS, slots = n, reagents = true, items = items } end
  end
  local bought = GetNumBankSlots and select(1, GetNumBankSlots()) or nil
  RebirthTrackBank = { v = 1, at = time(), bagSlots = bought, tabbed = tabbed or nil, containers = containers }
  if ns.refreshBank then ns.refreshBank() end
end
ns.scanBank = scan

local pending = false
local function scanSoon()
  if pending or not bankOpen then return end
  pending = true
  C_Timer.After(0.5, function() pending = false; pcall(scan) end)
end

-- ── Vista: como el banco del juego ────────────────────────────────────────────────────────
local SLOT, GAP = 37, 4
local page, content, scroll, header, search
local buttons, blocks = {}, {}

local function ago(at)
  local m = math.floor((time() - at) / 60)
  local a = T("ago")
  if m < 2 then return a.now elseif m < 60 then return a.min:format(m) elseif m < 1440 then return a.h:format(math.floor(m / 60)) end
  return a.d:format(math.floor(m / 1440))
end

local function qualityColor(q)
  local c = q and q > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
end

local function slotButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(SLOT, SLOT)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetTexture("Interface\\Buttons\\UI-Slot-Background")
  b.bg:SetTexCoord(0, 0.640625, 0, 0.640625)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints()
  b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -3, 3)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
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

local function fill(b, item, totals, emptyText)
  b.item, b.total, b.empty = item, item and totals[item.id], emptyText
  if item then
    b.icon:SetTexture(item.icon or (GetItemIcon and GetItemIcon(item.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
    b.icon:Show()
    b.count:SetText((item.n or 1) > 1 and item.n or "")
    local r, g, bl = qualityColor(item.q)
    if r then b.border:SetVertexColor(r, g, bl); b.border:Show() else b.border:Hide() end
  else
    b.icon:Hide(); b.count:SetText(""); b.border:Hide()
  end
end

local function matches(item, term)
  if term == "" then return true end
  if not item then return false end
  local name = item.link and item.link:match("%[(.-)%]") or (GetItemInfo and GetItemInfo(item.id)) or ""
  return name:lower():find(term, 1, true) ~= nil
end

local function block(i)
  local f = blocks[i]
  if not f then
    f = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
      f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
      f:SetBackdropBorderColor(0.6, 0.5, 0.35)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 30, -9)
    f.title:SetPoint("RIGHT", -8, 0)
    f.title:SetJustifyH("LEFT")
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(18, 18)
    f.icon:SetPoint("TOPLEFT", 8, -6)
    blocks[i] = f
  end
  f:ClearAllPoints()
  f:Show()
  return f
end

-- Arma un bloque con `slots` casilleros en `cols` columnas; devuelve su alto.
local function grid(f, c, cols, totals, term)
  local rows = math.ceil(c.slots / cols)
  for s = 1, c.slots do
    local b = nextButton(f)
    local col, row = (s - 1) % cols, math.floor((s - 1) / cols)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + col * (SLOT + GAP), -30 - row * (SLOT + GAP))
    fill(b, c.items[s], totals)
    b:SetAlpha(matches(c.items[s], term) and 1 or 0.25)
  end
  f.w, f.h = 20 + cols * (SLOT + GAP) - GAP, 40 + rows * (SLOT + GAP) - GAP
  f:SetSize(f.w, f.h)
end

function ns.refreshBank()
  if not page or not page:IsShown() then return end
  for _, b in ipairs(buttons) do b:Hide() end
  for _, f in ipairs(blocks) do f:Hide() end
  used = 0
  search.hint:SetText(T("search"))
  page.intro:SetText(T("intro"))
  local data = RebirthTrackBank
  if not data or not data.containers then header:SetText("|cff999999" .. T("never") .. "|r"); content:SetHeight(10); return end

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
  header:SetText(T("when"):format(ago(data.at), full, total, distinct))
  local term = (search:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  local width = math.max(300, (page:GetWidth() or 620) - 40)
  local x, y, rowH, n = 0, 0, 0, 0
  local function place(f)
    if x > 0 and x + f.w > width then x, y, rowH = 0, y + rowH + 10, 0 end
    f:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    x, rowH = x + f.w + 10, math.max(rowH, f.h)
  end

  -- Casilleros del banco (Classic: 24 en 6 columnas o 28 en 7) y la fila de huecos de bolsa.
  local bags = {}
  for _, c in ipairs(data.containers) do
    if c.id == BANK then
      n = n + 1
      local f = block(n)
      f.title:SetText(T("bank")); f.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
      grid(f, c, c.slots % 7 == 0 and 7 or 6, totals, term)
      place(f)
    elseif not c.reagents then
      bags[#bags + 1] = c
    end
  end
  if not data.tabbed and #bags > 0 then
    n = n + 1
    local f = block(n)
    f.title:SetText(T("bags")); f.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    for i, c in ipairs(bags) do
      local b = nextButton(f)
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * (SLOT + GAP), -30)
      local locked = data.bagSlots and i > data.bagSlots
      fill(b, c.link and { link = c.link, icon = c.icon, n = 1 } or nil, {}, locked and T("locked") or T("emptySlot"))
      if locked then b.bg:SetVertexColor(1, 0.2, 0.2) else b.bg:SetVertexColor(1, 1, 1) end
      b:SetAlpha(1)
    end
    f.w, f.h = 20 + #bags * (SLOT + GAP) - GAP, 40 + SLOT
    f:SetSize(f.w, f.h)
    place(f)
  end
  x, y, rowH = 0, y + rowH + 10, 0

  -- Cada bolsa abierta (4 columnas, como en el juego), las pestañas y los componentes.
  for _, c in ipairs(data.containers) do
    if c.id ~= BANK and c.slots > 0 then
      n = n + 1
      local f = block(n)
      f.title:SetText(c.reagents and T("reagents") or c.tab and T("tab"):format(c.tab) or c.name or "?")
      f.icon:SetTexture(c.icon or "Interface\\Icons\\INV_Misc_Bag_08")
      grid(f, c, (c.tab or c.reagents) and 7 or 4, totals, term)
      place(f)
    end
  end
  content:SetSize(width, y + rowH + 10)
end

local function createPage()
  if page or not ns.addOptionsPage then return end
  page = CreateFrame("Frame", "RebirthTrackBankPage", UIParent)
  page:Hide()
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  page.title = title
  page.intro = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  page.intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  page.intro:SetPoint("RIGHT", -24, 0)
  page.intro:SetJustifyH("LEFT")
  header = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  header:SetPoint("TOPLEFT", page.intro, "BOTTOMLEFT", 0, -8)
  search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  search:SetSize(180, 20)
  search:SetAutoFocus(false)
  search:SetPoint("TOPRIGHT", -24, -16)
  search.hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  search.hint:SetPoint("LEFT", 4, 0)
  search:SetScript("OnTextChanged", function(self)
    search.hint:SetShown((self:GetText() or "") == "")
    ns.refreshBank()
  end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  scroll = CreateFrame("ScrollFrame", "RebirthTrackBankScroll", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
  scroll:SetPoint("BOTTOMRIGHT", -30, 10)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 10)
  scroll:SetScrollChild(content)
  page:SetScript("OnShow", function() title:SetText(T("page")); ns.refreshBank() end)
  page:SetScript("OnSizeChanged", function() ns.refreshBank() end)
  ns.openBank = ns.addOptionsPage(page, T("page"))
end

-- ── Eventos ──────────────────────────────────────────────────────────────────────────────
local ON = {
  PLAYER_LOGIN = function() pcall(createPage) end,
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
