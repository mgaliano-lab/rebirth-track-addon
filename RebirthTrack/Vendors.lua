-- Rebirth Track · Lo que se compra en un vendedor
-- Para decir «se compra en el vendedor» cuando lo que falta para una receta (tooltip «Con lo del banco»,
-- materiales del Plan y detalle de Profesiones) es algo que vende un NPC. El juego no tiene una forma
-- de preguntarlo: se anota lo que vende cada vendedor que se abre (solo lo de stock infinito y por oro),
-- con precio, nombre del vendedor y zona, y se comparte por el canal de la guild, así lo aprende de
-- todos. Hasta haberlo visto, una lista fija de componentes de vendedor conocidos (hilos, tintes,
-- especias, viales, fundentes…) dice al menos «se vende en vendedores».
--
-- RebirthTrackDB.vendors[ítem] = "precio en cobre;vendedor;zona;hora"
-- Por el canal: "V;ítem;precio;vendedor;zona" (uno por ítem nuevo o con otro precio).
local ADDON, ns = ...
ns = ns or {}

local TEXTS = {
  es = { at = "se compra en el vendedor: %s (%s) · %s", atNoZone = "se compra en el vendedor: %s · %s", generic = "se vende en vendedores" },
  en = { at = "sold by a vendor: %s (%s) · %s", atNoZone = "sold by a vendor: %s · %s", generic = "sold by vendors" },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; return (TEXTS[l] or TEXTS.es)[key] or TEXTS.es[key] end

-- Componentes que venden los proveedores de comercio, cocina y profesiones (stock infinito).
local SEED = {}
for _, id in ipairs({
  159, 1179, 1205, 1645, 1708, 8766, -- agua y leche
  2320, 2321, 4291, 8343, 14341, -- hilos
  2324, 2325, 2604, 2605, 4340, 4341, 4342, 6260, 6261, 10290, -- blanqueador y tintes
  2678, 2692, 3713, 4289, 2665, 17194, 30817, -- especias, sal y harina
  2880, 3466, 3857, 18567, -- fundentes y carbón
  3371, 3372, 8925, 18256, -- viales
  6217, 4470, 4399, 4400, 11291, -- vara de cobre, madera simple, culatas y madera estelar
  2928, 2930, 5173, 8923, 8924, -- polvos y hierbas de venenos
}) do SEED[id] = true end

local function store()
  local d = ns.db and ns.db()
  if not d then return {} end
  d.vendors = d.vendors or {}
  return d.vendors
end
local function tok(s) return (tostring(s or ""):gsub("[|;\n\r\"]", " ")) end
local function itemOf(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end

local function coins(c)
  c = tonumber(c) or 0
  local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. "o" end
  if s > 0 then out[#out + 1] = s .. "p" end
  if k > 0 or #out == 0 then out[#out + 1] = k .. "c" end
  return table.concat(out, " ")
end

-- Lo que se sabe de un ítem: { price, vendor, zone } si se vio en un vendedor, { seed = true } si está
-- en la lista fija, nil si no se vende (o todavía no se sabe).
function ns.vendorInfo(id)
  id = tonumber(id)
  if not id then return nil end
  local v = store()[id]
  if type(v) == "string" then
    local price, vendor, zone = v:match("^(%d+);([^;]*);([^;]*)")
    if price then return { price = tonumber(price), vendor = vendor, zone = zone } end
  end
  if SEED[id] then return { seed = true } end
  return nil
end
-- El texto para mostrar (nil si no se vende).
function ns.vendorText(id)
  local v = ns.vendorInfo(id)
  if not v then return nil end
  if v.seed or not v.vendor or v.vendor == "" then return T("generic") end
  if v.zone and v.zone ~= "" then return T("at"):format(v.vendor, v.zone, coins(v.price)) end
  return T("atNoZone"):format(v.vendor, coins(v.price))
end

local function remember(id, price, vendor, zone, share)
  local s = store()
  local old = s[id]
  local oprice = type(old) == "string" and tonumber(old:match("^(%d+);")) or nil
  if oprice == price and old:find(";" .. tok(vendor) .. ";", 1, true) then return false end
  s[id] = table.concat({ price, tok(vendor), tok(zone), time() }, ";")
  if share and ns.send then ns.send(("V;%d;%d;%s;%s"):format(id, price, tok(vendor), tok(zone))) end
  return true
end

local function readMerchant()
  if not GetMerchantNumItems or not GetMerchantItemInfo or not GetMerchantItemLink then return end
  local vendor = UnitName and UnitName("npc") or ""
  local zone = GetZoneText and GetZoneText() or ""
  local sent = 0
  for i = 1, GetMerchantNumItems() or 0 do
    local _, _, price, qty, avail, _, _, extended = GetMerchantItemInfo(i)
    local id = itemOf(GetMerchantItemLink(i))
    -- Solo lo de stock infinito y por oro (no lo limitado ni lo que se paga con fichas).
    if id and price and price > 0 and (avail == nil or avail < 0) and not extended then
      local each = math.floor(price / math.max(1, qty or 1) + 0.5)
      if remember(id, each, vendor, zone, sent < 40) then sent = sent + 1 end
    end
  end
end

ns.onComm = ns.onComm or {}
ns.onComm.V = function(rest)
  local id, price, vendor, zone = tostring(rest or ""):match("^(%d+);(%d+);([^;]*);([^;]*)$")
  id, price = tonumber(id), tonumber(price)
  if not id or not price or price <= 0 or price > 1e7 then return end
  if store()[id] then return end -- lo que vi yo (o ya llegó) no lo pisa otro
  remember(id, price, vendor, zone, false)
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event) if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then pcall(readMerchant) end end)

-- Para las pruebas.
ns._vendors = { readMerchant = readMerchant, remember = remember, coins = coins }
