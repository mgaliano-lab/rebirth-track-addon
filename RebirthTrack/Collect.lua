-- Rebirth Track · Lo que el juego le muestra al jugador, anotado para el sitio
-- Personaje, balance, profesiones (niveles, recetas y cooldowns), equipo, talentos, bolsas y banco,
-- reputaciones, misiones completadas, subasta (solo lo que publicás y lo que comprás o vendés), banco
-- de la guild, historial de la guild, y en bandas y mazmorras el botín, los buffs al empezar cada jefe
-- y el equipo del resto (inspeccionando, fuera de combate). WoW no deja a los addons salir a internet:
-- todo queda en RebirthTrackDB y Rebirth Track Uploader lo sube cuando el juego guarda (/reload,
-- salir o desconectarse). Banco, correo, subasta, recetas y banco de la guild solo se ven con su
-- ventana abierta: se anotan cuando el jugador las abre.
--
-- Cada dato es una línea «tipo;dueño;hora;…» (sin «|», que WoW escapa, ni «;» dentro de los textos).
-- El dueño es el GUID del personaje (o «guild:<nombre>» para lo de la guild); la hora, de cuando
-- cambió por última vez.
--   RebirthTrackDB.data[dueño][clave] = el último estado
--     p1   nombre;reino;región;proyecto;clase;raza;nivel;facción;guild          (se comparte)
--     sk1  habilidad=nivel/máx,…  (profesiones, secundarias y armas)           (se comparte)
--     r1   profesión;nivel;máx;receta,…  (s<hechizo>, i<ítem> o n<nombre>)      (se comparte)
--     cd1  profesión;receta=hora en que vuelve a estar lista,…                  (se comparte)
--     eq1  ranura=ítem[:encantamiento],…  (propio o de alguien inspeccionado)   (se comparte el propio)
--     t1   grupo;rama~puntos~fila.columna.rango,…/…  (talentos, salvo Retail)  (se comparte)
--     mo1  balance en cobre (solo con la app y «Enviar mi balance» activada: AppSettings.lua)
--     pt1  tiempo jugado;en el nivel (al usar /played)
--     inv1 lugar;ítem:cantidad,…  (bags, bank, reagents)
--     rep1 facción=nivel:valor,… · q1 misión,… (completadas)
--     aho1 ítem:cantidad:oferta mínima:compra:oferta actual:tiempo:vendida,…  (lo que tenés publicado)
--     gb1  pestaña;nombre;ítem:cantidad,… · gbm1 balance · gx1 mensaje del día;información  (de la guild)
--   RebirthTrackDB.events = lo que pasa una vez (la hora es la del hecho):
--     lt1  botín en instancias (raro o mejor): quién;instancia;dificultad;ítem;cantidad;nombre de la instancia
--     bf1  buffs al empezar un jefe: encuentro;jefe;hechizo,…  (uno por jugador)
--     ahb1 compraste en la subasta: ítem;cantidad;precio;vendedor;nombre
--     ahi1 factura de la subasta (correo): buyer|seller;ítem;otro jugador;precio;compra;depósito;comisión;cantidad
--     ge1  historial de la guild: tipo;jugador;otro jugador;rango
--
-- Lo que no es privado y le sirve a la guild (personaje, profesiones, cooldowns, equipo y talentos)
-- se comparte por el canal de addons (RTK1), así lo sube cualquiera que tenga la app aunque vos no
-- la tengas. Lo recibido se guarda con «@remitente;» adelante. Balance, bolsas, banco, reputaciones,
-- misiones y subasta no se comparten: solo los sube tu app, a tu cuenta.
--
-- Por el canal (mensajes de hasta 255 caracteres):
--   "D;id;parte;partes;texto"  una línea, en partes de 200 caracteres
--   "E;desde"                  al entrar: «mandenme lo que cambió desde esta hora»
local ADDON, ns = ...
ns = ns or {}

local SHARED = { p1 = true, sk1 = true, r1 = true, cd1 = true, eq1 = true, t1 = true }
local KEYED = { r1 = true, cd1 = true, inv1 = true, gb1 = true } -- una por profesión, lugar o pestaña
local MAX_EVENTS, MAX_PEERS, MAX_REPLY, CHUNK = 1500, 400, 40, 200
local INSPECT_EVERY = 6 * 3600

local function tok(s) return (tostring(s == nil and "" or s):gsub("[|;,=/~:@\n\r\"]", " ")) end
local function J(...)
  local n, out = select("#", ...), {}
  for i = 1, n do
    local v = select(i, ...)
    out[i] = v == nil and "" or tostring(v)
  end
  return table.concat(out, ";", 1, n)
end
local function me() return UnitGUID("player") end
-- El balance de cada personaje se anota solo si la app está y su casilla «Enviar mi balance» está
-- activada: la app lo deja en AppSettings.lua (RebirthTrackApp.balance).
local function balanceOn() return type(RebirthTrackApp) == "table" and RebirthTrackApp.balance == true end

local function store()
  local d = ns.db()
  d.data = d.data or {}
  d.events = d.events or {}
  return d
end

-- "tipo;dueño;hora;resto" (sin el «@remitente;» de lo recibido).
local function body(line) return (line:gsub("^@[^;]*;", "", 1)) end
local function split4(line) return body(line):match("^(%w+);([^;]*);(%d+);(.*)$") end
local function keyOf(t, payload) return KEYED[t] and (t .. ":" .. (payload:match("^[^;]*") or "")) or t end

-- Guarda el estado propio (o de la guild, o de alguien inspeccionado). Si no cambió, queda la línea
-- vieja con su hora: la hora dice desde cuándo es así.
local share
local function put(owner, t, payload, doShare)
  if not owner or owner == "" then return false end
  local d = store()
  local c = d.data[owner] or {}
  d.data[owner] = c
  local key = keyOf(t, payload)
  local old = c[key]
  if old and old:sub(1, 1) ~= "@" and select(4, split4(old)) == payload then return false end
  local line = t .. ";" .. owner .. ";" .. time() .. ";" .. payload
  c[key] = line
  if doShare and SHARED[t] then share(line) end
  return true
end

local function saveBalance()
  local g = me()
  if g and GetMoney and balanceOn() then put(g, "mo1", tostring(GetMoney() or 0)) end
end

local function event(t, owner, payload, at)
  local ev = store().events
  ev[#ev + 1] = t .. ";" .. (owner or "") .. ";" .. math.floor(at or time()) .. ";" .. payload
  while #ev > MAX_EVENTS do table.remove(ev, 1) end
end

-- ── Canal de addons ────────────────────────────────────────────────────────────────────
local seq = 0
function share(line)
  if not ns.send then return end
  seq = seq % 4095 + 1
  local id = string.format("%x", seq)
  local n = math.ceil(#line / CHUNK)
  for i = 1, n do ns.send(("D;%s;%d;%d;%s"):format(id, i, n, line:sub((i - 1) * CHUNK + 1, i * CHUNK))) end
end

-- Si son demasiados, se olvida el que hace más tiempo que no cambia (lo propio nunca).
local function trimPeers()
  local d, count, oldest, oldestAt = store(), 0, nil, math.huge
  for owner, c in pairs(d.data) do
    if owner:match("^Player%-") and owner ~= me() then
      count = count + 1
      local newest = 0
      for _, line in pairs(c) do newest = math.max(newest, tonumber((select(3, split4(line)))) or 0) end
      if newest < oldestAt then oldest, oldestAt = owner, newest end
    end
  end
  if count > MAX_PEERS and oldest then d.data[oldest] = nil end
end

-- Una línea que mandó otro miembro: se guarda si es de un tipo que se comparte y más nueva que la que había.
local function putPeer(line, sender)
  local t, owner, at, payload = split4(line)
  at = tonumber(at)
  if not t or not SHARED[t] or not at or not owner:match("^Player%-[%w%-]+$") or owner == me() then return nil end
  local d = store()
  local c = d.data[owner] or {}
  d.data[owner] = c
  local key = keyOf(t, payload)
  local old = c[key]
  if old and (tonumber((select(3, split4(old)))) or 0) >= at then return nil end
  c[key] = "@" .. tok(sender) .. ";" .. line
  trimPeers()
  return owner .. "/" .. key
end

local partial, heardAt = {}, {}
local function onData(rest, sender)
  local id, i, n, chunk = rest:match("^(%x+);(%d+);(%d+);(.*)$")
  i, n = tonumber(i), tonumber(n)
  if not id or not i or not n or n < 1 or n > 80 or i < 1 or i > n then return end
  local nowT = GetTime()
  local k = sender .. "/" .. id
  local p = partial[k]
  if not p or p.n ~= n then
    for key, old in pairs(partial) do if nowT - old.t > 120 then partial[key] = nil end end
    p = { n = n, got = 0, parts = {}, t = nowT }
    partial[k] = p
  end
  if not p.parts[i] then p.parts[i], p.got = chunk, p.got + 1 end
  if p.got < n then return end
  partial[k] = nil
  local heard = putPeer(table.concat(p.parts, "", 1, n), Ambiguate and Ambiguate(sender, "none") or sender)
  if heard then heardAt[heard] = nowT end
end

-- Alguien entró y pidió lo que cambió desde «since»: tras una espera al azar se le manda (por el
-- canal, así lo ven todos), salvo lo que ya mandó otro mientras tanto.
local function onHello(rest)
  local since = tonumber(rest)
  if not since then return end
  local asked = GetTime()
  C_Timer.After(2 + math.random() * 6, function()
    local sent = 0
    for owner, c in pairs(store().data) do
      for key, line in pairs(c) do
        local t, _, at = split4(line)
        if SHARED[t] and (tonumber(at) or 0) > since and not ((heardAt[owner .. "/" .. key] or -1) >= asked)
          and (owner == me() or line:sub(1, 1) == "@") then
          share(body(line))
          sent = sent + 1
          if sent >= MAX_REPLY then return end
        end
      end
    end
  end)
end

ns.onComm = ns.onComm or {}
ns.onComm.D = onData
ns.onComm.E = onHello

-- ── Personaje ──────────────────────────────────────────────────────────────────────────
local function collectPlayer()
  local g = me()
  if not g then return end
  local _, class = UnitClass("player")
  local race = UnitRace and select(2, UnitRace("player")) or ""
  local guild = IsInGuild and IsInGuild() and GetGuildInfo("player") or ""
  put(g, "p1", J(tok(UnitName("player")), tok(GetRealmName()), ns.regionCode(), WOW_PROJECT_ID or 0, class or "",
    race or "", UnitLevel("player") or 0, UnitFactionGroup and UnitFactionGroup("player") or "", tok(guild)), true)
  saveBalance()
end

local function collectSkills()
  local g, out = me(), {}
  if not g then return end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() or 0 do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not header and rank then out[#out + 1] = tok(name) .. "=" .. rank .. "/" .. (max or 0) end
    end
  elseif GetProfessions and GetProfessionInfo then
    local p = { GetProfessions() }
    for i = 1, 6 do
      if p[i] then
        local name, _, rank, max = GetProfessionInfo(p[i])
        if name then out[#out + 1] = tok(name) .. "=" .. (rank or 0) .. "/" .. (max or 0) end
      end
    end
  end
  if #out > 0 then put(g, "sk1", table.concat(out, ","), true) end
end

-- ── Profesiones: recetas y cooldowns (con la ventana de la profesión abierta) ───────────
local function recipeId(link)
  if type(link) ~= "string" then return nil end
  local s = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
  if s then return "s" .. s end
  local it = link:match("item:(%d+)")
  return it and ("i" .. it) or nil
end
local function readyAt(cd) return math.floor((time() + cd) / 300 + 0.5) * 300 end

-- Las recetas se suman a las que ya estaban: una lista con categorías cerradas o con filtros no
-- borra nada. Si el nivel bajó (la olvidó y la volvió a aprender), arranca de cero.
local function saveProfession(prof, rank, max, ids, cds)
  local g = me()
  if not g or not prof or prof == "" or prof == "UNKNOWN" then return end
  prof, rank = tok(prof), tonumber(rank) or 0
  local set, list = {}, {}
  local c = store().data[g]
  local old = c and c["r1:" .. prof]
  if old then
    local orank, oids = (select(4, split4(old)) or ""):match("^[^;]*;(%d*);%d*;(.*)$")
    if (tonumber(orank) or 0) <= rank then
      for id in (oids or ""):gmatch("[^,]+") do if not set[id] then set[id] = true; list[#list + 1] = id end end
    end
  end
  for _, id in ipairs(ids) do if not set[id] then set[id] = true; list[#list + 1] = id end end
  if #list == 0 then return end
  table.sort(list)
  put(g, "r1", J(prof, rank, max or 0, table.concat(list, ",")), true)
  if #cds > 0 or (c and c["cd1:" .. prof]) then
    table.sort(cds)
    put(g, "cd1", J(prof, table.concat(cds, ",")), true)
  end
end

local function readTradeSkill()
  local T = C_TradeSkillUI
  if T and T.GetAllRecipeIDs then -- Retail
    if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild())
      or (T.IsNPCCrafting and T.IsNPCCrafting()) then return end
    local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    local child = T.GetChildProfessionInfo and T.GetChildProfessionInfo()
    local ids, cds = {}, {}
    for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
      local r = T.GetRecipeInfo(rid)
      if r and r.learned then
        ids[#ids + 1] = "s" .. rid
        local cd = T.GetRecipeCooldown and T.GetRecipeCooldown(rid)
        if cd and cd > 0 then cds[#cds + 1] = "s" .. rid .. "=" .. readyAt(cd) end
      end
    end
    local prof = base and base.professionName
    saveProfession(prof, (child and child.skillLevel) or (base and base.skillLevel) or 0,
      (child and child.maxSkillLevel) or (base and base.maxSkillLevel) or 0, ids, cds)
    return
  end
  if not GetTradeSkillLine or not GetNumTradeSkills then return end
  if IsTradeSkillLinked and IsTradeSkillLinked() then return end -- la de otro (link en el chat)
  local prof, rank, max = GetTradeSkillLine()
  local ids, cds = {}, {}
  for i = 1, GetNumTradeSkills() or 0 do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" and kind ~= "subheader" then
      local id = recipeId(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)) or recipeId(GetTradeSkillItemLink(i)) or ("n" .. tok(name))
      ids[#ids + 1] = id
      local cd = GetTradeSkillCooldown and GetTradeSkillCooldown(i)
      if cd and cd > 0 then cds[#cds + 1] = id .. "=" .. readyAt(cd) end
    end
  end
  saveProfession(prof, rank, max, ids, cds)
end

-- Encantamiento (y antes de WotLK) usa la ventana de «craft», con su propia API.
local function readCraft()
  if not GetNumCrafts or not GetCraftDisplaySkillLine then return end
  local prof, rank, max = GetCraftDisplaySkillLine()
  if not prof or not rank or rank == 0 then return end -- Adiestrar bestias no tiene nivel
  local ids = {}
  for i = 1, GetNumCrafts() or 0 do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then
      ids[#ids + 1] = recipeId(GetCraftRecipeLink and GetCraftRecipeLink(i)) or recipeId(GetCraftItemLink and GetCraftItemLink(i)) or ("n" .. tok(name))
    end
  end
  saveProfession(prof, rank, max, ids, {})
end

-- ── Equipo y talentos ──────────────────────────────────────────────────────────────────
local function gearOf(unit)
  local out = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink(unit, slot)
    local id, ench = link and link:match("item:(%d+):(%d*)")
    if id then out[#out + 1] = slot .. "=" .. id .. ((ench and ench ~= "" and ench ~= "0") and (":" .. ench) or "") end
  end
  return table.concat(out, ",")
end
local function collectGear()
  local g = me()
  local p = g and GetInventoryItemLink and gearOf("player")
  if p and p ~= "" then put(g, "eq1", p, true) end
end

-- Talentos por ramas (Classic Era, Forever, TBC); Retail y MoP tienen otro sistema y los da la API de Blizzard.
local function collectTalents()
  local g = me()
  if not g or not GetNumTalentTabs or not GetTalentInfo or not GetNumTalents then return end
  local tabs = {}
  for tab = 1, GetNumTalentTabs() or 0 do
    local a, b = GetTalentTabInfo(tab)
    local name = type(a) == "string" and a or (type(b) == "string" and b or "")
    local points, ranks = 0, {}
    for i = 1, GetNumTalents(tab) or 0 do
      local _, _, tier, col, rank = GetTalentInfo(tab, i)
      if rank and rank > 0 then
        points = points + rank
        ranks[#ranks + 1] = tier .. "." .. col .. "." .. rank
      end
    end
    table.sort(ranks)
    tabs[#tabs + 1] = tok(name) .. "~" .. points .. "~" .. table.concat(ranks, ",")
  end
  if #tabs > 0 then put(g, "t1", J(GetActiveTalentGroup and GetActiveTalentGroup() or 1, table.concat(tabs, "/")), true) end
end

-- ── Bolsas y banco ─────────────────────────────────────────────────────────────────────
local CB = C_Container
local function numSlots(bag)
  if CB and CB.GetContainerNumSlots then return CB.GetContainerNumSlots(bag) or 0 end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end
local function slotItem(bag, slot)
  if CB and CB.GetContainerItemInfo then
    local i = CB.GetContainerItemInfo(bag, slot)
    if i then return i.itemID, i.stackCount end
    return nil
  end
  if not GetContainerItemInfo then return nil end
  local _, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
  return id or (link and tonumber(link:match("item:(%d+)"))), count
end
local function counts(bags)
  local n = {}
  for _, b in ipairs(bags) do
    for s = 1, numSlots(b) do
      local id, c = slotItem(b, s)
      if id then n[id] = (n[id] or 0) + (c or 1) end
    end
  end
  return n
end
local function fmtCounts(n)
  local ids = {}
  for id in pairs(n) do ids[#ids + 1] = id end
  table.sort(ids)
  for i, id in ipairs(ids) do ids[i] = id .. ":" .. n[id] end
  return table.concat(ids, ",")
end
local function bagList()
  local out = {}
  for b = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do out[#out + 1] = b end
  return out
end
local function bankList()
  local B = Enum and Enum.BagIndex
  if B and B.CharacterBankTab_1 then -- Retail (pestañas del banco)
    local out = {}
    for i = 1, 6 do if B["CharacterBankTab_" .. i] then out[#out + 1] = B["CharacterBankTab_" .. i] end end
    return out
  end
  local out, first = { BANK_CONTAINER or -1 }, (NUM_BAG_SLOTS or 4) + 1
  for b = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do out[#out + 1] = b end
  return out
end

local bankOpen = false
local function collectBags()
  local g = me()
  if not g then return end
  put(g, "inv1", J("bags", fmtCounts(counts(bagList()))))
  if bankOpen then
    put(g, "inv1", J("bank", fmtCounts(counts(bankList()))))
    if REAGENTBANK_CONTAINER and IsReagentBankUnlocked and IsReagentBankUnlocked() then
      put(g, "inv1", J("reagents", fmtCounts(counts({ REAGENTBANK_CONTAINER }))))
    end
  end
  saveBalance()
end

-- ── Reputaciones y misiones ────────────────────────────────────────────────────────────
local function collectReputation()
  local g, out = me(), {}
  if not g then return end
  local R = C_Reputation
  if R and R.GetNumFactions and R.GetFactionDataByIndex then
    for i = 1, R.GetNumFactions() or 0 do
      local f = R.GetFactionDataByIndex(i)
      if f and f.factionID and (not f.isHeader or f.isHeaderWithRep) then
        out[#out + 1] = f.factionID .. "=" .. (f.reaction or 0) .. ":" .. (f.currentStanding or 0)
      end
    end
  elseif GetNumFactions and GetFactionInfo then
    for i = 1, GetNumFactions() or 0 do
      local _, _, standing, _, _, value, _, _, isHeader, _, hasRep, _, _, id = GetFactionInfo(i)
      if id and (not isHeader or hasRep) then out[#out + 1] = id .. "=" .. (standing or 0) .. ":" .. (value or 0) end
    end
  end
  if #out > 0 then put(g, "rep1", table.concat(out, ",")) end
end

local MAX_QUESTS = 8000
local function collectQuests()
  local g, ids = me(), {}
  if not g then return end
  if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
    for _, id in ipairs(C_QuestLog.GetAllCompletedQuestIDs() or {}) do ids[#ids + 1] = id end
  elseif GetQuestsCompleted then
    for id in pairs(GetQuestsCompleted() or {}) do ids[#ids + 1] = id end
  end
  if #ids == 0 or #ids > MAX_QUESTS then return end
  table.sort(ids)
  put(g, "q1", table.concat(ids, ","))
end

-- ── Subasta: lo que publicás, lo que comprás y las facturas del correo ─────────────────
local function collectOwnedAuctions()
  local g, out = me(), {}
  if not g then return end
  local A = C_AuctionHouse
  if A and A.GetNumOwnedAuctions then
    for i = 1, A.GetNumOwnedAuctions() or 0 do
      local a = A.GetOwnedAuctionInfo(i)
      if a and a.itemKey then
        out[#out + 1] = table.concat({ a.itemKey.itemID or 0, a.quantity or 1, 0, a.buyoutAmount or 0, a.bidAmount or 0,
          a.timeLeftSeconds or 0, a.status == 1 and 1 or 0 }, ":")
      end
    end
  elseif GetNumAuctionItems and GetAuctionItemInfo then
    for i = 1, (GetNumAuctionItems("owner")) or 0 do
      local _, _, count, _, _, _, _, minBid, _, buyout, bid, _, _, _, _, sold, itemId = GetAuctionItemInfo("owner", i)
      if itemId then
        out[#out + 1] = table.concat({ itemId, count or 1, minBid or 0, buyout or 0, bid or 0,
          GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("owner", i) or 0, sold == 1 and 1 or 0 }, ":")
      end
    end
  else
    return
  end
  put(g, "aho1", table.concat(out, ","))
end

-- Comprar al precio de compra (Classic): se anota en el momento. Las ofertas que ganás llegan como factura.
local function onBid(list, index, bid)
  if not GetAuctionItemInfo then return end
  local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, ownerFull, _, itemId = GetAuctionItemInfo(list, index)
  if itemId and buyout and buyout > 0 and bid and bid >= buyout then
    event("ahb1", me(), J(itemId, count or 1, bid, tok(ownerFull or owner), tok(name)))
  end
end

-- Facturas de la subasta en el correo: las ventas y compras quedan ahí 30 días. La hora es la del
-- envío (se calcula con los días que le quedan); la misma factura vista otro día no se repite.
local function collectInvoices()
  if not GetInboxNumItems or not GetInboxInvoiceInfo then return end
  local d = store()
  d.invoices = d.invoices or {}
  local seen = d.invoices
  for k, at in pairs(seen) do if time() - at > 40 * 86400 then seen[k] = nil end end
  for i = 1, GetInboxNumItems() or 0 do
    local kind, item, player, bid, buyout, deposit, fee, _, _, _, count = GetInboxInvoiceInfo(i)
    if kind == "buyer" or kind == "seller" then
      local daysLeft = select(7, GetInboxHeaderInfo(i)) or 30
      local sent = time() - math.floor((30 - daysLeft) * 86400)
      local key = table.concat({ kind, tok(item), tok(player), bid or 0, count or 1 }, "/")
      if not seen[key] or math.abs(seen[key] - sent) > 2 * 86400 then
        seen[key] = sent
        event("ahi1", me(), J(kind, tok(item), tok(player), bid or 0, buyout or 0, deposit or 0, fee or 0, count or 1), sent)
      end
    end
  end
end

-- ── Banda y botín ──────────────────────────────────────────────────────────────────────
local function inInstance()
  local inside, kind = IsInInstance()
  return inside and (kind == "raid" or kind == "party")
end

-- Patrón de Lua a partir de un texto del juego («%s recibe botín: %s.»), en el idioma del cliente.
local function pattern(fmt)
  local p = fmt:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
  p = p:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
  p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
  return "^" .. p .. "$"
end
local lootPatterns
local function getLootPatterns()
  if lootPatterns then return lootPatterns end
  lootPatterns = {}
  for _, x in ipairs({ { LOOT_ITEM_MULTIPLE, false }, { LOOT_ITEM, false }, { LOOT_ITEM_SELF_MULTIPLE, true }, { LOOT_ITEM_SELF, true } }) do
    if type(x[1]) == "string" then lootPatterns[#lootPatterns + 1] = { pat = pattern(x[1]), self = x[2] } end
  end
  return lootPatterns
end
local QUALITY = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6 }
local function quality(link)
  local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
  return hex and QUALITY[hex:lower()] or 0
end

local function onLoot(msg)
  if type(msg) ~= "string" or not inInstance() then return end
  for _, p in ipairs(getLootPatterns()) do
    local a, b, c = msg:match(p.pat)
    if a then
      local who, link, count
      if p.self then who, link, count = UnitName("player"), a, b else who, link, count = a, b, c end
      local id = link:match("item:(%d+)")
      if id and quality(link) >= 3 then
        local name, _, difficulty, _, _, _, _, instanceId = GetInstanceInfo()
        event("lt1", (p.self and me() or UnitGUID(who)) or "", J(tok(who), instanceId or 0, difficulty or 0, id, tonumber(count) or 1, tok(name)))
      end
      return
    end
  end
end

local function auraIds(unit)
  local ids = {}
  for i = 1, 40 do
    local sid
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
      if not a then break end
      sid = a.spellId
    elseif UnitBuff then
      local name, _, _, _, _, _, _, _, _, s = UnitBuff(unit, i)
      if not name then break end
      sid = s
    else
      break
    end
    if sid then ids[#ids + 1] = sid end
  end
  return table.concat(ids, ",")
end
local function groupUnits()
  local out = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
  else
    out[1] = "player"
    for i = 1, GetNumSubgroupMembers() do out[#out + 1] = "party" .. i end
  end
  return out
end
local function onEncounterStart(encounterId, encounterName)
  for _, u in ipairs(groupUnits()) do
    pcall(function() -- Retail 12 esconde datos de combate a los addons: si falla, se sigue con el resto
      local g = UnitGUID(u)
      local ids = g and auraIds(u)
      if ids and ids ~= "" then event("bf1", g, J(encounterId or 0, tok(encounterName), ids)) end
    end)
  end
end

-- Equipo del resto de la banda: de a uno, fuera de combate, a menos de 28 m y una vez cada 6 h por
-- jugador. No se toca si estás mirando a alguien con la ventana de inspeccionar.
local inspected, inspecting = {}, nil
local function inspectNext()
  if not IsInRaid() or not NotifyInspect or (InCombatLockdown and InCombatLockdown()) then return end
  if inspecting and time() - inspecting.at < 10 then return end
  if InspectFrame and InspectFrame:IsShown() then return end
  inspecting = nil
  for i = 1, GetNumGroupMembers() do
    local u = "raid" .. i
    local g = UnitGUID(u)
    if g and g ~= me() and time() - (inspected[g] or 0) > INSPECT_EVERY and CanInspect and CanInspect(u)
      and (not CheckInteractDistance or CheckInteractDistance(u, 1)) then
      inspecting = { guid = g, unit = u, at = time() }
      NotifyInspect(u)
      return
    end
  end
end
local function onInspectReady(guid)
  if not inspecting or inspecting.guid ~= guid then return end
  local u = inspecting.unit
  inspecting = nil
  inspected[guid] = time()
  if UnitGUID(u) ~= guid then return end
  local p = gearOf(u)
  if p ~= "" then put(guid, "eq1", p) end
  if ClearInspectPlayer and not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end
end

-- ── Guild: banco, mensaje del día, información e historial ─────────────────────────────
local function guildKey()
  local name = IsInGuild and IsInGuild() and GetGuildInfo("player")
  return name and ("guild:" .. tok(name)) or nil
end

local function collectGuildBank()
  local gk = guildKey()
  if not gk or not GetNumGuildBankTabs then return end
  local current = GetCurrentGuildBankTab and GetCurrentGuildBankTab()
  for tab = 1, GetNumGuildBankTabs() or 0 do
    local name, _, viewable = GetGuildBankTabInfo(tab)
    if viewable then
      local n, any = {}, false
      for slot = 1, 98 do
        local link = GetGuildBankItemLink(tab, slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
          local _, count = GetGuildBankItemInfo(tab, slot)
          n[id], any = (n[id] or 0) + (count or 1), true
        end
      end
      -- Una pestaña que todavía no cargó viene vacía: solo se anota vacía si es la que estás mirando.
      if any or tab == current then put(gk, "gb1", J(tab, tok(name), fmtCounts(n))) end
    end
  end
  if GetGuildBankMoney then put(gk, "gbm1", tostring(GetGuildBankMoney() or 0)) end
end
local function queryGuildBank()
  if not GetNumGuildBankTabs or not QueryGuildBankTab then return end
  for tab = 1, GetNumGuildBankTabs() or 0 do
    local _, _, viewable = GetGuildBankTabInfo(tab)
    if viewable then QueryGuildBankTab(tab) end
  end
end

local function collectGuildInfo()
  local gk = guildKey()
  if not gk then return end
  put(gk, "gx1", J(tok(GetGuildRosterMOTD and GetGuildRosterMOTD() or ""), tok(GetGuildInfoText and GetGuildInfoText() or "")))
end

-- Historial (ingresos, ascensos, descensos, expulsiones, salidas). El juego da «hace cuánto»: el
-- mismo hecho leído otro día cae unas horas corrido, así que no se repite si ya está a menos de 6 h.
local function collectGuildEvents()
  local gk = guildKey()
  if not gk or not GetNumGuildEvents or not GetGuildEventInfo then return end
  local d = store()
  d.guildEvents = d.guildEvents or {}
  local seen = d.guildEvents
  for i = 1, GetNumGuildEvents() or 0 do
    local kind, p1, p2, rank, y, m, dd, h = GetGuildEventInfo(i)
    if kind then
      local at = time() - ((((y or 0) * 365 + (m or 0) * 30 + (dd or 0)) * 24) + (h or 0)) * 3600
      at = math.floor(at / 3600) * 3600
      local key = table.concat({ gk, kind, tok(p1), tok(p2), tok(rank) }, "/")
      local prev = seen[key]
      if not prev or math.abs(prev - at) > 6 * 3600 then
        seen[key] = at
        event("ge1", gk, J(kind, tok(p1), tok(p2), tok(rank)), at)
      end
    end
  end
  for k, at in pairs(seen) do if time() - at > 120 * 86400 then seen[k] = nil end end
end

-- ── Eventos del juego ──────────────────────────────────────────────────────────────────
-- Cada lectura espera un instante (el juego manda varios avisos seguidos) y va con pcall: si una
-- versión de WoW no tiene alguna función, lo demás se sigue anotando.
local pending = {}
local function soon(name, fn, delay)
  if pending[name] then return end
  pending[name] = true
  C_Timer.After(delay or 2, function()
    pending[name] = nil
    pcall(fn)
  end)
end

local ON = {
  PLAYER_LOGIN = function()
    -- Sin la app o con «Enviar mi balance» desactivada, se borra el que haya quedado anotado.
    if not balanceOn() then for _, c in pairs(store().data) do c.mo1 = nil end end
    C_Timer.After(15, function()
      for _, fn in ipairs({ collectPlayer, collectSkills, collectGear, collectTalents, collectBags, collectReputation, collectQuests }) do pcall(fn) end
      if ns.send then ns.send("E;" .. math.max(0, (store().syncAt or 0) - 86400)) end
      pcall(function() if QueryGuildEventLog and IsInGuild() then QueryGuildEventLog() end end)
    end)
    if C_Timer.NewTicker then
      C_Timer.NewTicker(5, function() pcall(inspectNext) end)
      C_Timer.NewTicker(1800, function() pcall(function() if QueryGuildEventLog and IsInGuild() then QueryGuildEventLog() end end) end)
    end
  end,
  PLAYER_LOGOUT = function()
    for _, fn in ipairs({ collectPlayer, collectBags }) do pcall(fn) end
    store().syncAt = time()
  end,
  PLAYER_LEVEL_UP = function() soon("player", collectPlayer) end,
  PLAYER_GUILD_UPDATE = function() soon("player", collectPlayer) end,
  PLAYER_MONEY = function() soon("money", saveBalance, 5) end,
  SKILL_LINES_CHANGED = function() soon("skills", collectSkills) end,
  TRADE_SKILL_SHOW = function()
    pcall(function() if ExpandTradeSkillSubClass then ExpandTradeSkillSubClass(0) end end)
    soon("trade", readTradeSkill, 1)
  end,
  TRADE_SKILL_UPDATE = function() soon("trade", readTradeSkill) end,
  TRADE_SKILL_LIST_UPDATE = function() soon("trade", readTradeSkill) end,
  CRAFT_SHOW = function() soon("craft", readCraft, 1) end,
  CRAFT_UPDATE = function() soon("craft", readCraft) end,
  PLAYER_EQUIPMENT_CHANGED = function() soon("gear", collectGear) end,
  CHARACTER_POINTS_CHANGED = function() soon("talents", collectTalents) end,
  PLAYER_TALENT_UPDATE = function() soon("talents", collectTalents) end,
  BAG_UPDATE_DELAYED = function() soon("bags", collectBags, 3) end,
  BAG_UPDATE = function() soon("bags", collectBags, 3) end,
  BANKFRAME_OPENED = function() bankOpen = true; soon("bags", collectBags, 1) end,
  BANKFRAME_CLOSED = function() pcall(collectBags); bankOpen = false end,
  PLAYERBANKSLOTS_CHANGED = function() soon("bags", collectBags) end,
  PLAYERREAGENTBANKSLOTS_CHANGED = function() soon("bags", collectBags) end,
  UPDATE_FACTION = function() soon("rep", collectReputation, 5) end,
  QUEST_TURNED_IN = function() soon("quests", collectQuests, 5) end,
  TIME_PLAYED_MSG = function(total, level) local g = me(); if g and total then put(g, "pt1", J(total, level or 0)) end end,
  AUCTION_OWNED_LIST_UPDATE = function() soon("owned", collectOwnedAuctions, 1) end,
  OWNED_AUCTIONS_UPDATED = function() soon("owned", collectOwnedAuctions, 1) end,
  MAIL_INBOX_UPDATE = function() soon("mail", collectInvoices, 1) end,
  CHAT_MSG_LOOT = function(msg) pcall(onLoot, msg) end,
  ENCOUNTER_START = function(id, name) onEncounterStart(id, name) end,
  INSPECT_READY = function(guid) pcall(onInspectReady, guid) end,
  GUILDBANKFRAME_OPENED = function() pcall(queryGuildBank); soon("gbank", collectGuildBank, 2) end,
  GUILDBANKBAGSLOTS_CHANGED = function() soon("gbank", collectGuildBank) end,
  GUILDBANK_UPDATE_MONEY = function() soon("gbank", collectGuildBank) end,
  GUILD_ROSTER_UPDATE = function() soon("ginfo", collectGuildInfo, 3) end,
  GUILD_MOTD = function() soon("ginfo", collectGuildInfo, 3) end,
  GUILD_EVENT_LOG_UPDATE = function() soon("glog", collectGuildEvents, 1) end,
}

local cf = CreateFrame("Frame")
for e in pairs(ON) do pcall(cf.RegisterEvent, cf, e) end -- los que una versión no tiene, se saltean
cf:SetScript("OnEvent", function(_, e, ...) local fn = ON[e]; if fn then fn(...) end end)
if hooksecurefunc and PlaceAuctionBid then hooksecurefunc("PlaceAuctionBid", function(...) pcall(onBid, ...) end) end

-- /rt datos: qué hay anotado.
function ns.dataSummary()
  local d = store()
  local mine, peers, profs = 0, 0, 0
  for owner, c in pairs(d.data) do
    if owner:match("^Player%-") then
      local fromPeer = false
      for key, line in pairs(c) do
        if line:sub(1, 1) == "@" then fromPeer = true end
        if key:match("^r1:") then profs = profs + 1 end
      end
      if fromPeer then peers = peers + 1 else mine = mine + 1 end
    end
  end
  return mine, peers, profs, #d.events
end

-- Para las pruebas.
ns._collect = { put = put, putPeer = putPeer, share = share, pattern = pattern, collectBags = collectBags,
  collectOwnedAuctions = collectOwnedAuctions, collectInvoices = collectInvoices, readTradeSkill = readTradeSkill,
  readCraft = readCraft, collectGuildBank = collectGuildBank, collectGuildEvents = collectGuildEvents, onLoot = onLoot,
  onEncounterStart = onEncounterStart, inspectNext = inspectNext, onInspectReady = onInspectReady }
