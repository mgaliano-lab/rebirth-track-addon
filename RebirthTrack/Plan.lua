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
--   B;rama;nombre · T;rama;fila;columna;rango;máximo;nombre · L;rama;rango;máximo;nombre · N;notas
local ADDON, ns = ...
ns = ns or {}

local TX = {
  es = {
    title = "Plan del personaje", none = "Sin plan para este personaje.", noneHint = "Copiá el plan en rebirthknights.fun (Planificador de personajes › Para el addon) y pegalo con «Pegar plan». Con la app, los personajes vinculados llegan solos.",
    paste = "Pegar plan", read = "Leer", clear = "Borrar pegados", pasteHint = "Pegá acá el texto que copiaste del sitio y tocá Leer:",
    bad = "el texto no es un plan válido (copialo de nuevo del sitio).", loaded = "%d plan(es) leído(s).", cleared = "Planes pegados borrados.",
    tSummary = "Resumen", tProf = "Profesiones", tTalents = "Talentos", tLegacy = "Legado",
    level = "Nivel", total = "Avance", main = "main", fromApp = "de la app", pasted = "pegado", other = "Es de otro personaje: %s",
    skill = "Habilidad", notLearned = "sin aprender", step = "Paso %d de %d", done = "Ruta completa", now = "▶ ahora",
    mats = "Materiales de toda la ruta (bolsas + banco)", noRoute = "Sin ruta (se sube recolectando).",
    planned = "Planeados", spent = "Gastados", next = "Próximo a tocar: %s (%d→%d)", buildDone = "Build completa.", off = "Fuera del plan: %s",
    legacyNote = "El juego todavía no le muestra el Legado a los addons: tildalo a mano en el planificador del sitio.",
    notes = "Notas", noTalents = "Sin build de talentos en el plan.", noLegacy = "Sin reparto de Legado en el plan.",
    legend = "|cff40bf40verde|r: listo · |cffff8b3dnaranja|r: a medias · |cffffd100dorado|r: falta · |cffff4040rojo|r: fuera del plan",
    planRank = "Plan: %d/%d", notPlanned = "No está en el plan.", otherClass = "El plan es de otra clase: se ve como lista.",
  },
  en = {
    title = "Character plan", none = "No plan for this character.", noneHint = "Copy the plan at rebirthknights.fun (Character planner › For the addon) and paste it with «Paste plan». With the app, linked characters arrive on their own.",
    paste = "Paste plan", read = "Read", clear = "Clear pasted", pasteHint = "Paste the text you copied from the site and press Read:",
    bad = "the text isn't a valid plan (copy it again from the site).", loaded = "%d plan(s) read.", cleared = "Pasted plans cleared.",
    tSummary = "Summary", tProf = "Professions", tTalents = "Talents", tLegacy = "Legacy",
    level = "Level", total = "Progress", main = "main", fromApp = "from the app", pasted = "pasted", other = "It belongs to another character: %s",
    skill = "Skill", notLearned = "not learned", step = "Step %d of %d", done = "Route done", now = "▶ now",
    mats = "Materials for the whole route (bags + bank)", noRoute = "No route (leveled by gathering).",
    planned = "Planned", spent = "Spent", next = "Next to take: %s (%d→%d)", buildDone = "Build done.", off = "Off plan: %s",
    legacyNote = "The game doesn't expose Legacy to addons yet: tick it by hand in the site's planner.",
    notes = "Notes", noTalents = "No talent build in the plan.", noLegacy = "No Legacy points in the plan.",
    legend = "|cff40bf40green|r: done · |cffff8b3dorange|r: partial · |cffffd100gold|r: to take · |cffff4040red|r: off plan",
    planRank = "Plan: %d/%d", notPlanned = "Not in the plan.", otherClass = "The plan is for another class: shown as a list.",
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
    elseif t == "T" then table.insert(p.talents, { tree = n(2), row = n(3), col = n(4), rank = n(5), max = n(6), name = f[7] or "" })
    elseif t == "L" then table.insert(p.legacy, { tree = f[2] or "", rank = n(3), max = n(4), name = f[5] or "" })
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
local function skillOf(key)
  if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
  local names = PROF_NAMES[key] or {}
  for i = 1, GetNumSkillLines() do
    local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
    if name and not header then
      for _, n in ipairs(names) do if n:lower() == name:lower() then return rank, max end end
    end
  end
  return nil
end
local function talentRanks()
  local have = {}
  if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return have end
  for tab = 1, GetNumTalentTabs() do
    for i = 1, GetNumTalents(tab) do
      local name, _, tier, col, rank = GetTalentInfo(tab, i)
      if name then have[(tab - 1) .. "-" .. tier .. "-" .. col] = rank or 0 end
    end
  end
  return have
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
    local have, planned, matched, spent, next, off = talentRanks(), 0, 0, 0, nil, {}
    local wanted = {}
    for _, t in ipairs(p.talents) do
      local key = t.tree .. "-" .. t.row .. "-" .. t.col
      wanted[key] = true
      local h = have[key] or 0
      planned, matched = planned + t.rank, matched + math.min(h, t.rank)
      if not next and h < t.rank then next = { t = t, have = h } end
    end
    for key, r in pairs(have) do
      spent = spent + r
      if r > 0 and not wanted[key] then table.insert(off, key) end
    end
    out.tal = { planned = planned, matched = matched, spent = spent, next = next, off = #off }
    if planned > 0 then table.insert(vals, matched / planned) end
  end
  local sum = 0
  for _, v in ipairs(vals) do sum = sum + v end
  out.pct = math.floor(sum / #vals * 100 + 0.5)
  return out
end
ns.planProgress = progress

-- ── Ventana ──────────────────────────────────────────────────────────────────────────────────────
local GOLD, GREEN, GRAY, ORANGE = "|cffffd100", "|cff40bf40", "|cff9d9d9d", "|cffff8b3d"
local pw, sel, tab = nil, nil, "summary"

-- El árbol se dibuja con las ramas del juego: solo si el plan es de la clase del personaje con el que
-- estás (si no, las ramas no son las del plan y queda la lista).
local function canDraw(p)
  if #p.talents == 0 or not (GetNumTalentTabs and GetTalentInfo) then return false end
  if not UnitClass then return false end
  local _, token = UnitClass("player")
  return token ~= nil and token:upper() == (p.cls or ""):upper()
end

local function lines(p)
  local pr, out = progress(p), {}
  local add = function(s) out[#out + 1] = s end
  local cls = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.cls:upper()]) or p.cls
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.cls:upper()]
  add((color and ("|c" .. (color.colorStr or "ffffffff")) or GOLD) .. p.name .. "|r  " .. GRAY .. p.race .. " · " .. cls .. (p.main and (" · ★ " .. T("main")) or "") .. " · " .. T(p.source == "app" and "fromApp" or "pasted") .. "|r")
  if not isMine(p) then add(ORANGE .. T("other"):format(p.name .. (p.realm ~= "" and ("-" .. p.realm) or "")) .. "|r") end
  add("")
  if tab == "summary" then
    add(GOLD .. T("total") .. ": " .. pr.pct .. "%|r")
    add(T("level") .. ": " .. pr.level .. "/60")
    for _, x in ipairs(pr.profs) do
      local s = x.rank and (x.rank .. "/" .. (x.max or 300)) or (GRAY .. T("notLearned") .. "|r")
      local st = x.step and x.prof.steps[x.step]
      add(x.prof.name .. ": " .. s .. (st and (GRAY .. " · " .. st.name .. " ×" .. st.crafts .. "|r") or ""))
    end
    if pr.tal then
      add(T("tTalents") .. ": " .. pr.tal.matched .. "/" .. pr.tal.planned)
      if pr.tal.next then add(GRAY .. T("next"):format(pr.tal.next.t.name, pr.tal.next.have, pr.tal.next.t.rank) .. "|r") end
    end
    if #p.legacy > 0 then add(T("tLegacy") .. ": " .. #p.legacy) end
    if p.notes ~= "" then add(""); add(GOLD .. T("notes") .. "|r: " .. p.notes) end
  elseif tab == "prof" then
    for _, x in ipairs(pr.profs) do
      add(GOLD .. x.prof.name .. "|r  " .. T("skill") .. ": " .. (x.rank and (x.rank .. "/" .. (x.max or 300)) or T("notLearned")))
      if #x.prof.steps == 0 then add(GRAY .. T("noRoute") .. "|r")
      elseif not x.step and x.rank then add(GREEN .. "✓ " .. T("done") .. "|r")
      else add(GRAY .. T("step"):format(x.step or 1, #x.prof.steps) .. "|r") end
      for i, s in ipairs(x.prof.steps) do
        local mark = i == x.step and (GOLD .. T("now") .. " ") or ((x.step and i < x.step or (not x.step and x.rank)) and GREEN .. "✓ " or GRAY .. "  ")
        add(mark .. s.from .. "→" .. s.to .. "  " .. s.name .. " ×" .. s.crafts .. "|r")
      end
      if #x.prof.mats > 0 then
        add(""); add(GRAY .. T("mats") .. "|r")
        for _, m in ipairs(x.prof.mats) do
          local have = GetItemCount and GetItemCount(m.item, true) or 0
          add((have >= m.count and GREEN or ORANGE) .. have .. "/" .. m.count .. "|r  " .. m.name)
        end
      end
      add("")
    end
  elseif tab == "talents" then
    if #p.talents == 0 then add(GRAY .. T("noTalents") .. "|r") else
      local have = talentRanks()
      add(T("planned") .. ": " .. pr.tal.planned .. " · " .. T("spent") .. ": " .. pr.tal.spent .. " · ✓ " .. pr.tal.matched)
      if pr.tal.next then add(GOLD .. T("next"):format(pr.tal.next.t.name, pr.tal.next.have, pr.tal.next.t.rank) .. "|r")
      elseif pr.tal.matched >= pr.tal.planned then add(GREEN .. "✓ " .. T("buildDone") .. "|r") end
      if pr.tal.off > 0 then add(ORANGE .. T("off"):format(pr.tal.off) .. "|r") end
      if canDraw(p) then add(T("legend")); return out end
      if isMine(p) then add(""); add(GRAY .. T("otherClass") .. "|r") end
      local last
      for _, t in ipairs(p.talents) do
        if t.tree ~= last then add(""); add(GOLD .. (p.trees[t.tree + 1] or ("#" .. t.tree)) .. "|r"); last = t.tree end
        local h = have[t.tree .. "-" .. t.row .. "-" .. t.col] or 0
        add((h >= t.rank and GREEN or h > 0 and ORANGE or GRAY) .. h .. "/" .. t.rank .. "|r  " .. t.name)
      end
    end
  elseif tab == "legacy" then
    if #p.legacy == 0 then add(GRAY .. T("noLegacy") .. "|r") else
      local last
      for _, l in ipairs(p.legacy) do
        if l.tree ~= last then add(GOLD .. l.tree .. "|r"); last = l.tree end
        add("  " .. l.rank .. "/" .. l.max .. "  " .. l.name)
      end
      add(""); add(GRAY .. T("legacyNote") .. "|r")
    end
  end
  return out
end

-- ── Árbol de talentos ────────────────────────────────────────────────────────────────────────────
-- Las tres ramas una al lado de la otra, como la ventana de talentos del juego y la ficha del personaje
-- del sitio: ícono de cada talento en su fila y columna, flechas de requisitos y, por talento, lo que
-- tenés contra lo planeado (borde y número del color del estado). Pasando el mouse, la tooltip del juego.
local CELL, STEP, PADX, HEAD = 28, 34, 5, 20
local TREE_W = PADX * 2 + 3 * STEP + CELL
local COLORS = { done = { 0.25, 0.75, 0.25 }, part = { 1, 0.55, 0.24 }, todo = { 1, 0.82, 0 }, off = { 1, 0.25, 0.25 }, none = { 0.3, 0.3, 0.3 } }
local function cellAt(tree, t) return PADX + (t.col - 1) * STEP, -(HEAD + 4 + (t.row - 1) * STEP) end

local function treeFrame(i)
  local g = pw.grid
  g.trees = g.trees or {}
  local f = g.trees[i]
  if f then return f end
  f = CreateFrame("Frame", nil, g, BackdropTemplateMixin and "BackdropTemplate" or nil)
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, 0.55); f:SetBackdropBorderColor(0.45, 0.35, 0.2)
  end
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.title:SetPoint("TOPLEFT", 6, -5); f.title:SetPoint("TOPRIGHT", -6, -5); f.title:SetJustifyH("LEFT")
  f.cells, f.lines = {}, {}
  g.trees[i] = f
  return f
end
local function line(f, n)
  local l = f.lines[n]
  if not l then l = f:CreateTexture(nil, "ARTWORK"); f.lines[n] = l end
  l:ClearAllPoints(); l:Show()
  return l
end
local function cell(f, n)
  local b = f.cells[n]
  if b then return b end
  b = CreateFrame("Button", nil, f)
  b:SetSize(CELL, CELL)
  b.border = b:CreateTexture(nil, "BACKGROUND"); b.border:SetPoint("TOPLEFT", -2, 2); b.border:SetPoint("BOTTOMRIGHT", 2, -2)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
  b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); b.rank:SetPoint("BOTTOMRIGHT", 4, -3)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetTalent then GameTooltip:SetTalent(self.tab, self.i) else GameTooltip:AddLine(self.tname or "", 1, 1, 1) end
    if self.want > 0 then GameTooltip:AddLine(T("planRank"):format(self.want, self.max), 1, 0.82, 0)
    else GameTooltip:AddLine(T("notPlanned"), 0.6, 0.6, 0.6) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.cells[n] = b
  return b
end

local function stateOf(have, want)
  if want > 0 then return have >= want and "done" or have > 0 and "part" or "todo" end
  return have > 0 and "off" or "none"
end

-- Dibuja el árbol debajo del texto; devuelve el alto que ocupa.
local function drawTalents(p)
  local g = pw.grid
  local wanted = {}
  for _, t in ipairs(p.talents) do wanted[t.tree .. "-" .. t.row .. "-" .. t.col] = t.rank end
  local pr = progress(p)
  local nextKey = pr.tal and pr.tal.next and (pr.tal.next.t.tree .. "-" .. pr.tal.next.t.row .. "-" .. pr.tal.next.t.col)
  local trees, height = talentTrees(), 0
  for ti, tree in ipairs(trees) do
    local f = treeFrame(ti)
    local h = HEAD + 8 + tree.rows * STEP
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", (ti - 1) * (TREE_W + 8), 0); f:SetSize(TREE_W, h); f:Show()
    local spent, plan = 0, 0
    for _, t in ipairs(tree.talents) do spent = spent + t.rank; plan = plan + (wanted[t.key] or 0) end
    f.title:SetText((tree.name or ("#" .. ti)) .. "  " .. GRAY .. spent .. "/" .. plan .. "|r")
    local byKey = {}
    for _, t in ipairs(tree.talents) do byKey[t.key] = t end
    -- Flechas de requisito (por debajo de los íconos): vertical, o en L desde la fila del requisito.
    local nl = 0
    for _, t in ipairs(tree.talents) do
      local pre = t.pre and byKey[t.pre]
      if pre then
        local x1, y1 = cellAt(tree, pre)
        local x2, y2 = cellAt(tree, t)
        local on = (wanted[t.key] or 0) > 0 and (wanted[pre.key] or 0) > 0
        local r, gg, bb = 0.35, 0.35, 0.35
        if on then r, gg, bb = 1, 0.82, 0 end
        if x1 ~= x2 then
          nl = nl + 1
          local l = line(f, nl); l:SetColorTexture(r, gg, bb, 0.9)
          l:SetPoint("TOPLEFT", math.min(x1, x2) + CELL / 2, y1 - CELL / 2 + 2); l:SetSize(math.abs(x2 - x1), 4)
        end
        if y1 ~= y2 then
          nl = nl + 1
          local l = line(f, nl); l:SetColorTexture(r, gg, bb, 0.9)
          l:SetPoint("TOPLEFT", x2 + CELL / 2 - 2, (x1 ~= x2) and (y1 - CELL / 2) or (y1 - CELL)); l:SetSize(4, math.abs(y2 - y1) - ((x1 ~= x2) and CELL / 2 or CELL))
        end
      end
    end
    for k = nl + 1, #f.lines do f.lines[k]:Hide() end
    for n, t in ipairs(tree.talents) do
      local b = cell(f, n)
      local want = wanted[t.key] or 0
      local st = stateOf(t.rank, want)
      local c = COLORS[st]
      b.tab, b.i, b.tname, b.want, b.max = tree.tab, t.i, t.name, want, t.max
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", cellAt(tree, t)); b:Show()
      b.icon:SetTexture(t.icon)
      if b.icon.SetDesaturated then b.icon:SetDesaturated(st == "none") end
      b.icon:SetAlpha(st == "none" and 0.45 or 1)
      if t.key == nextKey then b.border:SetColorTexture(1, 1, 1, 1) else b.border:SetColorTexture(c[1], c[2], c[3], st == "none" and 0.6 or 1) end
      b.rank:SetText(want > 0 and (t.rank .. "/" .. want) or (t.rank > 0 and tostring(t.rank) or ""))
      b.rank:SetTextColor(c[1], c[2], c[3])
    end
    for k = #tree.talents + 1, #f.cells do f.cells[k]:Hide() end
    if h > height then height = h end
  end
  for k = #trees + 1, #(g.trees or {}) do g.trees[k]:Hide() end
  g:SetSize(3 * TREE_W + 16, math.max(1, height)); g:Show()
  return height
end
ns._planDraw = { trees = talentTrees, draw = function(p) return drawTalents(p) end, canDraw = function(p) return canDraw(p) end, grid = function() return pw and pw.grid end }

local function refresh()
  if not pw then return end
  local list = allPlans()
  if sel and not list[sel] then sel = nil end
  if not sel then for i, p in ipairs(list) do if isMine(p) then sel = i; break end end end
  if not sel and #list > 0 then sel = 1 end
  pw.title:SetText(T("title") .. (#list > 1 and ("  (" .. sel .. "/" .. #list .. ")") or ""))
  pw.prev:SetShown(#list > 1); pw.next:SetShown(#list > 1)
  for k, b in pairs(pw.tabs) do b:SetText(T(b.key)); if b.SetEnabled then b:SetEnabled(tab ~= k) end end
  pw.pasteBtn:SetText(T("paste")); pw.read:SetText(T("read")); pw.clear:SetText(T("clear")); pw.hint:SetText(T("pasteHint"))
  local p = list[sel or 0]
  pw.body:SetText(p and table.concat(lines(p), "\n") or (T("none") .. "\n\n" .. GRAY .. T("noneHint") .. "|r"))
  local textH = pw.body.GetStringHeight and (pw.body:GetStringHeight() or 0) or 0
  local treeH = 0
  if p and tab == "talents" and canDraw(p) then treeH = drawTalents(p) + 10 else pw.grid:Hide() end
  pw.child:SetHeight(math.max(1, textH + 8 + treeH))
end
ns.planRefresh = refresh

local function create()
  pw = CreateFrame("Frame", "RebirthTrackPlanFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  pw:SetSize(500, 520); pw:SetPoint("CENTER"); pw:SetFrameStrata("DIALOG")
  pw:SetMovable(true); pw:EnableMouse(true); pw:RegisterForDrag("LeftButton")
  pw:SetScript("OnDragStart", pw.StartMoving); pw:SetScript("OnDragStop", pw.StopMovingOrSizing)
  if pw.SetBackdrop then pw:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } }) end
  pw.title = pw:CreateFontString(nil, "OVERLAY", "GameFontNormal"); pw.title:SetPoint("TOP", 0, -14)
  local close = CreateFrame("Button", nil, pw, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
  pw.prev = CreateFrame("Button", nil, pw, "UIPanelButtonTemplate"); pw.prev:SetSize(24, 20); pw.prev:SetPoint("TOPLEFT", 14, -10); pw.prev:SetText("<")
  pw.prev:SetScript("OnClick", function() local n = #allPlans(); sel = ((sel or 1) - 2) % n + 1; refresh() end)
  pw.next = CreateFrame("Button", nil, pw, "UIPanelButtonTemplate"); pw.next:SetSize(24, 20); pw.next:SetPoint("LEFT", pw.prev, "RIGHT", 2, 0); pw.next:SetText(">")
  pw.next:SetScript("OnClick", function() local n = #allPlans(); sel = (sel or 1) % n + 1; refresh() end)
  pw.tabs = {}
  local order = { { "summary", "tSummary" }, { "prof", "tProf" }, { "talents", "tTalents" }, { "legacy", "tLegacy" } }
  for i, x in ipairs(order) do
    local b = CreateFrame("Button", nil, pw, "UIPanelButtonTemplate"); b:SetSize(100, 22); b:SetPoint("TOPLEFT", 16 + (i - 1) * 102, -36)
    b.key = x[2]; b:SetText(T(x[2]))
    b:SetScript("OnClick", function() tab = x[1]; refresh() end)
    pw.tabs[x[1]] = b
  end
  pw.scroll = CreateFrame("ScrollFrame", "RebirthTrackPlanScroll", pw, "UIPanelScrollFrameTemplate")
  pw.scroll:SetPoint("TOPLEFT", 16, -66); pw.scroll:SetPoint("BOTTOMRIGHT", -34, 44)
  pw.child = CreateFrame("Frame", nil, pw.scroll); pw.child:SetSize(440, 1)
  pw.scroll:SetScrollChild(pw.child)
  pw.body = pw.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pw.body:SetPoint("TOPLEFT", 2, -2); pw.body:SetWidth(436); pw.body:SetJustifyH("LEFT"); pw.body:SetJustifyV("TOP")
  if pw.body.SetSpacing then pw.body:SetSpacing(2) end
  pw.grid = CreateFrame("Frame", nil, pw.child); pw.grid:SetPoint("TOPLEFT", pw.body, "BOTTOMLEFT", 0, -10); pw.grid:Hide()
  -- Pegar: un cuadro de varias líneas (el plan trae una línea por dato).
  pw.paste = CreateFrame("Frame", nil, pw, BackdropTemplateMixin and "BackdropTemplate" or nil)
  pw.paste:SetPoint("TOPLEFT", 12, -62); pw.paste:SetPoint("BOTTOMRIGHT", -12, 40); pw.paste:SetFrameLevel((pw:GetFrameLevel() or 1) + 10); pw.paste:Hide()
  if pw.paste.SetBackdrop then pw.paste:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32 }) end
  pw.hint = pw.paste:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); pw.hint:SetPoint("TOPLEFT", 6, -6); pw.hint:SetPoint("TOPRIGHT", -6, -6); pw.hint:SetJustifyH("LEFT")
  local ps = CreateFrame("ScrollFrame", "RebirthTrackPlanPasteScroll", pw.paste, "UIPanelScrollFrameTemplate")
  ps:SetPoint("TOPLEFT", 6, -26); ps:SetPoint("BOTTOMRIGHT", -28, 6)
  pw.edit = CreateFrame("EditBox", nil, ps); pw.edit:SetMultiLine(true); pw.edit:SetAutoFocus(false); pw.edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall); pw.edit:SetWidth(420)
  if pw.edit.SetMaxLetters then pw.edit:SetMaxLetters(0) end
  pw.edit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  ps:SetScrollChild(pw.edit)
  pw.pasteBtn = CreateFrame("Button", nil, pw, "UIPanelButtonTemplate"); pw.pasteBtn:SetSize(130, 22); pw.pasteBtn:SetPoint("BOTTOMLEFT", 16, 14)
  pw.pasteBtn:SetScript("OnClick", function()
    if pw.paste:IsShown() then pw.paste:Hide() else pw.edit:SetText(""); pw.paste:Show(); pw.edit:SetFocus() end
  end)
  pw.read = CreateFrame("Button", nil, pw, "UIPanelButtonTemplate"); pw.read:SetSize(90, 22); pw.read:SetPoint("LEFT", pw.pasteBtn, "RIGHT", 6, 0)
  pw.read:SetScript("OnClick", function()
    if load(pw.edit:GetText() or "") > 0 then pw.paste:Hide(); sel = nil end
    refresh()
  end)
  pw.clear = CreateFrame("Button", nil, pw, "UIPanelButtonTemplate"); pw.clear:SetSize(120, 22); pw.clear:SetPoint("BOTTOMRIGHT", -16, 14)
  pw.clear:SetScript("OnClick", function() ns.db().plans = {}; sel = nil; say(T("cleared")); refresh() end)
  pw:RegisterEvent("SKILL_LINES_CHANGED"); pw:RegisterEvent("CHARACTER_POINTS_CHANGED"); pw:RegisterEvent("BAG_UPDATE_DELAYED"); pw:RegisterEvent("PLAYER_LEVEL_UP")
  pw:SetScript("OnEvent", function() if pw:IsShown() then refresh() end end)
  if UISpecialFrames then table.insert(UISpecialFrames, "RebirthTrackPlanFrame") end
end

-- /rt plan: abre la ventana (con texto pegado después del comando, lo lee primero).
function ns.openPlan(text)
  if not pw then create() end
  if text and text ~= "" then load(text) end
  pw:Show()
  refresh()
end
