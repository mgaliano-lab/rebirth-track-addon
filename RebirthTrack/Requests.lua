-- Rebirth Track · Pedidos de materiales a la guild
-- En la ventana de profesión, debajo de lo que pide la receta, «Solicitar a la Guild» × N pide lo que
-- te falta (descontando bolsas y banco anotado) para hacerla N veces. El pedido viaja por el canal de
-- addons de la guild (RTK1) y lo revisan el GM, los oficiales (los rangos del consejo que manda el
-- sitio; si no, 0 y 1) y los revisores que agregue el GM. Cuando lo trasladan a la guild, todos los
-- que tengan el addon ven «Requerido por» en el tooltip del ítem (bolsas, banco, subasta, enlaces) y
-- un aviso al ir a venderlo o destruirlo. Alt+clic en el ítem abre los nombres listos para copiar.
-- No vence salvo que un revisor le ponga vencimiento; lo cierra quien lo pidió (destildando) o un revisor.
--
-- RebirthTrackDB.requests = { lines = { [id] = "rq1;…" }, reviewers = "rv1;…" } (lo sube la app):
--   rq1;id;quien pidió;creado;cambiado;estado;quién lo cambió;vence;receta;ítem:cantidad,…
--       estado: p pendiente (solo lo ven los revisores) · g trasladado a la guild · c cerrado
--       vence: 0 = nunca. «@web» como autor: lo cambió el sitio (rebirthknights.fun).
--   rv1;cambiado;quién (el GM);Nombre-Reino,…   revisores que agregó el GM
-- RebirthTrackRequests (Plans.lua, lo escribe la app): lo que trasladaron o cerraron en el sitio.
--
-- Por el canal:
--   "Q;rq1;…"  un cambio propio (o del sitio, si lo reenvía un revisor)
--   "W;rq1;…"  reenvío al que acaba de entrar (vale si el autor de la línea podía hacer ese cambio)
--   "Y;rv1;…"  lista de revisores (solo vale la del GM)
--   "R;desde"  al entrar: «mandenme lo que cambió desde esta hora»
local ADDON, ns = ...
ns = ns or {}

local MAX_LINES, MAX_ITEMS, MAX_REPLY, KEEP_CLOSED = 400, 8, 60, 30 * 86400
local EXPIRY_DAYS = { 0, 7, 14, 30 }

local TEXTS = {
  es = {
    ask = "Solicitar a la Guild", askTip = "Pide a la guild lo que te falta para hacer esta receta las veces que digas (descuenta lo que tenés en las bolsas y en el banco). Lo ven el GM, los oficiales y los revisores; cuando lo trasladan, lo ve toda la guild en el tooltip de esos materiales. Destildalo cuando ya no lo necesites.",
    times = "× %d", haveAll = "ya tenés todo lo que pide la receta: no hace falta pedir nada.",
    asked = "pedido a la guild: %s (%s).", cancelled = "pedido cerrado: %s.",
    title = "Pedidos de la guild", tabMine = "Mis pedidos", tabPending = "Pendientes", tabGuild = "En la guild", tabReviewers = "Revisores",
    none = "No hay pedidos.", promote = "Trasladar", close = "Cerrar", expires = "Vence: %s", never = "nunca",
    inDays = "en %d d", expired = "vencido", pending = "pendiente", inGuild = "en la guild", closed = "cerrado",
    page = "%d / %d", noPerm = "Solo el GM, los oficiales y los revisores revisan los pedidos.",
    reviewersIntro = "Revisan los pedidos el GM y los oficiales (rangos %s). El GM puede sumar personajes:",
    add = "Agregar", remove = "Quitar", onlyGM = "Solo el GM cambia la lista de revisores.", namePh = "Nombre-Reino",
    tipHeader = "Requerido por la guild:", tipPending = " (pendiente)", tipCopy = "Alt+clic: copiar los nombres",
    tipSell = "No lo vendas ni lo destruyas: alguien de la guild lo necesita.",
    copyTitle = "Requerido por", copyHint = "Ctrl+C para copiar · Esc para cerrar",
    sellWarn = "|cffff6060Ojo|r: en tus bolsas tenés materiales que pide la guild: %s.",
    deleteWarn = "|cffff4040Alguien de la guild necesita este ítem: %s.|r",
    expiryBtn = "Vence",
    off = "los pedidos a la guild están apagados (Esc › Opciones › AddOns › Rebirth Track).",
  },
  en = {
    ask = "Request from the Guild", askTip = "Asks the guild for what you're missing to craft this recipe as many times as you say (counting your bags and bank). The GM, officers and reviewers see it; once they promote it, the whole guild sees it on those materials' tooltip. Untick it when you no longer need it.",
    times = "× %d", haveAll = "you already have everything the recipe needs: nothing to request.",
    asked = "requested from the guild: %s (%s).", cancelled = "request closed: %s.",
    title = "Guild requests", tabMine = "My requests", tabPending = "Pending", tabGuild = "In the guild", tabReviewers = "Reviewers",
    none = "No requests.", promote = "Promote", close = "Close", expires = "Expires: %s", never = "never",
    inDays = "in %d d", expired = "expired", pending = "pending", inGuild = "in the guild", closed = "closed",
    page = "%d / %d", noPerm = "Only the GM, officers and reviewers review requests.",
    reviewersIntro = "The GM and officers (ranks %s) review requests. The GM can add characters:",
    add = "Add", remove = "Remove", onlyGM = "Only the GM changes the reviewer list.", namePh = "Name-Realm",
    tipHeader = "Needed by the guild:", tipPending = " (pending)", tipCopy = "Alt+click: copy the names",
    tipSell = "Don't sell or destroy it: someone in the guild needs it.",
    copyTitle = "Needed by", copyHint = "Ctrl+C to copy · Esc to close",
    sellWarn = "|cffff6060Heads up|r: your bags have materials the guild needs: %s.",
    deleteWarn = "|cffff4040Someone in the guild needs this item: %s.|r",
    expiryBtn = "Expires",
    off = "guild requests are turned off (Esc › Options › AddOns › Rebirth Track).",
  },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; return (TEXTS[l] or TEXTS.es)[key] or TEXTS.es[key] end
local function say(msg) if ns.say then ns.say(msg) else print(msg) end end

-- ── Nombres ──────────────────────────────────────────────────────────────────────────────
local function tok(s) return (tostring(s == nil and "" or s):gsub("[|;,=:@\n\r\"]", " ")) end
local function realmKey(r) return (tostring(r or ""):gsub("[%s%-'%.]", "")) end
local function homeRealm()
  return (GetNormalizedRealmName and GetNormalizedRealmName()) or realmKey(GetRealmName and GetRealmName() or "")
end
-- «Nombre-Reino» con el reino sin espacios (como lo manda el juego en los mensajes de addon).
local function full(name)
  name = tostring(name or "")
  local n, r = name:match("^(.-)%-([^%-]+)$")
  if not n or n == "" then n, r = name, homeRealm() end
  return n .. "-" .. realmKey(r)
end
local function key(name) return full(name):lower() end
local function short(name) return (full(name):gsub("%-[^%-]+$", "")) end
-- En Forever el personaje es «Nombre Apellido» (así viene en la lista de la guild): GetUnitName(…, true).
local function me() return full((GetUnitName and GetUnitName("player", true)) or UnitName("player") or "") end

local function enabled()
  local d = ns.db and ns.db()
  return not (d and d.settings and d.settings.requests == false)
end

-- ── Quién revisa ─────────────────────────────────────────────────────────────────────────
local function store()
  local d = ns.db()
  d.requests = d.requests or {}
  d.requests.lines = d.requests.lines or {}
  return d.requests
end
local function councilRanks()
  local src, out = rawget(_G, "RebirthTrackCouncil"), {}
  local list = type(src) == "table" and type(src.ranks) == "table" and #src.ranks > 0 and src.ranks or { 0, 1 }
  for _, r in ipairs(list) do out[tonumber(r) or -1] = true end
  out[0] = true -- el GM siempre
  return out, list
end
local function guildRank(name)
  if not GetNumGuildMembers or not IsInGuild or not IsInGuild() then return nil end
  local want = key(name)
  for i = 1, GetNumGuildMembers() or 0 do
    local n, _, rankIndex = GetGuildRosterInfo(i)
    if n and key(n) == want then return rankIndex end
  end
  return nil
end
local function reviewerList()
  local rv = store().reviewers
  local out = {}
  local names = type(rv) == "string" and rv:match("^rv1;%d+;[^;]*;(.*)$")
  for n in (names or ""):gmatch("[^,]+") do out[#out + 1] = n end
  return out
end
local function isGM(name) return guildRank(name) == 0 end
local function isReviewer(name)
  local r = guildRank(name)
  if r and councilRanks()[r] then return true end
  local want = key(name)
  for _, n in ipairs(reviewerList()) do if key(n) == want then return true end end
  return false
end

-- ── Líneas ───────────────────────────────────────────────────────────────────────────────
local function parse(line)
  if type(line) ~= "string" then return nil end
  local f = {}
  for v in (line .. ";"):gmatch("([^;]*);") do f[#f + 1] = v end
  if f[1] ~= "rq1" or #f < 10 or f[2] == "" or not f[6]:match("^[pgc]$") then return nil end
  local items = {}
  for id, n in f[10]:gmatch("(%d+):(%d+)") do items[#items + 1] = { id = tonumber(id), n = tonumber(n) } end
  if #items == 0 then return nil end
  return { id = f[2], who = f[3], created = tonumber(f[4]) or 0, at = tonumber(f[5]) or 0, status = f[6], by = f[7],
    expires = tonumber(f[8]) or 0, recipe = f[9], items = items, line = line }
end
local function build(r)
  local parts = {}
  for i, it in ipairs(r.items) do if i <= MAX_ITEMS then parts[#parts + 1] = it.id .. ":" .. it.n end end
  local itemsStr = table.concat(parts, ",")
  local head = table.concat({ "rq1", r.id, full(r.who), r.created, r.at, r.status, r.by, r.expires or 0 }, ";")
  -- Que entre en un mensaje (255, con «Q;» adelante): se acorta la receta.
  local room = 250 - #head - #itemsStr - 2
  local recipe = tok(r.recipe):sub(1, math.max(0, math.min(48, room)))
  return head .. ";" .. recipe .. ";" .. itemsStr
end

local function expired(r, now) return (r.expires or 0) > 0 and (now or time()) >= r.expires end
local function isOpen(r, now) return r.status ~= "c" and not expired(r, now) end

-- ¿Puede el autor de la línea hacer este cambio? trusted = lo escribió el sitio (Plans.lua).
local function allowed(new, old, trusted)
  if new.by == "@web" then return trusted end
  local reviewer = isReviewer(new.by)
  if reviewer then return true end
  if key(new.by) ~= key(new.who) then return false end
  -- Quien pidió: crea, cambia cantidades (sin subir de estado ni tocar el vencimiento) o cierra.
  if new.status == "c" then return true end
  if not old then return new.status == "p" and (new.expires or 0) == 0 end
  return old.status ~= "c" and new.status == old.status and (new.expires or 0) == (old.expires or 0)
end

local listeners = {}
local function changed() for _, fn in ipairs(listeners) do pcall(fn) end end

-- Guarda una línea si es más nueva que la que había y el autor podía. Devuelve el pedido si entró.
local function accept(line, trusted)
  local new = parse(line)
  if not new then return nil end
  local s = store()
  local old = parse(s.lines[new.id])
  if old and (old.at > new.at or (old.at == new.at and old.line == new.line)) then return nil end
  if old and key(old.who) ~= key(new.who) then return nil end
  if not allowed(new, old, trusted) then return nil end
  s.lines[new.id] = new.line
  return new
end

-- Se olvidan los cerrados (o vencidos) hace más de 30 días, y si hay demasiados, los más viejos.
local function prune(now)
  now = now or time()
  local s, all = store(), {}
  for id, line in pairs(s.lines) do
    local r = parse(line)
    if not r or (not isOpen(r, now) and now - math.max(r.at, r.expires or 0) > KEEP_CLOSED) then s.lines[id] = nil
    else all[#all + 1] = r end
  end
  if #all > MAX_LINES then
    table.sort(all, function(a, b) return a.at > b.at end)
    for i = MAX_LINES + 1, #all do s.lines[all[i].id] = nil end
  end
end

local function all()
  local out = {}
  for _, line in pairs(store().lines) do local r = parse(line); if r then out[#out + 1] = r end end
  table.sort(out, function(a, b) if a.created ~= b.created then return a.created > b.created end return a.id < b.id end)
  return out
end

-- Pedidos abiertos que piden este ítem y que este personaje puede ver (los pendientes, solo revisores).
local function forItem(id, now)
  if not id then return {} end
  local reviewer, out = isReviewer(me()), {}
  for _, r in ipairs(all()) do
    if isOpen(r, now) and (r.status == "g" or reviewer) then
      for _, it in ipairs(r.items) do if it.id == id then out[#out + 1] = { r = r, n = it.n }; break end end
    end
  end
  return out
end

-- ── Canal ────────────────────────────────────────────────────────────────────────────────
local function send(msg) if ns.send then ns.send(msg) end end
local function newestAt()
  local n = 0
  for _, r in ipairs(all()) do n = math.max(n, r.at) end
  return n
end
local heardAt = {}
local function nowT() return GetTime and GetTime() or time() end

local function onQ(rest, sender, relay)
  if not enabled() then return end
  local new = parse(rest)
  if not new then return end
  -- Un cambio propio lo manda su autor; uno del sitio, un revisor. Los reenvíos valen si el autor podía.
  if not relay then
    if new.by == "@web" then if not isReviewer(sender) then return end
    elseif key(new.by) ~= key(sender) then return end
  elseif new.by == "@web" and not isReviewer(sender) then return end
  local r = accept(rest, new.by == "@web")
  if r then heardAt[r.id] = nowT(); changed() end
end

local function acceptReviewers(line, sender, relay)
  local at, by = tostring(line or ""):match("^rv1;(%d+);([^;]*);")
  if not at or not isGM(by) or (not relay and key(by) ~= key(sender)) then return false end
  local cur = store().reviewers
  local curAt = tonumber(type(cur) == "string" and cur:match("^rv1;(%d+);") or 0) or 0
  if tonumber(at) <= curAt then return false end
  store().reviewers = line
  return true
end

local function reply(since)
  local asked = nowT()
  C_Timer.After(2 + math.random() * 5, function()
    local sent = 0
    for _, r in ipairs(all()) do
      if r.at > since and not (heardAt[r.id] and heardAt[r.id] >= asked) then
        send("W;" .. r.line); sent = sent + 1
        if sent >= MAX_REPLY then break end
      end
    end
    local rv = store().reviewers
    if type(rv) == "string" and (tonumber(rv:match("^rv1;(%d+);")) or 0) > since then send("Y;" .. rv) end
  end)
end

ns.onComm = ns.onComm or {}
ns.onComm.Q = function(rest, sender) onQ(rest, sender, false) end
ns.onComm.W = function(rest, sender) onQ(rest, sender, true) end
ns.onComm.Y = function(rest, sender) if enabled() and acceptReviewers(rest, sender, false) then changed() end end
ns.onComm.R = function(rest) if enabled() then local since = tonumber(rest); if since and newestAt() > since then reply(since) end end end

-- Un cambio hecho acá: se guarda y se avisa por el canal.
local function commit(r)
  r.at = math.max(time(), (r.at or 0) + 1)
  r.by = me()
  local line = build(r)
  if not accept(line, false) then return nil end
  send("Q;" .. line)
  changed()
  return parse(line)
end

-- Lo que trasladó o cerró el sitio (Plans.lua). Si soy revisor, lo reenvío a la guild.
local GAMES = { [1] = "retail", [2] = "era", [5] = "anniversary", [11] = "classic", [14] = "classic", [19] = "classic", [18] = "forever" }
local function loadWeb()
  local src = rawget(_G, "RebirthTrackRequests")
  if type(src) ~= "table" then return 0 end
  local list = type(src.lines) == "table" and (src.lines[GAMES[WOW_PROJECT_ID or 0] or ""] or (src.lines[1] and src.lines)) or {}
  local n, relay = 0, isReviewer(me())
  for _, line in ipairs(list) do
    local r = accept(tostring(line), true)
    if r then n = n + 1; if relay then send("Q;" .. r.line) end end
  end
  if n > 0 then changed() end
  return n
end

-- ── Acciones ─────────────────────────────────────────────────────────────────────────────
local function newId()
  return string.format("%x%02x", time(), math.random(0, 255))
end

local function itemsText(items, max)
  local parts = {}
  for i, it in ipairs(items) do
    if max and i > max then parts[#parts + 1] = "…"; break end
    local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(it.id)) or (GetItemInfo and GetItemInfo(it.id)) or ("#" .. it.id)
    parts[#parts + 1] = name .. " ×" .. it.n
  end
  return table.concat(parts, ", ")
end

-- Mi pedido abierto de esta receta (para el estado del checkbox).
local function mineFor(recipe)
  local want, mine = tok(recipe), key(me())
  for _, r in ipairs(all()) do
    if isOpen(r) and key(r.who) == mine and r.recipe == want:sub(1, #r.recipe) and #r.recipe > 0 then return r end
  end
  return nil
end

-- reagents = { { id, need, have, bank } }: lo que falta para hacerla n veces.
local function missing(reagents, n)
  local out = {}
  for _, g in ipairs(reagents or {}) do
    local short = (g.need or 0) * n - (g.have or 0) - (g.bank or 0)
    if g.id and short > 0 then out[#out + 1] = { id = g.id, n = short } end
  end
  return out
end

local function request(recipe, reagents, n)
  if not enabled() then say(T("off")); return nil end
  local items = missing(reagents, math.max(1, n or 1))
  local cur = mineFor(recipe)
  if #items == 0 then
    if cur then cur.status = "c"; commit(cur) end
    say(T("haveAll")); return nil
  end
  local r = cur or { id = newId(), who = me(), created = time(), status = "p", expires = 0, recipe = recipe }
  r.items = items
  local saved = commit(r)
  if saved then say(T("asked"):format(saved.recipe, itemsText(saved.items))) end
  return saved
end

local function cancel(recipe)
  local cur = mineFor(recipe)
  if not cur then return nil end
  cur.status = "c"
  local saved = commit(cur)
  if saved then say(T("cancelled"):format(saved.recipe)) end
  return saved
end

local function setStatus(r, status)
  r = parse(store().lines[r.id]) or r
  r.status = status
  return commit(r)
end
local function cycleExpiry(r)
  r = parse(store().lines[r.id]) or r
  -- nunca → 7 → 14 → 30 días → nunca (contando desde ahora).
  local now, cur = time(), 0
  if (r.expires or 0) > now then cur = math.floor((r.expires - now) / 86400 + 0.5) end
  local nextDays = 0
  for _, d in ipairs(EXPIRY_DAYS) do if d > cur then nextDays = d; break end end
  r.expires = nextDays > 0 and (now + nextDays * 86400) or 0
  return commit(r)
end

local function setReviewers(names)
  if not isGM(me()) then say(T("onlyGM")); return false end
  local clean, seen = {}, {}
  for _, n in ipairs(names) do
    local f = full((tok(n):gsub("^%s+", ""):gsub("%s+$", "")))
    if f ~= "-" and not f:match("^%-") and not seen[f:lower()] then seen[f:lower()] = true; clean[#clean + 1] = f end
  end
  local cur = store().reviewers
  local at = math.max(time(), (tonumber(type(cur) == "string" and cur:match("^rv1;(%d+);") or 0) or 0) + 1)
  local line = "rv1;" .. at .. ";" .. me() .. ";" .. table.concat(clean, ",")
  store().reviewers = line
  send("Y;" .. line)
  changed()
  return true
end

-- ── Tooltip y avisos ─────────────────────────────────────────────────────────────────────
local function merchantOpen() return (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()) and true or false end

local function addLines(tooltip, id)
  if not enabled() or not tooltip or not tooltip.AddLine then return end
  local list = forItem(id)
  if #list == 0 then return end
  tooltip:AddLine(T("tipHeader"), 1, 0.55, 0.1)
  for _, x in ipairs(list) do
    tooltip:AddLine("  " .. short(x.r.who) .. " ×" .. x.n .. (x.r.status == "p" and T("tipPending") or ""), 1, 1, 1)
  end
  if merchantOpen() then tooltip:AddLine(T("tipSell"), 1, 0.25, 0.25, true) end
  tooltip:AddLine(T("tipCopy"), 0.6, 0.6, 0.6)
  if tooltip.Show then tooltip:Show() end
end
local function idOf(link) return link and tonumber(tostring(link):match("item:(%d+)")) end

local tooltipHooked = false
local function hookTooltips()
  if tooltipHooked then return end
  tooltipHooked = true
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      if tooltip == GameTooltip or tooltip == ItemRefTooltip then pcall(addLines, tooltip, data and data.id) end
    end)
    return
  end
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tt and tt.HookScript then
      tt:HookScript("OnTooltipSetItem", function(self)
        local _, link = self:GetItem()
        pcall(addLines, self, idOf(link))
      end)
    end
  end
end

-- Ventanita con los nombres para copiar (WoW no deja a los addons escribir en el portapapeles).
local copy
local function showCopy(id)
  local list = forItem(id)
  if #list == 0 then return false end
  if not copy then
    copy = CreateFrame("Frame", "RebirthTrackRequestCopy", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    copy:SetSize(260, 150)
    copy:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    copy:SetFrameStrata("DIALOG")
    copy:EnableMouse(true); copy:SetMovable(true); copy:RegisterForDrag("LeftButton")
    copy:SetScript("OnDragStart", copy.StartMoving); copy:SetScript("OnDragStop", copy.StopMovingOrSizing)
    if copy.SetBackdrop then
      copy:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    end
    copy.title = copy:CreateFontString(nil, "OVERLAY", "GameFontNormal"); copy.title:SetPoint("TOP", 0, -12)
    local x = CreateFrame("Button", nil, copy, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -2, -2)
    x:SetScript("OnClick", function() copy:Hide() end)
    copy.edit = CreateFrame("EditBox", nil, copy, "InputBoxTemplate")
    copy.edit:SetMultiLine(true)
    copy.edit:SetAutoFocus(true)
    copy.edit:SetPoint("TOPLEFT", 18, -34); copy.edit:SetPoint("BOTTOMRIGHT", -16, 30)
    copy.edit:SetScript("OnEscapePressed", function() copy:Hide() end)
    copy.edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(copy.value or ""); self:HighlightText() end end)
    copy.hint = copy:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); copy.hint:SetPoint("BOTTOM", 0, 12)
  end
  local names = {}
  for _, x in ipairs(list) do names[#names + 1] = full(x.r.who) end
  copy.value = table.concat(names, "\n")
  copy.title:SetText(T("copyTitle"))
  copy.hint:SetText(T("copyHint"))
  copy.edit:SetText(copy.value)
  copy:Show()
  copy.edit:SetFocus(); copy.edit:HighlightText()
  return true
end

local function bagIds()
  local out = {}
  local C = C_Container
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  if not numSlots then return out end
  for b = 0, (NUM_BAG_SLOTS or 4) do
    for s = 1, numSlots(b) or 0 do
      local id
      if C and C.GetContainerItemID then id = C.GetContainerItemID(b, s)
      elseif GetContainerItemID then id = GetContainerItemID(b, s)
      elseif GetContainerItemInfo then id = select(10, GetContainerItemInfo(b, s)) end
      if id then out[id] = true end
    end
  end
  return out
end

-- Al abrir el vendedor o la subasta: qué de lo que llevás pide la guild.
local function warnBags()
  if not enabled() then return nil end
  local names = {}
  for id in pairs(bagIds()) do
    local list = forItem(id)
    if #list > 0 then
      local who = {}
      for _, x in ipairs(list) do who[#who + 1] = short(x.r.who) end
      names[#names + 1] = itemsText({ { id = id, n = 0 } }):gsub(" ×0$", "") .. " (" .. table.concat(who, ", ") .. ")"
    end
  end
  if #names == 0 then return nil end
  table.sort(names)
  local msg = T("sellWarn"):format(table.concat(names, "; "))
  say(msg)
  return msg
end

-- Al confirmar «¿Destruir…?»: se suma al cartel quién lo necesita.
local function onDeletePopup(which)
  if not enabled() or type(which) ~= "string" or not which:match("^DELETE_") then return end
  if not GetCursorInfo then return end
  local kind, id = GetCursorInfo()
  if kind ~= "item" then return end
  local list = forItem(tonumber(id))
  if #list == 0 then return end
  local who = {}
  for _, x in ipairs(list) do who[#who + 1] = short(x.r.who) end
  local msg = T("deleteWarn"):format(table.concat(who, ", "))
  local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
  local text = dialog and (dialog.text or dialog.Text or (dialog.GetName and _G[dialog:GetName() .. "Text"]))
  if text and text.GetText and text.SetText then
    text:SetText((text:GetText() or "") .. "\n\n" .. msg)
    if StaticPopup_Resize then pcall(StaticPopup_Resize, dialog, which) end
  end
  say(msg)
end

-- ── Checkbox en la receta ────────────────────────────────────────────────────────────────
-- Clásica: TradeSkillFrame (y CraftFrame en Vanilla), al lado de «Componentes:». Nueva
-- (ProfessionsFrame, la de Forever): arriba de los componentes de la receta elegida.
local function current()
  local pf = _G.ProfessionsFrame
  if pf and pf.IsShown and pf:IsShown() then
    local form = pf.CraftingPage and pf.CraftingPage.SchematicForm
    local info = form and ((form.GetRecipeInfo and form:GetRecipeInfo()) or form.currentRecipeInfo)
    if info and info.recipeID then
      return { recipe = info.name or ("#" .. info.recipeID), kind = "modern", index = info.recipeID,
        anchor = form.Reagents and (form.Reagents.Label or form.Reagents) or form, modern = true, parent = form }
    end
  end
  local tf = _G.TradeSkillFrame
  if tf and tf.IsShown and tf:IsShown() and GetTradeSkillSelectionIndex then
    local i = GetTradeSkillSelectionIndex()
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" and kind ~= "subheader" then
      return { recipe = name, kind = "trade", index = i, anchor = _G.TradeSkillReagentLabel, parent = tf }
    end
  end
  local cf = _G.CraftFrame
  if cf and cf.IsShown and cf:IsShown() and GetCraftSelectionIndex then
    local i = GetCraftSelectionIndex()
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then
      return { recipe = name, kind = "craft", index = i, anchor = _G.CraftReagentLabel, parent = cf }
    end
  end
  return nil
end

local function reagentsOf(c) return ns.recipeReagents and ns.recipeReagents(c.kind, c.index) or {} end

local box
local function createBox()
  if box then return box end
  box = CreateFrame("Frame", "RebirthTrackRequestBox", UIParent)
  box:SetSize(230, 24)
  box:SetFrameStrata("HIGH")
  box.check = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
  box.check:SetSize(22, 22)
  box.check:SetPoint("LEFT", 0, 0)
  box.label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  box.label:SetPoint("LEFT", box.check, "RIGHT", 2, 1)
  box.times = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  box.times:SetPoint("LEFT", box.label, "RIGHT", 8, 0)
  box.n = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
  box.n:SetSize(28, 18)
  box.n:SetAutoFocus(false)
  box.n:SetNumeric(true)
  box.n:SetMaxLetters(2)
  box.n:SetPoint("LEFT", box.times, "RIGHT", 6, 0)
  box.n:SetText("1")
  local function count() return math.max(1, tonumber(box.n:GetText()) or 1) end
  box.check:SetScript("OnClick", function(self)
    local c = current()
    if not c then return end
    if self:GetChecked() then request(c.recipe, reagentsOf(c), count()) else cancel(c.recipe) end
    box.update()
  end)
  box.n:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local c = current()
    if c and mineFor(c.recipe) then request(c.recipe, reagentsOf(c), count()) end
    box.update()
  end)
  box.n:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box.check:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(T("askTip"), 1, 1, 1, true); GameTooltip:Show() end)
  box.check:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box.lastRecipe = nil
  function box.update()
    local c = enabled() and current() or nil
    if not c or not c.anchor then box:Hide(); return end
    if box.lastParent ~= c.parent or box.lastAnchor ~= c.anchor then
      box:SetParent(c.parent)
      box:ClearAllPoints()
      if c.modern and c.anchor == c.parent then box:SetPoint("TOPRIGHT", c.parent, "TOPRIGHT", -8, -36)
      elseif c.modern then box:SetPoint("BOTTOMLEFT", c.anchor, "TOPLEFT", 0, 4)
      else box:SetPoint("LEFT", c.anchor, "RIGHT", 6, 0) end
      box:SetFrameLevel((c.parent.GetFrameLevel and c.parent:GetFrameLevel() or 1) + 10)
      box.lastParent, box.lastAnchor = c.parent, c.anchor
    end
    local mine = mineFor(c.recipe)
    box.label:SetText(T("ask"))
    box.times:SetText("×")
    if box.lastRecipe ~= c.recipe and not box.n:HasFocus() then box.n:SetText("1") end
    box.lastRecipe = c.recipe
    box.check:SetChecked(mine and true or false)
    box:Show()
  end
  return box
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, e)
  acc = acc + (e or 0)
  if acc < 0.4 then return end
  acc = 0
  if box then pcall(box.update) end
end)

-- ── Ventana de pedidos ───────────────────────────────────────────────────────────────────
local win
local ROWS = 9
local function backdrop(frame)
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
end
local function btn(parent, w, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

local function expiryText(r)
  if (r.expires or 0) == 0 then return T("never") end
  local left = r.expires - time()
  if left <= 0 then return T("expired") end
  return T("inDays"):format(math.max(1, math.floor(left / 86400 + 0.5)))
end

-- Qué muestra cada pestaña (para la ventana y las pruebas).
local function tabRows(tab)
  local out, mine, now = {}, key(me()), time()
  for _, r in ipairs(all()) do
    if tab == "mine" and key(r.who) == mine and isOpen(r, now) then out[#out + 1] = r
    elseif tab == "pending" and r.status == "p" and isOpen(r, now) then out[#out + 1] = r
    elseif tab == "guild" and r.status == "g" and isOpen(r, now) then out[#out + 1] = r end
  end
  return out
end

local refreshWin
local function createWindow()
  if win then return win end
  win = CreateFrame("Frame", "RebirthTrackRequestsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  win:SetSize(520, 420)
  win:SetFrameStrata("HIGH")
  win:SetClampedToScreen(true)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  backdrop(win)
  win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal"); win.title:SetPoint("TOP", 0, -14)
  local x = CreateFrame("Button", nil, win, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -2, -2)
  x:SetScript("OnClick", function() win:Hide() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "RebirthTrackRequestsFrame") end

  win.tab, win.page = "mine", 1
  win.tabs = {}
  for i, t in ipairs({ { "mine", "tabMine" }, { "pending", "tabPending" }, { "guild", "tabGuild" }, { "reviewers", "tabReviewers" } }) do
    local b = btn(win, 118, "", function() win.tab, win.page = t[1], 1; refreshWin() end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 122, -36)
    b.tab, b.key = t[1], t[2]
    win.tabs[#win.tabs + 1] = b
  end
  win.msg = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  win.msg:SetPoint("TOPLEFT", 18, -70); win.msg:SetPoint("RIGHT", -18, 0); win.msg:SetJustifyH("LEFT")

  win.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, win)
    row:SetSize(484, 32)
    row:SetPoint("TOPLEFT", 18, -66 - (i - 1) * 34)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", 0, -2); row.text:SetPoint("RIGHT", -190, 0)
    row.text:SetJustifyH("LEFT"); row.text:SetHeight(30)
    if row.text.SetWordWrap then row.text:SetWordWrap(true) end
    row.a = btn(row, 76, "", function() if row.onA then row.onA() end end); row.a:SetPoint("RIGHT", -110, 0)
    row.b = btn(row, 54, "", function() if row.onB then row.onB() end end); row.b:SetPoint("RIGHT", -54, 0)
    row.c = btn(row, 52, "", function() if row.onC then row.onC() end end); row.c:SetPoint("RIGHT", 0, 0)
    win.rows[i] = row
  end

  win.prev = btn(win, 26, "<", function() win.page = math.max(1, win.page - 1); refreshWin() end)
  win.prev:SetPoint("BOTTOMLEFT", 18, 14)
  win.next = btn(win, 26, ">", function() win.page = win.page + 1; refreshWin() end)
  win.next:SetPoint("LEFT", win.prev, "RIGHT", 4, 0)
  win.pageText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); win.pageText:SetPoint("LEFT", win.next, "RIGHT", 8, 0)

  -- Revisores: agregar por nombre (solo el GM).
  win.name = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
  win.name:SetSize(200, 20); win.name:SetAutoFocus(false)
  win.name:SetPoint("BOTTOMRIGHT", -100, 16)
  win.add = btn(win, 80, "", function()
    local n = win.name:GetText() or ""
    if n:match("%S") then
      local list = reviewerList(); list[#list + 1] = n
      if setReviewers(list) then win.name:SetText("") end
    end
    refreshWin()
  end)
  win.add:SetPoint("LEFT", win.name, "RIGHT", 6, 0)
  win.name:SetScript("OnEnterPressed", function() win.add:Click() end)
  win.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return win
end

function refreshWin()
  if not win or not win:IsShown() then return end
  local reviewer, gm = isReviewer(me()), isGM(me())
  win.title:SetText(T("title"))
  for _, b in ipairs(win.tabs) do
    b:SetText(T(b.key))
    local onlyRev = b.tab == "pending" or b.tab == "reviewers"
    b:SetEnabled((not onlyRev or reviewer) and b.tab ~= win.tab)
  end
  if (win.tab == "pending" or win.tab == "reviewers") and not reviewer then win.tab = "mine" end
  local rowsData, msg = {}, nil
  if win.tab == "reviewers" then
    local _, ranks = councilRanks()
    msg = T("reviewersIntro"):format(table.concat(ranks, ", "))
    for _, n in ipairs(reviewerList()) do rowsData[#rowsData + 1] = { reviewer = n } end
  else
    rowsData = tabRows(win.tab)
    if #rowsData == 0 then msg = T("none") end
  end
  local pages = math.max(1, math.ceil(#rowsData / ROWS))
  win.page = math.min(win.page, pages)
  win.msg:SetText(msg or ""); win.msg:SetShown(msg and true or false)
  local top = msg and -86 or -66
  for i, row in ipairs(win.rows) do
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 18, top - (i - 1) * 34)
    local d = rowsData[(win.page - 1) * ROWS + i]
    row.onA, row.onB, row.onC = nil, nil, nil
    row.a:Hide(); row.b:Hide(); row.c:Hide()
    if not d then row:Hide()
    elseif d.reviewer then
      row.text:SetText(d.reviewer)
      if gm then
        row.c:SetText(T("remove")); row.c:Show()
        row.onC = function()
          local list = {}
          for _, n in ipairs(reviewerList()) do if key(n) ~= key(d.reviewer) then list[#list + 1] = n end end
          setReviewers(list); refreshWin()
        end
      end
      row:Show()
    else
      local r = d
      local state = r.status == "g" and T("inGuild") or T("pending")
      row.text:SetText("|cffffffff" .. short(r.who) .. "|r · " .. r.recipe .. " · |cff9d9d9d" .. state .. " · " .. T("expires"):format(expiryText(r)) .. "|r\n" .. itemsText(r.items, 4))
      if reviewer and r.status == "p" then
        row.a:SetText(T("promote")); row.a:Show(); row.onA = function() setStatus(r, "g"); refreshWin() end
      end
      if reviewer then
        row.b:SetText(T("expiryBtn")); row.b:Show(); row.onB = function() cycleExpiry(r); refreshWin() end
      end
      if reviewer or key(r.who) == key(me()) then
        row.c:SetText(T("close")); row.c:Show(); row.onC = function() setStatus(r, "c"); refreshWin() end
      end
      row:Show()
    end
  end
  win.pageText:SetText(T("page"):format(win.page, pages))
  win.prev:SetEnabled(win.page > 1); win.next:SetEnabled(win.page < pages)
  local editing = win.tab == "reviewers" and gm
  win.name:SetShown(editing); win.add:SetShown(editing); win.add:SetText(T("add"))
end
listeners[#listeners + 1] = function() if win then refreshWin() end end

function ns.openRequests(tab)
  if not enabled() then say(T("off")); return end
  createWindow()
  if tab then win.tab = tab end
  win:Show()
  refreshWin()
end

-- ── Arranque ─────────────────────────────────────────────────────────────────────────────
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "MERCHANT_SHOW", "AUCTION_HOUSE_SHOW", "TRADE_SKILL_SHOW", "CRAFT_SHOW" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    hookTooltips()
    createBox()
    if hooksecurefunc then
      if type(HandleModifiedItemClick) == "function" then
        hooksecurefunc("HandleModifiedItemClick", function(link)
          if enabled() and IsAltKeyDown and IsAltKeyDown() then pcall(showCopy, idOf(link)) end
        end)
      end
      if type(StaticPopup_Show) == "function" then hooksecurefunc("StaticPopup_Show", function(which) pcall(onDeletePopup, which) end) end
    end
    prune()
    C_Timer.After(15, function()
      if not IsInGuild or not IsInGuild() then return end
      loadWeb()
      if enabled() then send("R;" .. newestAt()) end
    end)
  elseif event == "MERCHANT_SHOW" or event == "AUCTION_HOUSE_SHOW" then
    pcall(warnBags)
  elseif box then
    pcall(box.update)
  end
end)

-- Para las pruebas.
ns._requests = { parse = parse, build = build, accept = accept, allowed = allowed, request = request, cancel = cancel,
  setStatus = setStatus, cycleExpiry = cycleExpiry, setReviewers = setReviewers, isReviewer = isReviewer, forItem = forItem,
  missing = missing, mineFor = mineFor, tabRows = tabRows, loadWeb = loadWeb, warnBags = warnBags, addLines = addLines,
  showCopy = showCopy, onDeletePopup = onDeletePopup, prune = prune, all = all, store = store, full = full,
  refreshWin = function() return refreshWin() end, box = function() return box end, current = current }
