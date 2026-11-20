-- Rebirth Track · El plan de tus personajes en el juego (plan contra avance)
-- El sitio arma el plan de cada personaje (Planificador de personajes › «Para el addon») como un
-- texto RTP1: una línea por dato, campos con «;» y al final «Z;<crc32>» de todo el bloque, así lo
-- copiado a medias no se lee. Llega de dos formas:
--   · pegado en la ventana (/rt plan → Pegar plan): queda en RebirthTrackDB.plans (para quien usa
--     solo el addon, sin la app);
--   · Plans.lua, que escribe Rebirth Track Uploader en la carpeta del addon con los personajes
--     vinculados de la cuenta (RebirthTrackPlans): se carga al entrar o con /reload.
-- La ventana muestra el plan del personaje con el que estás (por nombre y reino) o el que elijas,
-- contra lo que ve el juego: nivel, habilidad de cada profesión (el paso de la ruta en el que estás y
-- los materiales que tenés en bolsas y banco), talentos gastados (el próximo a tocar) y el Legado
-- planeado (el juego todavía no lo muestra a los addons). Nada de esto sale del juego.
--   RTP1;id;nombre;reino;raza;clase;modalidad;main
--   P;oficio;nombre · S;oficio;desde;hasta;veces;hechizo;receta · M;oficio;ítem;cantidad;nombre
--   B;rama;nombre · T;rama;fila;columna;rango;máximo;nombre;hechizos;inglés · L;rama;rango;máximo;nombre;inglés · N;notas
local ADDON, ns = ...
ns = ns or {}

local TX = {
  es = {
    title = "Plan del personaje", none = "Sin plan para este personaje.", noneHint = "Copiá el plan en rebirthknights.fun (Planificador de personajes › Para el addon) y pegalo con «Pegar plan». Con la app, los personajes vinculados llegan solos.",
    paste = "Pegar plan", read = "Leer", clear = "Borrar pegados", pasteHint = "Pegá acá el texto que copiaste del sitio y tocá Leer:",
    bad = "el texto no es un plan válido (copialo de nuevo del sitio).", loaded = "%d plan(es) leído(s).", cleared = "Planes pegados borrados.",
    tSummary = "Resumen", tProf = "Profesiones", tTalents = "Talentos", tLegacy = "Legado",
    level = "Nivel", total = "Avance", main = "main", fromApp = "de la app", pasted = "pegado", other = "Es de otro personaje: %s",
    skill = "Habilidad", notLearned = "sin aprender", step = "Paso %d de %d", done = "Ruta completa", now = "ahora",
    mats = "Materiales de toda la ruta (bolsas + banco)", matsLeftTitle = "Materiales que faltan (bolsas + banco)",
    matsAll = "Todas", matsLeft = "Solo lo que falta", matsLeftTip = "Saca los materiales de los niveles de la profesión que ya pasaste: queda lo que falta desde tu nivel actual (del paso en el que estás, la parte que te queda).",
    matsNoCat = "%s: sin el catálogo de la app, va el total de la ruta.", matsNone = "No falta nada: ya pasaste la ruta.", noRoute = "Sin ruta (se sube recolectando).",
    planned = "Planeados", spent = "Gastados", next = "Próximo a tocar: %s (%d→%d)", buildDone = "Build completa.", off = "Fuera del plan: %s",
    legacyNote = "No se encontró tu Legado en el juego (con ? los que no se pudieron leer): tildalo a mano en el planificador del sitio y pasá /rt diag a quien mantiene el addon.",
    notes = "Notas", noTalents = "Sin build de talentos en el plan.", noLegacy = "Sin reparto de Legado en el plan.",
    legend = "|cff40bf40verde|r: listo · |cffff8b3dnaranja|r: a medias · |cffffd100dorado|r: falta · |cffff4040rojo|r: fuera del plan",
    planRank = "Plan: %d/%d", notPlanned = "No está en el plan.", otherClass = "El plan es de otra clase: se ve como lista.",
    ofPlan = "del plan", nextShort = "próximo: %s (%d→%d)", byTree = "Talentos por rama", seeTree = "Ver el árbol ›",
    matsReady = "%d de %d listos", spentOf = "/ %d · %d gastados", lgCard = "/ 16 · plan %d",
    lgTotal = "/ 16 puntos repartidos · plan %d", lgTree = "%s en la rama · plan %d", lgNext = "Próximo: %s %d → %d", lgDone = "Legado completo.",
    gate = "%d en rama", lgRank = "rango %s/%d", lgGateTip = "Pide %d puntos en la rama.", lgReqTip = "Pide: %s", nextTip = "El próximo a tocar.",
    lgOther = "Otros del plan", lgDoneL = "listo", lgPart = "a medias", lgTodo = "falta", lgOff = "fuera del plan", lgNextL = "el próximo",
    lgNone = "no está en el plan", lgReserved = "reservado (Blizzard la suma después)", lgGateL = "«5 en rama»: puntos que pide la rama",
  },
  en = {
    title = "Character plan", none = "No plan for this character.", noneHint = "Copy the plan at rebirthknights.fun (Character planner › For the addon) and paste it with «Paste plan». With the app, linked characters arrive on their own.",
    paste = "Paste plan", read = "Read", clear = "Clear pasted", pasteHint = "Paste the text you copied from the site and press Read:",
    bad = "the text isn't a valid plan (copy it again from the site).", loaded = "%d plan(s) read.", cleared = "Pasted plans cleared.",
    tSummary = "Summary", tProf = "Professions", tTalents = "Talents", tLegacy = "Legacy",
    level = "Level", total = "Progress", main = "main", fromApp = "from the app", pasted = "pasted", other = "It belongs to another character: %s",
    skill = "Skill", notLearned = "not learned", step = "Step %d of %d", done = "Route done", now = "now",
    mats = "Materials for the whole route (bags + bank)", matsLeftTitle = "Materials still needed (bags + bank)",
    matsAll = "All", matsLeft = "Only what's left", matsLeftTip = "Removes the materials for the profession levels you already passed: what's left from your current level (for the step you're on, the part that remains).",
    matsNoCat = "%s: without the app's catalog, the whole route is shown.", matsNone = "Nothing left: you're past the route.", noRoute = "No route (leveled by gathering).",
    planned = "Planned", spent = "Spent", next = "Next to take: %s (%d→%d)", buildDone = "Build done.", off = "Off plan: %s",
    legacyNote = "Your Legacy wasn't found in the game (? marks what couldn't be read): tick it by hand in the site's planner and send /rt diag to the addon's maintainer.",
    notes = "Notes", noTalents = "No talent build in the plan.", noLegacy = "No Legacy points in the plan.",
    legend = "|cff40bf40green|r: done · |cffff8b3dorange|r: partial · |cffffd100gold|r: to take · |cffff4040red|r: off plan",
    planRank = "Plan: %d/%d", notPlanned = "Not in the plan.", otherClass = "The plan is for another class: shown as a list.",
    ofPlan = "of the plan", nextShort = "next: %s (%d→%d)", byTree = "Talents by tree", seeTree = "See the tree ›",
    matsReady = "%d of %d ready", spentOf = "/ %d · %d spent", lgCard = "/ 16 · plan %d",
    lgTotal = "/ 16 points spent · plan %d", lgTree = "%s in the tree · plan %d", lgNext = "Next: %s %d → %d", lgDone = "Legacy done.",
    gate = "%d in tree", lgRank = "rank %s/%d", lgGateTip = "Needs %d points in the tree.", lgReqTip = "Requires: %s", nextTip = "Next to take.",
    lgOther = "Others in the plan", lgDoneL = "done", lgPart = "partial", lgTodo = "to take", lgOff = "off plan", lgNextL = "next",
    lgNone = "not in the plan", lgReserved = "reserved (Blizzard adds it later)", lgGateL = "«5 in tree»: points the tree needs",
  },
}
local function T(k) local l = ns.lang and ns.lang() or "es"; return (TX[l] or TX.es)[k] or TX.es[k] or k end
local function say(msg) if ns.say then ns.say(msg) else print(msg) end end

-- ── CRC-32 (el de zip, como el sitio) ─────────────────────────────────────────────────────────────
-- Con la librería bit de WoW si está; si no, con aritmética (para correr las pruebas fuera del juego).
local bxor
if bit and bit.bxor then
  bxor = function(a, b) return bit.bxor(a, b) % 4294967296 end
else
  bxor = function(a, b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
      local x, y = a % 2, b % 2
      if x ~= y then r = r + p end
      a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return r
  end
end
local CRC = {}
for n = 0, 255 do
  local c = n
  for _ = 1, 8 do
    if c % 2 == 1 then c = bxor(0xEDB88320, math.floor(c / 2)) else c = math.floor(c / 2) end
  end
  CRC[n] = c
end
local function crc32(s)
  local c = 0xFFFFFFFF
  for i = 1, #s do c = bxor(CRC[bxor(c, s:byte(i)) % 256], math.floor(c / 256)) end
  return string.format("%08x", bxor(c, 0xFFFFFFFF))
end

-- ── Lectura ───────────────────────────────────────────────────────────────────────────────────────
local function fields(line)
  local f = {}
  for v in (line .. ";"):gmatch("([^;]*);") do f[#f + 1] = v end
  return f
end
-- «123,456» → { 123, 456 } (los hechizos de cada rango; los planes viejos no los traen).
local function idList(v)
  local out = {}
  for x in tostring(v or ""):gmatch("%d+") do out[#out + 1] = tonumber(x) end
  return out
end
local function fromLines(lines)
  local h = fields(lines[1])
  local p = { id = h[2] or "", name = h[3] or "", realm = h[4] or "", race = h[5] or "", cls = h[6] or "", mode = h[7] or "", main = h[8] == "1",
    profs = {}, trees = {}, talents = {}, legacy = {}, notes = "" }
  local byKey = {}
  for i = 2, #lines do
    local f = fields(lines[i])
    local n = function(k) return tonumber(f[k]) or 0 end
    local t = f[1]
    if t == "P" then local pr = { key = f[2], name = f[3] or f[2], steps = {}, mats = {} }; table.insert(p.profs, pr); byKey[f[2]] = pr
    elseif t == "S" and byKey[f[2]] then table.insert(byKey[f[2]].steps, { from = n(3), to = n(4), crafts = n(5), spell = n(6), name = f[7] or "" })
    elseif t == "M" and byKey[f[2]] then table.insert(byKey[f[2]].mats, { item = n(3), count = n(4), name = f[5] or "" })
    elseif t == "B" then p.trees[n(2) + 1] = f[3] or ""
    elseif t == "T" then table.insert(p.talents, { tree = n(2), row = n(3), col = n(4), rank = n(5), max = n(6), name = f[7] or "", spells = idList(f[8]), en = f[9] or "" })
    elseif t == "L" then table.insert(p.legacy, { tree = f[2] or "", rank = n(3), max = n(4), name = f[5] or "", en = f[6] or "" })
    elseif t == "N" then p.notes = table.concat(f, " ", 2)
    end
  end
  return p
end
-- Todos los bloques válidos del texto (los que tienen la suma bien).
local function parse(text)
  local out, block = {}, {}
  for raw in ((text or "") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local line = raw:match("^%s*(.-)%s*$")
    if line:find("^RTP1;") then block = {} end
    if line:find("^Z;") then
      if block[1] and block[1]:find("^RTP1;") and line:sub(3):lower() == crc32(table.concat(block, "\n")) then
        table.insert(out, { text = table.concat(block, "\n") .. "\n" .. line, plan = fromLines(block) })
      end
      block = {}
    elseif line ~= "" then
      table.insert(block, line)
    end
  end
  return out
end
ns.planParse, ns.planCrc32 = parse, crc32

local function pastedDB()
  local d = ns.db()
  d.plans = d.plans or {}
  return d.plans
end
-- Los de la app (Plans.lua) y los pegados; si el mismo personaje está en los dos, gana el pegado.
local function allPlans()
  local list, seen = {}, {}
  for id, text in pairs(pastedDB()) do
    for _, b in ipairs(parse(text)) do if not seen[b.plan.id] then seen[b.plan.id] = true; b.plan.source = "pasted"; table.insert(list, b.plan) end end
  end
  local file = rawget(_G, "RebirthTrackPlans")
  for _, text in ipairs(type(file) == "table" and file.plans or {}) do
    for _, b in ipairs(parse(text)) do if not seen[b.plan.id] then seen[b.plan.id] = true; b.plan.source = "app"; table.insert(list, b.plan) end end
  end
  table.sort(list, function(a, b) if a.main ~= b.main then return a.main end return a.name < b.name end)
  return list
end
local function load(text)
  local blocks = parse(text)
  if #blocks == 0 then say(T("bad")); return 0 end
  for _, b in ipairs(blocks) do pastedDB()[b.plan.id] = b.text end
  say(T("loaded"):format(#blocks))
  return #blocks
end

-- ── Lo que ve el juego ───────────────────────────────────────────────────────────────────────────
local PROF_NAMES = {
  alchemy = { "Alchemy", "Alquimia" }, blacksmithing = { "Blacksmithing", "Herrería" }, enchanting = { "Enchanting", "Encantamiento" },
  engineering = { "Engineering", "Ingeniería" }, leatherworking = { "Leatherworking", "Peletería" }, tailoring = { "Tailoring", "Sastrería", "Costura" },
  mining = { "Mining", "Minería" }, herbalism = { "Herbalism", "Herboristería", "Herbalismo" }, skinning = { "Skinning", "Desuello", "Desollar" },
  cooking = { "Cooking", "Cocina" }, firstaid = { "First Aid", "Primeros auxilios" }, fishing = { "Fishing", "Pesca" },
}
-- Línea de habilidad de cada profesión (GetProfessionInfo la devuelve: no depende del idioma).
local SKILL_LINES = {
  alchemy = 171, blacksmithing = 164, enchanting = 333, engineering = 202, leatherworking = 165, tailoring = 197,
  mining = 186, herbalism = 182, skinning = 393, cooking = 185, firstaid = 129, fishing = 356,
}
local function sameName(key, name)
  for _, n in ipairs(PROF_NAMES[key] or {}) do if n:lower() == tostring(name):lower() then return true end end
  return false
end
-- Classic: la lista de habilidades (GetSkillLineInfo). WoW Forever y los clientes con el motor nuevo
-- no la tienen: ahí las profesiones salen de GetProfessions (como en Collect.lua). Antes solo se miraba
-- la primera y en Forever todo quedaba «sin aprender».
local function skillOf(key)
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() or 0 do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not header and sameName(key, name) then return rank, max end
    end
  end
  if GetProfessions and GetProfessionInfo then
    local list = { GetProfessions() }
    for i = 1, 6 do
      if list[i] then
        local name, _, rank, max, _, _, line = GetProfessionInfo(list[i])
        if (line and line == SKILL_LINES[key]) or (name and sameName(key, name)) then return rank, max end
      end
    end
  end
  return nil
end
ns._skillOf = skillOf

-- Lo gastado en el juego, como lista de «nodos» { key | spells+name, rank }:
--  · Classic: GetTalentInfo(rama, i) → clave «rama-fila-columna», la misma del plan.
--  · WoW Forever: no tiene esa API; usa el sistema nuevo (C_ClassTalents + C_Traits). Ahí no hay filas
--    ni columnas: cada nodo se cruza con el plan por el hechizo (los ID de cada rango que manda el sitio)
--    o, en planes viejos, por el nombre.
local function spellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id)) or nil
end
local function traitNodes(configID)
  local out = {}
  local T = C_Traits
  local cfg = configID and T and T.GetConfigInfo and T.GetConfigInfo(configID)
  if not cfg or not cfg.treeIDs then return out end
  for _, treeID in ipairs(cfg.treeIDs) do
    for _, nodeID in ipairs(T.GetTreeNodes(treeID) or {}) do
      local node = T.GetNodeInfo(configID, nodeID)
      if node and (node.maxRanks or 0) > 0 then
        local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
        local entry = entryID and T.GetEntryInfo(configID, entryID)
        local def = entry and entry.definitionID and T.GetDefinitionInfo(entry.definitionID)
        local spell = def and def.spellID
        local name = (def and def.overrideName ~= "" and def.overrideName) or spellName(spell)
        if spell or name then
          out[#out + 1] = { spells = { [spell or 0] = true, [def and def.overriddenSpellID or 0] = true }, name = name and name:lower() or nil,
            rank = node.ranksPurchased or node.currentRank or node.activeRank or 0, max = node.maxRanks, tree = treeID }
        end
      end
    end
  end
  return out
end
-- Configuraciones de otros sistemas de C_Traits (el Legado de Forever va en uno propio).
local function systemConfigs()
  local out, seen = {}, {}
  local T = C_Traits
  if not (T and T.GetConfigIDBySystemID) then return out end
  for sys = 1, 80 do
    local ok, id = pcall(T.GetConfigIDBySystemID, sys)
    if ok and id and id ~= 0 and not seen[id] then seen[id] = true; out[#out + 1] = { system = sys, config = id } end
  end
  return out
end

local function talentState()
  local nodes = {}
  if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
    for tab = 1, GetNumTalentTabs() do
      for i = 1, GetNumTalents(tab) do
        local name, _, tier, col, rank = GetTalentInfo(tab, i)
        if name then nodes[#nodes + 1] = { key = (tab - 1) .. "-" .. tier .. "-" .. col, rank = rank or 0 } end
      end
    end
    return { nodes = nodes, classic = true }
  end
  local active = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
  local ok, list = pcall(traitNodes, active)
  return { nodes = ok and list or {}, traits = true, config = active }
end
-- Los nodos de todos los sistemas (para el Legado), sin repetir la configuración de talentos.
local function legacyNodes(state)
  local out = {}
  for _, c in ipairs(systemConfigs()) do
    if c.config ~= state.config then
      local ok, list = pcall(traitNodes, c.config)
      if ok then for _, n in ipairs(list) do out[#out + 1] = n end end
    end
  end
  return out
end
-- El nodo del juego que corresponde a un talento (o punto de Legado) del plan.
local function nodeFor(nodes, t, key)
  for _, n in ipairs(nodes) do
    if key and n.key == key then return n end
    if not n.key then
      for _, id in ipairs(t.spells or {}) do if n.spells[id] then return n end end
    end
  end
  -- Por nombre: el del plan (idioma del sitio) o el inglés (el del cliente de Forever en inglés).
  for _, nm in ipairs({ t.name, t.en }) do
    local name = nm and nm:lower()
    if name and name ~= "" then for _, n in ipairs(nodes) do if not n.key and n.name == name then return n end end end
  end
  return nil
end
local function haveOf(state, t)
  local n = nodeFor(state.nodes, t, state.classic and (t.tree .. "-" .. t.row .. "-" .. t.col) or nil)
  return n and n.rank or 0, n
end

-- /rt diag: qué API de talentos, Legado y profesiones ofrece este cliente (para adaptar el addon a WoW
-- Forever): las funciones conocidas y todo lo global con «Talent», «Legacy» o «Trait» en el nombre.
function ns.planDiag()
  local function has(name)
    local v = _G[name]
    return v == nil and "no" or type(v)
  end
  local function try(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then return "error: " .. tostring(r[2]) end
    local out = {}
    for i = 2, math.min(#r, 9) do out[#out + 1] = tostring(r[i]) end
    return table.concat(out, ", ")
  end
  say("diag · proyecto " .. tostring(WOW_PROJECT_ID) .. " · build " .. try(GetBuildInfo))
  for _, n in ipairs({ "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo", "GetTalentInfoByID",
    "GetNumSpecializations", "GetSpecialization", "GetActiveTalentGroup", "GetNumSkillLines", "GetProfessions",
    "C_ClassTalents", "C_Traits", "C_SpecializationInfo", "C_Talent", "C_TalentTree" }) do
    say("diag · " .. n .. ": " .. has(n))
  end
  if GetNumTalentTabs then say("diag · GetNumTalentTabs() = " .. try(GetNumTalentTabs)) end
  if GetTalentInfo then say("diag · GetTalentInfo(1, 1) = " .. try(GetTalentInfo, 1, 1)) end
  if GetTalentTabInfo then say("diag · GetTalentTabInfo(1) = " .. try(GetTalentTabInfo, 1)) end
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then say("diag · C_ClassTalents.GetActiveConfigID() = " .. try(C_ClassTalents.GetActiveConfigID)) end
  if GetProfessions then say("diag · GetProfessions() = " .. try(GetProfessions)) end
  local st = talentState()
  local spent = 0
  for _, n in ipairs(st.nodes) do spent = spent + (n.rank or 0) end
  say("diag · talentos: " .. (st.classic and "clásicos" or "C_Traits") .. ", " .. #st.nodes .. " nodos, " .. spent .. " puntos")
  local shown = 0
  for _, n in ipairs(st.nodes) do
    if (n.rank or 0) > 0 and shown < 5 then shown = shown + 1; say("diag ·   " .. tostring(n.name) .. " " .. n.rank .. "/" .. tostring(n.max)) end
  end
  for _, c in ipairs(systemConfigs()) do
    local ok, list = pcall(traitNodes, c.config)
    local cfg = C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(c.config)
    local pts, sample = 0, {}
    for _, n in ipairs(ok and list or {}) do pts = pts + (n.rank or 0); if #sample < 3 and n.name then sample[#sample + 1] = n.name end end
    say("diag · sistema " .. c.system .. ": config " .. c.config .. " «" .. tostring(cfg and cfg.name) .. "» " .. (ok and #list or 0) .. " nodos, " .. pts .. " puntos · " .. table.concat(sample, ", "))
  end
  local names = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and (k:find("Talent") or k:find("Legacy") or k:find("Trait")) and (type(v) == "function" or (type(v) == "table" and k:match("^C_"))) then names[#names + 1] = k end
  end
  table.sort(names)
  for i = 1, #names, 6 do say("diag · " .. table.concat(names, " ", i, math.min(#names, i + 5))) end
end

-- Las ramas de talentos del juego (de la clase del personaje), para dibujarlas como en la ventana de
-- talentos: cada talento con su ícono, fila, columna, rango, máximo y requisito.
local function talentTrees()
  local out = {}
  if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return out end
  for tab = 1, GetNumTalentTabs() do
    local tname, ticon = GetTalentTabInfo and GetTalentTabInfo(tab)
    local tree = { tab = tab, name = tname, icon = ticon, talents = {}, rows = 1 }
    for i = 1, GetNumTalents(tab) do
      local name, icon, tier, col, rank, max = GetTalentInfo(tab, i)
      if name and tier and col then
        local pt, pc
        if GetTalentPrereqs then pt, pc = GetTalentPrereqs(tab, i) end
        table.insert(tree.talents, { i = i, name = name, icon = icon, row = tier, col = col, rank = rank or 0, max = max or 1,
          key = (tab - 1) .. "-" .. tier .. "-" .. col, pre = pt and pc and ((tab - 1) .. "-" .. pt .. "-" .. pc) or nil })
        if tier > tree.rows then tree.rows = tier end
      end
    end
    table.insert(out, tree)
  end
  return out
end
local function slug(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
local function isMine(p)
  local me = UnitName("player")
  return p.name:lower() == (me or ""):lower() and (p.realm == "" or slug(p.realm) == slug(GetRealmName and GetRealmName()))
end

-- Las mismas cuentas que el sitio (shared/planProgress.ts).
local function progress(p)
  local level = UnitLevel and UnitLevel("player") or 0
  local out = { level = level, profs = {}, tal = nil }
  local vals = { math.min(1, level / 60) }
  for _, pr in ipairs(p.profs) do
    local rank, max = skillOf(pr.key)
    local at
    for i, s in ipairs(pr.steps) do if (rank or 1) < s.to then at = i; break end end
    table.insert(out.profs, { prof = pr, rank = rank, max = max, step = at })
    table.insert(vals, math.min(1, (rank or 0) / 300))
  end
  if #p.talents > 0 then
    local state, planned, matched, spent, next, off = talentState(), 0, 0, 0, nil, 0
    local used = {}
    for _, t in ipairs(p.talents) do
      local h, n = haveOf(state, t)
      if n then used[n] = true end
      planned, matched = planned + t.rank, matched + math.min(h, t.rank)
      if not next and h < t.rank then next = { t = t, have = h } end
    end
    for _, n in ipairs(state.nodes) do
      spent = spent + (n.rank or 0)
      if (n.rank or 0) > 0 and not used[n] then off = off + 1 end
    end
    out.tal = { planned = planned, matched = matched, spent = spent, next = next, off = off, state = state }
    if planned > 0 then table.insert(vals, matched / planned) end
  end
  local sum = 0
  for _, v in ipairs(vals) do sum = sum + v end
  out.pct = math.floor(sum / #vals * 100 + 0.5)
  return out
end
ns.planProgress = progress


-- ── Ventana ──────────────────────────────────────────────────────────────────────────────────────
-- Con el kit «Obsidiana» (UI.lua): franja de título con ‹ › para pasar de plan, cabecera del personaje
-- (nombre en el color de su clase, raza · clase · de dónde vino y el % del plan), pestañas planas y,
-- abajo, Pegar plan / Leer / Borrar pegados.
local GOLD, GREEN, GRAY, ORANGE, RED, WHITE_C = "|cfff2c14e", "|cff5fd49b", "|cff8a909d", "|cfff0b64f", "|cffff7a7e", "|cffffffff"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local W, H, HERO_H = 720, 640, 60
local CW = W - 44 -- ancho del contenido (lo que deja la barra del scroll)
local BLUE, PURPLE, BOARD, DARK = { 0.290, 0.639, 0.941 }, { 0.773, 0.545, 1 }, { 0.059, 0.071, 0.094 }, { 0.039, 0.047, 0.063 }
local CELLBG = { 0.102, 0.114, 0.141 }
-- Estados (borde, texto del rango): como el sitio.
local ST = {
  done = { { 0.298, 0.765, 0.541 }, { 0.373, 0.831, 0.608 } }, part = { { 0.941, 0.714, 0.310 }, { 0.941, 0.714, 0.310 } },
  todo = { { 0.788, 0.588, 0.180 }, { 0.788, 0.588, 0.180 } }, off = { { 0.898, 0.282, 0.302 }, { 1, 0.478, 0.494 } },
  none = { { 0.180, 0.200, 0.239 }, { 0.420, 0.443, 0.490 } }, next = { { 1, 1, 1 }, { 1, 1, 1 } },
}
local pw, sel, tab = nil, nil, "summary"
local function lang() return ns.lang and ns.lang() or "es" end
local function tw(fs) return (fs and fs.GetStringWidth and fs:GetStringWidth()) or 0 end
local function th(fs) return (fs and fs.GetStringHeight and fs:GetStringHeight()) or 0 end
local function nowrap(fs) if fs.SetWordWrap then fs:SetWordWrap(false) end return fs end
-- Textura lisa con subnivel (para apilar borde, fondo e ícono) y, si `round`, redonda.
local function ltex(frame, layer, sub, c, a, round)
  local t = frame:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(WHITE)
  if round and t.SetMask then pcall(t.SetMask, t, MASK) end
  if c and t.SetVertexColor then t:SetVertexColor(c[1], c[2], c[3], a or 1) end
  return t
end
local function tint(t, c, a) if t and t.SetVertexColor then t:SetVertexColor(c[1], c[2], c[3], a or 1) end end
local function color(fs, c) if fs and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3]) end end
local function pool(list, i, make) local x = list[i]; if not x then x = make(); list[i] = x end; x:Show(); return x end
local function hideFrom(list, n) for k = n, #list do list[k]:Hide() end end

-- El árbol se dibuja con las ramas del juego: solo si el plan es de la clase del personaje con el que
-- estás (si no, las ramas no son las del plan y queda la lista).
local function canDraw(p)
  if #p.talents == 0 or not (GetNumTalentTabs and GetTalentInfo) then return false end
  if not UnitClass then return false end
  local _, token = UnitClass("player")
  return token ~= nil and token:upper() == (p.cls or ""):upper()
end

local function stateOf(have, want)
  if want > 0 then return have >= want and "done" or have > 0 and "part" or "todo" end
  return have > 0 and "off" or "none"
end

-- Texto de la pestaña Profesiones (la ruta paso a paso y los materiales).
local function profLines(pr)
  local out = {}
  local add = function(s) out[#out + 1] = s end
  for _, x in ipairs(pr.profs) do
    add(GOLD .. x.prof.name .. "|r  " .. T("skill") .. ": " .. (x.rank and (x.rank .. "/" .. (x.max or 300)) or T("notLearned")))
    if #x.prof.steps == 0 then add(GRAY .. T("noRoute") .. "|r")
    elseif not x.step and x.rank then add(ns.ui.ICON.check .. GREEN .. T("done") .. "|r")
    else add(GRAY .. T("step"):format(x.step or 1, #x.prof.steps) .. "|r") end
    for i, s in ipairs(x.prof.steps) do
      local mark = i == x.step and (ns.ui.ICON.play .. GOLD .. T("now") .. " ") or ((x.step and i < x.step or (not x.step and x.rank)) and ns.ui.ICON.check .. GREEN or GRAY .. "  ")
      add(mark .. s.from .. "→" .. s.to .. "  " .. s.name .. " ×" .. s.crafts .. "|r")
    end
    if #x.prof.mats > 0 then
      add(""); add(GRAY .. T("mats") .. "|r")
      for _, m in ipairs(x.prof.mats) do
        local have = GetItemCount and GetItemCount(m.item, true) or 0
        add((have >= m.count and GREEN or RED) .. have .. "/" .. m.count .. "|r  " .. m.name)
      end
    end
    add("")
  end
  return out
end

-- Talentos como lista (WoW Forever, o plan de otra clase).
local function talentLines(p, pr)
  local out = {}
  local add = function(s) out[#out + 1] = s end
  if isMine(p) and GetNumTalentTabs then add(GRAY .. T("otherClass") .. "|r") end -- en Forever no hay árbol: es la lista y no es de otra clase
  local last
  for _, t in ipairs(p.talents) do
    if t.tree ~= last then add(""); add(GOLD .. (p.trees[t.tree + 1] or ("#" .. t.tree)) .. "|r"); last = t.tree end
    local h = haveOf(pr.tal.state, t)
    add((h >= t.rank and GREEN or h > 0 and ORANGE or GRAY) .. h .. "/" .. t.rank .. "|r  " .. t.name)
  end
  return out
end

-- ── Árbol de talentos ────────────────────────────────────────────────────────────────────────────
-- Las tres ramas una al lado de la otra, como la ventana de talentos del juego y la ficha del personaje
-- del sitio: ícono de cada talento en su fila y columna, flechas de requisitos y, por talento, lo que
-- tenés contra lo planeado (borde y número del color del estado). Pasando el mouse, la tooltip del juego.
local CELL, STEP, PADX, HEAD, PADY, GAP = 32, 44, 18, 30, 12, 12
local TREE_W = PADX * 2 + 3 * STEP + CELL
local function cellAt(t) return PADX + (t.col - 1) * STEP, -(HEAD + PADY + (t.row - 1) * STEP) end

-- Panel plano de una rama: cabecera (emblema, nombre, gastado/planeado) y el tablero.
local function treePanel(parent, w)
  local U, C = ns.ui, ns.ui.C
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(w)
  U.fill(f, BOARD, 1); U.edge(f, C.line, 1)
  f.head = CreateFrame("Frame", nil, f)
  f.head:SetPoint("TOPLEFT", 1, -1); f.head:SetPoint("TOPRIGHT", -1, -1)
  U.fill(f.head, C.strip, 1)
  f.headLine = U.tex(f.head, "ARTWORK", C.line); f.headLine:SetHeight(1)
  f.headLine:SetPoint("BOTTOMLEFT", 0, 0); f.headLine:SetPoint("BOTTOMRIGHT", 0, 0)
  f.cells, f.lines, f.tiers = {}, {}, {}
  return f
end

local function treeFrame(i)
  local g = pw.grid
  g.trees = g.trees or {}
  local f = g.trees[i]
  if f then return f end
  local C = ns.ui.C
  f = treePanel(g, TREE_W)
  f.head:SetHeight(HEAD - 1)
  f.emb = ltex(f.head, "ARTWORK", 1, nil, nil, true); f.emb:SetSize(18, 18); f.emb:SetPoint("LEFT", 8, 0)
  f.count = ns.ui.font(f.head, "GameFontHighlightSmall", C.muted, "RIGHT"); f.count:SetPoint("RIGHT", -8, 0)
  f.title = nowrap(ns.ui.font(f.head, "GameFontNormalSmall", C.text, "LEFT")); f.title:SetPoint("LEFT", f.emb, "RIGHT", 6, 0)
  f.title:SetWidth(TREE_W - 90)
  g.trees[i] = f
  return f
end
local function line(f, n)
  local l = f.lines[n]
  if not l then l = ltex(f, "ARTWORK", 2, ns.ui.C.btnLine); f.lines[n] = l end
  l:ClearAllPoints(); l:Show()
  return l
end
local function cell(f, n)
  local b = f.cells[n]
  if b then return b end
  local C = ns.ui.C
  b = CreateFrame("Button", nil, f)
  b:SetSize(CELL, CELL)
  b.glow = ltex(b, "BACKGROUND", -8, { 1, 1, 1 }, 0.3); b.glow:SetPoint("TOPLEFT", -3, 3); b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
  b.border = ltex(b, "BACKGROUND", 1, ST.none[1]); b.border:SetAllPoints()
  b.inner = ltex(b, "BORDER", 1, { 0, 0, 0 }); b.inner:SetPoint("TOPLEFT", 2, -2); b.inner:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  -- El rango en una pastilla redonda en la esquina.
  b.badge = CreateFrame("Frame", nil, b)
  b.badge:SetSize(26, 14); b.badge:SetPoint("CENTER", b, "BOTTOMRIGHT", -3, 1)
  if b.badge.SetFrameLevel then b.badge:SetFrameLevel((b:GetFrameLevel() or 1) + 2) end
  b.badge.o = ltex(b.badge, "ARTWORK", 1, C.btnLine, 1, true); b.badge.o:SetAllPoints()
  b.badge.i = ltex(b.badge, "ARTWORK", 2, DARK, 1, true); b.badge.i:SetPoint("TOPLEFT", 1, -1); b.badge.i:SetPoint("BOTTOMRIGHT", -1, 1)
  b.rank = b.badge:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); b.rank:SetPoint("CENTER", 0, 0)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetTalent then GameTooltip:SetTalent(self.tab, self.i) else GameTooltip:AddLine(self.tname or "", 1, 1, 1) end
    if self.want > 0 then GameTooltip:AddLine(T("planRank"):format(self.want, self.max), 0.95, 0.76, 0.31)
    else GameTooltip:AddLine(T("notPlanned"), 0.54, 0.56, 0.62) end
    if self.isNext then GameTooltip:AddLine(T("nextTip"), 1, 1, 1) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.cells[n] = b
  return b
end

-- Dibuja las tres ramas en pw.grid; devuelve el alto que ocupan.
local function drawTalents(p)
  local g = pw.grid
  local C = ns.ui.C
  local wanted = {}
  for _, t in ipairs(p.talents) do wanted[t.tree .. "-" .. t.row .. "-" .. t.col] = t.rank end
  local pr = progress(p)
  local nextKey = pr.tal and pr.tal.next and (pr.tal.next.t.tree .. "-" .. pr.tal.next.t.row .. "-" .. pr.tal.next.t.col)
  local trees, height = talentTrees(), 0
  local x0 = math.max(0, math.floor((CW - (3 * TREE_W + 2 * GAP)) / 2))
  for ti, tree in ipairs(trees) do
    local f = treeFrame(ti)
    local h = HEAD + PADY * 2 + (tree.rows - 1) * STEP + CELL + 6
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", x0 + (ti - 1) * (TREE_W + GAP), 0); f:SetHeight(h); f:Show()
    local spent, plan = 0, 0
    for _, t in ipairs(tree.talents) do spent = spent + t.rank; plan = plan + (wanted[t.key] or 0) end
    f.title:SetText(tree.name or ("#" .. ti))
    f.count:SetText(((plan > 0 and spent >= plan) and GREEN or ORANGE) .. spent .. "|r " .. GRAY .. "/ " .. plan .. "|r")
    if tree.icon then f.emb:SetTexture(tree.icon); tint(f.emb, { 1, 1, 1 }) else f.emb:SetTexture(WHITE); tint(f.emb, C.line) end
    -- Una línea tenue por fila.
    for r = 1, tree.rows do
      local tl = f.tiers[r]
      if not tl then tl = ltex(f, "BORDER", 1, { 0.102, 0.118, 0.153 }); tl:SetHeight(1); f.tiers[r] = tl end
      tl:ClearAllPoints(); tl:SetPoint("TOPLEFT", 1, -(HEAD + PADY + (r - 1) * STEP + CELL / 2)); tl:SetPoint("TOPRIGHT", -1, -(HEAD + PADY + (r - 1) * STEP + CELL / 2)); tl:Show()
    end
    for k = tree.rows + 1, #f.tiers do f.tiers[k]:Hide() end
    local byKey = {}
    for _, t in ipairs(tree.talents) do byKey[t.key] = t end
    -- Flechas de requisito (por debajo de los íconos): vertical, o en L desde la fila del requisito;
    -- doradas si las dos puntas están en el plan.
    local nl = 0
    for _, t in ipairs(tree.talents) do
      local pre = t.pre and byKey[t.pre]
      if pre then
        local x1, y1 = cellAt(pre)
        local x2, y2 = cellAt(t)
        local on = (wanted[t.key] or 0) > 0 and (wanted[pre.key] or 0) > 0
        local c = on and C.action or C.btnLine
        if x1 ~= x2 then
          nl = nl + 1
          local l = line(f, nl); tint(l, c)
          l:SetPoint("TOPLEFT", math.min(x1, x2) + CELL / 2, y1 - CELL / 2 + 1); l:SetSize(math.abs(x2 - x1) + 1, 3)
        end
        if y1 ~= y2 then
          nl = nl + 1
          local l = line(f, nl); tint(l, c)
          l:SetPoint("TOPLEFT", x2 + CELL / 2 - 1, (x1 ~= x2) and (y1 - CELL / 2) or (y1 - CELL)); l:SetSize(3, math.max(1, math.abs(y2 - y1) - ((x1 ~= x2) and CELL / 2 or CELL)))
        end
      end
    end
    for k = nl + 1, #f.lines do f.lines[k]:Hide() end
    for n, t in ipairs(tree.talents) do
      local b = cell(f, n)
      local want = wanted[t.key] or 0
      local st = stateOf(t.rank, want)
      local isNext = t.key == nextKey
      b.tab, b.i, b.tname, b.want, b.max, b.isNext = tree.tab, t.i, t.name, want, t.max, isNext
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", cellAt(t)); b:Show()
      b.icon:SetTexture(t.icon)
      if b.icon.SetDesaturated then b.icon:SetDesaturated(st == "none") end
      b.icon:SetAlpha(st == "none" and 0.4 or (t.rank > 0 and 1 or 0.7))
      tint(b.border, ST[isNext and "next" or st][1])
      b.glow:SetShown(isNext)
      local rank = want > 0 and (t.rank .. "/" .. want) or (t.rank > 0 and tostring(t.rank) or "")
      b.rank:SetText(rank)
      color(b.rank, ST[st][2])
      b.badge:SetShown(rank ~= "")
    end
    for k = #tree.talents + 1, #f.cells do f.cells[k]:Hide() end
    if h > height then height = h end
  end
  for k = #trees + 1, #(g.trees or {}) do g.trees[k]:Hide() end
  g:SetSize(CW, math.max(1, height)); g:Show()
  return height
end

-- ── Legado ───────────────────────────────────────────────────────────────────────────────────────
-- Las tres verticales del Legado (la cuenta, no el personaje) con la misma disposición que el sitio:
-- 4×4 por rama, puntos que pide la rama («5 en rama»), requisitos y los casilleros reservados que
-- Blizzard todavía no llenó. El plan no trae filas ni columnas: van acá, por el nombre inglés.
local function P(en, row, col, max, gate, req) return { en = en, row = row, col = col, max = max, gate = gate, req = req } end
local function R(row, col) return { row = row, col = col, reserved = true } end
local LEGACY = {
  { es = "Aventura", en = "Adventure", color = { 0.290, 0.639, 0.941 }, glyph = { 0.227, 0.431, 0.659 }, perks = {
    P("High Alert", 1, 2, 2, 5), P("Well Rested", 2, 1, 5), P("Talented", 2, 2, 5, 5, "Well Rested"), R(2, 3), R(2, 4),
    P("Thrill of Adventure", 3, 1, 5), P("Field Guide", 3, 2, 3, 5), P("Frequent Flier", 3, 3, 1, 10, "Field Guide"), P("Field Medicine", 4, 2, 2, 5) } },
  { es = "Ingenio", en = "Resourcefulness", color = { 0.298, 0.765, 0.541 }, glyph = { 0.180, 0.420, 0.290 }, perks = {
    P("For Great Honor", 1, 2, 5, 5), P("Gourmand", 2, 1, 3), P("Permanence", 2, 2, 2, 5, "Gourmand"), R(2, 3), R(2, 4),
    P("The Quick and the Dead", 3, 1, 2), P("Reagent Economy", 3, 3, 1, 10, "The Quick and the Dead"), P("Reinforce", 4, 1, 5), P("Diplomat", 4, 2, 5, 5) } },
  { es = "Oficios", en = "Professions", color = { 0.773, 0.545, 1 }, glyph = { 0.486, 0.357, 0.722 }, perks = {
    P("Master Chef", 1, 2, 5, 5), P("Working Overtime", 2, 1, 5), P("Bartering", 2, 2, 2, 5), P("Dedicated Study", 2, 3, 1, 10, "Bartering"),
    P("Bountiful Harvest", 3, 1, 5), P("Performance Bonus", 3, 2, 3, 5, "Bountiful Harvest"), R(3, 3), R(3, 4), P("Luremaster", 4, 2, 2, 5) } },
}
local LCELL, LSX, LSY, LPADX, LPADY, LHEAD = 36, 50, 60, 14, 18, 58
local LTREE_W = LPADX * 2 + 3 * LSX + LCELL
local LTREE_H = LHEAD + LPADY + 3 * LSY + LCELL + 16
local function lcellAt(pk) return LPADX + (pk.col - 1) * LSX, -(LHEAD + LPADY + (pk.row - 1) * LSY) end

-- El plan de Legado contra el juego, en la disposición de arriba. Lo del plan que no está en la tabla
-- (planes viejos sin nombre inglés) queda en `extra`.
local function legacyInfo(p)
  local nodes = legacyNodes(talentState())
  local byName = {}
  for _, l in ipairs(p.legacy) do
    for _, k in ipairs({ l.en, l.name }) do if k and k ~= "" and not byName[k:lower()] then byName[k:lower()] = l end end
  end
  local info = { trees = {}, spent = 0, planned = 0, matched = 0, found = 0, extra = {} }
  local used, cellOf = {}, {}
  for ti, def in ipairs(LEGACY) do
    local tr = { def = def, cells = {}, spent = 0, planned = 0, byEn = {} }
    for _, pk in ipairs(def.perks) do
      local c = { pk = pk, want = 0 }
      if not pk.reserved then
        local l = byName[pk.en:lower()]
        if l and not used[l] then used[l] = true; cellOf[l] = c; c.plan = l; c.want = l.rank or 0 end
        local n = nodeFor(nodes, { name = (l and l.name ~= "" and l.name) or pk.en, en = pk.en })
        c.have = n and (n.rank or 0) or nil
        c.name = (l and l.name ~= "" and l.name) or pk.en
        if n then info.found = info.found + 1; tr.spent = tr.spent + c.have end
        tr.planned = tr.planned + c.want
        info.matched = info.matched + math.min(c.have or 0, c.want)
        tr.byEn[pk.en] = c
      end
      tr.cells[#tr.cells + 1] = c
    end
    info.spent, info.planned = info.spent + tr.spent, info.planned + tr.planned
    info.trees[ti] = tr
  end
  for _, l in ipairs(p.legacy) do
    if not used[l] then
      local n = nodeFor(nodes, l)
      if n then info.found = info.found + 1 end
      info.planned = info.planned + (l.rank or 0)
      info.matched = info.matched + math.min(n and n.rank or 0, l.rank or 0)
      info.extra[#info.extra + 1] = { l = l, have = n and (n.rank or 0) or nil }
    end
  end
  for _, l in ipairs(p.legacy) do
    local c = cellOf[l]
    if c and (c.have or 0) < c.want then info.next = c; break end
  end
  return info
end

local function legacyTree(i)
  local g = pw.lgrid
  local f = g.trees[i]
  if f then return f end
  local U, C = ns.ui, ns.ui.C
  local def = LEGACY[i]
  f = treePanel(g, LTREE_W)
  f:SetHeight(LTREE_H)
  f.head:SetHeight(LHEAD - 1)
  f.emb = ltex(f.head, "ARTWORK", 1, def.color, 1, true); f.emb:SetSize(18, 18); f.emb:SetPoint("TOP", 0, -7)
  f.title = U.font(f.head, "GameFontNormal", C.gold, "CENTER"); f.title:SetPoint("TOP", 0, -27)
  f.count = U.font(f.head, "GameFontHighlightSmall", C.muted, "CENTER"); f.count:SetPoint("TOP", 0, -42)
  -- Requisitos: flecha horizontal de la ventaja que se pide a la que la pide (siempre en la misma fila).
  local byEn = {}
  for _, pk in ipairs(def.perks) do if pk.en then byEn[pk.en] = pk end end
  for _, pk in ipairs(def.perks) do
    local req = pk.req and byEn[pk.req]
    if req then
      local x1, y1 = lcellAt(req)
      local x2 = lcellAt(pk)
      local l = ltex(f, "ARTWORK", 2, C.btnLine)
      l:SetPoint("TOPLEFT", x1 + LCELL, y1 - LCELL / 2 + 1); l:SetSize(math.max(1, x2 - x1 - LCELL), 3)
      f.lines[#f.lines + 1] = { tex = l, from = req.en, to = pk.en }
    end
  end
  for n, pk in ipairs(def.perks) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(LCELL, LCELL)
    b:SetPoint("TOPLEFT", lcellAt(pk))
    b.pk, b.def = pk, def
    b.glow = ltex(b, "BACKGROUND", -8, { 1, 1, 1 }, 0.3, true); b.glow:SetPoint("TOPLEFT", -4, 4); b.glow:SetPoint("BOTTOMRIGHT", 4, -4)
    b.ring = ltex(b, "BORDER", 1, ST.none[1], 1, true); b.ring:SetAllPoints()
    b.inner = ltex(b, "BORDER", 2, CELLBG, 1, true); b.inner:SetPoint("TOPLEFT", 2, -2); b.inner:SetPoint("BOTTOMRIGHT", -2, 2)
    b.gl = ltex(b, "ARTWORK", 1, def.glyph, 1, true); b.gl:SetPoint("TOPLEFT", 6, -6); b.gl:SetPoint("BOTTOMRIGHT", -6, 6)
    b.icon = b:CreateTexture(nil, "ARTWORK", nil, 2); b.icon:SetPoint("TOPLEFT", 5, -5); b.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    if b.icon.SetMask then pcall(b.icon.SetMask, b.icon, MASK) end
    b.icon:Hide()
    if pk.gate then
      b.gate = nowrap(U.font(b, "GameFontHighlightSmall", C.muted, "CENTER")); b.gate:SetPoint("BOTTOM", b, "TOP", 0, 1)
      local font = b.gate.GetFont and b.gate:GetFont() -- más chico: dos vecinos con «5 en rama» y «10 en rama» no se pisan
      if font then b.gate:SetFont(font, 8, "") end
    end
    if not pk.reserved then
      b.badge = CreateFrame("Frame", nil, b)
      b.badge:SetSize(28, 14); b.badge:SetPoint("CENTER", b, "BOTTOM", 0, -1)
      if b.badge.SetFrameLevel then b.badge:SetFrameLevel((b:GetFrameLevel() or 1) + 2) end
      b.badge.o = ltex(b.badge, "ARTWORK", 1, C.btnLine, 1, true); b.badge.o:SetAllPoints()
      b.badge.i = ltex(b.badge, "ARTWORK", 2, DARK, 1, true); b.badge.i:SetPoint("TOPLEFT", 1, -1); b.badge.i:SetPoint("BOTTOMRIGHT", -1, 1)
      b.rank = b.badge:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); b.rank:SetPoint("CENTER", 0, 0)
    else
      tint(b.ring, C.btnLine, 0.6); tint(b.inner, BOARD); b.gl:Hide(); b.glow:Hide()
    end
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local tname = lang() == "en" and self.def.en or self.def.es
      if self.pk.reserved then GameTooltip:AddLine(T("lgReserved"), 0.54, 0.56, 0.62); GameTooltip:Show(); return end
      local c = self.c or {}
      GameTooltip:AddLine(c.name or self.pk.en, 1, 1, 1)
      GameTooltip:AddLine(tname .. " · " .. T("lgRank"):format(c.have and tostring(c.have) or "?", self.pk.max), 0.54, 0.56, 0.62)
      if self.pk.gate then GameTooltip:AddLine(T("lgGateTip"):format(self.pk.gate), 0.54, 0.56, 0.62) end
      if self.pk.req then GameTooltip:AddLine(T("lgReqTip"):format(self.reqName or self.pk.req), 0.54, 0.56, 0.62) end
      if (c.want or 0) > 0 then GameTooltip:AddLine(T("planRank"):format(c.want, self.pk.max), 0.95, 0.76, 0.31)
      else GameTooltip:AddLine(T("notPlanned"), 0.54, 0.56, 0.62) end
      if self.isNext then GameTooltip:AddLine(T("nextTip"), 1, 1, 1) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.cells[n] = b
  end
  g.trees[i] = f
  return f
end

local function spellIcon(n)
  for id in pairs(n and n.spells or {}) do
    if id ~= 0 then
      local t = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id))
      if t then return t end
    end
  end
  return nil
end

-- Dibuja las tres verticales en pw.lgrid; devuelve el alto.
local function drawLegacyTrees(info)
  local g = pw.lgrid
  local C = ns.ui.C
  local x0 = math.max(0, math.floor((CW - (3 * LTREE_W + 2 * GAP)) / 2))
  local nextC = info.next
  for ti, tr in ipairs(info.trees) do
    local f = legacyTree(ti)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", x0 + (ti - 1) * (LTREE_W + GAP), 0); f:Show()
    f.title:SetText(lang() == "en" and tr.def.en or tr.def.es)
    local spent = info.found > 0 and tostring(tr.spent) or "?"
    f.count:SetText(T("lgTree"):format(((tr.planned > 0 and tr.spent >= tr.planned) and GREEN or ORANGE) .. spent .. "|r", tr.planned))
    for _, l in ipairs(f.lines) do
      local a, b = tr.byEn[l.from], tr.byEn[l.to]
      tint(l.tex, (a and b and a.want > 0 and b.want > 0) and C.action or C.btnLine)
    end
    for n, c in ipairs(tr.cells) do
      local b = f.cells[n]
      b.c = c
      if b.gate then b.gate:SetText(T("gate"):format(c.pk.gate)) end
      if not c.pk.reserved then
        local isNext = c == nextC
        local st = stateOf(c.have or 0, c.want)
        b.isNext = isNext
        b.reqName = c.pk.req and tr.byEn[c.pk.req] and tr.byEn[c.pk.req].name or nil
        tint(b.ring, ST[isNext and "next" or st][1])
        b.glow:SetShown(isNext)
        b.gl:SetAlpha(st == "none" and 0.25 or ((c.have or 0) > 0 and 1 or 0.5))
        local icon = c.have and spellIcon(c.node)
        if icon then b.icon:SetTexture(icon); b.icon:Show(); b.icon:SetAlpha(st == "none" and 0.35 or 1) else b.icon:Hide() end
        b.rank:SetText((c.have and tostring(c.have) or "?") .. "/" .. (c.want > 0 and c.want or c.pk.max))
        color(b.rank, ST[st][2])
      end
    end
  end
  g:SetSize(CW, LTREE_H); g:Show()
  return LTREE_H
end

-- ── Piezas de la ventana ─────────────────────────────────────────────────────────────────────────
local function newCard(parent)
  local U, C = ns.ui, ns.ui.C
  local f = CreateFrame("Frame", nil, parent)
  U.fill(f, C.sub, 1); U.edge(f, C.line, 1)
  f.lbl = U.label(f, ""); f.lbl:SetPoint("TOPLEFT", 10, -9)
  return f
end
local function setLbl(fs, text) fs:SetText((text or ""):upper()) end

-- Tarjeta con un número grande, el detalle al lado y una barra.
local function statCard(parent, w)
  local U, C = ns.ui, ns.ui.C
  local f = newCard(parent); f:SetSize(w, 66)
  f.w = w
  f.big = U.font(f, "GameFontNormalLarge", C.text, "LEFT"); f.big:SetPoint("TOPLEFT", 10, -24)
  f.small = nowrap(U.font(f, "GameFontHighlightSmall", C.muted, "LEFT")); f.small:SetPoint("LEFT", f.big, "RIGHT", 5, 0)
  f.bar = U.bar(f, w - 20, 8); f.bar:SetPoint("BOTTOMLEFT", 10, 10)
  function f.Set(self, big, small, frac, c)
    self.big:SetText(tostring(big or ""))
    self.small:SetText(small or "")
    self.small:SetWidth(math.max(20, self.w - 25 - tw(self.big)))
    self.bar:SetValue(frac or 0, c)
  end
  return f
end

-- Fila nombre · barra · valor.
local BAR_NAME, BAR_VAL = 110, 80
local function barRow(parent)
  local U, C = ns.ui, ns.ui.C
  local r = CreateFrame("Frame", nil, parent); r:SetHeight(18)
  r.name = nowrap(U.font(r, "GameFontHighlightSmall", C.text, "LEFT")); r.name:SetPoint("LEFT", 0, 0); r.name:SetWidth(BAR_NAME)
  r.val = nowrap(U.font(r, "GameFontHighlightSmall", C.muted, "RIGHT")); r.val:SetPoint("RIGHT", 0, 0); r.val:SetWidth(BAR_VAL)
  r.bar = U.bar(r, CW - 20 - BAR_NAME - BAR_VAL - 16, 8); r.bar:SetPoint("LEFT", BAR_NAME + 8, 0)
  return r
end

-- Franja de arriba de Talentos y Legado: número grande, detalle, barra, el próximo y (a la derecha) lo de fuera del plan.
local function strip(parent)
  local U, C = ns.ui, ns.ui.C
  local f = CreateFrame("Frame", nil, parent); f:SetSize(CW, 34)
  U.fill(f, C.sub, 1); U.edge(f, C.line, 1)
  f.big = U.font(f, "GameFontNormalLarge", C.text, "LEFT"); f.big:SetPoint("LEFT", 10, 0)
  f.small = nowrap(U.font(f, "GameFontHighlightSmall", C.muted, "LEFT")); f.small:SetPoint("LEFT", f.big, "RIGHT", 5, 0)
  f.bar = U.bar(f, 120, 6)
  f.right = nowrap(U.font(f, "GameFontHighlightSmall", C.red, "RIGHT")); f.right:SetPoint("RIGHT", -10, 0)
  f.next = nowrap(U.font(f, "GameFontHighlightSmall", C.text, "LEFT"))
  function f.Set(self, big, small, frac, nextText, right)
    self.big:SetText(tostring(big or "")); self.small:SetText(small or ""); self.right:SetText(right or "")
    self.small:SetWidth(math.max(20, math.min(260, tw(self.small) + 2)))
    local x = 10 + tw(self.big) + 5 + tw(self.small) + 12
    self.bar:ClearAllPoints(); self.bar:SetPoint("LEFT", x, 0); self.bar:SetValue(frac or 0)
    self.next:ClearAllPoints(); self.next:SetPoint("LEFT", x + 132, 0)
    self.next:SetWidth(math.max(40, CW - x - 132 - 20 - tw(self.right)))
    self.next:SetText(nextText or "")
  end
  return f
end

-- Leyenda de colores (cuadrada para talentos, redonda para el Legado); se acomoda en filas.
local function legend(parent, round)
  local U, C = ns.ui, ns.ui.C
  local f = CreateFrame("Frame", nil, parent); f:SetWidth(CW)
  U.fill(f, C.sub, 1); U.edge(f, C.line, 1)
  f.items = {}
  function f.Set(self, list)
    local x, y, rowH = 10, -9, 16
    for i, it in ipairs(list) do
      local e = self.items[i]
      if not e then
        e = {}
        e.o = ltex(self, "ARTWORK", 1, C.line, 1, round); e.o:SetSize(12, 12)
        e.i = ltex(self, "ARTWORK", 2, CELLBG, 1, round); e.i:SetSize(8, 8); e.i:SetPoint("CENTER", e.o, "CENTER", 0, 0)
        e.fs = nowrap(U.font(self, "GameFontHighlightSmall", C.muted, "LEFT"))
        self.items[i] = e
      end
      e.fs:SetText(it[2])
      local sw = it[1] and 17 or 0
      local w = sw + math.ceil(tw(e.fs)) + 14
      if x + w > CW - 10 and x > 10 then x = 10; y = y - rowH end
      e.o:SetShown(it[1] ~= nil); e.i:SetShown(it[1] ~= nil)
      if it[1] then tint(e.o, it[1]); e.o:ClearAllPoints(); e.o:SetPoint("TOPLEFT", x, y - 1) end
      e.fs:ClearAllPoints(); e.fs:SetPoint("TOPLEFT", x + sw, y)
      e.fs:Show()
      x = x + w
    end
    for k = #list + 1, #self.items do local e = self.items[k]; e.o:Hide(); e.i:Hide(); e.fs:Hide() end
    local h = -y + rowH + 4
    self:SetHeight(h)
    return h
  end
  return f
end

-- ── Pestañas ─────────────────────────────────────────────────────────────────────────────────────
local function showBody(y, text)
  pw.body:ClearAllPoints(); pw.body:SetPoint("TOPLEFT", pw.child, "TOPLEFT", 2, y)
  pw.body:SetText(text or "")
  return -y + th(pw.body) + 8
end

local refresh
-- Filtro de la lista de materiales del resumen (queda guardado).
local function matsState()
  local d = ns.db and ns.db()
  d.ui = d.ui or {}
  d.ui.planMats = d.ui.planMats or {}
  return d.ui.planMats
end
-- Lo que falta de una profesión desde el nivel actual: los pasos que terminan arriba de tu nivel, con
-- los componentes del catálogo (Professions.lua) por las veces de cada paso; del paso en el que estás,
-- la parte que queda. nil si alguna receta no está en el catálogo (entonces va el total de la ruta).
local function remainingMats(x)
  if not ns.catalogReagents then return nil end
  local rank = x.rank or 0
  local totals, order = {}, {}
  for _, st in ipairs(x.prof.steps) do
    if st.to > rank then
      local reag = ns.catalogReagents(x.prof.key, st.spell)
      if not reag then return nil end
      local crafts = st.crafts
      if rank > st.from and st.to > st.from then crafts = math.ceil(st.crafts * (st.to - rank) / (st.to - st.from)) end
      for _, g in ipairs(reag) do
        if not totals[g.item] then totals[g.item] = 0; order[#order + 1] = g.item end
        totals[g.item] = totals[g.item] + g.count * crafts
      end
    end
  end
  local names = {}
  for _, m in ipairs(x.prof.mats) do names[m.item] = m.name end
  local out = {}
  for _, id in ipairs(order) do
    out[#out + 1] = { item = id, count = totals[id], name = names[id] or (ns.catalogItemName and ns.catalogItemName(id)) or ("#" .. id) }
  end
  return out
end

ns._planRemaining = function(x) return remainingMats(x) end

local function drawSummary(p, pr)
  local s = pw.sum
  local C = ns.ui.C
  s:Show()
  local y = 0
  local w3 = math.floor((CW - 20) / 3)
  s.lvl:ClearAllPoints(); s.lvl:SetPoint("TOPLEFT", 0, y)
  setLbl(s.lvl.lbl, T("level")); s.lvl:Set(pr.level, "/ 60", pr.level / 60, BLUE)
  s.tal:ClearAllPoints(); s.tal:SetPoint("TOPLEFT", w3 + 10, y)
  setLbl(s.tal.lbl, T("tTalents"))
  if pr.tal then
    local nx = pr.tal.next and (" · " .. T("nextShort"):format(pr.tal.next.t.name, pr.tal.next.have, pr.tal.next.t.rank)) or ""
    s.tal:Set(pr.tal.matched, "/ " .. pr.tal.planned .. nx, pr.tal.planned > 0 and pr.tal.matched / pr.tal.planned or 0, C.green)
  else s.tal:Set("—", T("noTalents"), 0) end
  s.leg:ClearAllPoints(); s.leg:SetPoint("TOPLEFT", 2 * (w3 + 10), y)
  setLbl(s.leg.lbl, T("tLegacy"))
  if #p.legacy > 0 then
    local li = legacyInfo(p)
    s.leg:Set(li.found > 0 and li.spent or "?", T("lgCard"):format(li.planned), li.planned > 0 and li.matched / li.planned or 0, C.gold)
  else s.leg:Set("—", T("noLegacy"), 0) end
  y = y - 66 - 10

  -- Profesiones: habilidad de cada una y el paso de la ruta en el que estás.
  local c = s.prof
  if #pr.profs > 0 then
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, y); c:SetWidth(CW); c:Show()
    setLbl(c.lbl, T("tProf"))
    local ry = -28
    for i, x in ipairs(pr.profs) do
      local r = pool(c.rows, i, function() return barRow(c) end)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, ry); r:SetPoint("TOPRIGHT", -10, ry)
      r.name:SetText(x.prof.name)
      r.val:SetText(x.rank and (x.rank .. "/" .. (x.max or 300)) or T("notLearned"))
      r.bar:SetValue((x.rank or 0) / 300, PURPLE)
      ry = ry - 22
    end
    hideFrom(c.rows, #pr.profs + 1)
    local nn = 0
    for _, x in ipairs(pr.profs) do
      local st = x.step and x.prof.steps[x.step]
      if st then
        nn = nn + 1
        if nn == 1 then c.sep:ClearAllPoints(); c.sep:SetPoint("TOPLEFT", 10, ry - 2); c.sep:SetPoint("TOPRIGHT", -10, ry - 2); c.sep:Show(); ry = ry - 8 end
        local fs = c.now[nn]
        if not fs then fs = nowrap(ns.ui.font(c, "GameFontHighlightSmall", C.text, "LEFT")); fs:SetWidth(CW - 20); c.now[nn] = fs end
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 10, ry); fs:Show()
        fs:SetText(GOLD .. T("now") .. "|r  " .. GRAY .. x.prof.name .. ":|r " .. st.name .. GRAY .. "  ×" .. st.crafts .. " · " .. st.from .. "→" .. st.to .. "|r")
        ry = ry - 16
      end
    end
    if nn == 0 then c.sep:Hide() end
    for k = nn + 1, #c.now do c.now[k]:Hide() end
    c:SetHeight(-ry + 8)
    y = y - (-ry + 8) - 10
  else c:Hide() end

  -- Materiales (bolsas + banco), con el ícono del ítem y lo que tenés contra lo que pide. Filtro por
  -- profesión y «Solo lo que falta» (sin los niveles que ya pasaste, con los componentes del catálogo).
  c = s.mats
  local ms = matsState()
  local withMats = {}
  for _, x in ipairs(pr.profs) do if #x.prof.mats > 0 then withMats[#withMats + 1] = x end end
  if ms.prof then
    local ok = false
    for _, x in ipairs(withMats) do if x.prof.key == ms.prof then ok = true end end
    if not ok then ms.prof = nil end
  end
  local mats, noCat = {}, {}
  for _, x in ipairs(withMats) do
    if not ms.prof or ms.prof == x.prof.key then
      local list = ms.left and remainingMats(x) or nil
      if ms.left and not list then noCat[#noCat + 1] = x.prof.name end
      for _, m in ipairs(list or x.prof.mats) do mats[#mats + 1] = m end
    end
  end
  if #withMats > 0 then
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, y); c:SetWidth(CW); c:Show()
    setLbl(c.lbl, T(ms.left and "matsLeftTitle" or "mats"))
    -- Botones: Todas, una por profesión y, a la derecha, «Solo lo que falta».
    local chips = { { key = nil, label = T("matsAll") } }
    for _, x in ipairs(withMats) do chips[#chips + 1] = { key = x.prof.key, label = x.prof.name } end
    c.chips = c.chips or {}
    local prev
    for i, ch in ipairs(chips) do
      local b = pool(c.chips, i, function() return ns.ui.button(c, "", "off", nil, { h = 20 }) end)
      b:SetScript("OnClick", function() matsState().prof = ch.key; refresh() end)
      b:SetKind(ms.prof == ch.key and "on" or "off"); b:SetLabel(ch.label)
      b:ClearAllPoints()
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 10, -26) end
      prev = b
    end
    hideFrom(c.chips, #chips + 1)
    if not c.left then c.left = ns.ui.button(c, "", "off", function() matsState().left = not matsState().left; refresh() end, { h = 20 }) end
    c.left:SetKind(ms.left and "on" or "off"); c.left:SetLabel((ms.left and ns.ui.ICON.check or "") .. T("matsLeft")); c.left.tip = T("matsLeftTip")
    c.left:ClearAllPoints(); c.left:SetPoint("TOPRIGHT", -10, -26)
    c.note = c.note or nowrap(ns.ui.font(c, "GameFontHighlightSmall", C.muted, "LEFT"))
    local top = -54
    local note = #noCat > 0 and T("matsNoCat"):format(table.concat(noCat, ", ")) or (#mats == 0 and T("matsNone")) or nil
    c.note:SetShown(note ~= nil)
    if note then c.note:ClearAllPoints(); c.note:SetPoint("TOPLEFT", 10, top); c.note:SetWidth(CW - 20); c.note:SetText(note); top = top - 18 end
    local ready = 0
    local mw = math.floor((CW - 20) / 3)
    for i, m in ipairs(mats) do
      local it = pool(c.items, i, function()
        local f = CreateFrame("Frame", nil, c); f:SetSize(mw, 30)
        f.icon = ns.ui.icon(f, 26); f.icon:SetPoint("LEFT", 0, 0)
        f.name = nowrap(ns.ui.font(f, "GameFontHighlightSmall", C.text, "LEFT")); f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, -1); f.name:SetWidth(mw - 40)
        f.cnt = ns.ui.font(f, "GameFontHighlightSmall", C.green, "LEFT"); f.cnt:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 6, 1)
        return f
      end)
      local have = GetItemCount and GetItemCount(m.item, true) or 0
      if have >= m.count then ready = ready + 1 end
      it:ClearAllPoints(); it:SetPoint("TOPLEFT", 10 + ((i - 1) % 3) * mw, top - math.floor((i - 1) / 3) * 36)
      it.icon:SetItem(m.item > 0 and m.item or nil, m.count)
      it.name:SetText(m.name)
      it.cnt:SetText(have .. " / " .. m.count); color(it.cnt, have >= m.count and C.green or C.red)
    end
    hideFrom(c.items, #mats + 1)
    c.right:SetText(T("matsReady"):format(ready, #mats))
    local hh = -top + math.ceil(#mats / 3) * 36 + 4
    c:SetHeight(hh)
    y = y - hh - 10
  else c:Hide() end

  -- Talentos por rama.
  c = s.trees
  if pr.tal and #p.talents > 0 then
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, y); c:SetWidth(CW); c:Show()
    setLbl(c.lbl, T("byTree"))
    c.see:SetLabel(T("seeTree"))
    local per, order = {}, {}
    for _, t in ipairs(p.talents) do
      local e = per[t.tree]
      if not e then e = { planned = 0, matched = 0, tree = t.tree }; per[t.tree] = e; order[#order + 1] = e end
      local h = haveOf(pr.tal.state, t)
      e.planned, e.matched = e.planned + t.rank, e.matched + math.min(h, t.rank)
    end
    table.sort(order, function(a, b) return a.tree < b.tree end)
    local ry = -30
    for i, e in ipairs(order) do
      local r = pool(c.rows, i, function() return barRow(c) end)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, ry); r:SetPoint("TOPRIGHT", -10, ry)
      r.name:SetText(p.trees[e.tree + 1] or ("#" .. e.tree))
      r.val:SetText(e.matched .. "/" .. e.planned)
      r.bar:SetValue(e.planned > 0 and e.matched / e.planned or 0, e.matched >= e.planned and C.green or C.gold)
      ry = ry - 22
    end
    hideFrom(c.rows, #order + 1)
    c:SetHeight(-ry + 6)
    y = y - (-ry + 6) - 10
  else c:Hide() end

  -- Notas.
  c = s.notes
  if p.notes ~= "" then
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, y); c:SetWidth(CW); c:Show()
    setLbl(c.lbl, T("notes"))
    c.text:SetText(p.notes)
    local hh = 30 + math.max(14, th(c.text)) + 8
    c:SetHeight(hh)
    y = y - hh - 10
  else c:Hide() end
  return -y
end

local function talentLegend()
  return { { ST.done[1], T("lgDoneL") }, { ST.part[1], T("lgPart") }, { ST.todo[1], T("lgTodo") }, { ST.off[1], T("lgOff") },
    { ST.next[1], T("lgNextL") }, { ST.none[1], T("lgNone") } }
end

local function drawTalentTab(p, pr)
  if #p.talents == 0 then return showBody(0, GRAY .. T("noTalents") .. "|r") end
  local s = pw.tstrip
  s:Show()
  local nx = pr.tal.next and (GRAY .. T("next"):format(WHITE_C .. pr.tal.next.t.name .. GRAY, pr.tal.next.have, pr.tal.next.t.rank) .. "|r")
    or (pr.tal.matched >= pr.tal.planned and (ns.ui.ICON.check .. GREEN .. T("buildDone") .. "|r")) or ""
  s:Set(pr.tal.matched, T("spentOf"):format(pr.tal.planned, pr.tal.spent), pr.tal.planned > 0 and pr.tal.matched / pr.tal.planned or 0,
    nx, pr.tal.off > 0 and T("off"):format(pr.tal.off) or "")
  local y = -44
  if canDraw(p) then
    pw.grid:ClearAllPoints(); pw.grid:SetPoint("TOPLEFT", pw.child, "TOPLEFT", 0, y)
    y = y - drawTalents(p) - 10
    local lg = pw.tlegend
    lg:ClearAllPoints(); lg:SetPoint("TOPLEFT", pw.child, "TOPLEFT", 0, y); lg:Show()
    y = y - lg:Set(talentLegend())
    return -y
  end
  return showBody(y, table.concat(talentLines(p, pr), "\n"))
end

local function drawLegacyTab(p)
  local info = legacyInfo(p)
  local s = pw.lstrip
  s:Show()
  local nx = ""
  if #p.legacy == 0 then nx = GRAY .. T("noLegacy") .. "|r"
  elseif info.next then nx = GRAY .. T("lgNext"):format(WHITE_C .. info.next.name .. GRAY, info.next.have or 0, info.next.want) .. "|r"
  elseif info.found > 0 and info.matched >= info.planned then nx = ns.ui.ICON.check .. GREEN .. T("lgDone") .. "|r" end
  s:Set(info.found > 0 and info.spent or "?", T("lgTotal"):format(info.planned),
    info.planned > 0 and info.matched / info.planned or info.spent / 16, nx, "")
  local y = -44
  pw.lgrid:ClearAllPoints(); pw.lgrid:SetPoint("TOPLEFT", pw.child, "TOPLEFT", 0, y)
  y = y - drawLegacyTrees(info) - 10
  local lg = pw.llegend
  lg:ClearAllPoints(); lg:SetPoint("TOPLEFT", pw.child, "TOPLEFT", 0, y); lg:Show()
  local items = talentLegend()
  items[#items + 1] = { ns.ui.C.btnLine, T("lgReserved") }
  items[#items + 1] = { nil, T("lgGateL") }
  y = y - lg:Set(items) - 8
  local out = {}
  if #info.extra > 0 then
    out[#out + 1] = GOLD .. T("lgOther") .. "|r"
    for _, e in ipairs(info.extra) do
      local h = e.have
      out[#out + 1] = "  " .. (h and (h >= e.l.rank and GREEN or h > 0 and ORANGE or GRAY) or GRAY) .. (h or "?") .. "/" .. e.l.rank .. "|r  " .. e.l.name .. (e.l.tree ~= "" and (GRAY .. " · " .. e.l.tree .. "|r") or "")
    end
  end
  if #p.legacy > 0 and info.found == 0 then
    if #out > 0 then out[#out + 1] = "" end
    out[#out + 1] = GRAY .. T("legacyNote") .. "|r"
  end
  if #out == 0 then return -y end
  return showBody(y, table.concat(out, "\n"))
end

ns._planTraits = { state = function() return talentState() end, legacy = function(st) return legacyNodes(st) end, nodeFor = function(...) return nodeFor(...) end }
ns._planDraw = { trees = talentTrees, draw = function(p) return drawTalents(p) end, canDraw = function(p) return canDraw(p) end, grid = function() return pw and pw.grid end,
  legacy = function(p) return legacyInfo(p) end, legacyLayout = LEGACY }

-- Cabecera del personaje.
local function drawHero(p, pr)
  local h = pw.hero
  if not p then h:Hide(); return end
  h:Show()
  local token = (p.cls or ""):upper()
  local cname = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or p.cls
  local cc = ns.ui.classColor(token)
  tint(h.dot, cc)
  h.name:SetText(p.name .. (p.main and ("  " .. ns.ui.ICON.star .. GOLD .. " " .. T("main") .. "|r") or ""))
  color(h.name, cc)
  h.sub:SetText(p.race .. " · " .. cname .. " · " .. T(p.source == "app" and "fromApp" or "pasted"))
  h.other:SetText(not isMine(p) and T("other"):format(p.name .. (p.realm ~= "" and ("-" .. p.realm) or "")) or "")
  h.pct:SetText(pr.pct .. " %")
  h.of:SetText(T("ofPlan"))
  h.bar:SetValue(pr.pct / 100, ns.ui.C.gold)
end

function refresh()
  if not pw then return end
  local list = allPlans()
  if sel and not list[sel] then sel = nil end
  if not sel then for i, p in ipairs(list) do if isMine(p) then sel = i; break end end end
  if not sel and #list > 0 then sel = 1 end
  local multi = #list > 1
  pw.title:SetText(T("title"))
  pw.count:SetText(multi and (sel .. " / " .. #list) or "")
  pw.title:ClearAllPoints()
  if multi then pw.title:SetPoint("LEFT", pw.next, "RIGHT", 8, 0) else pw.title:SetPoint("LEFT", pw.header, "LEFT", 12, 0) end
  pw.prev:SetShown(multi); pw.next:SetShown(multi)
  local labels = { summary = T("tSummary"), prof = T("tProf"), talents = T("tTalents"), legacy = T("tLegacy") }
  pw.tabs:Update(tab, nil, nil, labels)
  for _, b in ipairs(pw.tabs.items) do b.text = labels[b.key] end -- (para las pruebas: el texto de la pestaña)
  pw.pasteBtn:SetLabel(T("paste")); pw.read:SetLabel(T("read")); pw.clear:SetLabel(T("clear")); pw.hint:SetText(T("pasteHint"))
  pw.read:SetShown(pw.paste:IsShown() and true or false)
  local p = list[sel or 0]
  local pr = p and progress(p)
  drawHero(p, pr)
  pw.sum:Hide(); pw.grid:Hide(); pw.lgrid:Hide(); pw.tstrip:Hide(); pw.lstrip:Hide(); pw.tlegend:Hide(); pw.llegend:Hide()
  pw.body:SetText("")
  local h
  if not p then h = showBody(-4, T("none") .. "\n\n" .. GRAY .. T("noneHint") .. "|r")
  elseif tab == "summary" then h = drawSummary(p, pr)
  elseif tab == "prof" then h = showBody(0, table.concat(profLines(pr), "\n"))
  elseif tab == "talents" then h = drawTalentTab(p, pr)
  else h = drawLegacyTab(p) end
  pw.child:SetHeight(math.max(1, h or 1))
end
ns.planRefresh = refresh

local function create()
  local U, C = ns.ui, ns.ui.C
  pw = U.window("RebirthTrackPlanFrame", W, H, T("title"))
  pw.prev = U.iconButton(pw.header, 22, "‹", function() local n = #allPlans(); if n > 0 then sel = ((sel or 1) - 2) % n + 1 end; refresh() end)
  pw.prev:SetPoint("LEFT", 6, 0)
  pw.next = U.iconButton(pw.header, 22, "›", function() local n = #allPlans(); if n > 0 then sel = (sel or 1) % n + 1 end; refresh() end)
  pw.next:SetPoint("LEFT", pw.prev, "RIGHT", 2, 0)
  pw.count = U.font(pw.header, "GameFontHighlightSmall", C.muted, "LEFT"); pw.count:SetPoint("LEFT", pw.title, "RIGHT", 8, 0)

  -- Cabecera del personaje: punto del color de la clase, nombre, raza · clase · origen y el % del plan.
  local hero = CreateFrame("Frame", nil, pw)
  hero:SetPoint("TOPLEFT", 1, pw.top); hero:SetPoint("TOPRIGHT", -1, pw.top); hero:SetHeight(HERO_H)
  hero.ring = ltex(hero, "ARTWORK", 1, C.border, 1, true); hero.ring:SetSize(42, 42); hero.ring:SetPoint("LEFT", 12, 0)
  hero.dot = ltex(hero, "ARTWORK", 2, C.text, 1, true); hero.dot:SetSize(36, 36); hero.dot:SetPoint("CENTER", hero.ring, "CENTER", 0, 0)
  hero.name = nowrap(U.font(hero, "GameFontNormalLarge", C.text, "LEFT")); hero.name:SetPoint("TOPLEFT", 66, -10); hero.name:SetWidth(W - 66 - 200)
  hero.sub = nowrap(U.font(hero, "GameFontHighlightSmall", C.muted, "LEFT")); hero.sub:SetPoint("TOPLEFT", hero.name, "BOTTOMLEFT", 0, -3); hero.sub:SetWidth(W - 66 - 200)
  hero.other = nowrap(U.font(hero, "GameFontHighlightSmall", C.amber, "LEFT")); hero.other:SetPoint("TOPLEFT", hero.sub, "BOTTOMLEFT", 0, -2); hero.other:SetWidth(W - 66 - 200)
  hero.of = U.font(hero, "GameFontHighlightSmall", C.muted, "RIGHT"); hero.of:SetPoint("TOPRIGHT", -14, -14)
  hero.pct = U.font(hero, "GameFontNormalLarge", C.gold, "RIGHT"); hero.pct:SetPoint("RIGHT", hero.of, "LEFT", -5, 0)
  hero.bar = U.bar(hero, 150, 8); hero.bar:SetPoint("TOPRIGHT", -14, -36)
  pw.hero = hero

  pw.tabs = U.tabs(pw, pw.top - HERO_H, { { "summary", T("tSummary") }, { "prof", T("tProf") }, { "talents", T("tTalents") }, { "legacy", T("tLegacy") } },
    function(k) tab = k; refresh() end)

  local ft = U.footer(pw, 36)
  pw.scroll = CreateFrame("ScrollFrame", "RebirthTrackPlanScroll", pw, "UIPanelScrollFrameTemplate")
  pw.scroll:SetPoint("TOPLEFT", 12, pw.top - HERO_H - 30 - 10); pw.scroll:SetPoint("BOTTOMRIGHT", -30, 36 + 8)
  pw.child = CreateFrame("Frame", nil, pw.scroll); pw.child:SetSize(CW, 1)
  pw.scroll:SetScrollChild(pw.child)
  pw.body = U.font(pw.child, "GameFontHighlightSmall", C.text, "LEFT")
  pw.body:SetPoint("TOPLEFT", 2, 0); pw.body:SetWidth(CW - 4)
  if pw.body.SetJustifyV then pw.body:SetJustifyV("TOP") end
  if pw.body.SetSpacing then pw.body:SetSpacing(2) end

  -- Resumen: tarjetas.
  local s = CreateFrame("Frame", nil, pw.child); s:SetPoint("TOPLEFT", 0, 0); s:SetSize(CW, 1); s:Hide()
  local w3 = math.floor((CW - 20) / 3)
  s.lvl, s.tal, s.leg = statCard(s, w3), statCard(s, w3), statCard(s, w3)
  s.prof = newCard(s); s.prof.rows, s.prof.now = {}, {}
  s.prof.sep = U.tex(s.prof, "ARTWORK", { 0.122, 0.137, 0.173 }); s.prof.sep:SetHeight(1)
  s.mats = newCard(s); s.mats.items = {}
  s.mats.right = U.font(s.mats, "GameFontHighlightSmall", C.muted, "RIGHT"); s.mats.right:SetPoint("TOPRIGHT", -10, -9)
  s.trees = newCard(s); s.trees.rows = {}
  s.trees.see = U.button(s.trees, T("seeTree"), nil, function() tab = "talents"; refresh() end, { h = 20 })
  s.trees.see:SetPoint("TOPRIGHT", -6, -5)
  s.notes = newCard(s)
  s.notes.text = U.font(s.notes, "GameFontHighlightSmall", C.text, "LEFT"); s.notes.text:SetPoint("TOPLEFT", 10, -28); s.notes.text:SetWidth(CW - 20)
  pw.sum = s

  -- Talentos y Legado.
  pw.tstrip = strip(pw.child); pw.tstrip:SetPoint("TOPLEFT", 0, 0); pw.tstrip:Hide()
  pw.lstrip = strip(pw.child); pw.lstrip:SetPoint("TOPLEFT", 0, 0); pw.lstrip:Hide()
  pw.grid = CreateFrame("Frame", nil, pw.child); pw.grid:Hide()
  pw.lgrid = CreateFrame("Frame", nil, pw.child); pw.lgrid.trees = {}; pw.lgrid:Hide()
  pw.tlegend = legend(pw.child, false); pw.tlegend:Hide()
  pw.llegend = legend(pw.child, true); pw.llegend:Hide()

  -- Pegar: un cuadro de varias líneas (el plan trae una línea por dato), encima del contenido.
  pw.paste = CreateFrame("Frame", nil, pw)
  pw.paste:SetPoint("TOPLEFT", 1, pw.top); pw.paste:SetPoint("BOTTOMRIGHT", -1, 37)
  pw.paste:SetFrameLevel((pw:GetFrameLevel() or 1) + 20); pw.paste:EnableMouse(true); pw.paste:Hide()
  U.fill(pw.paste, C.bg, 1)
  pw.hint = U.font(pw.paste, "GameFontHighlightSmall", C.text, "LEFT"); pw.hint:SetPoint("TOPLEFT", 12, -12); pw.hint:SetPoint("TOPRIGHT", -12, -12)
  local box = CreateFrame("Frame", nil, pw.paste)
  box:SetPoint("TOPLEFT", 12, -32); box:SetPoint("BOTTOMRIGHT", -12, 10)
  U.fill(box, C.input, 1); U.edge(box, C.btnLine, 1)
  local ps = CreateFrame("ScrollFrame", "RebirthTrackPlanPasteScroll", box, "UIPanelScrollFrameTemplate")
  ps:SetPoint("TOPLEFT", 8, -8); ps:SetPoint("BOTTOMRIGHT", -28, 8)
  pw.edit = CreateFrame("EditBox", nil, ps); pw.edit:SetMultiLine(true); pw.edit:SetAutoFocus(false); pw.edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall); pw.edit:SetWidth(W - 24 - 44)
  if pw.edit.SetMaxLetters then pw.edit:SetMaxLetters(0) end
  pw.edit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  ps:SetScrollChild(pw.edit)

  pw.pasteBtn = U.button(ft, T("paste"), nil, function()
    if pw.paste:IsShown() then pw.paste:Hide() else pw.edit:SetText(""); pw.paste:Show(); pw.edit:SetFocus() end
    pw.read:SetShown(pw.paste:IsShown() and true or false)
  end)
  pw.pasteBtn:SetPoint("LEFT", 10, 0)
  pw.read = U.button(ft, T("read"), "pri", function()
    if load(pw.edit:GetText() or "") > 0 then pw.paste:Hide(); sel = nil end
    refresh()
  end)
  pw.read:SetPoint("LEFT", pw.pasteBtn, "RIGHT", 6, 0); pw.read:Hide()
  pw.clear = U.button(ft, T("clear"), "dng", function() ns.db().plans = {}; sel = nil; say(T("cleared")); refresh() end)
  pw.clear:SetPoint("RIGHT", -10, 0)
  pw:RegisterEvent("SKILL_LINES_CHANGED"); pw:RegisterEvent("CHARACTER_POINTS_CHANGED"); pw:RegisterEvent("BAG_UPDATE_DELAYED"); pw:RegisterEvent("PLAYER_LEVEL_UP")
  pw:SetScript("OnEvent", function() if pw:IsShown() then refresh() end end)
end

-- /rt plan: abre la ventana (con texto pegado después del comando, lo lee primero).
function ns.openPlan(text)
  if not pw then create() end
  if text and text ~= "" then load(text) end
  pw:Show()
  refresh()
end
