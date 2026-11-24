-- Rebirth Track · Lo que el juego le muestra al jugador, anotado para el sitio
-- Personaje, profesiones (niveles, recetas y cooldowns), equipo, talentos, reputaciones, misiones
-- completadas, subasta (solo lo que publicás y lo que comprás o vendés), banco, balance y registro de
-- oro de la guild,
-- historial de la guild, y en bandas y mazmorras el botín, los buffs al empezar cada jefe y el equipo
-- del resto (inspeccionando, fuera de combate). El balance, las bolsas y el banco de cada persona no
-- se anotan. WoW no deja a los addons salir a internet:
-- todo queda en RebirthTrackDB y Rebirth Track Uploader lo sube cuando el juego guarda (/reload,
-- salir o desconectarse). Correo, subasta, recetas y banco de la guild solo se ven con su
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
--     rd1  profesión;nivel;máx;receta,…  la definición real de lo que ves en la ventana (se comparte):
--          receta = id:ítem que fabrica:fabrica mín:máx:dificultad (o y g r):ítemxcantidad.…:nombre
--     tt1  rama;CLASE;nombre;talento,…  el árbol de talentos real de tu clase (se comparte):
--          talento = fila:columna:rango máx:id de talento:fila:columna del requisito:nombre:ícono
--     eq1  ranura=ítem[:encantamiento],…  (propio o de alguien inspeccionado)   (se comparte el propio)
--     t1   grupo;rama~puntos~fila.columna.rango,…/…  (talentos, salvo Retail)  (se comparte)
--     pos1 mapa;x;y;continente;x;y;zona;instancia;nombre del continente  («off» si no la comparte) (se comparte)
--     pt1  tiempo jugado;en el nivel (al usar /played)
--     rep1 facción=nivel:valor,… · q1 misión,… (completadas)
--     aho1 ítem:cantidad:oferta mínima:compra:oferta actual:tiempo:vendida,…  (lo que tenés publicado)
--     gb1  pestaña;nombre;ítem:cantidad,…;casillero=ítem:cantidad,… · gbm1 balance · gx1 mensaje del día;información  (de la guild)
--   RebirthTrackDB.events = lo que pasa una vez (la hora es la del hecho):
--     lt1  botín en instancias (raro o mejor): quién;instancia;dificultad;ítem;cantidad;nombre de la instancia
--     rl1  tirada de botín en instancias (poco común o mejor), al cerrarse: instancia;dificultad;nombre de la
--          instancia;ítem;calidad;nombre del ítem;resultado (w ganó alguien, p pasaron todos, ? sin cierre);
--          ganador;su elección;su número;jefe (si cayó hace poco);quién:elección:número,…
--          (elección n Necesidad, g Codicia, d Desencantar, t Transfiguración, p Paso, a paso automático)
--     bf1  buffs al empezar un jefe: encuentro;jefe;hechizo,…  (uno por jugador)
--     ahb1 compraste en la subasta: ítem;cantidad;precio;vendedor;nombre
--     ahi1 factura de la subasta (correo): buyer|seller;ítem;otro jugador;precio;compra;depósito;comisión;cantidad
--     ge1  historial de la guild: tipo;jugador;otro jugador;rango
--     gm1  oro del banco de la guild: tipo;jugador;cobre  (deposit, withdraw, repair, buyTab, …)
--
-- Lo que no es privado y le sirve a la guild (personaje, profesiones, cooldowns, equipo y talentos)
-- se comparte por el canal de addons (RTK1), así lo sube cualquiera que tenga la app aunque vos no
-- la tengas. Lo recibido se guarda con «@remitente;» adelante. Reputaciones,
-- misiones y subasta no se comparten: solo los sube tu app, a tu cuenta.
--
-- Por el canal (mensajes de hasta 255 caracteres):
--   "D;id;parte;partes;texto"  una línea, en partes de 200 caracteres
--   "E;desde"                  al entrar: «mandenme lo que cambió desde esta hora»
-- Las tiradas (rl1) y el botín de instancias (lt1) también viajan por el canal y se reenvían a quien
-- entra (ver «Reenvío»): así llegan al sitio aunque quien estuvo en la instancia no tenga la app.
local ADDON, ns = ...
ns = ns or {}

local SHARED = { p1 = true, sk1 = true, r1 = true, cd1 = true, eq1 = true, t1 = true, pos1 = true, tt1 = true, rd1 = true }
local KEYED = { r1 = true, cd1 = true, gb1 = true, tt1 = true, rd1 = true } -- una por profesión, rama o pestaña
local MAX_EVENTS, MAX_PEERS, MAX_REPLY, CHUNK = 1500, 400, 40, 200
-- Hechos que viajan de addon en addon (ver «Reenvío» más abajo): las tiradas y el botín de instancias.
local RELAY = { rl1 = true, lt1 = true }
local RELAY_FOR, MAX_RELAY, MAX_RELAY_REPLY = 14 * 86400, 400, 20
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
local function put(owner, t, payload, doShare, force)
  if not owner or owner == "" then return false end
  local d = store()
  local c = d.data[owner] or {}
  d.data[owner] = c
  local key = keyOf(t, payload)
  local old = c[key]
  if not force and old and old:sub(1, 1) ~= "@" and select(4, split4(old)) == payload then return false end
  local line = t .. ";" .. owner .. ";" .. time() .. ";" .. payload
  c[key] = line
  if doShare and SHARED[t] then share(line) end
  return true
end

-- ── Reenvío ────────────────────────────────────────────────────────────────────────────
-- Las tiradas (rl1) y el botín de instancias (lt1) no tienen que esperar a que quien estuvo ahí tenga
-- la app: salen por el canal de la guild y cada addon que las recibe las guarda (con «@remitente;»
-- adelante, como lo demás recibido) y las vuelve a mandar cuando entra alguien que no las vio. Así
-- llegan al sitio con la app de cualquiera que se cruce con ellas, aunque no haya ido a la instancia.
-- RebirthTrackDB.relay[línea] = cuándo la conoció este addon (la anotó o la recibió): al que entra
-- se le manda lo conocido después de su última salida. Se olvidan a los 14 días.
local function relayIndex()
  local d = store()
  if not d.relay then
    d.relay = {}
    -- Lo anotado antes de esta versión (0.14.0) también viaja.
    for _, l in ipairs(d.events) do
      local t, _, at = split4(l)
      if RELAY[t] then d.relay[body(l)] = tonumber(at) end
    end
  end
  return d.relay
end

local function pruneRelay()
  local idx, now, n, oldest, oldestAt = relayIndex(), time(), 0, nil, math.huge
  for line, known in pairs(idx) do
    local at = tonumber((select(3, split4(line)))) or 0
    if at < now - RELAY_FOR then idx[line] = nil
    else
      n = n + 1
      if known < oldestAt then oldest, oldestAt = line, known end
    end
  end
  if n > MAX_RELAY and oldest then idx[oldest] = nil; pruneRelay() end
end

local function event(t, owner, payload, at)
  local ev = store().events
  local line = t .. ";" .. (owner or "") .. ";" .. math.floor(at or time()) .. ";" .. payload
  ev[#ev + 1] = line
  while #ev > MAX_EVENTS do table.remove(ev, 1) end
  if RELAY[t] then
    relayIndex()[line] = time()
    pruneRelay()
    share(line)
  end
end

-- Un hecho que mandó otro: se guarda una vez (lo mismo puede llegar de varios) y se devuelve su
-- clave para no reenviarlo si otro ya lo mandó.
local function putRelay(line, sender)
  line = body(line)
  local t, owner, at = split4(line)
  at = tonumber(at)
  local now = time()
  if not t or not RELAY[t] or not at or at < now - RELAY_FOR or at > now + 86400 then return nil end
  if owner ~= "" and not owner:match("^Player%-[%w%-]+$") then return nil end
  local idx = relayIndex()
  if not idx[line] then
    idx[line] = now
    local ev = store().events
    ev[#ev + 1] = "@" .. tok(sender) .. ";" .. line
    while #ev > MAX_EVENTS do table.remove(ev, 1) end
    pruneRelay()
  end
  return "ev/" .. line
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
  if t and RELAY[t] then return putRelay(line, sender) end
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
  if t == "pos1" and ns.onPeerPosition then ns.onPeerPosition(owner) end
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
    -- Tiradas y botín conocidos después de su última salida (de a pocos, sin repetir lo que ya mandó otro).
    local relayed = 0
    for line, known in pairs(relayIndex()) do
      if relayed >= MAX_RELAY_REPLY then break end
      if known > since and not ((heardAt["ev/" .. line] or -1) >= asked) then
        share(line)
        relayed = relayed + 1
      end
    end
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
  put(g, "p1", J(tok(UnitName("player")), tok(ns.selfRealm()), ns.regionCode(), WOW_PROJECT_ID or 0, class or "",
    race or "", UnitLevel("player") or 0, UnitFactionGroup and UnitFactionGroup("player") or "", tok(guild)), true)
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
local function itemOf(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
-- La definición de una receta como la ve el juego (rd1): id:ítem:mín:máx:dificultad:componentes:nombre.
local DIFF = { optimal = "o", orange = "o", medium = "y", yellow = "y", easy = "g", green = "g", trivial = "r", gray = "r", grey = "r" }
local function recipeDef(id, item, lo, hi, kind, reag, name)
  return table.concat({ id, item or 0, math.max(1, tonumber(lo) or 1), math.max(1, tonumber(hi) or tonumber(lo) or 1),
    DIFF[kind or ""] or "r", table.concat(reag, "."), tok(name) }, ":")
end
-- Se comparte cuando cambia lo que sabés o cómo son las recetas; si solo cambian los colores (subiste de
-- nivel), como mucho una vez por hora o cada 10 puntos, para no llenar el canal con cada punto.
local function saveDefs(prof, rank, max, defs)
  local g = me()
  if not g or not prof or prof == "" or prof == "UNKNOWN" or #defs == 0 then return end
  prof, rank = tok(prof), tonumber(rank) or 0
  table.sort(defs)
  local c = store().data[g]
  local old = c and c["rd1:" .. prof]
  if old then
    local at, orank, olist = old:match("^rd1;[^;]*;(%d+);[^;]*;(%d*);%d*;(.*)$")
    local function shape(list) return (tostring(list or ""):gsub(":[oygr]:", ":?:")) end
    if at and shape(olist) == shape(table.concat(defs, ",")) and math.abs((tonumber(orank) or 0) - rank) < 10
      and time() - (tonumber(at) or 0) < 3600 then return end
  end
  put(g, "rd1", J(prof, rank, max or 0, table.concat(defs, ",")), true)
end

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

local function snapTradeSkill()
  if IsTradeSkillLinked and IsTradeSkillLinked() then return nil end -- la de otro (link en el chat)
  local prof, rank, max = GetTradeSkillLine()
  local ids, cds, defs = {}, {}, {}
  for i = 1, GetNumTradeSkills() or 0 do
    local name, kind = GetTradeSkillInfo(i)
    if name and kind ~= "header" and kind ~= "subheader" then
      local id = recipeId(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)) or recipeId(GetTradeSkillItemLink(i)) or ("n" .. tok(name))
      ids[#ids + 1] = id
      local reag = {}
      for j = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)) or 0 do
        local _, _, count = GetTradeSkillReagentInfo(i, j)
        local rid = itemOf(GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j))
        if rid and count then reag[#reag + 1] = rid .. "x" .. count end
      end
      local lo, hi = 1, 1
      if GetTradeSkillNumMade then lo, hi = GetTradeSkillNumMade(i) end
      defs[#defs + 1] = recipeDef(id, itemOf(GetTradeSkillItemLink and GetTradeSkillItemLink(i)), lo, hi, kind, reag, name)
      local cd = GetTradeSkillCooldown and GetTradeSkillCooldown(i)
      if cd and cd > 0 then cds[#cds + 1] = id .. "=" .. readyAt(cd) end
    end
  end
  local again = GetTradeSkillLine() -- cambió mientras se leía la lista: no sirve
  if again ~= prof then return nil end
  return { prof = prof, rank = rank, max = max, ids = ids, cds = cds, defs = defs, sig = table.concat(ids, ",") }
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
  -- Al pasar de una profesión a otra, el juego avisa la nueva un instante antes de cambiar la lista
  -- (hasta la 0.5.3 eso anotaba, por ejemplo, las recetas de Peletería como de Primeros auxilios). Se
  -- lee dos veces, con medio segundo de diferencia, y solo se anota si las dos lecturas coinciden.
  local first = snapTradeSkill()
  if not first then return end
  C_Timer.After(0.5, function()
    local again = snapTradeSkill()
    if again and again.prof == first.prof and again.sig == first.sig then
      saveProfession(again.prof, again.rank, again.max, again.ids, again.cds)
      saveDefs(again.prof, again.rank, again.max, again.defs)
    end
  end)
end

-- Encantamiento (y antes de WotLK) usa la ventana de «craft», con su propia API.
local function readCraft()
  if not GetNumCrafts or not GetCraftDisplaySkillLine then return end
  local prof, rank, max = GetCraftDisplaySkillLine()
  if not prof or not rank or rank == 0 then return end -- Adiestrar bestias no tiene nivel
  local ids, defs = {}, {}
  for i = 1, GetNumCrafts() or 0 do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then
      local id = recipeId(GetCraftRecipeLink and GetCraftRecipeLink(i)) or recipeId(GetCraftItemLink and GetCraftItemLink(i)) or ("n" .. tok(name))
      ids[#ids + 1] = id
      local reag = {}
      for j = 1, (GetCraftNumReagents and GetCraftNumReagents(i)) or 0 do
        local _, _, count = GetCraftReagentInfo(i, j)
        local rid = itemOf(GetCraftReagentItemLink and GetCraftReagentItemLink(i, j))
        if rid and count then reag[#reag + 1] = rid .. "x" .. count end
      end
      defs[#defs + 1] = recipeDef(id, itemOf(GetCraftItemLink and GetCraftItemLink(i)), 1, 1, kind, reag, name)
    end
  end
  saveProfession(prof, rank, max, ids, {})
  saveDefs(prof, rank, max, defs)
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

-- El árbol de talentos real de tu clase (tt1, una línea por rama): para corregir el del sitio, que en
-- Forever sale de otra fuente. No depende de los puntos gastados: cambia solo si cambia el juego.
local function collectTalentTree()
  local g = me()
  if not g or not GetNumTalentTabs or not GetTalentInfo or not GetNumTalents then return end
  local _, class = UnitClass("player")
  if not class then return end
  for tab = 1, GetNumTalentTabs() or 0 do
    local a, b = GetTalentTabInfo(tab)
    local tabName = type(a) == "string" and a or (type(b) == "string" and b or "")
    local list = {}
    for i = 1, GetNumTalents(tab) or 0 do
      local name, icon, tier, col, _, max = GetTalentInfo(tab, i)
      if name and tier and col then
        local pt, pc = 0, 0
        if GetTalentPrereqs then local t, c2 = GetTalentPrereqs(tab, i); pt, pc = tonumber(t) or 0, tonumber(c2) or 0 end
        local link = GetTalentLink and GetTalentLink(tab, i)
        local tid = type(link) == "string" and tonumber(link:match("talent:(%d+)")) or 0
        list[#list + 1] = table.concat({ tier, col, max or 1, tid, pt, pc, tok(name), tonumber(icon) or "" }, ":")
      end
    end
    if #list > 0 then
      table.sort(list, function(x, y)
        local a1, a2 = x:match("^(%d+):(%d+)"); local b1, b2 = y:match("^(%d+):(%d+)")
        a1, a2, b1, b2 = tonumber(a1), tonumber(a2), tonumber(b1), tonumber(b2)
        if a1 ~= b1 then return a1 < b1 end
        return a2 < b2
      end)
      put(g, "tt1", J(tab, class, tok(tabName), table.concat(list, ",")), true)
    end
  end
end

-- «ítem:cantidad,…» ordenado por ítem (banco de la guild).
local function fmtCounts(n)
  local ids = {}
  for id in pairs(n) do ids[#ids + 1] = id end
  table.sort(ids)
  for i, id in ipairs(ids) do ids[i] = id .. ":" .. n[id] end
  return table.concat(ids, ",")
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

-- ── Tiradas de botín (Necesidad / Codicia / Desencantar / Paso) ───────────────────────
-- Lo que el juego avisa en el chat de botín mientras el grupo tira por un ítem: quién eligió qué, el
-- número que sacó cada uno y quién lo ganó. Se arma con los textos del cliente (en su idioma, y con
-- el orden de los argumentos que use: «%2$s … %1$d»). Al cerrarse (alguien gana o todos pasan) queda
-- un evento rl1; lo anota cada uno del grupo que tenga el addon y el sitio lo junta en uno.
-- Para cada texto: la elección (n Necesidad, g Codicia, d Desencantar, t Transfiguración, p Paso,
-- a paso automático), si es el propio («Has seleccionado…») y qué es cada argumento, en el orden
-- en que el juego se los pasa (w quién, i ítem, r número).
local ROLL_TEXTS = {
  { "LOOT_ROLL_NEED", "n", false, "wi" }, { "LOOT_ROLL_GREED", "g", false, "wi" },
  { "LOOT_ROLL_DISENCHANT", "d", false, "wi" }, { "LOOT_ROLL_TRANSMOG", "t", false, "wi" },
  { "LOOT_ROLL_PASSED", "p", false, "wi" }, { "LOOT_ROLL_PASSED_AUTO", "a", false, "wi" },
  { "LOOT_ROLL_PASSED_AUTO_FEMALE", "a", false, "wi" },
  { "LOOT_ROLL_NEED_SELF", "n", true, "i" }, { "LOOT_ROLL_GREED_SELF", "g", true, "i" },
  { "LOOT_ROLL_DISENCHANT_SELF", "d", true, "i" }, { "LOOT_ROLL_TRANSMOG_SELF", "t", true, "i" },
  { "LOOT_ROLL_PASSED_SELF", "p", true, "i" }, { "LOOT_ROLL_PASSED_SELF_AUTO", "a", true, "i" },
  { "LOOT_ROLL_ROLLED_NEED", "n", false, "riw", "rolled" }, { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "n", false, "riw", "rolled" },
  { "LOOT_ROLL_ROLLED_GREED", "g", false, "riw", "rolled" }, { "LOOT_ROLL_ROLLED_DE", "d", false, "riw", "rolled" },
  { "LOOT_ROLL_ROLLED_TRANSMOG", "t", false, "riw", "rolled" },
  { "LOOT_ROLL_WON_NO_SPAM_NEED", "n", false, "wri", "won" }, { "LOOT_ROLL_WON_NO_SPAM_GREED", "g", false, "wri", "won" },
  { "LOOT_ROLL_WON_NO_SPAM_DE", "d", false, "wri", "won" }, { "LOOT_ROLL_WON_NO_SPAM_TRANSMOG", "t", false, "wri", "won" },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "n", true, "ri", "won" }, { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "g", true, "ri", "won" },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "d", true, "ri", "won" }, { "LOOT_ROLL_YOU_WON_NO_SPAM_TRANSMOG", "t", true, "ri", "won" },
  { "LOOT_ROLL_WON", nil, false, "wi", "won" }, { "LOOT_ROLL_YOU_WON", nil, true, "i", "won" },
  { "LOOT_ROLL_ALL_PASSED", nil, false, "i", "passed" },
}

-- Patrón de un texto del juego y, por cada captura (en el orden en que aparecen), qué argumento es.
local function fmtPattern(fmt)
  local order, n, lits = {}, 0, 0
  local p = fmt:gsub("%%(%d?)%$?([sd])", function(pos, kind)
    n = n + 1
    order[#order + 1] = tonumber(pos) or n
    return kind == "s" and "\1" or "\2"
  end)
  lits = #(p:gsub("[\1\2]", ""))
  p = p:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
  p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
  return "^" .. p .. "$", order, lits
end

local rollPatterns
local function getRollPatterns()
  if rollPatterns and #rollPatterns > 0 then return rollPatterns end
  rollPatterns = {}
  for _, x in ipairs(ROLL_TEXTS) do
    local fmt = _G[x[1]]
    if type(fmt) == "string" and fmt ~= "" then
      local pat, order, lits = fmtPattern(fmt)
      rollPatterns[#rollPatterns + 1] = { pat = pat, order = order, lits = lits, choice = x[2], self = x[3], roles = x[4], what = x[5] or "chose" }
    end
  end
  -- El más específico primero: «Has ganado: %s» antes que «%s ha ganado: %s».
  table.sort(rollPatterns, function(a, b) return a.lits > b.lits end)
  return rollPatterns
end

local MAX_ROLL_AGE = 15 * 60 -- una tirada sin cierre (te fuiste del grupo) se anota igual a los 15 min
local rolls, lastBoss = {}, nil

local function rollLine(r, result, winner, wc, wn)
  local list = {}
  for _, who in ipairs(r.order) do
    local c = r.choices[who]
    list[#list + 1] = tok(who) .. ":" .. (c.c or "") .. ":" .. (c.n or "")
  end
  local boss = ""
  if lastBoss and lastBoss.instanceId == r.instanceId and r.at >= lastBoss.at - 60 and r.at - lastBoss.at <= 300 then boss = lastBoss.name end
  event("rl1", me() or "", J(r.instanceId, r.difficulty, tok(r.instance), r.item, r.quality, tok(r.name), result, tok(winner or ""),
    wc or "", wn or "", tok(boss), table.concat(list, ",")), r.at)
end

local function closeRoll(r, result, winner)
  for i, x in ipairs(rolls) do if x == r then table.remove(rolls, i) break end end
  local c = winner and r.choices[winner]
  rollLine(r, result, winner, c and c.c, c and c.n)
end

local function flushStaleRolls()
  local now = time()
  for i = #rolls, 1, -1 do
    local r = rolls[i]
    if now - r.at > MAX_ROLL_AGE then closeRoll(r, "?") end
  end
end

local function openRoll(link)
  local id = link:match("item:(%d+)")
  if not id or quality(link) < 2 then return nil end
  local name, _, difficulty, _, _, _, _, instanceId = GetInstanceInfo()
  local r = { link = link, item = tonumber(id), quality = quality(link), name = link:match("%[(.-)%]") or "", at = time(),
    instance = name or "", difficulty = difficulty or 0, instanceId = instanceId or 0, choices = {}, order = {} }
  rolls[#rolls + 1] = r
  return r
end

-- La tirada abierta de ese ítem que cumple «ok» (puede haber dos iguales a la vez: va a la primera).
local function findRoll(link, ok)
  for _, r in ipairs(rolls) do if r.link == link and (not ok or ok(r)) then return r end end
end

local function setChoice(r, who, c, n)
  local x = r.choices[who]
  if not x then x = {}; r.choices[who] = x; r.order[#r.order + 1] = who end
  if c then x.c = c end
  if n then x.n = n end
end

local function onRollMsg(msg)
  if type(msg) ~= "string" or not inInstance() then return end
  for _, p in ipairs(getRollPatterns()) do
    local caps = { msg:match(p.pat) }
    if caps[1] then
      local args = {}
      for k, pos in ipairs(p.order) do args[pos] = caps[k] end
      local who, link, n
      for k = 1, #p.roles do
        local role, v = p.roles:sub(k, k), args[k]
        if role == "w" then who = v elseif role == "i" then link = v elseif role == "r" then n = tonumber(v) end
      end
      if p.self then who = UnitName("player") end
      if not link or not link:match("item:%d+") then return end
      flushStaleRolls()
      if p.what == "chose" then
        local r = findRoll(link, function(x) return not x.choices[who] end) or openRoll(link)
        if r then setChoice(r, who, p.choice) end
      elseif p.what == "rolled" then
        local r = findRoll(link, function(x) return x.choices[who] and not x.choices[who].n end)
          or findRoll(link, function(x) return not x.choices[who] end) or openRoll(link)
        if r then setChoice(r, who, p.choice, n) end
      elseif p.what == "won" then
        local r = findRoll(link, function(x) local c = x.choices[who]; return c and (not n or not c.n or c.n == n) end)
          or findRoll(link) or openRoll(link)
        if r then
          setChoice(r, who, p.choice, n)
          closeRoll(r, "w", who)
        end
      else
        local r = findRoll(link) or openRoll(link)
        if r then closeRoll(r, "p") end
      end
      return
    end
  end
end

-- Al empezar una tirada (la ventana de Necesidad/Codicia): queda abierta desde ahora.
local function onStartRoll(rollID)
  if not inInstance() or not GetLootRollItemLink then return end
  local link = GetLootRollItemLink(rollID)
  if type(link) == "string" then flushStaleRolls(); openRoll(link) end
end

local function onEncounterEnd(encounterId, encounterName, _, _, success)
  if success ~= 1 and success ~= true then return end
  local _, _, _, _, _, _, _, instanceId = GetInstanceInfo()
  lastBoss = { name = encounterName or "", id = encounterId, instanceId = instanceId or 0, at = time() }
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
      local n, slots, any = {}, {}, false
      for slot = 1, 98 do
        local link = GetGuildBankItemLink(tab, slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
          local _, count = GetGuildBankItemInfo(tab, slot)
          n[id], any = (n[id] or 0) + (count or 1), true
          slots[#slots + 1] = slot .. "=" .. id .. ":" .. (count or 1) -- dónde está, para mostrarlo como en el juego
        end
      end
      -- Una pestaña que todavía no cargó viene vacía: solo se anota vacía si es la que estás mirando.
      if any or tab == current then put(gk, "gb1", J(tab, tok(name), fmtCounts(n), table.concat(slots, ","))) end
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

-- Registro de oro del banco (depósitos, retiros, reparaciones, compra de pestañas). Como el
-- historial, el juego da «hace cuánto» y el mismo movimiento leído otro día cae unas horas corrido:
-- cada lectura se empareja con lo ya anotado (mismo tipo, jugador y monto, a menos de 6 h) y solo
-- lo que sobra es nuevo. Así dos depósitos iguales del mismo día cuentan dos veces.
local function collectGuildMoneyLog()
  local gk = guildKey()
  if not gk or not GetNumGuildBankMoneyTransactions or not GetGuildBankMoneyTransaction then return end
  local d = store()
  d.guildMoney = d.guildMoney or {}
  local seen, used = d.guildMoney, {}
  for i = 1, GetNumGuildBankMoneyTransactions() or 0 do
    local kind, who, amount, y, m, dd, h = GetGuildBankMoneyTransaction(i)
    if kind and amount then
      local at = time() - ((((y or 0) * 365 + (m or 0) * 30 + (dd or 0)) * 24) + (h or 0)) * 3600
      at = math.floor(at / 3600) * 3600
      local key = table.concat({ gk, kind, tok(who), amount }, "/")
      seen[key] = seen[key] or {}
      used[key] = used[key] or {}
      local match
      for j, prev in ipairs(seen[key]) do
        if not used[key][j] and math.abs(prev - at) <= 6 * 3600 then match = j; break end
      end
      if match then
        used[key][match] = true
      else
        local list = seen[key]
        list[#list + 1] = at
        used[key][#list] = true
        event("gm1", gk, J(tok(kind), tok(who), amount), at)
      end
    end
  end
  for k, list in pairs(seen) do
    local keep = {}
    for _, at in ipairs(list) do if time() - at <= 120 * 86400 then keep[#keep + 1] = at end end
    seen[k] = #keep > 0 and keep or nil
  end
end
local function queryMoneyLog()
  if QueryGuildBankLog then QueryGuildBankLog((MAX_GUILDBANK_TABS or 6) + 1) end
end

-- Mensaje del día e información de la guild. En algunos clientes una de las dos es protegida: el
-- juego bloquea la llamada (ADDON_ACTION_BLOCKED, que no es un error de Lua y pcall no lo ataja) y
-- devuelve nada. `calling` marca cuál se está leyendo; si el juego la bloquea, se deja de llamar
-- en esta sesión y se conserva lo último que se anotó. En combate no se lee ninguna.
local blockedApi, calling = {}, nil
local function readGuildText(name)
  local fn = _G[name]
  if not fn or blockedApi[name] then return nil end
  calling = name
  local ok, v = pcall(fn)
  calling = nil
  if blockedApi[name] or not ok or type(v) ~= "string" then return nil end
  return v
end
local function onActionBlocked(addon)
  if addon == ADDON and calling then blockedApi[calling] = true end
end

local function collectGuildInfo()
  local gk = guildKey()
  if not gk or (InCombatLockdown and InCombatLockdown()) then return end
  local motd, info = readGuildText("GetGuildRosterMOTD"), readGuildText("GetGuildInfoText")
  if not motd and not info then return end
  if not motd or not info then
    -- Si una no se pudo leer, se mantiene la anterior en vez de mandarla vacía.
    local c = store().data[gk]
    local pm, pi = ((c and c.gx1 and select(4, split4(c.gx1))) or ""):match("^([^;]*);(.*)$")
    motd, info = motd or pm or "", info or pi or ""
  end
  put(gk, "gx1", J(tok(motd), tok(info)))
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

-- ── Posición ──────────────────────────────────────────────────────────────────────────
-- Como lo hace OpenMap: cada 2 s se mira dónde está el personaje y se comparte con la guild cada
-- 10 s mientras se mueve y cada minuto si está quieto (así su punto no desaparece del mapa de los
-- demás). Va el mapa de la zona y el del continente (uiMapID) con la posición en cada uno (0 a 1),
-- para el mapa del juego (Positions.lua) y el del sitio. Dentro de instancias el juego no da
-- coordenadas: va solo la instancia, una vez. Desde la 0.12.0 se comparte siempre (no se puede
-- apagar); los addons viejos todavía pueden mandar «off».
local CONTINENT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
local MOVED, SEND_EVERY, STILL_EVERY = 0.002, 10, 60
local last = { at = -math.huge }
local function r3(v) return (string.format("%.3f", v or 0):gsub("%.?0+$", "")) end
local function continentOf(mapId)
  local id, guard = mapId, 0
  while id and id > 0 and guard < 10 do
    local info = C_Map.GetMapInfo(id)
    if not info then return nil end
    if info.mapType == CONTINENT then return id end
    id, guard = info.parentMapID, guard + 1
  end
end
local function collectPosition()
  local g = me()
  if not g then return end
  if ns.sharePos and not ns.sharePos() then put(g, "pos1", "off", true); last.at = -math.huge; return end
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  if IsInInstance and IsInInstance() then
    local name, _, _, _, _, _, _, instanceId = GetInstanceInfo()
    put(g, "pos1", J(0, 0, 0, 0, 0, 0, tok(name), instanceId or 0, ""), true)
    last.at = -math.huge
    return
  end
  local mapId = C_Map.GetBestMapForUnit("player")
  if not mapId then return end
  local pos = C_Map.GetPlayerMapPosition(mapId, "player")
  if not pos then return end
  local x, y = pos:GetXY()
  if type(x) ~= "number" or type(y) ~= "number" or (x <= 0 and y <= 0) then return end -- 0, 0: el juego no sabe
  local moved = mapId ~= last.map or math.abs(x - last.x) > MOVED or math.abs(y - last.y) > MOVED
  local now = GetTime()
  if now - last.at < (moved and SEND_EVERY or STILL_EVERY) then return end
  local cont = continentOf(mapId)
  local cx, cy = 0, 0
  if cont then
    local cp = C_Map.GetPlayerMapPosition(cont, "player")
    if cp then cx, cy = cp:GetXY() end
  end
  local info, contInfo = C_Map.GetMapInfo(mapId), cont and C_Map.GetMapInfo(cont)
  last.map, last.x, last.y, last.at = mapId, x, y, now
  -- Quieto: la misma posición con la hora de ahora (force), para que los demás sepan que sigue ahí.
  put(g, "pos1", J(mapId, r3(x), r3(y), cont or 0, r3(cx), r3(cy), tok(info and info.name or (GetZoneText and GetZoneText()) or ""), 0,
    tok(contInfo and contInfo.name or "")), true, not moved)
end
ns.collectPosition = function() pcall(collectPosition) end

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
    -- Hasta la 0.3.1 se anotaban el balance y las bolsas y el banco de cada personaje: ya no (solo
    -- los de la guild). Se borra lo que haya quedado.
    for _, c in pairs(store().data) do
      for key in pairs(c) do if key == "mo1" or key:match("^inv1") then c[key] = nil end end
    end
    pcall(pruneRelay)
    C_Timer.After(15, function()
      for _, fn in ipairs({ collectPlayer, collectSkills, collectGear, collectTalents, collectTalentTree, collectReputation, collectQuests }) do pcall(fn) end
      if ns.send then ns.send("E;" .. math.max(0, (store().syncAt or 0) - 86400)) end
      pcall(function() if QueryGuildEventLog and IsInGuild() then QueryGuildEventLog() end end)
    end)
    if C_Timer.NewTicker then
      C_Timer.NewTicker(2, function() pcall(collectPosition) end)
      C_Timer.NewTicker(5, function() pcall(inspectNext) end)
      C_Timer.NewTicker(1800, function() pcall(function() if QueryGuildEventLog and IsInGuild() then QueryGuildEventLog() end end) end)
    end
  end,
  PLAYER_LOGOUT = function()
    pcall(collectPlayer)
    store().syncAt = time()
  end,
  PLAYER_LEVEL_UP = function() soon("player", collectPlayer) end,
  ZONE_CHANGED_NEW_AREA = function() soon("pos", collectPosition, 3) end,
  PLAYER_ENTERING_WORLD = function() soon("pos", collectPosition, 20) end,
  PLAYER_GUILD_UPDATE = function() soon("player", collectPlayer) end,
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
  UPDATE_FACTION = function() soon("rep", collectReputation, 5) end,
  QUEST_TURNED_IN = function() soon("quests", collectQuests, 5) end,
  TIME_PLAYED_MSG = function(total, level) local g = me(); if g and total then put(g, "pt1", J(total, level or 0)) end end,
  AUCTION_OWNED_LIST_UPDATE = function() soon("owned", collectOwnedAuctions, 1) end,
  OWNED_AUCTIONS_UPDATED = function() soon("owned", collectOwnedAuctions, 1) end,
  MAIL_INBOX_UPDATE = function() soon("mail", collectInvoices, 1) end,
  CHAT_MSG_LOOT = function(msg) pcall(onLoot, msg); pcall(onRollMsg, msg) end,
  START_LOOT_ROLL = function(rollID) pcall(onStartRoll, rollID) end,
  ENCOUNTER_START = function(id, name) onEncounterStart(id, name) end,
  ENCOUNTER_END = function(...) pcall(onEncounterEnd, ...) end,
  INSPECT_READY = function(guid) pcall(onInspectReady, guid) end,
  GUILDBANKFRAME_OPENED = function()
    pcall(queryGuildBank); pcall(queryMoneyLog)
    soon("gbank", collectGuildBank, 2); soon("gmlog", collectGuildMoneyLog, 3)
  end,
  GUILDBANKLOG_UPDATE = function() soon("gmlog", collectGuildMoneyLog, 1) end,
  GUILDBANKBAGSLOTS_CHANGED = function() soon("gbank", collectGuildBank) end,
  GUILDBANK_UPDATE_MONEY = function() soon("gbank", collectGuildBank) end,
  GUILD_ROSTER_UPDATE = function() soon("ginfo", collectGuildInfo, 3) end,
  GUILD_MOTD = function() soon("ginfo", collectGuildInfo, 3) end,
  GUILD_EVENT_LOG_UPDATE = function() soon("glog", collectGuildEvents, 1) end,
  ADDON_ACTION_BLOCKED = onActionBlocked,
  ADDON_ACTION_FORBIDDEN = onActionBlocked,
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
ns._collect = { put = put, collectPosition = collectPosition, resetPosition = function() last.at = -math.huge end, putPeer = putPeer, share = share, pattern = pattern,
  collectTalentTree = collectTalentTree, collectOwnedAuctions = collectOwnedAuctions, collectInvoices = collectInvoices, readTradeSkill = readTradeSkill,
  readCraft = readCraft, collectGuildBank = collectGuildBank, collectGuildEvents = collectGuildEvents, collectGuildMoneyLog = collectGuildMoneyLog, onLoot = onLoot,
  onRollMsg = onRollMsg, putRelay = putRelay, relayIndex = relayIndex, pruneRelay = pruneRelay, onStartRoll = onStartRoll, onEncounterEnd = onEncounterEnd, flushStaleRolls = flushStaleRolls, fmtPattern = fmtPattern, openRolls = function() return rolls end,
  onEncounterStart = onEncounterStart, inspectNext = inspectNext, onInspectReady = onInspectReady }
