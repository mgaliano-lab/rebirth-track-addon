-- Rebirth Track · Profesiones de la guild (/rt profesiones)
-- Lo mismo que /profesiones del sitio, dentro del juego. Dos pestañas:
--   · Por profesión: quién la tiene, con su barra de habilidad, cuántas recetas sabe y el cooldown.
--   · Recetas de la guild: todas las recetas de la profesión (las que no sabe nadie, en gris), con
--     buscador, orden, nivel, personajes y «Solo adquiridas»; al elegir una, su detalle (nivel que
--     pide, colores, componentes, cómo se consigue y quién la sabe hacer).
-- «Requeridos» abre los pedidos de materiales (Requests.lua). Clic derecho en un nombre: susurrar,
-- invitar al grupo o copiar el nombre.
--
-- Quién sabe qué sale de lo que anota cada addon y viaja por el canal de la guild (Collect.lua: p1,
-- sk1, r1:<profesión>, cd1:<profesión>), así anda aunque nadie abra la web. El catálogo (todas las
-- recetas, nivel, colores, componentes y cómo se consiguen) lo escribe la app en Plans.lua
-- (RebirthTrackCatalog, del sitio: shared/addonCatalog.ts). Sin catálogo se listan solo las que sabe
-- alguien, con el nombre y el icono que da el juego. Las listas mezcladas de versiones viejas del addon
-- se limpian como en el sitio (shared/professions.ts › cleanRecipeList).
local ADDON, ns = ...
ns = ns or {}

local TEXTS = {
  es = {
    title = "Profesiones de la guild", tabMembers = "Por profesión", tabRecipes = "Recetas de la guild", tabRequests = "Requeridos",
    tipRequests = "Los pedidos de materiales de la guild: abre «Pedidos de la guild» (/rt pedidos).",
    groups = { craft = "Elaboración", gather = "Recolección", basic = "Secundarias" },
    railRecipes = "Recetas que saben",
    members = "Miembros", maxed = "Al máximo", avg = "Promedio", recipes = "Recetas",
    sortLabel = "Ordenar", sAsc = "Nivel", sDesc = "Nivel", sRecipes = "Recetas", sName = "Nombre",
    sLevel = "Nivel", sRare = "Más raras",
    colChar = "Personaje", colSkill = "Habilidad", colRecipes = "Recetas", colCd = "Cooldown",
    cdReady = "%s: lista", cdIn = "%s en %s", hours = "%d h", days = "%d d",
    nobody = "Nadie de la guild tiene %s anotada todavía (cada uno tiene que abrir la ventana de la profesión con el addon).",
    footMembers = "Mouse encima: cuándo se actualizó · Clic: sus recetas · Clic derecho: susurrar, invitar o copiar el nombre",
    updated = "Actualizado %s", never = "sin datos de la ventana de la profesión",
    search = "Buscar receta…", allLevels = "Todos los niveles", allChars = "Personajes: todos", charsN = "Personajes: %d",
    onlyKnown = "Solo adquiridas", summary = "%d de %d recetas de %s · las saben %d personas · %d las sabe uno solo",
    summaryLoose = "%d recetas de %s que sabe alguien de la guild · sin el catálogo de la web (llega con la app)",
    none = "Ninguna receta con esos filtros.", shown = "Mostrando %d de %d",
    nobodyShort = "nadie", onlyOne = "solo 1", peopleN = "%d personas",
    pick = "Elegí una receta para ver su detalle.", makes = "Fabrica %d", cooldown = "con cooldown",
    requires = "Requiere %s %d", reagents = "Componentes", vendorShort = "vendedor", have = "tenés %d", howTo = "Cómo se consigue",
    taughtBy = "La enseña: %s", knownBy = "La saben hacer (%d)", nobodyKnows = "Nadie de la guild la sabe hacer.",
    rightClick = "Clic derecho en un nombre: susurrar, invitar o copiar.",
    link = "Enlazar en el chat", ask = "Pedir materiales", askTip = "Pide a la guild lo que te falta para hacerla una vez (descontando bolsas y banco). Va a «Pedidos de la guild».",
    askNone = "ya tenés todo para hacerla.", unknownSrc = "Sin datos de cómo se consigue.",
    whisper = "Susurrar", invite = "Invitar al grupo", copy = "Copiar el nombre", seeRecipes = "Ver sus recetas", cancel = "Cancelar",
    copyTitle = "Nombre", copyHint = "Ctrl+C para copiar · Esc cierra",
    ranks = { "Aprendiz", "Oficial", "Experto", "Artesano", "Maestro", "Gran maestro", "Ilustre", "Zen" },
    source = {
      trainer = "Entrenador de %s", starter = "Se aprende con la profesión", camp = "Misión o construcción del campamento",
      vendorAt = "La vende", dropAt = "La suelta", npcAt = "NPC", vendorZone = "Vendedor en", dropZone = "Botín en",
      questAt = "Misión", objectAt = "En", itemAt = "Dentro de", spellAt = "Se crea con", crafted = "Se fabrica",
      drop = "Botín del mundo", pvp = "JcJ", quest = "Misión", vendor = "Vendedores", discovery = "Descubrimiento",
      event = "Evento", achievement = "Logro", fished = "Pesca", pickpocket = "Robar (pícaro)",
    },
    names = {
      firstaid = "Primeros auxilios", cooking = "Cocina", fishing = "Pesca", herbalism = "Herboristería", mining = "Minería",
      skinning = "Desuello", alchemy = "Alquimia", blacksmithing = "Herrería", enchanting = "Encantamiento", engineering = "Ingeniería",
      jewelcrafting = "Joyería", inscription = "Inscripción", leatherworking = "Peletería", tailoring = "Sastrería",
    },
  },
  en = {
    title = "Guild professions", tabMembers = "By profession", tabRecipes = "Guild recipes", tabRequests = "Requests",
    tipRequests = "The guild's material requests: opens «Guild requests» (/rt requests).",
    groups = { craft = "Crafting", gather = "Gathering", basic = "Secondary" },
    railRecipes = "Recipes known",
    members = "Members", maxed = "Maxed", avg = "Average", recipes = "Recipes",
    sortLabel = "Sort", sAsc = "Level", sDesc = "Level", sRecipes = "Recipes", sName = "Name",
    sLevel = "Level", sRare = "Rarest",
    colChar = "Character", colSkill = "Skill", colRecipes = "Recipes", colCd = "Cooldown",
    cdReady = "%s: ready", cdIn = "%s in %s", hours = "%d h", days = "%d d",
    nobody = "Nobody in the guild has %s recorded yet (each one has to open the profession window with the addon).",
    footMembers = "Hover: when it was updated · Click: their recipes · Right-click: whisper, invite or copy the name",
    updated = "Updated %s", never = "no data from the profession window",
    search = "Search recipe…", allLevels = "All levels", allChars = "Characters: all", charsN = "Characters: %d",
    onlyKnown = "Known only", summary = "%d of %d %s recipes · known by %d people · %d known by only one",
    summaryLoose = "%d %s recipes someone in the guild knows · without the site's catalog (it comes with the app)",
    none = "No recipe with those filters.", shown = "Showing %d of %d",
    nobodyShort = "nobody", onlyOne = "only 1", peopleN = "%d people",
    pick = "Pick a recipe to see its details.", makes = "Makes %d", cooldown = "has a cooldown",
    requires = "Requires %s %d", reagents = "Reagents", vendorShort = "vendor", have = "you have %d", howTo = "How to get it",
    taughtBy = "Taught by: %s", knownBy = "Known by (%d)", nobodyKnows = "Nobody in the guild knows it.",
    rightClick = "Right-click a name: whisper, invite or copy.",
    link = "Link in chat", ask = "Request materials", askTip = "Asks the guild for what you're missing to craft it once (counting bags and bank). It goes to «Guild requests».",
    askNone = "you already have everything to craft it.", unknownSrc = "No data on how to get it.",
    whisper = "Whisper", invite = "Invite to group", copy = "Copy the name", seeRecipes = "See their recipes", cancel = "Cancel",
    copyTitle = "Name", copyHint = "Ctrl+C to copy · Esc closes",
    ranks = { "Apprentice", "Journeyman", "Expert", "Artisan", "Master", "Grand Master", "Illustrious", "Zen" },
    source = {
      trainer = "%s trainer", starter = "Learned with the profession", camp = "Camp quest or building",
      vendorAt = "Sold by", dropAt = "Dropped by", npcAt = "NPC", vendorZone = "Vendor in", dropZone = "Drop in",
      questAt = "Quest", objectAt = "In", itemAt = "Inside", spellAt = "Created with", crafted = "Crafted",
      drop = "World drop", pvp = "PvP", quest = "Quest", vendor = "Vendors", discovery = "Discovery",
      event = "Event", achievement = "Achievement", fished = "Fishing", pickpocket = "Pickpocket (rogue)",
    },
    names = {
      firstaid = "First Aid", cooking = "Cooking", fishing = "Fishing", herbalism = "Herbalism", mining = "Mining",
      skinning = "Skinning", alchemy = "Alchemy", blacksmithing = "Blacksmithing", enchanting = "Enchanting", engineering = "Engineering",
      jewelcrafting = "Jewelcrafting", inscription = "Inscription", leatherworking = "Leatherworking", tailoring = "Tailoring",
    },
  },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; local v = (TEXTS[l] or TEXTS.es)[key]; if v == nil then v = TEXTS.es[key] end; return v end

-- ── Profesiones (como shared/professions.ts) ─────────────────────────────────────────────
local PROFS = {
  { key = "firstaid", es = "Primeros auxilios", en = "First Aid", icon = "Spell_Holy_SealOfSacrifice", group = "basic", games = { forever = 1, era = 1, anniversary = 1, classic = 1 } },
  { key = "cooking", es = "Cocina", en = "Cooking", icon = "INV_Misc_Food_15", group = "basic" },
  { key = "fishing", es = "Pesca", en = "Fishing", icon = "Trade_Fishing", group = "basic" },
  { key = "herbalism", es = "Herboristería", en = "Herbalism", icon = "Spell_Nature_NatureTouchGrow", group = "gather", aliases = { "Herbalismo" } },
  { key = "mining", es = "Minería", en = "Mining", icon = "Trade_Mining", group = "gather" },
  { key = "skinning", es = "Desuello", en = "Skinning", icon = "INV_Misc_Pelt_Wolf_01", group = "gather", aliases = { "Desollar" } },
  { key = "alchemy", es = "Alquimia", en = "Alchemy", icon = "Trade_Alchemy", group = "craft" },
  { key = "blacksmithing", es = "Herrería", en = "Blacksmithing", icon = "Trade_BlackSmithing", group = "craft" },
  { key = "enchanting", es = "Encantamiento", en = "Enchanting", icon = "Trade_Engraving", group = "craft" },
  { key = "engineering", es = "Ingeniería", en = "Engineering", icon = "Trade_Engineering", group = "craft" },
  { key = "jewelcrafting", es = "Joyería", en = "Jewelcrafting", icon = "INV_Misc_Gem_01", group = "craft", games = { anniversary = 1, classic = 1, retail = 1 } },
  { key = "inscription", es = "Inscripción", en = "Inscription", icon = "INV_Inscription_Tradeskill01", group = "craft", games = { classic = 1, retail = 1 } },
  { key = "leatherworking", es = "Peletería", en = "Leatherworking", icon = "INV_Misc_ArmorKit_17", group = "craft" },
  { key = "tailoring", es = "Sastrería", en = "Tailoring", icon = "Trade_Tailoring", group = "craft", aliases = { "Costura" } },
}
local GROUPS = { "craft", "gather", "basic" }
local GROUP_COLOR = { craft = { 0.71, 0.34, 1 }, gather = { 0.30, 0.76, 0.54 }, basic = { 0.94, 0.71, 0.31 } }
local GAMES = { [1] = "retail", [2] = "era", [5] = "anniversary", [11] = "classic", [14] = "classic", [19] = "classic", [18] = "forever" }
local function game() return GAMES[WOW_PROJECT_ID or 0] or "era" end
local function iconPath(icon) return icon and icon ~= "" and ("Interface\\Icons\\" .. icon) or "Interface\\Icons\\INV_Misc_QuestionMark" end

local ACCENTS = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
  ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n" }
local function norm(s)
  s = tostring(s or "")
  for k, v in pairs(ACCENTS) do s = s:gsub(k, v) end
  return (s:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end
local BY_NAME = {}
for _, p in ipairs(PROFS) do
  BY_NAME[norm(p.es)], BY_NAME[norm(p.en)] = p, p
  for _, n in ipairs(p.aliases or {}) do BY_NAME[norm(n)] = p end
end
local function profOf(name) return BY_NAME[norm(name)] end
local function profsOfGame(g)
  local out = {}
  for _, p in ipairs(PROFS) do if not p.games or p.games[g] then out[#out + 1] = p end end
  return out
end
local function profName(key) return (T("names") or {})[key] or key end

-- Venenos del pícaro (shared/professions.ts › POISON_RECIPES): no son de ninguna profesión.
local POISONS = {}
for _, id in ipairs({ 2835, 2837, 11357, 11358, 25347, 26969, 27282, 8681, 8687, 8691, 11341, 11342, 11343, 26892,
  3420, 3421, 5763, 8694, 11400, 13220, 13228, 13229, 13230, 27283, 6510 }) do POISONS["s" .. id] = true end

-- ── Datos ────────────────────────────────────────────────────────────────────────────────
local function split(s, sep)
  local out = {}
  for v in ((s or "") .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do out[#out + 1] = v end
  return out
end
local function fields(line) return split((tostring(line or ""):gsub("^@[^;]*;", "", 1)), ";") end
local function cleanName(s) return (tostring(s or ""):gsub("[|;,=/~:@\n\r\"]", " ")) end

-- Los personajes de la guild (y los propios) con lo que anotaron de profesiones.
local function chars()
  local d = ns.db and ns.db()
  local out = {}
  if not d or not d.data then return out end
  local guild = IsInGuild and IsInGuild() and GetGuildInfo and GetGuildInfo("player") or nil
  guild = guild and norm(cleanName(guild)) or nil
  local mine = UnitGUID and UnitGUID("player")
  for owner, c in pairs(d.data) do
    if type(owner) == "string" and owner:match("^Player%-") and type(c) == "table" and c.p1 then
      local p = fields(c.p1)
      local proj = tonumber(p[7])
      local inGuild = guild and norm(p[12] or "") == guild
      if (owner == mine or inGuild) and (not proj or not WOW_PROJECT_ID or proj == WOW_PROJECT_ID) then
        local ch = { guid = owner, name = p[4] or "?", realm = p[5] or "", class = p[8] or "", skills = {}, recipes = {}, cds = {}, mine = owner == mine }
        for _, line in pairs(c) do
          local f = fields(line)
          if f[1] == "sk1" then
            for nm, r, m in (f[4] or ""):gmatch("([^,=]+)=(%d+)/(%d+)") do ch.skills[#ch.skills + 1] = { name = nm, rank = tonumber(r), max = tonumber(m) } end
          elseif f[1] == "r1" then
            local ids = {}
            for id in (f[7] or ""):gmatch("[^,]+") do ids[#ids + 1] = id end
            ch.recipes[#ch.recipes + 1] = { prof = f[4], rank = tonumber(f[5]) or 0, max = tonumber(f[6]) or 0, ids = ids, at = tonumber(f[3]) or 0 }
          elseif f[1] == "cd1" then
            local list = {}
            for id, at in (f[5] or ""):gmatch("([^,=]+)=(%d+)") do list[#list + 1] = { recipe = id, readyAt = tonumber(at) } end
            ch.cds[#ch.cds + 1] = { prof = f[4], list = list }
          end
        end
        out[#out + 1] = ch
      end
    end
  end
  return out
end

-- El catálogo de la versión (Plans.lua › RebirthTrackCatalog), leído una vez.
-- hechizo;ítem;cuántos;calidad;nivel;colores;icono;nombre;componentes;enseña;cómo
local function parseRecipe(line)
  local f = split(line, ";")
  if #f < 11 then return nil end
  local r = { spell = tonumber(f[1]) or 0, item = tonumber(f[2]) or 0, makes = tonumber(f[3]) or 1, quality = tonumber(f[4]) or 1,
    learnedAt = tonumber(f[5]), icon = f[7], name = f[8], colors = {}, reagents = {}, source = {} }
  for c in (f[6] or ""):gmatch("%d+") do r.colors[#r.colors + 1] = tonumber(c) end
  for id, n in (f[9] or ""):gmatch("(%d+):(%d+)") do r.reagents[#r.reagents + 1] = { item = tonumber(id), count = tonumber(n) } end
  local ri, rq, rn = (f[10] or ""):match("^(%d+):(%d+):(.*)$")
  if ri then r.recipeItem = { id = tonumber(ri), quality = tonumber(rq) or 1, name = rn } end
  for row in (f[11] or ""):gmatch("[^~]+") do
    local s = split(row, ":")
    r.source[#r.source + 1] = { label = s[1], name = s[2] ~= "" and s[2] or nil, zone = s[3] ~= "" and s[3] or nil, cost = tonumber(s[4]) }
  end
  return r
end
local catCache
local function catalog()
  local src = rawget(_G, "RebirthTrackCatalog")
  local g = type(src) == "table" and type(src.games) == "table" and src.games[game()] or nil
  if type(g) ~= "table" then return nil end
  if catCache and catCache.src == g then return catCache end
  local c = { src = g, profs = {}, owners = {}, items = type(g.items) == "table" and g.items or {} }
  local function own(id, prof) c.owners[id] = c.owners[id] or {}; c.owners[id][prof] = true end
  for prof, lines in pairs(type(g.recipes) == "table" and g.recipes or {}) do
    local e = { list = {}, bySpell = {}, byItem = {}, byName = {} }
    for _, line in ipairs(lines) do
      local r = parseRecipe(line)
      if r then
        e.list[#e.list + 1] = r
        if r.spell ~= 0 then e.bySpell[r.spell] = r; own("s" .. r.spell, prof) end
        if r.item > 0 then e.byItem[r.item] = e.byItem[r.item] or r; own("i" .. r.item, prof) end
        e.byName[norm(r.name)] = e.byName[norm(r.name)] or r
      end
    end
    c.profs[prof] = e
  end
  catCache = c
  return c
end
local function catItem(id)
  local c = catalog()
  local v = c and c.items[id]
  if type(v) ~= "string" then return nil end
  local f = split(v, ";")
  return { name = f[1], icon = f[2], quality = tonumber(f[3]) or 1 }
end
local function itemName(id)
  local n = GetItemInfo and GetItemInfo(id)
  if not n and C_Item and C_Item.GetItemNameByID then n = C_Item.GetItemNameByID(id) end
  return n or (catItem(id) or {}).name or ("#" .. id)
end
local function spellInfo(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local i = C_Spell.GetSpellInfo(id)
    if i then return i.name, i.iconID end
  end
  if GetSpellInfo then local n, _, ic = GetSpellInfo(id); return n, ic end
  return nil
end
-- Una receta anotada (s<hechizo>, i<ítem>, n<nombre>) → la del catálogo.
local function match(e, id)
  if not e then return nil end
  local k, v = id:match("^([sin])(.+)$")
  if k == "s" then return e.bySpell[tonumber(v) or 0] end
  if k == "i" then return e.byItem[tonumber(v) or 0] end
  if k == "n" then return e.byName[norm(v)] end
  return nil
end

-- Saca de una lista lo que es de otra profesión (catálogo) o, si no está en ninguno, lo que la guild
-- anota más en otra (como cleanRecipeList del sitio).
local function cleanList(prof, ids, votes, cat)
  local out = {}
  for _, id in ipairs(ids) do
    local keep = not POISONS[id]
    if keep then
      local own = cat and cat.owners[id]
      if own then keep = own[prof] and true or false
      else
        local v = votes[id]
        if v then
          local n, top = 0, 0
          for _, c in pairs(v) do n = n + 1; top = math.max(top, c) end
          if n >= 2 then keep = (v[prof] or 0) >= top end
        end
      end
    end
    if keep then out[#out + 1] = id end
  end
  return out
end

-- Por profesión: miembros (con nivel, máximo, recetas y cooldowns) y quién sabe cada receta.
local function build()
  local cs, cat = chars(), catalog()
  local votes = {}
  for _, ch in ipairs(cs) do
    for _, r in ipairs(ch.recipes) do
      local p = profOf(r.prof)
      if p then
        local seen = {}
        for _, id in ipairs(r.ids) do
          if not seen[id] then seen[id] = true; votes[id] = votes[id] or {}; votes[id][p.key] = (votes[id][p.key] or 0) + 1 end
        end
      end
    end
  end
  local profs, byGuid = {}, {}
  local function entry(key)
    profs[key] = profs[key] or { key = key, cap = 0, members = {}, byRecipe = {}, recipeCount = 0 }
    return profs[key]
  end
  for _, ch in ipairs(cs) do
    byGuid[ch.guid] = ch
    local mine, order = {}, {}
    local function member(key)
      if not mine[key] then
        mine[key] = { guid = ch.guid, ch = ch, rank = 0, max = 0, recipes = 0, cds = {}, at = nil }
        order[#order + 1] = key
      end
      return mine[key]
    end
    for _, s in ipairs(ch.skills) do
      local p = profOf(s.name)
      if p then local m = member(p.key); m.rank, m.max = s.rank, s.max end
    end
    for _, r in ipairs(ch.recipes) do
      local p = profOf(r.prof)
      if p then
        local m = member(p.key)
        if m.rank == 0 then m.rank, m.max = r.rank, r.max end
        local ids = cleanList(p.key, r.ids, votes, cat)
        m.recipes = #ids
        m.at = math.max(m.at or 0, r.at)
        local e = entry(p.key)
        for _, id in ipairs(ids) do
          if not e.byRecipe[id] then e.byRecipe[id] = {}; e.recipeCount = e.recipeCount + 1 end
          local w = e.byRecipe[id]
          w[#w + 1] = ch.guid
        end
      end
    end
    for _, cd in ipairs(ch.cds) do
      local p = profOf(cd.prof)
      if p then member(p.key).cds = cd.list end
    end
    for _, key in ipairs(order) do
      local e = entry(key)
      e.members[#e.members + 1] = mine[key]
      e.cap = math.max(e.cap, mine[key].max or 0)
    end
  end
  return profs, byGuid
end

-- Las recetas de una profesión: las del catálogo (con quién las sabe) y las anotadas que no están.
local function recipeRows(e, key)
  local cat = catalog()
  local cp = cat and cat.profs[key]
  local rows, who, matched = {}, {}, {}
  e = e or { byRecipe = {} }
  if cp then
    for id, list in pairs(e.byRecipe) do
      local r = match(cp, id)
      if r then
        matched[id] = true
        who[r] = who[r] or {}
        for _, g in ipairs(list) do who[r][g] = true end
      end
    end
    for _, r in ipairs(cp.list) do
      local w = {}
      for g in pairs(who[r] or {}) do w[#w + 1] = g end
      rows[#rows + 1] = { key = "s" .. r.spell, name = r.name, icon = iconPath(r.icon), quality = r.quality, learnedAt = r.learnedAt, who = w, recipe = r }
    end
  end
  for id, list in pairs(e.byRecipe) do
    if not matched[id] then
      local k, v = id:match("^([sin])(.+)$")
      local name, icon, q, spell, item
      if k == "s" then spell = tonumber(v); name, icon = spellInfo(spell or 0)
      elseif k == "i" then item = tonumber(v); name = itemName(item or 0); q = ns.ui.itemQuality(item or 0)
      else name = v end
      local w = {}
      for _, g in ipairs(list) do w[#w + 1] = g end
      rows[#rows + 1] = { key = id, name = name or ("#" .. tostring(v)), icon = icon or (item and ns.ui and ns.ui.itemIcon(item)) or "Interface\\Icons\\INV_Misc_QuestionMark",
        quality = q or 1, who = w, loose = true, spell = spell, item = item }
    end
  end
  return rows
end

local RANK_STEP = 75
local function rankOf(lvl) return math.min(math.floor((lvl or 0) / RANK_STEP), 7) end

-- Filtros y orden de la lista (como GuildProfessionRecipes.vue).
local function filterRows(rows, f)
  local needle = norm(f.q or "")
  local out = {}
  for _, r in ipairs(rows) do
    local ok = (not f.onlyKnown or #r.who > 0) and (needle == "" or norm(r.name):find(needle, 1, true))
      and (f.rank == nil or (r.learnedAt and rankOf(r.learnedAt) == f.rank))
    if ok and f.picks and next(f.picks) then
      ok = false
      for _, g in ipairs(r.who) do if f.picks[g] then ok = true; break end end
    end
    if ok then out[#out + 1] = r end
  end
  local function byName(a, b) return norm(a.name) < norm(b.name) end
  if f.sort == "rare" then
    table.sort(out, function(a, b)
      local x, y = (#a.who > 0) and #a.who or 999, (#b.who > 0) and #b.who or 999
      if x ~= y then return x < y end
      return byName(a, b)
    end)
  elseif f.sort == "name" then table.sort(out, byName)
  else
    local function lv(r)
      local n = 0
      for _, g in ipairs(r.recipe and r.recipe.reagents or {}) do n = n + g.count end
      return { r.learnedAt or 9999, r.recipe and r.recipe.colors[4] or 9999, r.recipe and n or 99 }
    end
    table.sort(out, function(a, b)
      local x, y = lv(a), lv(b)
      for i = 1, 3 do if x[i] ~= y[i] then return x[i] < y[i] end end
      return byName(a, b)
    end)
  end
  return out
end

-- Cómo se escribe el nombre para susurrar o invitar (en Forever, «Nombre Apellido»).
local function targetName(ch)
  local name, realm = ch.name or "", ch.realm or ""
  if WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18) then
    if not name:find(" ") and realm ~= "" and realm ~= (GetRealmName and GetRealmName() or "") then return name .. " " .. realm end
    return name
  end
  local rk = realm:gsub("[%s%-']", "")
  local home = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName() or ""):gsub("[%s%-']", "")
  if rk == "" or rk == home then return name end
  return name .. "-" .. rk
end
local function colorOf(ch) return ns.ui.classColor(ch and ch.class) end
local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255)) end

local function cdText(cd)
  local cat = catalog()
  local name
  for _, e in pairs(cat and cat.profs or {}) do local r = match(e, cd.recipe); if r then name = r.name; break end end
  if not name then
    local k, v = cd.recipe:match("^([sin])(.+)$")
    if k == "s" then name = spellInfo(tonumber(v) or 0) elseif k == "i" then name = itemName(tonumber(v) or 0) else name = v end
  end
  name = name or cd.recipe
  local left = (cd.readyAt or 0) - time()
  if left <= 0 then return T("cdReady"):format(name), true end
  local h = math.ceil(left / 3600)
  local t = h >= 48 and T("days"):format(math.floor(h / 24 + 0.5)) or T("hours"):format(h)
  return T("cdIn"):format(name, t), false
end

-- ── Acciones sobre un nombre ─────────────────────────────────────────────────────────────
local function whisper(ch)
  local n = targetName(ch)
  if ChatFrame_SendTell then ChatFrame_SendTell(n)
  elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. n .. " ") end
end
local function invite(ch)
  local n = targetName(ch)
  if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(n) elseif InviteUnit then InviteUnit(n) end
end
local copyWin
local function copyName(ch)
  local U = ns.ui
  if not copyWin then
    copyWin = U.window("RebirthTrackProfCopy", 260, 110, "", { point = { "CENTER", 0, 140 } })
    copyWin.edit = U.input(copyWin, 230, 24)
    copyWin.edit:SetPoint("TOPLEFT", 14, copyWin.top - 12)
    copyWin.edit:SetScript("OnEscapePressed", function() copyWin:Hide() end)
    copyWin.edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(copyWin.value or ""); self:HighlightText() end end)
    copyWin.hint = U.font(copyWin, "GameFontHighlightSmall", U.C.muted, "CENTER"); copyWin.hint:SetPoint("BOTTOM", 0, 12)
  end
  copyWin.value = targetName(ch)
  copyWin.title:SetText(T("copyTitle"))
  copyWin.hint:SetText(T("copyHint"))
  copyWin.edit:SetText(copyWin.value)
  copyWin:Show()
  copyWin.edit:SetFocus(); copyWin.edit:HighlightText()
end

-- Menú chico (clic derecho en un nombre y desplegables): { { text, onClick, keep, checked, title } }.
local menu
local function openMenu(items, owner)
  local U, C = ns.ui, ns.ui.C
  if not menu then
    menu = CreateFrame("Frame", "RebirthTrackProfMenu", UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    U.fill(menu, { 0.039, 0.047, 0.063 }, 0.98)
    U.edge(menu, C.border, 1)
    menu.rows = {}
    if UISpecialFrames then table.insert(UISpecialFrames, "RebirthTrackProfMenu") end
  end
  for _, b in ipairs(menu.rows) do b:Hide() end
  local y, w = -4, 160
  for i, it in ipairs(items) do
    local b = menu.rows[i]
    if not b then
      b = CreateFrame("Button", nil, menu)
      b:SetHeight(20)
      b.hl = U.fill(b, C.hover, 0)
      b.fs = U.font(b, "GameFontHighlightSmall", C.text, "LEFT"); b.fs:SetPoint("LEFT", 8, 0)
      b:SetScript("OnEnter", function(self) if not self.isTitle and self.hl.SetVertexColor then self.hl:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 1) end end)
      b:SetScript("OnLeave", function(self) if self.hl.SetVertexColor then self.hl:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 0) end end)
      menu.rows[i] = b
    end
    b.isTitle = it.title
    local label = it.text or ""
    if it.checked ~= nil then label = (it.checked and U.ICON.check or "|TInterface\\Buttons\\WHITE8x8:12:12:0:0:8:8:0:8:0:8:40:44:52|t") .. " " .. label end
    b.fs:SetText(label)
    b.text = it.text -- (para las pruebas)
    local c = it.title and C.gold or (it.muted and C.muted or C.text)
    if b.fs.SetTextColor then b.fs:SetTextColor(c[1], c[2], c[3]) end
    b:SetScript("OnClick", function()
      if it.title then return end
      if not it.keep then menu:Hide() end
      if it.onClick then it.onClick() end
    end)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, y); b:SetPoint("TOPRIGHT", -4, y)
    b:Show()
    w = math.max(w, math.ceil(U.textWidth(b.fs)) + 30)
    y = y - 20
  end
  menu:SetSize(w, -y + 4)
  menu:ClearAllPoints()
  if owner then menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  else
    local x, cy = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, cy / s)
  end
  menu:Show()
  if menu.Raise then menu:Raise() end
  return menu
end

local win
local refresh
local function nameMenu(ch, extra)
  local items = { { text = targetName(ch), title = true },
    { text = T("whisper"), onClick = function() whisper(ch) end },
    { text = T("invite"), onClick = function() invite(ch) end },
    { text = T("copy"), onClick = function() copyName(ch) end } }
  if extra then items[#items + 1] = extra end
  items[#items + 1] = { text = T("cancel"), muted = true }
  return openMenu(items)
end

-- ── Ventana ──────────────────────────────────────────────────────────────────────────────
local W, H, RAIL = 940, 520, 160
local DETAIL = 290
local MEMBER_ROWS, RECIPE_ROWS = 10, 13

local function state()
  local d = ns.db and ns.db()
  d.ui = d.ui or {}
  d.ui.profs = d.ui.profs or {}
  return d.ui.profs
end

local function setupRail()
  local U, C = ns.ui, ns.ui.C
  win.rail = CreateFrame("Frame", nil, win)
  win.rail:SetPoint("TOPLEFT", 1, win.top - 30); win.rail:SetPoint("BOTTOMLEFT", 1, 1); win.rail:SetWidth(RAIL)
  U.fill(win.rail, { 0.063, 0.075, 0.102 }, 1)
  local edge = U.tex(win.rail, "ARTWORK", C.line); edge:SetWidth(1); edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT")
  win.railItems = {}
end

local function railItem(i)
  local U, C = ns.ui, ns.ui.C
  local b = win.railItems[i]
  if b then return b end
  b = CreateFrame("Button", nil, win.rail)
  b:SetHeight(22)
  b.hl = U.fill(b, C.gold, 0)
  b.mark = U.tex(b, "ARTWORK", C.gold); b.mark:SetWidth(2); b.mark:SetPoint("TOPLEFT"); b.mark:SetPoint("BOTTOMLEFT")
  b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetSize(16, 16); b.ic:SetPoint("LEFT", 6, 0)
  if b.ic.SetTexCoord then b.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.fs = U.font(b, "GameFontHighlightSmall", C.text, "LEFT"); b.fs:SetPoint("LEFT", b.ic, "RIGHT", 6, 0); b.fs:SetWidth(RAIL - 60)
  if b.fs.SetWordWrap then b.fs:SetWordWrap(false) end
  b.n = U.font(b, "GameFontHighlightSmall", C.muted, "RIGHT"); b.n:SetPoint("RIGHT", -8, 0)
  b.head = U.font(win.rail, "GameFontNormalSmall", C.muted, "LEFT")
  win.railItems[i] = b
  return b
end

local function currentProf(profs, list, tab)
  local st = state()
  for _, p in ipairs(list) do if p.key == st.prof then return p.key end end
  -- Sin elegir: la primera de elaboración con alguien, si no la primera con alguien.
  local first
  for _, p in ipairs(list) do
    local e = profs[p.key]
    if e and #e.members > 0 then
      if p.group == "craft" then return p.key end
      first = first or p.key
    end
  end
  return first or (list[1] and list[1].key)
end

local function drawRail(profs, list, tab, key)
  local U, C = ns.ui, ns.ui.C
  local y, i = -6, 0
  for _, b in ipairs(win.railItems) do b:Hide(); b.head:Hide() end
  for _, g in ipairs(GROUPS) do
    local any = false
    for _, p in ipairs(list) do
      if p.group == g then
        i = i + 1
        local b = railItem(i)
        if not any then
          any = true
          b.head:ClearAllPoints(); b.head:SetPoint("TOPLEFT", 10, y - 2)
          b.head:SetText(((T("groups") or {})[g] or g):upper()); b.head:Show()
          y = y - 16
        end
        local e = profs[p.key]
        local n = tab == "recipes" and (e and e.recipeCount or 0) or (e and #e.members or 0)
        local on = p.key == key
        b.key = p.key
        b.ic:SetTexture(iconPath(p.icon))
        b.fs:SetText(profName(p.key)); b.text = profName(p.key)
        b.n:SetText(tostring(n))
        local c = on and C.gold or (n == 0 and C.muted or C.text)
        if b.fs.SetTextColor then b.fs:SetTextColor(c[1], c[2], c[3]) end
        if b.hl.SetVertexColor then b.hl:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], on and 0.12 or 0) end
        b.mark:SetShown(on)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 4, y); b:SetPoint("TOPRIGHT", -4, y)
        b:SetScript("OnClick", function(self) state().prof = self.key; win.sel, win.page = nil, 1; state().picks = nil; refresh() end)
        b:Show()
        y = y - 22
      end
    end
    if any then y = y - 6 end
  end
end

-- Pestaña «Por profesión».
local function setupMembers()
  local U, C = ns.ui, ns.ui.C
  local m = CreateFrame("Frame", nil, win)
  m:SetPoint("TOPLEFT", RAIL + 1, win.top - 30); m:SetPoint("BOTTOMRIGHT", -1, 1)
  win.mem = m
  m.icon = m:CreateTexture(nil, "ARTWORK"); m.icon:SetSize(32, 32); m.icon:SetPoint("TOPLEFT", 12, -10)
  m.group = U.font(m, "GameFontNormalSmall", C.muted, "LEFT"); m.group:SetPoint("TOPLEFT", m.icon, "TOPRIGHT", 10, -1)
  m.name = U.font(m, "GameFontNormalLarge", C.text, "LEFT"); m.name:SetPoint("TOPLEFT", m.group, "BOTTOMLEFT", 0, -2)
  m.stats = {}
  local sw = math.floor((W - RAIL - 24 - 18) / 4)
  for i, k in ipairs({ "members", "maxed", "avg", "recipes" }) do
    local box = CreateFrame("Frame", nil, m)
    box:SetSize(sw, 38); box:SetPoint("TOPLEFT", 12 + (i - 1) * (sw + 6), -50)
    U.fill(box, C.sub, 1); U.edge(box, C.line, 1)
    box.l = U.label(box, T(k)); box.l:SetPoint("TOPLEFT", 8, -5); box.k = k
    box.v = U.font(box, "GameFontHighlight", C.text, "LEFT"); box.v:SetPoint("BOTTOMLEFT", 8, 5)
    m.stats[i] = box
  end
  m.sortLabel = U.font(m, "GameFontHighlightSmall", C.muted, "LEFT"); m.sortLabel:SetPoint("TOPLEFT", 12, -100)
  m.sorts = {}
  for _, s in ipairs({ { "asc", "sAsc", "up" }, { "desc", "sDesc", "down" }, { "recipes", "sRecipes" }, { "name", "sName" } }) do
    local b = U.button(m, "", "off", function() state().mSort = s[1]; refresh() end)
    b.key, b.label, b.glyph = s[1], s[2], s[3]
    m.sorts[#m.sorts + 1] = b
  end
  m.cols = { { "who", 0, "colChar" }, { "skill", 150, "colSkill" }, { "rec", 70, "colRecipes", "RIGHT" }, { "cd", 190, "colCd" } }
  local hcols = {}
  for _, c in ipairs(m.cols) do hcols[#hcols + 1] = { c[1], c[2], T(c[3]), c[4] } end
  m.head = U.tableHeader(m, hcols, W - RAIL - 2, -128)
  m.rows = {}
  m.nobody = U.font(m, "GameFontHighlightSmall", C.muted, "LEFT"); m.nobody:SetPoint("TOPLEFT", 12, -160); m.nobody:SetWidth(W - RAIL - 40)
  local ft = U.footer(m, 30)
  m.ft = ft
  m.foot = U.font(ft, "GameFontHighlightSmall", C.muted, "LEFT"); m.foot:SetPoint("LEFT", 10, 0)
  m.prev = U.iconButton(ft, 22, "‹", function() win.mPage = math.max(1, (win.mPage or 1) - 1); refresh() end)
  m.next = U.iconButton(ft, 22, "›", function() win.mPage = (win.mPage or 1) + 1; refresh() end)
  m.pageText = U.font(ft, "GameFontHighlightSmall", C.muted, "CENTER")
  m.next:SetPoint("RIGHT", -8, 0); m.pageText:SetPoint("RIGHT", m.next, "LEFT", -6, 0); m.prev:SetPoint("RIGHT", m.pageText, "LEFT", -6, 0)
end

local function memberRow(i)
  local U, C = ns.ui, ns.ui.C
  local m = win.mem
  local r = m.rows[i]
  if r then return r end
  r = U.row(m, 26, i)
  r:SetPoint("TOPLEFT", 1, -150 - (i - 1) * 26); r:SetPoint("TOPRIGHT", -1, -150 - (i - 1) * 26)
  if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  local pos = m.head.pos
  r.dot = U.dot(r, 8, C.text); r.dot:SetPoint("LEFT", 10, 0)
  r.name = U.font(r, "GameFontHighlightSmall", C.text, "LEFT"); r.name:SetPoint("LEFT", r.dot, "RIGHT", 6, 0); r.name:SetWidth(pos.who.w - 30)
  if r.name.SetWordWrap then r.name:SetWordWrap(false) end
  r.bar = U.bar(r, pos.skill.w - 16, 14); r.bar:SetPoint("LEFT", 8 + pos.skill.x, 0)
  r.barText = U.font(r.bar, "GameFontHighlightSmall", C.text, "CENTER"); r.barText:SetPoint("CENTER", 0, 0)
  r.rec = U.font(r, "GameFontHighlightSmall", C.text, "RIGHT"); r.rec:SetPoint("LEFT", 8 + pos.rec.x, 0); r.rec:SetWidth(pos.rec.w - 16)
  r.cd = U.font(r, "GameFontHighlightSmall", C.muted, "LEFT"); r.cd:SetPoint("LEFT", 8 + pos.cd.x, 0); r.cd:SetWidth(pos.cd.w - 12)
  if r.cd.SetWordWrap then r.cd:SetWordWrap(false) end
  r.onEnter = function(self)
    if not self.m then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(targetName(self.m.ch), 1, 0.82, 0)
    GameTooltip:AddLine(self.m.at and T("updated"):format(date("%d/%m %H:%M", self.m.at)) or T("never"), 1, 1, 1, true)
    GameTooltip:Show()
  end
  r:SetScript("OnClick", function(self, button)
    if not self.m then return end
    if button == "RightButton" then
      nameMenu(self.m.ch, { text = T("seeRecipes"), onClick = function() state().tab = "recipes"; state().picks = { [self.m.guid] = true }; win.page = 1; refresh() end })
    else
      state().tab = "recipes"; state().picks = { [self.m.guid] = true }; win.page = 1; refresh()
    end
  end)
  m.rows[i] = r
  return r
end

local function sortMembers(list, how)
  local out = {}
  for _, m in ipairs(list) do out[#out + 1] = m end
  local function nm(a, b) return norm(a.ch.name) < norm(b.ch.name) end
  table.sort(out, function(a, b)
    if how == "desc" then if a.rank ~= b.rank then return a.rank > b.rank end return nm(a, b)
    elseif how == "recipes" then if a.recipes ~= b.recipes then return a.recipes > b.recipes end return nm(a, b)
    elseif how == "name" then return nm(a, b) end
    if a.rank ~= b.rank then return a.rank < b.rank end
    return nm(a, b)
  end)
  return out
end

local function drawMembers(e, key)
  local U, C = ns.ui, ns.ui.C
  local m = win.mem
  local def
  for _, p in ipairs(PROFS) do if p.key == key then def = p end end
  m.icon:SetTexture(iconPath(def and def.icon))
  local gc = GROUP_COLOR[def and def.group or "craft"]
  m.group:SetText(((T("groups") or {})[def and def.group or "craft"] or ""):upper())
  if m.group.SetTextColor then m.group:SetTextColor(gc[1], gc[2], gc[3]) end
  m.name:SetText(profName(key))
  local members = e and e.members or {}
  local maxed, sum = 0, 0
  for _, x in ipairs(members) do
    sum = sum + (x.rank or 0)
    if (e.cap or 0) > 0 and x.rank >= e.cap then maxed = maxed + 1 end
  end
  local vals = { tostring(#members), "|cff" .. U.HEX.green .. maxed .. "|r",
    #members > 0 and (math.floor(sum / #members + 0.5) .. " |cff" .. U.HEX.muted .. "/ " .. (e.cap or 0) .. "|r") or "—",
    tostring(e and e.recipeCount or 0) }
  for i, box in ipairs(m.stats) do box.l:SetText(T(box.k):upper()); box.v:SetText(vals[i]) end
  m.sortLabel:SetText(T("sortLabel"))
  local how = state().mSort or "asc"
  local prev
  for _, b in ipairs(m.sorts) do
    b:SetKind(b.key == how and "on" or "off"); b:SetLabel(T(b.label) .. (b.glyph and (" " .. U.ICON[b.glyph]) or ""))
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT", m.sortLabel, "RIGHT", 8, 0) end
    prev = b
  end
  for _, c in ipairs(m.cols) do if m.head.cells[c[1]] then m.head.cells[c[1]]:SetText(T(c[3]):upper()) end end
  local list = sortMembers(members, how)
  local pages = math.max(1, math.ceil(#list / MEMBER_ROWS))
  win.mPage = math.min(math.max(1, win.mPage or 1), pages)
  for _, r in ipairs(m.rows) do r:Hide(); r.m = nil end
  m.nobody:SetShown(#list == 0)
  m.nobody:SetText(T("nobody"):format(profName(key)))
  local from = (win.mPage - 1) * MEMBER_ROWS
  for i = 1, MEMBER_ROWS do
    local x = list[from + i]
    if not x then break end
    local r = memberRow(i)
    r.m = x
    local cc = colorOf(x.ch)
    r.dot:SetColor(cc)
    r.name:SetText("|cff" .. hex(cc) .. targetName(x.ch) .. "|r")
    r.name.text = targetName(x.ch)
    r.text = targetName(x.ch) -- (para las pruebas: clic en la fila)
    r.bar:SetValue((x.max or 0) > 0 and x.rank / x.max or 0, (x.max or 0) > 0 and x.rank >= x.max and C.green or { 0.24, 0.56, 0.29 })
    r.barText:SetText(x.rank .. " / " .. (x.max or 0))
    r.rec:SetText(tostring(x.recipes or 0))
    local cds = {}
    local ready = false
    for _, cd in ipairs(x.cds or {}) do local t, ok = cdText(cd); cds[#cds + 1] = t; ready = ready or ok end
    r.cd:SetText(#cds > 0 and table.concat(cds, " · ") or "—")
    local col = ready and C.green or (#cds > 0 and C.text or C.muted)
    if r.cd.SetTextColor then r.cd:SetTextColor(col[1], col[2], col[3]) end
    r:Show()
  end
  m.foot:SetText(T("footMembers"))
  m.pageText:SetText(win.mPage .. " / " .. pages)
  m.prev:SetShown(pages > 1); m.next:SetShown(pages > 1); m.pageText:SetShown(pages > 1)
  m.prev:SetEnabled(win.mPage > 1); m.next:SetEnabled(win.mPage < pages)
end

-- Pestaña «Recetas de la guild».
local function setupRecipes()
  local U, C = ns.ui, ns.ui.C
  local r = CreateFrame("Frame", nil, win)
  r:SetPoint("TOPLEFT", RAIL + 1, win.top - 30); r:SetPoint("BOTTOMRIGHT", -(DETAIL + 1), 1)
  win.rec = r
  local LW = W - RAIL - DETAIL - 2
  r.search = U.input(r, LW - 140, 24, T("search"))
  r.search:SetPoint("TOPLEFT", 10, -8)
  r.search:SetScript("OnTextChanged", function(self) self.updatePlaceholder(self); win.page = 1; if not win.drawing then refresh() end end)
  r.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  r.sorts = {}
  for _, s in ipairs({ { "level", "sLevel" }, { "rare", "sRare" }, { "name", "sName" } }) do
    local b = U.button(r, "", "off", function() state().rSort = s[1]; refresh() end)
    b.key, b.label = s[1], s[2]
    r.sorts[#r.sorts + 1] = b
  end
  r.level = U.button(r, "", nil, function(self)
    local items = { { text = T("allLevels"), onClick = function() state().rank = nil; win.page = 1; refresh() end } }
    for i = 0, (win.topRank or 0) do
      items[#items + 1] = { text = ("%s (%d-%d)"):format(T("ranks")[i + 1] or "", i * RANK_STEP, (i + 1) * RANK_STEP - 1),
        onClick = function() state().rank = i; win.page = 1; refresh() end }
    end
    openMenu(items, self)
  end)
  local openChars
  function openChars(self)
    local items = {}
    local st = state()
    for _, x in ipairs(win.profMembers or {}) do
      local g = x.guid
      items[#items + 1] = { text = targetName(x.ch) .. "  |cff" .. U.HEX.muted .. x.rank .. "|r", keep = true, checked = st.picks and st.picks[g] or false,
        onClick = function() st.picks = st.picks or {}; st.picks[g] = not st.picks[g] or nil; win.page = 1; refresh(); openChars(r.chars) end }
    end
    if st.picks and next(st.picks) then items[#items + 1] = { text = T("allChars"), onClick = function() st.picks = nil; win.page = 1; refresh() end } end
    if #items > 0 then openMenu(items, self) end
  end
  r.chars = U.button(r, "", nil, function(self) openChars(self) end)
  r.known = U.button(r, "", "off", function() state().onlyKnown = not state().onlyKnown; win.page = 1; refresh() end)
  r.summary = U.font(r, "GameFontHighlightSmall", C.muted, "LEFT"); r.summary:SetPoint("TOPLEFT", 10, -66); r.summary:SetWidth(LW - 20)
  if r.summary.SetWordWrap then r.summary:SetWordWrap(false) end
  U.hline(r, -82, 0)
  r.rows = {}
  r.none = U.font(r, "GameFontHighlightSmall", C.muted, "LEFT"); r.none:SetPoint("TOPLEFT", 10, -96)
  local ft = U.footer(r, 30)
  r.foot = U.font(ft, "GameFontHighlightSmall", C.muted, "LEFT"); r.foot:SetPoint("LEFT", 10, 0)
  r.prev = U.iconButton(ft, 22, "‹", function() win.page = math.max(1, (win.page or 1) - 1); refresh() end)
  r.next = U.iconButton(ft, 22, "›", function() win.page = (win.page or 1) + 1; refresh() end)
  r.pageText = U.font(ft, "GameFontHighlightSmall", C.muted, "CENTER")
  r.next:SetPoint("RIGHT", -8, 0); r.pageText:SetPoint("RIGHT", r.next, "LEFT", -6, 0); r.prev:SetPoint("RIGHT", r.pageText, "LEFT", -6, 0)

  -- Detalle.
  local d = CreateFrame("Frame", nil, win)
  d:SetPoint("TOPRIGHT", -1, win.top - 30); d:SetPoint("BOTTOMRIGHT", -1, 1); d:SetWidth(DETAIL)
  U.fill(d, C.sub, 1)
  local edge = U.tex(d, "ARTWORK", C.line); edge:SetWidth(1); edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT")
  win.det = d
  d.icon = U.icon(d, 40); d.icon:SetPoint("TOPLEFT", 12, -12)
  d.name = U.font(d, "GameFontNormal", C.text, "LEFT"); d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2); d.name:SetWidth(DETAIL - 80)
  d.sub = U.font(d, "GameFontHighlightSmall", C.muted, "LEFT"); d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
  d.req = U.font(d, "GameFontHighlightSmall", C.text, "LEFT"); d.req:SetPoint("TOPLEFT", 12, -62)
  d.diff = U.font(d, "GameFontHighlightSmall", C.text, "RIGHT"); d.diff:SetPoint("TOPRIGHT", -12, -62)
  d.pick = U.font(d, "GameFontHighlightSmall", C.muted, "LEFT"); d.pick:SetPoint("TOPLEFT", 12, -14); d.pick:SetWidth(DETAIL - 24)
  d.lines = {}
  d.reag = {}
  d.who = {}
  d.link = U.button(d, "", nil, function() if win.selRow then local l = win.linkOf(win.selRow); if l then if ChatEdit_InsertLink and ChatEdit_InsertLink(l) then return end; if ChatFrame_OpenChat then ChatFrame_OpenChat(l) end end end end)
  d.ask = U.button(d, "", "pri", function() if win.selRow and ns.requestReagents then ns.requestReagents(win.selRow.name, win.selRow.recipe and win.selRow.recipe.reagents or {}) end end)
  d.link:SetPoint("BOTTOMLEFT", 12, 10)
  d.ask:SetPoint("BOTTOMRIGHT", -12, 10)
end

local function recipeRow(i)
  local U, C = ns.ui, ns.ui.C
  local r = win.rec
  local b = r.rows[i]
  if b then return b end
  b = U.row(r, 24, i)
  b:SetPoint("TOPLEFT", 1, -84 - (i - 1) * 24); b:SetPoint("TOPRIGHT", -1, -84 - (i - 1) * 24)
  b.mark = U.tex(b, "ARTWORK", C.gold); b.mark:SetWidth(2); b.mark:SetPoint("TOPLEFT"); b.mark:SetPoint("BOTTOMLEFT")
  b.ic = b:CreateTexture(nil, "ARTWORK"); b.ic:SetSize(18, 18); b.ic:SetPoint("LEFT", 8, 0)
  if b.ic.SetTexCoord then b.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.name = U.font(b, "GameFontHighlightSmall", C.text, "LEFT"); b.name:SetPoint("LEFT", b.ic, "RIGHT", 8, 0)
  b.tag = U.font(b, "GameFontHighlightSmall", C.muted, "RIGHT"); b.tag:SetPoint("RIGHT", -10, 0); b.tag:SetWidth(76)
  b.lv = U.font(b, "GameFontHighlightSmall", C.muted, "RIGHT"); b.lv:SetPoint("RIGHT", b.tag, "LEFT", -6, 0); b.lv:SetWidth(30)
  b.name:SetPoint("RIGHT", b.lv, "LEFT", -6, 0)
  if b.name.SetWordWrap then b.name:SetWordWrap(false) end
  b:SetScript("OnClick", function(self) if self.row then win.sel = self.row.key; refresh() end end)
  b.onEnter = function(self)
    local row = self.row
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local item = row.recipe and row.recipe.item or row.item
    if item and item > 0 and GameTooltip.SetItemByID then GameTooltip:SetItemByID(item)
    elseif row.spell and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(row.spell)
    else GameTooltip:AddLine(row.name, 1, 1, 1) end
    GameTooltip:Show()
  end
  r.rows[i] = b
  return b
end

local function detailLine(i)
  local U, C = ns.ui, ns.ui.C
  local d = win.det
  local fs = d.lines[i]
  if not fs then
    fs = U.font(d, "GameFontHighlightSmall", C.text, "LEFT"); fs:SetWidth(DETAIL - 24)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    d.lines[i] = fs
  end
  return fs
end
local function reagRow(i)
  local U, C = ns.ui, ns.ui.C
  local d = win.det
  local x = d.reag[i]
  if x then return x end
  x = CreateFrame("Frame", nil, d)
  x:SetSize(DETAIL - 24, 24)
  x.icon = U.icon(x, 22); x.icon:SetPoint("LEFT", 0, 0)
  x.name = U.font(x, "GameFontHighlightSmall", C.text, "LEFT"); x.name:SetPoint("LEFT", x.icon, "RIGHT", 8, 0); x.name:SetWidth(DETAIL - 120)
  if x.name.SetWordWrap then x.name:SetWordWrap(false) end
  x.have = U.font(x, "GameFontHighlightSmall", C.muted, "RIGHT"); x.have:SetPoint("RIGHT", 0, 0)
  d.reag[i] = x
  return x
end
local function whoRow(i)
  local U, C = ns.ui, ns.ui.C
  local d = win.det
  local x = d.who[i]
  if x then return x end
  x = CreateFrame("Button", nil, d)
  x:SetSize(DETAIL - 24, 20)
  if x.RegisterForClicks then x:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  x.hl = U.fill(x, C.hover, 0)
  x.dot = U.dot(x, 8, C.text); x.dot:SetPoint("LEFT", 4, 0)
  x.name = U.font(x, "GameFontHighlightSmall", C.text, "LEFT"); x.name:SetPoint("LEFT", x.dot, "RIGHT", 6, 0)
  x.rank = U.font(x, "GameFontHighlightSmall", C.muted, "LEFT"); x.rank:SetPoint("LEFT", x.name, "RIGHT", 6, 0)
  x:SetScript("OnEnter", function(self) if self.hl.SetVertexColor then self.hl:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 1) end end)
  x:SetScript("OnLeave", function(self) if self.hl.SetVertexColor then self.hl:SetVertexColor(C.hover[1], C.hover[2], C.hover[3], 0) end end)
  x:SetScript("OnClick", function(self) if self.ch then nameMenu(self.ch) end end)
  d.who[i] = x
  return x
end

local function coinsText(c)
  if not c or c <= 0 then return "" end
  local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then out[#out + 1] = "|cfff2c14e" .. g .. "o|r" end
  if s > 0 then out[#out + 1] = "|cffc9cdd6" .. s .. "p|r" end
  if k > 0 then out[#out + 1] = "|cffc98b4a" .. k .. "c|r" end
  return table.concat(out, " ")
end
local function itemCount(id)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id, true) or 0 end
  if GetItemCount then return GetItemCount(id, true) or 0 end
  return 0
end

local function drawDetail(row, key, byGuid, e)
  local U, C = ns.ui, ns.ui.C
  local d = win.det
  win.selRow = row
  for _, fs in ipairs(d.lines) do fs:Hide() end
  for _, x in ipairs(d.reag) do x:Hide() end
  for _, x in ipairs(d.who) do x:Hide(); x.ch = nil end
  local has = row ~= nil
  d.icon:SetShown(has); d.name:SetShown(has); d.sub:SetShown(has); d.req:SetShown(has); d.diff:SetShown(has)
  d.link:SetShown(has); d.ask:SetShown(false)
  d.pick:SetShown(not has); d.pick:SetText(T("pick"))
  if not has then return end
  local rec = row.recipe
  d.icon:SetItem(rec and rec.item > 0 and rec.item or row.item, nil, row.icon)
  d.icon.id = (rec and rec.item > 0 and rec.item) or row.item
  local q = U.QUALITY[row.quality or 1] or U.QUALITY[1]
  d.name:SetText(row.name)
  if d.name.SetTextColor then d.name:SetTextColor(q[1], q[2], q[3]) end
  local sub = {}
  if rec and rec.makes > 1 then sub[#sub + 1] = T("makes"):format(rec.makes) end
  local hasCd = false
  local cp = catalog() and catalog().profs[key]
  for _, m in ipairs(e and e.members or {}) do for _, cd in ipairs(m.cds or {}) do if cd.recipe == row.key or (rec and match(cp, cd.recipe) == rec) then hasCd = true end end end
  if hasCd then sub[#sub + 1] = T("cooldown") end
  d.sub:SetText(table.concat(sub, " · "))
  d.req:SetText(row.learnedAt and T("requires"):format(profName(key), row.learnedAt) or "")
  if rec and #rec.colors == 4 then
    d.diff:SetText(("|cffff8040%d|r |cffffff00%d|r |cff40bf40%d|r |cff9d9d9d%d|r"):format(rec.colors[1], rec.colors[2], rec.colors[3], rec.colors[4]))
  else d.diff:SetText("") end
  local y, li = -84, 0
  local function line(text, c)
    li = li + 1
    local fs = detailLine(li)
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 12, y)
    fs:SetText(text)
    local cc = c or C.text
    if fs.SetTextColor then fs:SetTextColor(cc[1], cc[2], cc[3]) end
    fs:Show()
    y = y - math.max(14, math.ceil((fs.GetStringHeight and fs:GetStringHeight()) or 14)) - 4
  end
  local missing = 0
  if rec and #rec.reagents > 0 then
    line(T("reagents"), C.gold)
    for i, g in ipairs(rec.reagents) do
      local x = reagRow(i)
      local ci = catItem(g.item)
      x.icon:SetItem(g.item, g.count, not ns.ui.itemIcon(g.item) and ci and ci.icon ~= "" and iconPath(ci.icon) or nil)
      local have = itemCount(g.item)
      if have < g.count then missing = missing + 1 end
      x.name:SetText(itemName(g.item) .. " |cff" .. U.HEX.muted .. "×" .. g.count .. "|r")
      local v = have < g.count and ns.vendorText and ns.vendorText(g.item) or nil
      x.have:SetText(T("have"):format(have) .. (v and (" |cffe0b04a· " .. T("vendorShort") .. "|r") or ""))
      x.icon.extra = v
      x:ClearAllPoints(); x:SetPoint("TOPLEFT", 12, y)
      x:Show()
      y = y - 26
    end
    y = y - 4
  end
  if rec then
    line(T("howTo"), C.gold)
    if rec.recipeItem then line(T("taughtBy"):format(rec.recipeItem.name)) end
    local src = T("source") or {}
    for _, s in ipairs(rec.source) do
      local label = src[s.label] or s.label
      if s.label == "trainer" then label = label:format(profName(key)) end
      local t = label .. (s.name and (": |cffe6e8ec" .. s.name .. "|r") or "") .. (s.zone and (" |cff" .. U.HEX.muted .. "— " .. s.zone .. "|r") or "")
      if s.cost then t = t .. " · " .. coinsText(s.cost) end
      line(t)
    end
    if #rec.source == 0 and not rec.recipeItem then line(T("unknownSrc"), C.muted) end
    y = y - 4
  end
  -- Quién la sabe hacer, del que más nivel tiene al que menos.
  local who = {}
  local ranks = {}
  for _, m in ipairs(e and e.members or {}) do ranks[m.guid] = m.rank end
  for _, g in ipairs(row.who) do if byGuid[g] then who[#who + 1] = byGuid[g] end end
  table.sort(who, function(a, b) local x, z = ranks[a.guid] or 0, ranks[b.guid] or 0; if x ~= z then return x > z end return norm(a.name) < norm(b.name) end)
  line(T("knownBy"):format(#who), C.gold)
  local iKnow = false
  for i, ch in ipairs(who) do
    if ch.mine then iKnow = true end
    if y < -(H - 140) then break end
    local x = whoRow(i)
    x.ch = ch
    local cc = colorOf(ch)
    x.dot:SetColor(cc)
    x.name:SetText("|cff" .. hex(cc) .. targetName(ch) .. "|r"); x.text = targetName(ch)
    x.rank:SetText(tostring(ranks[ch.guid] or ""))
    x:ClearAllPoints(); x:SetPoint("TOPLEFT", 12, y)
    x:Show()
    y = y - 20
  end
  if #who == 0 then line(T("nobodyKnows"), C.muted)
  else line(T("rightClick"), C.muted) end
  d.link:SetLabel(T("link"))
  d.ask:SetLabel(T("ask")); d.ask.tip = T("askTip")
  d.ask:SetShown(iKnow and rec ~= nil and #rec.reagents > 0 and ns.requestReagents ~= nil)
end

local function drawRecipes(e, key, profs, byGuid)
  local U, C = ns.ui, ns.ui.C
  local r = win.rec
  local st = state()
  local all = recipeRows(e, key)
  local top = 0
  for _, x in ipairs(all) do if x.learnedAt then top = math.max(top, rankOf(x.learnedAt)) end end
  win.topRank = top
  local members = {}
  for _, m in ipairs(e and e.members or {}) do members[#members + 1] = m end
  table.sort(members, function(a, b) return norm(a.ch.name) < norm(b.ch.name) end)
  win.profMembers = members
  if st.picks then
    local ok = {}
    for _, m in ipairs(members) do ok[m.guid] = true end
    for g in pairs(st.picks) do if not ok[g] then st.picks[g] = nil end end
  end
  local rows = filterRows(all, { q = r.search:GetText(), sort = st.rSort or "level", rank = st.rank, picks = st.picks, onlyKnown = st.onlyKnown })
  -- Controles.
  local how = st.rSort or "level"
  local prev
  for _, b in ipairs(r.sorts) do
    b:SetKind(b.key == how and "on" or "off"); b:SetLabel(T(b.label))
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 10, -38) end
    prev = b
  end
  r.level:SetLabel((st.rank and ("%s (%d-%d)"):format(T("ranks")[st.rank + 1] or "", st.rank * RANK_STEP, (st.rank + 1) * RANK_STEP - 1) or T("allLevels")) .. " " .. U.ICON.down)
  r.level:ClearAllPoints(); r.level:SetPoint("LEFT", prev, "RIGHT", 10, 0)
  local npk = 0
  for _ in pairs(st.picks or {}) do npk = npk + 1 end
  r.chars:SetLabel((npk > 0 and T("charsN"):format(npk) or T("allChars")) .. " " .. U.ICON.down)
  r.chars:ClearAllPoints(); r.chars:SetPoint("LEFT", r.level, "RIGHT", 6, 0)
  r.chars:SetEnabled(#members > 0)
  r.known:SetKind(st.onlyKnown and "on" or "off"); r.known:SetLabel((st.onlyKnown and U.ICON.check or "") .. T("onlyKnown"))
  r.known:ClearAllPoints(); r.known:SetPoint("LEFT", r.search, "RIGHT", 10, 0)
  r.search.ph:SetText(T("search"))
  -- Resumen.
  local known, only, people = 0, 0, {}
  for _, x in ipairs(all) do
    if #x.who > 0 then known = known + 1 end
    if #x.who == 1 then only = only + 1 end
    for _, g in ipairs(x.who) do people[g] = true end
  end
  local np = 0
  for _ in pairs(people) do np = np + 1 end
  local cat = catalog()
  if cat and cat.profs[key] then r.summary:SetText(T("summary"):format(known, #all, profName(key), np, only))
  else r.summary:SetText(T("summaryLoose"):format(#all, profName(key))) end
  -- Filas.
  local pages = math.max(1, math.ceil(#rows / RECIPE_ROWS))
  win.page = math.min(math.max(1, win.page or 1), pages)
  for _, b in ipairs(r.rows) do b:Hide(); b.row = nil end
  r.none:SetShown(#rows == 0); r.none:SetText(T("none"))
  local from = (win.page - 1) * RECIPE_ROWS
  local selRow
  for _, x in ipairs(all) do if x.key == win.sel then selRow = x end end
  for i = 1, RECIPE_ROWS do
    local x = rows[from + i]
    if not x then break end
    local b = recipeRow(i)
    b.row = x
    b.text = x.name -- (para las pruebas)
    b.ic:SetTexture(x.icon)
    if b.ic.SetDesaturated then b.ic:SetDesaturated(#x.who == 0) end
    b.ic:SetAlpha(#x.who == 0 and 0.45 or 1)
    local q = #x.who == 0 and C.muted or (U.QUALITY[x.quality or 1] or U.QUALITY[1])
    b.name:SetText(x.name)
    if b.name.SetTextColor then b.name:SetTextColor(q[1], q[2], q[3]) end
    b.lv:SetText(x.learnedAt and tostring(x.learnedAt) or "")
    local tag, tc
    if #x.who == 0 then tag, tc = T("nobodyShort"), C.line
    elseif #x.who == 1 then tag, tc = T("onlyOne"), C.amber
    else tag, tc = T("peopleN"):format(#x.who), C.muted end
    b.tag:SetText(tag)
    if b.tag.SetTextColor then b.tag:SetTextColor(tc[1], tc[2], tc[3]) end
    b.mark:SetShown(x.key == win.sel)
    b:Show()
  end
  r.foot:SetText(T("shown"):format(#rows, #all))
  r.pageText:SetText(win.page .. " / " .. pages)
  r.prev:SetEnabled(win.page > 1); r.next:SetEnabled(win.page < pages)
  drawDetail(selRow, key, byGuid, e)
end

local function createWindow()
  if win then return win end
  local U = ns.ui
  win = U.window("RebirthTrackProfessionsFrame", W, H, "", { point = { "CENTER", 0, 30 } })
  win.tabs = U.tabs(win, win.top, { { "members", "" }, { "recipes", "" }, { "requests", "" } }, function(k)
    if k == "requests" then
      if ns.openRequests then ns.openRequests(ns.requestsBadge and ns.requestsBadge() > 0 and "pending" or "guild") end
      return
    end
    state().tab = k; win.page, win.mPage = 1, 1; refresh()
  end)
  local reqTab = win.tabs.byKey.requests
  reqTab:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(T("tipRequests"), 1, 1, 1, true); GameTooltip:Show() end)
  reqTab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  setupRail()
  setupMembers()
  setupRecipes()
  win.linkOf = function(row)
    local rec = row.recipe
    local spell = rec and rec.spell or row.spell
    if spell and spell > 0 then
      local l = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spell)) or (GetSpellLink and GetSpellLink(spell))
      if l then return l end
    end
    local item = (rec and rec.item > 0 and rec.item) or row.item
    if item and GetItemInfo then return select(2, GetItemInfo(item)) end
    return nil
  end
  if win.HookScript then win:HookScript("OnHide", function() if menu then menu:Hide() end end) end
  return win
end

function refresh()
  if not win or not win:IsShown() then return end
  win.drawing = true
  local ok, err = pcall(function()
    local profs, byGuid = build()
    local st = state()
    local tab = st.tab == "recipes" and "recipes" or "members"
    local list = profsOfGame(game())
    local key = currentProf(profs, list, tab)
    st.prof = key
    win.title:SetText(T("title"))
    local badge = ns.requestsBadge and ns.requestsBadge() or 0
    win.tabs:Update(tab, { requests = badge > 0 and badge or nil, hot = "requests" }, nil,
      { members = T("tabMembers"), recipes = T("tabRecipes"), requests = T("tabRequests") .. " »" })
    drawRail(profs, list, tab, key)
    win.mem:SetShown(tab == "members")
    win.rec:SetShown(tab == "recipes"); win.det:SetShown(tab == "recipes")
    if tab == "members" then drawMembers(profs[key], key) else drawRecipes(profs[key], key, profs, byGuid) end
  end)
  win.drawing = false
  win.err = not ok and err or nil
  if not ok and ns.debug then print(err) end
end

function ns.openProfessions(tab, prof)
  createWindow()
  if tab then state().tab = tab end
  if prof then state().prof = prof end
  win:Show()
  refresh()
end
ns.refreshProfessions = function() refresh() end

-- Para el plan (Plan.lua › materiales que faltan): los componentes de una receta del catálogo.
function ns.catalogReagents(prof, spell)
  local c = catalog()
  local e = c and c.profs[prof]
  local r = e and e.bySpell[spell]
  return r and r.reagents or nil
end
ns.catalogItemName = itemName

-- Para las pruebas.
ns._professions = { build = build, chars = chars, catalog = catalog, recipeRows = recipeRows, filterRows = filterRows,
  cleanList = cleanList, profOf = profOf, targetName = targetName, parseRecipe = parseRecipe, window = function() return win end,
  menu = function() return menu end, nameMenu = nameMenu, resetCatalog = function() catCache = nil end }
