-- Rebirth Track · Reparto de botín por consejo (estilo RCLootCouncil)
-- El master looter (en Retail, que no tiene botín maestro, el líder de banda) abre un reparto con
-- los ítems de un jefe (al lootear el cadáver, o agregándolos de las bolsas con /rt reparto agregar
-- <link>). Cada jugador ve el ítem y lo que tiene equipado en esa ranura, y responde BiS · Mejora ·
-- Off-spec · Transmog · Pasar con una nota. El consejo (los rangos de la guild que dice la web, y el
-- master looter siempre) ve las respuestas junto a lo que sabe la web de cada uno (rango, asistencia
-- y botín recibido en 8 semanas, lo que ya sacó hoy) ordenadas con la misma prioridad que el sitio
-- (shared/lootPriority.ts), vota, y el master looter adjudica: con botín maestro el addon entrega el
-- ítem (GiveMasterLoot); si no, avisa a quién comerciárselo. Lo que nadie pide va a desencantar o al
-- banco.
--
-- Todo viaja por el canal de addons de la banda (prefijo RTLC) y cada addon que lo oye lo anota en
-- RebirthTrackDB.council, así lo sube a rebirthknights.fun cualquiera que tenga la app (el sitio lo
-- junta por reparto e ítem y descarta lo repetido). El estado del reparto se arma de nuevo con esas
-- líneas, así que un /reload no lo pierde. La web devuelve sus datos en Plans.lua (RebirthTrackCouncil).
--
-- Líneas (sin «|», que WoW escapa; el dueño es el GUID del master looter):
--   lc1;ml;hora;reparto;nombre del ML;instancia;dificultad;encuentro;jefe;nombre de la instancia
--   ld1;ml;hora;reparto;n;ítem (item:…);ilvl;ranura (INVTYPE_…);quién lo looteó
--   lr1;ml;hora;reparto;n;jugador;respuesta;ilvl que gana;equipado (id@ilvl,…);nota
--   lv1;ml;hora;reparto;n;quién vota;a quién;1 (vota) | 0 (saca el voto)
--   la1;ml;hora;reparto;n;a quién (vacío = nadie);respuesta;ml | trade | de | bank;quién adjudicó
--   lo1;ml;hora;reparto;n          (el ML abrió el ítem a todos: cualquiera responde aunque no sea su armadura)
--   lx1;ml;hora;reparto                                                            (se cerró)
-- Por el canal va lo mismo sin tipo, dueño ni hora: "S;…" (lc1, con el GUID del ML al final), "I;…",
-- "R;…", "V;…", "A;…", "O;reparto;n", "X;reparto" y "Q;reparto" (el que llegó tarde pide que se lo manden de nuevo).
-- Los jugadores son «Nombre-Reino» (el reino sin espacios, como lo da el juego).
--
-- Retail y WoW Forever restringen los mensajes de addon en instancias: se mandan fuera de combate
-- (y fuera de un encuentro), y si el juego igual los rechaza, el master looter anuncia los ítems en
-- el chat de banda y cada uno responde por susurro («1 bis», «2 mejora con nota»).
local ADDON, ns = ...
ns = ns or {}

local PREFIX = "RTLC"
local KINDS = { "bis", "upgrade", "offspec", "transmog", "pass" }
local KIND_ORDER = { bis = 1, upgrade = 2, offspec = 3, transmog = 4, pass = 5 }
local MAX_LINES, MAX_ROWS, KEEP_OPEN = 4000, 20, 6 * 3600
local RESTRICTED = WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1) or WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)

local TX = {
  es = {
    title = "Reparto de botín", respond = "Botín: ¿lo querés?", item = "Ítem %d de %d", noItem = "Sin ítems.",
    bis = "BiS", upgrade = "Mejora", offspec = "Off-spec", transmog = "Transmog", pass = "Pasar",
    note = "Nota (opcional):", youHave = "Tenés: %s", nothing = "nada en esa ranura", answered = "Respondiste: %s",
    start = "Repartir (%d)", add = "agregado al reparto: %s", noLink = "pegá el link del ítem: /rt reparto agregar [ítem]",
    notML = "solo el master looter (o el líder de banda) abre el reparto.", none = "No hay un reparto abierto.",
    vote = "Votar", unvote = "Quitar", give = "Dar", de = "Desencantar", bank = "Al banco", close = "Cerrar reparto",
    awarded = "Adjudicado a %s (%s)", toDE = "A desencantar", toBank = "Al banco", noAnswers = "Nadie respondió todavía.",
    votes = "votos %d", today = "hoy %d", hist = "%d/%d", knight = "Caballero", recruit = "Recluta", renegade = "Renegado",
    opened = "%s abrió un reparto: %d ítem(s). /rt reparto para verlo.", closed = "Reparto cerrado.",
    tradeIt = "comerciale %s a %s.", lootIt = "abrí el cadáver para entregar %s a %s.",
    blocked = "el juego no deja mandar mensajes de addon acá: anuncio los ítems en el chat de banda y se responde por susurro.",
    chatItems = "[Rebirth Track] Reparto: %s · susurrame «número respuesta nota» (bis, mejora, off, transmo, paso).",
    chatAward = "[Rebirth Track] %s → %s (%s)", chatDE = "[Rebirth Track] %s → desencantar", chatBank = "[Rebirth Track] %s → banco de la guild",
    council = "Consejo", prev = "<", next = ">", whisperOk = "Anotado: %s para el ítem %d.",
    notYours = "No es tu tipo de armadura (%s): solo podés pasar, salvo que el master looter lo abra a todos.",
    openAll = "Abrir a todos", opened2 = "Abierto a todos", offArmor = "otra armadura",
    cloth = "tela", leather = "cuero", mail = "malla", plate = "placa",
  },
  en = {
    title = "Loot council", respond = "Loot: do you want it?", item = "Item %d of %d", noItem = "No items.",
    bis = "BiS", upgrade = "Upgrade", offspec = "Off-spec", transmog = "Transmog", pass = "Pass",
    note = "Note (optional):", youHave = "You have: %s", nothing = "nothing in that slot", answered = "You answered: %s",
    start = "Distribute (%d)", add = "added to the council: %s", noLink = "paste the item link: /rt loot add [item]",
    notML = "only the master looter (or the raid leader) opens the council.", none = "No council is open.",
    vote = "Vote", unvote = "Unvote", give = "Award", de = "Disenchant", bank = "To bank", close = "Close council",
    awarded = "Awarded to %s (%s)", toDE = "To disenchant", toBank = "To the bank", noAnswers = "No answers yet.",
    votes = "votes %d", today = "today %d", hist = "%d/%d", knight = "Knight", recruit = "Recruit", renegade = "Renegade",
    opened = "%s opened a council: %d item(s). /rt loot to see it.", closed = "Council closed.",
    tradeIt = "trade %s to %s.", lootIt = "open the corpse to hand %s to %s.",
    blocked = "the game blocks addon messages here: announcing the items in raid chat, answers by whisper.",
    chatItems = "[Rebirth Track] Council: %s · whisper me «number answer note» (bis, upgrade, off, transmog, pass).",
    chatAward = "[Rebirth Track] %s → %s (%s)", chatDE = "[Rebirth Track] %s → disenchant", chatBank = "[Rebirth Track] %s → guild bank",
    council = "Council", prev = "<", next = ">", whisperOk = "Noted: %s for item %d.",
    notYours = "Not your armor type (%s): you can only pass, unless the master looter opens it to everyone.",
    openAll = "Open to all", opened2 = "Open to everyone", offArmor = "other armor",
    cloth = "cloth", leather = "leather", mail = "mail", plate = "plate",
  },
}
local function T(k) local l = ns.lang and ns.lang() or "es"; return (TX[l] or TX.es)[k] or TX.es[k] or k end
local function say(msg) if ns.say then ns.say(msg) else print(msg) end end

-- ── Utilidades ───────────────────────────────────────────────────────────────────────────
local function tok(s) return (tostring(s == nil and "" or s):gsub("[|;\n\r\"]", " ")) end
local function note(s) return (tok(s):gsub("[,@]", " "):sub(1, 80)) end
local function split(s)
  local out = {}
  for part in (s .. ";"):gmatch("([^;]*);") do out[#out + 1] = part end
  return out
end
local function realm() return (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or ""):gsub("[%s%-']", "") end
-- «Nombre-Reino» siempre con reino (el juego lo omite para el propio).
local function full(name)
  if not name or name == "" then return "" end
  if name:find("-", 1, true) then return name end
  return name .. "-" .. realm()
end
local function short(name) return (tostring(name or ""):gsub("%-.*", "")) end
local function meFull() return full(UnitName("player")) end
local function itemString(link)
  local s = tostring(link or ""):match("(item:[%-%d:]+)")
  return s and s:gsub(":+$", "") or nil
end
local function itemId(s) return tonumber(tostring(s or ""):match("item:(%d+)")) end
local function itemInfo(s)
  if not s or not GetItemInfo then return nil end
  local ok, name, link, q, ilvl, _, _, _, _, equipLoc, icon, _, classID, subclassID = pcall(GetItemInfo, s)
  if not ok or not name then return nil end
  local detailed = (C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link))
    or (GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link))
  return { name = name, link = link, quality = q, ilvl = detailed or ilvl or 0, equipLoc = equipLoc or "", icon = icon,
    classID = classID, subclassID = subclassID }
end
local function linkOf(s) local i = itemInfo(s); return i and i.link or s or "?" end

-- Armadura: cada clase pide la de su tipo principal (la placa no es para un mago, ni la tela para un
-- guerrero). Si no es la suya solo puede pasar, salvo que el master looter abra el ítem a todos.
-- Capas, cuellos, anillos, abalorios, escudos y lo de la mano izquierda no cuentan.
local ARMOR = { 1, 2, 3, 4 } -- subclases de armadura (classID 4): tela, cuero, malla, placa
local ARMOR_NAMES = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate" }
local CLASS_ARMOR = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
  ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2, MAGE = 1, PRIEST = 1, WARLOCK = 1 }
local ARMOR_SLOTS = { INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
  INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true }
-- Tipo de armadura que pide el ítem (1 a 4) o nil si no es armadura con tipo.
local function armorOf(info)
  if not info or info.classID ~= 4 or not ARMOR_SLOTS[info.equipLoc or ""] then return nil end
  return ARMOR[info.subclassID or 0] and info.subclassID or nil
end
-- ¿Esa clase (token del juego: WARRIOR, MAGE…) usa ese ítem? nil = no se sabe (se deja responder).
local function canUse(info, classToken)
  local need = armorOf(info)
  local has = classToken and CLASS_ARMOR[classToken]
  if not need or not has then return nil end
  return need == has
end
local function classOf(name)
  if not UnitClass then return nil end
  if full(name):lower() == full(UnitName("player")):lower() then return select(2, UnitClass("player")) end
  local ok, _, token = pcall(UnitClass, short(name))
  if ok and token then return token end
  ok, _, token = pcall(UnitClass, name)
  return ok and token or nil
end

-- Ranuras del personaje por tipo de ítem.
local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18, 16 }, INVTYPE_RANGEDRIGHT = { 18, 16 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
-- Lo que tengo puesto en la ranura del ítem: "id@ilvl,…" y cuánto ilvl gano contra lo peor de ahí
-- (sin ranura, como los tokens: nil).
local function equippedFor(equipLoc, ilvl)
  local slots = SLOTS[equipLoc or ""]
  if not slots or not GetInventoryItemLink then return "", nil end
  local parts, worst = {}, nil
  for _, slot in ipairs(slots) do
    local link = GetInventoryItemLink("player", slot)
    local i = link and itemInfo(link)
    if i then
      parts[#parts + 1] = (itemId(link) or 0) .. "@" .. (i.ilvl or 0)
      worst = math.min(worst or math.huge, i.ilvl or 0)
    elseif slot ~= 18 or #slots == 1 then
      worst = 0 -- ranura vacía: todo es mejora
    end
  end
  if not ilvl or ilvl == 0 then return table.concat(parts, ","), nil end
  return table.concat(parts, ","), math.floor(ilvl - (worst or 0))
end

-- ── Lo que manda la web (Plans.lua → RebirthTrackCouncil) ────────────────────────────────
--   RebirthTrackCouncil = { at = hora, ranks = { 0, 1 }, players = { forever = { "Nombre-Reino;rango;asistidas;recibidos", … }, … } }
-- Por versión de WoW (la propia sale de WOW_PROJECT_ID); rango = knight | recruit | renegade, como en
-- la prioridad del sitio. El reino se compara sin espacios, guiones ni apóstrofos.
local GAMES = { [1] = "retail", [2] = "era", [5] = "anniversary", [11] = "classic", [14] = "classic", [19] = "classic", [18] = "forever" }
local function playerKey(name)
  local n, r = tostring(name or ""):match("^([^%-]+)%-?(.*)$")
  return ((n or "") .. "-" .. (r or ""):gsub("[%s%-'%.]", "")):lower()
end
local webPlayers, webAt
local function web()
  local src = RebirthTrackCouncil
  if type(src) ~= "table" or type(src.players) ~= "table" then return {} end
  if webPlayers and webAt == src.at then return webPlayers end
  webPlayers, webAt = {}, src.at
  local list = src.players[GAMES[WOW_PROJECT_ID or 0] or ""] or (src.players[1] and src.players) or {}
  for _, line in ipairs(list) do
    local f = split(tostring(line))
    if f[1] and f[1] ~= "" then
      webPlayers[playerKey(f[1])] = { rank = f[2] ~= "" and f[2] or nil, attended = tonumber(f[3]) or 0, received = tonumber(f[4]) or 0 }
    end
  end
  return webPlayers
end

-- Rango en la guild de alguien («Nombre-Reino») con la lista de miembros del juego.
local function guildRank(name)
  if not GetNumGuildMembers or not IsInGuild or not IsInGuild() then return nil end
  local want = full(name):lower()
  for i = 1, GetNumGuildMembers() or 0 do
    local n, _, rankIndex = GetGuildRosterInfo(i)
    if n and full(n):lower() == want then return rankIndex end
  end
  return nil
end
local function councilRanks()
  local src = RebirthTrackCouncil
  local out = {}
  for _, r in ipairs(type(src) == "table" and src.ranks or { 0, 1 }) do out[tonumber(r) or -1] = true end
  return out
end

-- ── Prioridad (la misma que shared/lootPriority.ts del sitio) ────────────────────────────
-- 0) el Renegado va último siempre; 1) le sirve (mejora, o sin datos de equipo) antes que a quien no
-- le sube; 2) Caballero antes que Recluta; 3) no sacó nada hoy; 4) menos botín por raid asistida;
-- 5) más mejora. Acá además manda la respuesta: BiS antes que Mejora, etc.
local RANK_ORDER = { knight = 0, recruit = 1, renegade = 2 }
local function priorityLess(a, b)
  local function rank(c) return RANK_ORDER[c.rank or "recruit"] or 1 end
  local function renegade(c) return c.rank == "renegade" and 1 or 0 end
  local function tier(c) return (c.delta == nil or c.delta > 0) and 0 or 1 end
  local function ratio(c) return c.received / math.max(1, c.attended) end
  local keys = {
    { renegade(a), renegade(b) }, { tier(a), tier(b) }, { rank(a), rank(b) }, { a.today, b.today },
    { ratio(a), ratio(b) }, { -(a.delta or 0), -(b.delta or 0) },
  }
  for _, k in ipairs(keys) do if k[1] ~= k[2] then return k[1] < k[2] end end
  return false
end
ns.councilPriorityLess = priorityLess

-- ── Estado: se arma con las líneas anotadas ──────────────────────────────────────────────
local state = { sessions = {}, order = {} } -- reparto → { ml, mlName, items = { [n] = {…} }, closed }
local seen = {}

local function lines()
  local d = ns.db and ns.db() or {}
  d.council = d.council or {}
  return d.council
end

local function getSession(sid) return state.sessions[sid] end
local function getItem(sid, n)
  local s = state.sessions[sid]
  if not s then return nil end
  s.items[n] = s.items[n] or { n = n, responses = {}, votes = {} }
  return s.items[n]
end

-- Aplica una línea (tipo, dueño, hora, campos) al estado.
local function apply(kind, owner, at, f)
  local sid = f[1]
  if kind == "lc1" then
    if not state.sessions[sid] then state.order[#state.order + 1] = sid end
    state.sessions[sid] = state.sessions[sid] or { items = {} }
    local s = state.sessions[sid]
    s.sid, s.ml, s.mlName, s.at = sid, owner, f[2], at
    s.instanceId, s.difficulty, s.encounterId, s.boss, s.instance = tonumber(f[3]), tonumber(f[4]), tonumber(f[5]), f[6], f[7]
    return
  end
  local s = state.sessions[sid]
  if not s then return end
  if kind == "lx1" then s.closed = true; return end
  local it = getItem(sid, tonumber(f[2]) or 0)
  if kind == "ld1" then
    it.item, it.ilvl, it.equipLoc, it.looter = f[3], tonumber(f[4]) or 0, f[5], f[6]
  elseif kind == "lr1" then
    it.responses[f[3]] = { kind = f[4], delta = tonumber(f[5]), eq = f[6], note = f[7], at = at }
  elseif kind == "lv1" then
    it.votes[f[3]] = it.votes[f[3]] or {}
    it.votes[f[3]][f[4]] = f[5] == "1" or nil
  elseif kind == "la1" then
    it.award = { to = f[3], kind = f[4], how = f[5], by = f[6], at = at }
  elseif kind == "lo1" then
    it.open = true
  end
end

-- Anota una línea (si no estaba) y la aplica.
local function record(kind, owner, payload, at)
  local key = kind .. ";" .. owner .. ";" .. payload
  if kind == "lv1" or kind == "lr1" then key = key .. ";" .. (at or time()) end -- votos y respuestas pueden cambiar
  if seen[key] then return false end
  seen[key] = true
  local t = math.floor(at or time())
  local L = lines()
  L[#L + 1] = kind .. ";" .. owner .. ";" .. t .. ";" .. payload
  while #L > MAX_LINES do table.remove(L, 1) end
  apply(kind, owner, t, split(payload))
  return true
end

-- Al cargar (o tras un /reload) se rearma el estado con lo anotado.
local function rebuild()
  state.sessions, state.order, seen = {}, {}, {}
  for _, line in ipairs(lines()) do
    local kind, owner, at, payload = line:match("^(l%a1);([^;]*);(%d+);(.*)$")
    if kind then
      local key = kind .. ";" .. owner .. ";" .. payload
      if kind == "lv1" or kind == "lr1" then key = key .. ";" .. at end
      seen[key] = true
      apply(kind, owner, tonumber(at), split(payload))
    end
  end
end

-- El reparto abierto más nuevo (de hace menos de 6 h).
local function current()
  for i = #state.order, 1, -1 do
    local s = state.sessions[state.order[i]]
    if s and not s.closed and time() - (s.at or 0) < KEEP_OPEN then return s end
  end
  return nil
end

local function isML(s) return s and s.ml == UnitGUID("player") end
local function isCouncil(s, name)
  if s and full(s.mlName) == full(name) then return true end
  local r = guildRank(name)
  return r ~= nil and councilRanks()[r] == true
end

-- ── Canal de la banda ────────────────────────────────────────────────────────────────────
local queue, pumping, failures, blocked = {}, false, 0, false
local function channel()
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return nil
end
local function paused()
  if InCombatLockdown and InCombatLockdown() then return true end
  return RESTRICTED and IsEncounterInProgress and IsEncounterInProgress() and true or false
end
-- Manda y devuelve si el juego lo aceptó (12.0 devuelve un código; 0 = bien; los clásicos, nada).
local function rawSend(msg, chan)
  local ok, res
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, chan)
  elseif SendAddonMessage then ok, res = pcall(SendAddonMessage, PREFIX, msg, chan)
  else return false end
  if not ok or res == false then return false end
  if type(res) == "number" and res ~= 0 then return false end
  return true
end
local pump
function pump()
  if #queue == 0 then pumping = false; return end
  if paused() then C_Timer.After(3, pump); return end
  local chan = channel()
  if not chan then queue = {}; pumping = false; return end
  local m = table.remove(queue, 1)
  if rawSend(m.msg, chan) then
    failures = 0
  else
    failures = failures + 1
    m.tries = (m.tries or 0) + 1
    if m.tries < 3 then table.insert(queue, 1, m) end
    if failures >= 2 and not blocked then blocked = true; if ns.councilOnBlocked then ns.councilOnBlocked() end end
  end
  C_Timer.After(0.25, pump)
end
local function send(msg)
  if not channel() or #queue >= 400 then return end
  queue[#queue + 1] = { msg = msg }
  if not pumping then pumping = true; C_Timer.After(0, pump) end
end

-- ── Acciones (lo propio se anota al toque; lo de los demás llega por el canal) ───────────
local refresh -- ventanas

local function payloadS(s, guid)
  return table.concat({ s.sid, tok(s.mlName), s.instanceId or 0, s.difficulty or 0, s.encounterId or 0, tok(s.boss), tok(s.instance), guid }, ";")
end

local function lc1(s) return table.concat({ s.sid, tok(s.mlName), s.instanceId or 0, s.difficulty or 0, s.encounterId or 0, tok(s.boss), tok(s.instance) }, ";") end

-- Abre un reparto con los ítems (item:… y quién lo looteó).
local lastBoss = {}
local function openSession(items)
  if #items == 0 then return nil end
  local guid = UnitGUID("player")
  local name, _, difficulty, _, _, _, _, instanceId = GetInstanceInfo()
  local s = {
    sid = string.format("%x", time()), mlName = meFull(), instanceId = instanceId or 0, difficulty = difficulty or 0,
    encounterId = (time() - (lastBoss.at or 0) < 600) and lastBoss.id or 0,
    boss = (time() - (lastBoss.at or 0) < 600) and lastBoss.name or "", instance = name or "",
  }
  while state.sessions[s.sid] do s.sid = string.format("%x", tonumber(s.sid, 16) + 1) end
  record("lc1", guid, lc1(s))
  send("S;" .. payloadS(s, guid))
  for n, it in ipairs(items) do
    local info = itemInfo(it.item) or {}
    local p = table.concat({ s.sid, n, it.item, info.ilvl or 0, info.equipLoc or "", tok(it.looter or "") }, ";")
    record("ld1", guid, p)
    send("I;" .. p)
  end
  if blocked and ns.councilAnnounceChat then ns.councilAnnounceChat(state.sessions[s.sid]) end
  return state.sessions[s.sid]
end

-- Si ese jugador puede pedir el ítem (o solo pasar).
local function allowed(it, name, kind)
  if kind == "pass" or it.open then return true end
  return canUse(itemInfo(it.item), classOf(name)) ~= false
end

local function openToAll(s, n)
  local it = s and s.items[n]
  if not it or not isML(s) or it.open then return end
  local p = s.sid .. ";" .. n
  record("lo1", s.ml, p)
  send("O;" .. p)
end

local function respond(s, n, kind, txt)
  local it = s and s.items[n]
  if not it or not KIND_ORDER[kind] or not allowed(it, meFull(), kind) then return end
  local eq, delta = equippedFor(it.equipLoc, it.ilvl)
  local p = table.concat({ s.sid, n, meFull(), kind, delta or "", eq, note(txt) }, ";")
  record("lr1", s.ml, p)
  send("R;" .. p)
end

local function vote(s, n, candidate, on)
  local p = table.concat({ s.sid, n, meFull(), candidate, on and 1 or 0 }, ";")
  record("lv1", s.ml, p)
  send("V;" .. p)
end

-- Entrega con botín maestro si el cadáver está abierto; si no, queda pendiente para el próximo.
local pendingDelivery = {}
local function deliver(item, winner)
  if not GiveMasterLoot or not GetNumLootItems or not GetMasterLootCandidate then return false end
  local id = itemId(item)
  for slot = 1, GetNumLootItems() or 0 do
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    if link and itemId(link) == id then
      for i = 1, 40 do
        local cand = GetMasterLootCandidate(slot, i)
        if cand and full(cand):lower() == full(winner):lower() then GiveMasterLoot(slot, i); return true end
      end
    end
  end
  return false
end
local function masterLoot()
  local method
  if C_PartyInfo and C_PartyInfo.GetLootMethod then method = C_PartyInfo.GetLootMethod()
  elseif GetLootMethod then method = GetLootMethod() end
  return method == "master" or (Enum and Enum.LootMethod and method == Enum.LootMethod.Masterlooter) or false
end

local function chat(msg)
  if not channel() or not SendChatMessage then return end
  pcall(SendChatMessage, msg, channel())
end

local function award(s, n, winner, kind, how)
  local it = s and s.items[n]
  if not it or not isML(s) then return end
  how = how or (winner ~= "" and (masterLoot() and "ml" or "trade")) or "de"
  local p = table.concat({ s.sid, n, tok(winner), kind or "", how, meFull() }, ";")
  record("la1", s.ml, p)
  send("A;" .. p)
  local link = linkOf(it.item)
  if how == "de" then chat(T("chatDE"):format(link))
  elseif how == "bank" then chat(T("chatBank"):format(link))
  else
    chat(T("chatAward"):format(link, short(winner), T(kind ~= "" and kind or "pass")))
    if how == "ml" then
      if not deliver(it.item, winner) then
        pendingDelivery[#pendingDelivery + 1] = { item = it.item, winner = winner }
        say(T("lootIt"):format(link, short(winner)))
      end
    else
      say(T("tradeIt"):format(link, short(winner)))
    end
  end
end

local function closeSession(s)
  if not s or not isML(s) then return end
  record("lx1", s.ml, s.sid)
  send("X;" .. s.sid)
  say(T("closed"))
end

-- Mensaje de otro addon.
local asked = {}
local function onMessage(prefix, msg, chan, sender)
  if prefix ~= PREFIX or type(msg) ~= "string" then return end
  sender = full(sender)
  if sender:lower() == meFull():lower() then return end
  local kind, rest = msg:match("^(%u);(.*)$")
  if not kind then return end
  local f = split(rest)
  if kind == "S" then
    local guid = f[8]
    if not guid or not guid:match("^Player%-[%w%-]+$") or full(f[2]):lower() ~= sender then return end
    local isNew = not state.sessions[f[1]]
    record("lc1", guid, table.concat(f, ";", 1, 7))
    if isNew then C_Timer.After(1, function()
      local s = state.sessions[f[1]]
      local count = 0
      for _ in pairs(s and s.items or {}) do count = count + 1 end
      say(T("opened"):format(short(sender), count))
      if refresh then refresh(true) end
    end) end
    return
  end
  local s = state.sessions[f[1]]
  if not s then
    if kind ~= "Q" and not asked[f[1]] then asked[f[1]] = true; send("Q;" .. f[1]) end
    return
  end
  local fromML = sender == full(s.mlName):lower() or sender == full(s.mlName)
  if kind == "I" and fromML then record("ld1", s.ml, rest)
  elseif kind == "R" and full(f[3]):lower() == sender:lower() then
    local it = s.items[tonumber(f[2]) or 0]
    if it and allowed(it, sender, f[4]) then record("lr1", s.ml, rest) end
  elseif kind == "O" and fromML then record("lo1", s.ml, s.sid .. ";" .. (tonumber(f[2]) or 0))
  elseif kind == "V" and full(f[3]):lower() == sender:lower() and isCouncil(s, sender) then record("lv1", s.ml, rest)
  elseif kind == "A" and fromML then record("la1", s.ml, rest)
  elseif kind == "X" and fromML then record("lx1", s.ml, s.sid)
  elseif kind == "Q" and isML(s) then
    send("S;" .. payloadS(s, s.ml))
    for n, it in pairs(s.items) do
      if it.item then send("I;" .. table.concat({ s.sid, n, it.item, it.ilvl or 0, it.equipLoc or "", tok(it.looter or "") }, ";")) end
      if it.award then send("A;" .. table.concat({ s.sid, n, tok(it.award.to), it.award.kind or "", it.award.how or "", tok(it.award.by) }, ";")) end
    end
  end
  if refresh then refresh() end
end

-- Respuestas por susurro (cuando el juego bloquea los mensajes de addon): «1 bis», «2 mejora nota».
local WORDS = { bis = "bis", need = "bis", mejora = "upgrade", upgrade = "upgrade", up = "upgrade", off = "offspec",
  offspec = "offspec", transmo = "transmog", transmog = "transmog", tmog = "transmog", paso = "pass", pass = "pass", pasar = "pass" }
local function onWhisper(msg, sender)
  local s = current()
  if not s or not isML(s) or type(msg) ~= "string" then return end
  local n, word, rest = msg:lower():match("^%s*(%d+)%s+(%a+)%s*(.-)%s*$")
  local kind = word and WORDS[word]
  n = tonumber(n)
  if not kind or not n or not s.items[n] or not s.items[n].item then return end
  local who = full(sender)
  if not allowed(s.items[n], who, kind) then return end
  local p = table.concat({ s.sid, n, who, kind, "", "", note(rest) }, ";")
  record("lr1", s.ml, p)
  send("R;" .. p)
  if SendChatMessage then pcall(SendChatMessage, T("whisperOk"):format(T(kind), n), "WHISPER", nil, sender) end
  if refresh then refresh() end
end

function ns.councilAnnounceChat(s)
  if not s then return end
  local parts = {}
  for n = 1, #s.items do local it = s.items[n]; if it and it.item then parts[#parts + 1] = n .. ") " .. linkOf(it.item) end end
  chat(T("chatItems"):format(table.concat(parts, " ")))
end
function ns.councilOnBlocked()
  say(T("blocked"))
  local s = current()
  if s and isML(s) then ns.councilAnnounceChat(s) end
end

-- ── Botín del cadáver (master looter) y del jefe ─────────────────────────────────────────
local pendingLoot, lootedFrom = {}, {}
local function onLootOpened()
  for i = #pendingDelivery, 1, -1 do
    local d = pendingDelivery[i]
    if deliver(d.item, d.winner) then table.remove(pendingDelivery, i) end
  end
  if not masterLoot() or not GetNumLootItems then return end
  local s = current()
  local source = GetLootSourceInfo and GetLootSourceInfo(1)
  if source and lootedFrom[source] then return end
  local threshold = (GetLootThreshold and GetLootThreshold()) or 4
  local found = {}
  for slot = 1, GetNumLootItems() or 0 do
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local is = itemString(link)
    local q = (itemInfo(link) or {}).quality -- GetLootSlotInfo cambia el orden según la versión
    if is and (q or 0) >= threshold then
      local already = false
      for _, it in pairs(s and s.items or {}) do if it.item == is and not it.award then already = true end end
      if not already then found[#found + 1] = { item = is, looter = meFull() } end
    end
  end
  if #found == 0 then return end
  if source then lootedFrom[source] = true end
  pendingLoot = found
  if refresh then refresh(true) end
end

-- ── Comando /rt reparto ───────────────────────────────────────────────────────────────────
function ns.councilCommand(rest)
  rest = rest or ""
  local sub = rest:lower():match("^%s*(%S*)")
  if sub == "agregar" or sub == "add" or sub == "añadir" then
    local found = 0
    for link in rest:gmatch("|H(item:[^|]+)|h") do
      local is = itemString(link)
      if is then pendingLoot[#pendingLoot + 1] = { item = is, looter = meFull() }; found = found + 1; say(T("add"):format(linkOf(is))) end
    end
    if found == 0 then for is in rest:gmatch("(item:[%-%d:]+)") do pendingLoot[#pendingLoot + 1] = { item = itemString(is), looter = meFull() }; found = found + 1 end end
    if found == 0 then say(T("noLink")) end
  elseif sub == "cerrar" or sub == "close" then
    local s = current()
    if s and isML(s) then closeSession(s) else say(T("none")) end
  end
  if refresh then refresh(true) end
end

-- ── Ventanas ──────────────────────────────────────────────────────────────────────────────
local win, sel = nil, 1
local function viewSession() return current() end

local function backdrop(frame)
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
end
local function btn(parent, w, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end
local function label(parent, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetJustifyH("LEFT")
  return fs
end
local function itemTip(frame, getItem)
  frame:SetScript("OnEnter", function(self)
    local is = getItem()
    if not is or not GameTooltip.SetHyperlink then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(is); GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Candidatos de un ítem con lo que sabe la web, en orden.
local function candidates(s, it)
  local w, today, out = web(), {}, {}
  for _, other in pairs(s.items) do
    if other.award and other.award.to ~= "" then today[other.award.to:lower()] = (today[other.award.to:lower()] or 0) + 1 end
  end
  for name, r in pairs(it.responses) do
    local info = w[playerKey(name)] or {}
    local votes = 0
    for _, v in pairs(it.votes) do if v[name] then votes = votes + 1 end end
    out[#out + 1] = { name = name, kind = r.kind, delta = r.delta, eq = r.eq, note = r.note, votes = votes,
      rank = info.rank, attended = info.attended or 0, received = info.received or 0, today = today[name:lower()] or 0,
      offArmor = canUse(itemInfo(it.item), classOf(name)) == false }
  end
  table.sort(out, function(a, b)
    local ka, kb = KIND_ORDER[a.kind] or 9, KIND_ORDER[b.kind] or 9
    if ka ~= kb then return ka < kb end
    if priorityLess(a, b) then return true end
    if priorityLess(b, a) then return false end
    return a.name < b.name
  end)
  return out
end

local function createWindow()
  if win then return win end
  win = CreateFrame("Frame", "RebirthTrackCouncilFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  win:SetSize(460, 560)
  win:SetFrameStrata("HIGH")
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetPoint("CENTER", UIParent, "CENTER", -250, 60)
  backdrop(win)
  win.title = label(win, "GameFontNormal"); win.title:SetPoint("TOP", 0, -14)
  local x = CreateFrame("Button", nil, win, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -2, -2)
  x:SetScript("OnClick", function() win:Hide() end)

  -- Ítems sueltos del cadáver, todavía sin reparto (solo el master looter).
  win.start = btn(win, 180, "", function()
    local items = pendingLoot
    pendingLoot = {}
    local s = current()
    if s and isML(s) then
      local guid = s.ml
      local n = 0
      for k in pairs(s.items) do n = math.max(n, k) end
      for _, it in ipairs(items) do
        n = n + 1
        local info = itemInfo(it.item) or {}
        local p = table.concat({ s.sid, n, it.item, info.ilvl or 0, info.equipLoc or "", tok(it.looter or "") }, ";")
        record("ld1", guid, p); send("I;" .. p)
      end
    else
      openSession(items)
    end
    sel = 1
    refresh(true)
  end)
  win.start:SetPoint("TOP", 0, -34)

  win.prev = btn(win, 26, T("prev"), function() sel = math.max(1, sel - 1); refresh() end); win.prev:SetPoint("TOPLEFT", 14, -62)
  win.nxt = btn(win, 26, T("next"), function() sel = sel + 1; refresh() end); win.nxt:SetPoint("TOPRIGHT", -14, -62)
  win.count = label(win); win.count:SetPoint("TOP", 0, -66)
  win.item = CreateFrame("Button", nil, win); win.item:SetSize(400, 18); win.item:SetPoint("TOP", 0, -88)
  win.itemText = label(win.item, "GameFontNormal"); win.itemText:SetPoint("CENTER")
  itemTip(win.item, function() local s = viewSession(); local it = s and s.items[sel]; return it and it.item end)
  win.mine = label(win); win.mine:SetPoint("TOPLEFT", 18, -110); win.mine:SetPoint("TOPRIGHT", -18, -110)

  -- Responder (todos).
  win.kinds = {}
  for i, k in ipairs(KINDS) do
    local b = btn(win, 82, T(k), function()
      local s = viewSession()
      if s then respond(s, sel, k, win.note:GetText()); refresh() end
    end)
    b:SetPoint("TOPLEFT", 14 + (i - 1) * 86, -128)
    b.kind = k
    win.kinds[i] = b
  end
  win.noteLabel = label(win); win.noteLabel:SetPoint("TOPLEFT", 18, -156)
  win.note = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
  win.note:SetSize(300, 20); win.note:SetPoint("TOPLEFT", 130, -152); win.note:SetAutoFocus(false); win.note:SetMaxLetters(80)
  win.answered = label(win); win.answered:SetPoint("TOPLEFT", 18, -178)
  win.armor = label(win); win.armor:SetPoint("TOPLEFT", 18, -190); win.armor:SetPoint("TOPRIGHT", -18, -190)
  win.openAll = btn(win, 110, T("openAll"), function() local s = viewSession(); if s then openToAll(s, sel); refresh() end end)
  win.openAll:SetPoint("BOTTOM", 0, 40)

  -- Consejo: candidatos en orden, votar y dar.
  win.councilTitle = label(win, "GameFontNormal"); win.councilTitle:SetPoint("TOPLEFT", 18, -208)
  win.rows = {}
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, win)
    r:SetSize(420, 13); r:SetPoint("TOPLEFT", 18, -224 - (i - 1) * 13)
    r.text = label(r); r.text:SetPoint("LEFT"); r.text:SetWidth(300)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
      if not self.c or not GameTooltip.AddLine then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(short(self.c.name), 1, 1, 1)
      if self.c.note and self.c.note ~= "" then GameTooltip:AddLine(self.c.note, 1, 0.82, 0, true) end
      for part in tostring(self.c.eq or ""):gmatch("[^,]+") do
        local id, lvl = part:match("^(%d+)@(%d+)$")
        if id then GameTooltip:AddLine(linkOf("item:" .. id) .. " (" .. lvl .. ")") end
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.vote = btn(r, 50, T("vote"), function()
      local s = viewSession()
      if s and r.c then vote(s, sel, r.c.name, not r.voted); refresh() end
    end)
    r.vote:SetHeight(13); r.vote:SetPoint("RIGHT", -48, 0)
    r.give = btn(r, 44, T("give"), function()
      local s = viewSession()
      if s and r.c then award(s, sel, r.c.name, r.c.kind); refresh() end
    end)
    r.give:SetHeight(13); r.give:SetPoint("RIGHT", 0, 0)
    win.rows[i] = r
  end
  win.de = btn(win, 110, T("de"), function() local s = viewSession(); if s then award(s, sel, "", "", "de"); refresh() end end)
  win.de:SetPoint("BOTTOMLEFT", 14, 14)
  win.bank = btn(win, 110, T("bank"), function() local s = viewSession(); if s then award(s, sel, "", "", "bank"); refresh() end end)
  win.bank:SetPoint("BOTTOM", -20, 14)
  win.close = btn(win, 120, T("close"), function() closeSession(viewSession()); refresh() end)
  win.close:SetPoint("BOTTOMRIGHT", -14, 14)
  return win
end

local KIND_COLOR = { bis = "ff8000", upgrade = "1eff00", offspec = "0070dd", transmog = "a335ee", pass = "9d9d9d" }
function refresh(open)
  if not win and not open then return end
  createWindow()
  if open then win:Show() end
  if not win:IsShown() then return end
  local s = viewSession()
  win.title:SetText(T("title"))
  win.start:SetText(T("start"):format(#pendingLoot))
  win.start:SetShown(#pendingLoot > 0)
  local items = {}
  for n in pairs(s and s.items or {}) do items[#items + 1] = n end
  table.sort(items)
  local total = #items
  sel = math.max(1, math.min(sel, math.max(total, 1)))
  local it = s and s.items[items[sel]]
  local n = items[sel]
  local has = it and it.item
  win.count:SetText(has and T("item"):format(sel, total) or (s and T("noItem") or T("none")))
  win.itemText:SetText(has and (linkOf(it.item) .. (it.ilvl and it.ilvl > 0 and (" (" .. it.ilvl .. ")") or "")) or "")
  local eq, delta = "", nil
  if has then eq, delta = equippedFor(it.equipLoc, it.ilvl) end
  local mineTxt = {}
  for part in eq:gmatch("[^,]+") do local id, lvl = part:match("^(%d+)@(%d+)$"); if id then mineTxt[#mineTxt + 1] = linkOf("item:" .. id) .. " " .. lvl end end
  win.mine:SetText(has and T("youHave"):format(#mineTxt > 0 and table.concat(mineTxt, ", ") or T("nothing"))
    .. (delta and delta ~= 0 and ((delta > 0 and "  |cff3fbf3f+" or "  |cffff4040") .. delta .. "|r") or "") or "")
  local mine = has and it.responses[meFull()]
  local canAnswer = has and not it.award and not s.closed
  local mayAsk = has and allowed(it, meFull(), "bis")
  for _, b in ipairs(win.kinds) do
    b:SetText(T(b.kind)); b:SetShown(canAnswer and true or false)
    if b.SetEnabled then b:SetEnabled(b.kind == "pass" or mayAsk and true or false) end
  end
  local need = has and armorOf(itemInfo(it.item))
  win.armor:SetText((canAnswer and not mayAsk and need) and T("notYours"):format(T(ARMOR_NAMES[need])) or (has and it.open and T("opened2") or ""))
  win.noteLabel:SetText(T("note")); win.noteLabel:SetShown(canAnswer and true or false); win.note:SetShown(canAnswer and true or false)
  win.answered:SetText(has and (it.award and (it.award.to ~= "" and T("awarded"):format(short(it.award.to), T(it.award.kind ~= "" and it.award.kind or "pass"))
    or (it.award.how == "bank" and T("toBank") or T("toDE"))) or (mine and T("answered"):format(T(mine.kind)) or "")) or "")

  local council = s and isCouncil(s, meFull())
  local ml = s and isML(s)
  win.councilTitle:SetText(council and T("council") or ""); win.councilTitle:SetShown(council and true or false)
  local list = (council and has) and candidates(s, it) or {}
  if council and has and #list == 0 then win.councilTitle:SetText(T("council") .. " · " .. T("noAnswers")) end
  for i, r in ipairs(win.rows) do
    local c = list[i]
    r.c = c
    r:SetShown(c and true or false)
    if c then
      local myVotes = it.votes[meFull()] or {}
      r.voted = myVotes[c.name] and true or false
      local web = {}
      if c.rank then web[#web + 1] = T(c.rank) end
      if c.attended > 0 or c.received > 0 then web[#web + 1] = T("hist"):format(c.received, c.attended) end
      if c.today > 0 then web[#web + 1] = T("today"):format(c.today) end
      if c.votes > 0 then web[#web + 1] = T("votes"):format(c.votes) end
      r.text:SetText(("%d. %s |cff%s%s|r%s · %s%s"):format(i, short(c.name), KIND_COLOR[c.kind] or "ffffff", T(c.kind),
        c.delta and ((c.delta > 0 and " +" or " ") .. c.delta) or "", table.concat(web, " · "), (c.note and c.note ~= "") and " *" or "") .. (c.offArmor and (" |cffff4040" .. T("offArmor") .. "|r") or ""))
      r.vote:SetText(r.voted and T("unvote") or T("vote"))
      r.vote:SetShown(not it.award and not s.closed)
      r.give:SetText(T("give"))
      r.give:SetShown(ml and not it.award and not s.closed and true or false)
    end
  end
  local mlOpen = ml and has and not it.award and not s.closed and true or false
  win.de:SetText(T("de")); win.de:SetShown(mlOpen)
  win.openAll:SetText(T("openAll")); win.openAll:SetShown(mlOpen and need and not it.open and true or false)
  win.bank:SetText(T("bank")); win.bank:SetShown(mlOpen)
  win.close:SetText(T("close")); win.close:SetShown(ml and not s.closed and true or false)
  win.prev:SetShown(total > 1); win.nxt:SetShown(total > 1)
  return n
end

function ns.openCouncil(rest)
  if rest and rest ~= "" then ns.councilCommand(rest) else refresh(true) end
end

-- ── Eventos ───────────────────────────────────────────────────────────────────────────────
local ef = CreateFrame("Frame")
local ON = {
  PLAYER_LOGIN = function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
    rebuild()
  end,
  CHAT_MSG_ADDON = function(...) onMessage(...) end,
  CHAT_MSG_WHISPER = function(msg, sender) pcall(onWhisper, msg, sender) end,
  LOOT_OPENED = function() local ok, err = pcall(onLootOpened); if not ok and ns.debug then print(err) end end,
  ENCOUNTER_END = function(id, name, _, _, success) if success == 1 then lastBoss = { id = id, name = name, at = time() } end end,
  GET_ITEM_INFO_RECEIVED = function() if win and win:IsShown() then refresh() end end,
}
for e in pairs(ON) do pcall(ef.RegisterEvent, ef, e) end
ef:SetScript("OnEvent", function(_, e, ...) local fn = ON[e]; if fn then fn(...) end end)

-- Para las pruebas.
ns._council = { state = state, rebuild = rebuild, current = current, candidates = candidates, onMessage = onMessage,
  onWhisper = onWhisper, openSession = openSession, respond = respond, vote = vote, award = award,
  closeSession = closeSession, equippedFor = equippedFor, refresh = function(o) return refresh(o) end,
  pending = function() return pendingLoot end, openToAll = openToAll, canUse = canUse, allowed = allowed, setBlocked = function(v) blocked = v end }
