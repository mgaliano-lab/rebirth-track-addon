-- Rebirth Track · Recetas con lo del banco (solo local)
-- En la ventana de profesión del juego, al lado de cada receta, suma lo que tenés en el banco personal
-- (lo que anotó Bank.lua la última vez que lo abriste, RebirthTrackBank):
--   · «Venda de lana gruesa [1] (+Banco 3) (4)»: con el bolso hacés 1 y, trayendo lo del banco, 4.
--   · «(+Parcial Banco)»: el banco tiene parte de lo que falta, pero no alcanza para hacer una más.
-- Con el mouse encima, qué componentes están en el banco (y cuáles faltan, si es parcial).
-- En las ventanas clásicas (TradeSkillFrame y, en Vanilla, CraftFrame de Encantamiento) y en la nueva
-- (ProfessionsFrame), que es la que usa WoW Forever. En Retail no: el juego ya cuenta los bancos solo.
local ADDON, ns = ...
ns = ns or {}

local TEXTS = {
  es = {
    bank = "+Banco %d", partial = "+Parcial Banco", title = "Con lo del banco",
    from = "%s: %d del banco (hay %d)", missing = "%s: faltan %d", inBank = "%s: %d en el banco",
    hint = "Traé esto del banco para hacer %d más.", hintPartial = "Lo del banco no alcanza para hacer una más.",
    at = "Banco anotado %s", ago = { now = "recién", min = "hace %d min", h = "hace %d h", d = "hace %d días" },
  },
  en = {
    bank = "+Bank %d", partial = "+Partial Bank", title = "With what's in the bank",
    from = "%s: %d from the bank (%d there)", missing = "%s: %d missing", inBank = "%s: %d in the bank",
    hint = "Bring this from the bank to make %d more.", hintPartial = "What's in the bank isn't enough for one more.",
    at = "Bank recorded %s", ago = { now = "just now", min = "%d min ago", h = "%d h ago", d = "%d days ago" },
  },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; return (TEXTS[l] or TEXTS.es)[key] or TEXTS.es[key] end

local function ago(at)
  local m = math.floor((time() - at) / 60)
  local a = T("ago")
  if m < 2 then return a.now elseif m < 60 then return a.min:format(m) elseif m < 1440 then return a.h:format(math.floor(m / 60)) end
  return a.d:format(math.floor(m / 1440))
end

-- ── Cálculo (sin UI, para las pruebas) ───────────────────────────────────────────────────
-- Cuánto de cada ítem hay en el banco anotado.
local function bankTotals()
  local data, out = RebirthTrackBank, {}
  if not data or not data.containers then return nil end
  for _, c in ipairs(data.containers) do
    for s = 1, c.slots or 0 do
      local it = c.items and c.items[s]
      if it and it.id then out[it.id] = (out[it.id] or 0) + (it.n or 1) end
    end
  end
  return out
end

-- reagents = { { id, name, need, have, bank } }. Devuelve nil si el banco no suma nada; si no,
-- { bags, total, extra, partial, lines }.
local function calc(reagents)
  if #reagents == 0 then return nil end
  local bags, total, anyBank = math.huge, math.huge, false
  for _, r in ipairs(reagents) do
    if not r.need or r.need <= 0 then return nil end
    bags = math.min(bags, math.floor((r.have or 0) / r.need))
    total = math.min(total, math.floor(((r.have or 0) + (r.bank or 0)) / r.need))
    if (r.bank or 0) > 0 then anyBank = true end
  end
  if not anyBank then return nil end
  local extra = total - bags
  local lines = {}
  if extra > 0 then
    for _, r in ipairs(reagents) do
      local used = math.min(r.bank or 0, math.max(0, r.need * total - (r.have or 0)))
      if used > 0 then lines[#lines + 1] = T("from"):format(r.name or "?", used, r.bank) end
    end
    return { bags = bags, total = total, extra = extra, lines = lines }
  end
  -- Parcial: algún componente del banco sirve para la próxima, pero falta otro.
  local next, useful = bags + 1, false
  for _, r in ipairs(reagents) do
    local have, bank = r.have or 0, r.bank or 0
    if bank > 0 and have < r.need * next then useful = true; lines[#lines + 1] = T("inBank"):format(r.name or "?", bank) end
  end
  if not useful then return nil end
  for _, r in ipairs(reagents) do
    local short = r.need * next - (r.have or 0) - (r.bank or 0)
    if short > 0 then lines[#lines + 1] = "|cffff6060" .. T("missing"):format(r.name or "?", short) .. "|r" end
  end
  return { bags = bags, total = total, extra = 0, partial = true, lines = lines }
end

local function label(res)
  if not res then return nil end
  if res.partial then return "|cff9d9d9d(" .. T("partial") .. ")|r" end
  return "|cff4fc3f7(" .. T("bank"):format(res.extra) .. ")|r |cffffffff(" .. res.total .. ")|r"
end

-- ── Lo que pide cada receta, según la ventana ────────────────────────────────────────────
local function itemId(link) return link and tonumber(link:match("item:(%d+)")) end

local API = {
  trade = {
    prefix = "TradeSkillSkill", update = "TradeSkillFrame_Update", frame = "TradeSkillFrame",
    isHeader = function(i) local _, kind = GetTradeSkillInfo(i); return not kind or kind == "header" or kind == "subheader" end,
    num = function(i) return GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0 end,
    info = function(i, r) return GetTradeSkillReagentInfo(i, r) end,
    link = function(i, r) return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r) end,
  },
  craft = {
    prefix = "Craft", update = "CraftFrame_Update", frame = "CraftFrame",
    isHeader = function(i) local _, _, kind = GetCraftInfo(i); return not kind or kind == "header" end,
    num = function(i) return GetCraftNumReagents and GetCraftNumReagents(i) or 0 end,
    info = function(i, r) return GetCraftReagentInfo(i, r) end,
    link = function(i, r) return GetCraftReagentItemLink and GetCraftReagentItemLink(i, r) end,
  },
}

local function reagentsOf(api, index, totals)
  local out = {}
  for r = 1, api.num(index) do
    local name, _, need, have = api.info(index, r)
    local id = itemId(api.link(index, r))
    if not id then return {} end -- sin el ítem no se puede cruzar con el banco
    out[#out + 1] = { id = id, name = name, need = need, have = have, bank = totals[id] or 0 }
  end
  return out
end

local function forRecipe(api, index, totals)
  if not totals or api.isHeader(index) then return nil end
  return calc(reagentsOf(api, index, totals))
end

-- ── Etiqueta en cada fila ────────────────────────────────────────────────────────────────
local function tag(btn)
  if btn.rtBank then return btn.rtBank end
  local t = CreateFrame("Button", nil, btn)
  t:SetHeight(14)
  t:SetFrameLevel((btn:GetFrameLevel() or 1) + 2)
  t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.text:SetPoint("LEFT", t, "LEFT", 0, 0)
  t:SetScript("OnEnter", function(self)
    if not self.res then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(T("title"), 0.31, 0.76, 0.97)
    for _, l in ipairs(self.res.lines) do GameTooltip:AddLine(l, 1, 1, 1) end
    GameTooltip:AddLine(self.res.partial and T("hintPartial") or T("hint"):format(self.res.extra), 0.8, 0.8, 0.8, true)
    local at = RebirthTrackBank and RebirthTrackBank.at
    if at then GameTooltip:AddLine(T("at"):format(ago(at)), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  t:SetScript("OnClick", function() if btn.Click then btn:Click() end end) -- el clic sigue eligiendo la receta
  btn.rtBank = t
  return t
end

local function textWidth(fs)
  if not fs or (fs.IsShown and not fs:IsShown()) then return 0 end
  local w = fs:GetStringWidth() or 0
  local max = fs:GetWidth() or 0
  return (max > 0 and max < w) and max or w
end

-- text/count: el nombre y el «[n]» de la fila. modern: la ventana nueva, que ajusta el ancho del
-- nombre en cada fila (no hay que restaurarlo).
local function place(btn, res, text, count, modern)
  local t = tag(btn)
  if not modern then
    local name = btn:GetName() or ""
    text = _G[name .. "Text"] or (btn.GetFontString and btn:GetFontString())
    count = _G[name .. "Count"]
    if text and not text.rtW then text.rtW = text:GetWidth() end
  end
  if not res then
    t.res = nil; t:Hide()
    if not modern and text and text.rtW and text.rtW > 0 then text:SetWidth(text.rtW) end
    return
  end
  t.res = res
  t.text:SetText(label(res))
  local lw = (t.text:GetStringWidth() or 0) + 2
  t:SetWidth(lw)
  -- Si no entra en la fila, se achica el nombre (el juego lo corta con «…»).
  local cur = text and (modern and text:GetWidth() or text.rtW)
  if cur and cur > 0 then
    local room = (btn:GetWidth() or 0) - 24 - textWidth(count) - lw
    if room < cur then text:SetWidth(math.max(60, room)) elseif not modern then text:SetWidth(text.rtW) end
  end
  local after = (count and textWidth(count) > 0) and count or text
  t:ClearAllPoints()
  if after then t:SetPoint("LEFT", after, "LEFT", textWidth(after) + 4, 0) else t:SetPoint("RIGHT", btn, "RIGHT", -4, 0) end
  t:Show()
end

local function refresh(kind)
  local api = API[kind]
  local frame = _G[api.frame]
  if not frame or (frame.IsShown and not frame:IsShown()) then return end
  local totals = bankTotals()
  for i = 1, 60 do
    local btn = _G[api.prefix .. i]
    if not btn then break end
    local index = btn.IsShown and btn:IsShown() and btn.GetID and btn:GetID()
    local ok, res = false, nil
    if index and index > 0 then ok, res = pcall(forRecipe, api, index, totals) end
    pcall(place, btn, ok and res or nil)
  end
end

-- ── Ventana nueva (Forever y clientes con el motor de Retail) ────────────────────────────
-- ProfessionsFrame: la lista es un ScrollBox con filas recicladas; cada fila trae su receta en
-- GetElementData():GetData().recipeInfo, y los componentes salen de C_TradeSkillUI.GetRecipeSchematic.
local schematics = {}
local function basicType() return (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1 end
local function bagCount(id)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
  return GetItemCount and GetItemCount(id) or 0
end
local function itemName(id)
  local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  return n or (GetItemInfo and GetItemInfo(id)) or ("#" .. id)
end

local function modernReagents(recipeID, totals)
  local sch = schematics[recipeID]
  if sch == nil then
    sch = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeID, false) or false
    schematics[recipeID] = sch
  end
  if not sch or not sch.reagentSlotSchematics then return {} end
  local out = {}
  for _, slot in ipairs(sch.reagentSlotSchematics) do
    if (slot.reagentType == nil or slot.reagentType == basicType()) and (slot.required ~= false) then
      -- Un hueco puede aceptar varias calidades del mismo componente: cuentan todas juntas.
      local need, have, bank, first = slot.quantityRequired or 0, 0, 0, nil
      for _, r in ipairs(slot.reagents or {}) do
        if r.itemID then first = first or r.itemID; have = have + bagCount(r.itemID); bank = bank + (totals[r.itemID] or 0) end
      end
      if first and need > 0 then out[#out + 1] = { id = first, name = itemName(first), need = need, have = have, bank = bank } end
    end
  end
  return out
end

local function recipeOfRow(row)
  local ed = row.GetElementData and row:GetElementData()
  local data = ed and ed.GetData and ed:GetData()
  local info = data and data.recipeInfo
  if not info or not info.recipeID or info.learned == false then return nil end
  return info.recipeID
end

local function modernList()
  local pf = _G.ProfessionsFrame
  local list = pf and pf.CraftingPage and pf.CraftingPage.RecipeList
  return pf, list and list.ScrollBox
end

local function refreshModern()
  local pf, box = modernList()
  if not pf or not pf:IsShown() or not box or not box.ForEachFrame then return end
  local totals = bankTotals()
  box:ForEachFrame(function(row)
    local id = recipeOfRow(row)
    local ok, res = false, nil
    if id and totals then ok, res = pcall(calc, modernReagents(id, totals)) end
    pcall(place, row, ok and res or nil, row.Label, row.Count, true)
  end)
end

-- Las filas se reciclan al bajar por la lista o al buscar: mientras la ventana está abierta se repasa
-- cada cuarto de segundo (son unas 15 filas, no pesa).
local ticker = CreateFrame("Frame")
ticker:Hide()
local acc = 0
ticker:SetScript("OnUpdate", function(_, e)
  acc = acc + (e or 0)
  if acc < 0.25 then return end
  acc = 0
  pcall(refreshModern)
end)
local modernHooked = false
local function hookModern()
  local pf = _G.ProfessionsFrame
  if modernHooked or not pf or not pf.HookScript then return end
  modernHooked = true
  pf:HookScript("OnShow", function() schematics = {}; acc = 1; ticker:Show() end)
  pf:HookScript("OnHide", function() ticker:Hide() end)
  if pf:IsShown() then ticker:Show() end
end

-- ── Ganchos ──────────────────────────────────────────────────────────────────────────────
local hooked = {}
local function hook(kind)
  local api = API[kind]
  if hooked[kind] or type(_G[api.update]) ~= "function" then return end
  hooked[kind] = true
  hooksecurefunc(api.update, function() refresh(kind) end)
end
local function hookAll() hook("trade"); hook("craft"); hookModern() end

-- Cuando se vuelve a anotar el banco, se actualizan las ventanas abiertas.
ns.refreshBankCraft = function() refresh("trade"); refresh("craft"); pcall(refreshModern) end

local RETAIL = WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1)
if RETAIL then hookAll = function() end end
local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "ADDON_LOADED")
pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
f:SetScript("OnEvent", function() hookAll() end)
hookAll()

-- Para las pruebas.
ns._bankCraft = { calc = calc, label = label, totals = bankTotals, refresh = refresh, hookAll = hookAll, refreshModern = refreshModern, ticker = ticker }
