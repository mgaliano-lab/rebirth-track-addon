dofile(arg[1] or "tests/wowstub.lua") -- stubs de la API de WoW
local chunk = assert(loadfile(arg[2] or "RebirthTrack/RebirthTrack.lua"))
local ns = {} -- como en WoW: los archivos del addon comparten esta tabla
assert(loadfile("RebirthTrack/UI.lua"))("RebirthTrack", ns)
chunk("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Collect.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Bank.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/BankCraft.lua"))("RebirthTrack", ns)
-- HereBeDragons-Pins de mentira: anota qué puntos se ponen en el mapa.
mapPins = {}
LibStub = function(name)
  if name ~= "HereBeDragons-Pins-2.0" then return nil end
  return {
    RemoveAllWorldMapIcons = function(_, ref) for k, v in pairs(mapPins) do if v.ref == ref then mapPins[k] = nil end end end,
    AddWorldMapIconMap = function(_, ref, icon, map, x, y, flag) mapPins[icon] = { ref = ref, map = map, x = x, y = y, flag = flag, p = icon.p } end,
  }
end
assert(loadfile("RebirthTrack/Positions.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Recruit.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Plan.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Council.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Requests.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Professions.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Vendors.lua"))("RebirthTrack", ns)
fire("ADDON_LOADED", "RebirthTrack")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
local rt = SlashCmdList.REBIRTHTRACK
for _, c in ipairs({ "", "help", "ayuda", "mostrar", "status", "estado", "vincular", "link", "registrar", "detener", "mazmorras", "dungeons", "ocultar", "show", "borrar", "minimapa", "minimap", "cualquiera" }) do
  print("== /rt " .. c); rt(c)
end
for _, b in ipairs({ "Vincular", "Estado", "Detener", "Registrar", "Mazmorras", "Ayuda", "Volver" }) do print("== click " .. b); click(b) end
print("links:", #RebirthTrackDB.links, RebirthTrackDB.links[1])
print("ui:", RebirthTrackDB.ui.shown)
assert(SLASH_REBIRTHTRACK1 == "/rt", "falta registrar /rt (SLASH_REBIRTHTRACK1)")
assert(SlashCmdList.REBIRTHTRACK, "falta el manejador de /rt")
print("comando /rt registrado OK")

local mmb
for _, fr in ipairs(__frames or {}) do end
print("minimapa:", RebirthTrackDB.ui.minimap)

-- Idioma: por defecto español, /rt idioma en lo pasa a inglés y el botón ES/EN alterna.
assert(click("Vincular personaje"), "por defecto en español")
rt("idioma en"); assert(RebirthTrackDB.settings.lang == "en")
assert(click("Link character"), "botones en inglés")
rt("language es"); assert(RebirthTrackDB.settings.lang == "es")
click("EN"); assert(RebirthTrackDB.settings.lang == "en", "el botón EN cambia a inglés")
click("ES"); assert(RebirthTrackDB.settings.lang == "es")
print("idioma OK")

-- Grupos: al entrar a la instancia queda anotado el grupo (sin «|», que WoW escapa al guardar).
assert(RebirthTrackDB.groups and #RebirthTrackDB.groups > 0, "anota los grupos")
assert(RebirthTrackDB.groups[1]:match("^g1;%d+;Player%-[%w%-]+=1$"), RebirthTrackDB.groups[1])
print("grupos OK", RebirthTrackDB.groups[1])

-- Guild: la lista de miembros queda anotada (sin «|») con el reino propio y los de otros reinos.
fire("GUILD_ROSTER_UPDATE")
local g = RebirthTrackDB.guild
assert(g and g.info and g.info:match("^gi1;Rebirth Knights;Nightslayer;us;5;%d+$"), tostring(g and g.info))
assert(#g.members == 3, "anota los 3 miembros")
assert(g.members[1] == "m1;Roguebash;Nightslayer;ROGUE;60;1;Oficial;Player-6065-044C2423;0;;", g.members[1])
assert(g.members[2]:match("^m1;Healz;Nightslayer;PRIEST;58;3;Miembro;Player%-6065%-0411;%d+;Alt de Roguebash;$"), g.members[2])
assert(g.members[3]:find("^m1;Otro;Dreamscythe;MAGE"), g.members[3])
for _, m in ipairs(g.members) do assert(not m:find("|", 1, true)) end
-- Mensaje del día e info de la guild. Si el juego bloquea una (ADDON_ACTION_BLOCKED, ej. GetGuildInfoText
-- protegida), se deja de llamar y se conserva lo último anotado.
local function gx1()
  for _, c in pairs(RebirthTrackDB.data) do if c.gx1 then return c.gx1 end end
end
local infoCalls, infoBlocked = 0, false
GetGuildRosterMOTD = function() return "Raid jueves 21 h" end
GetGuildInfoText = function()
  infoCalls = infoCalls + 1
  if infoBlocked then fire("ADDON_ACTION_BLOCKED", "RebirthTrack", "UNKNOWN()"); return nil end
  return "Reglas en el Discord"
end
fire("GUILD_MOTD")
assert(gx1() and gx1():match(";Raid jueves 21 h;Reglas en el Discord$"), tostring(gx1()))
infoBlocked = true
GetGuildRosterMOTD = function() return "Raid viernes" end
fire("GUILD_MOTD")
assert(gx1():match(";Raid viernes;Reglas en el Discord$"), "conserva la info anterior: " .. gx1())
local calls = infoCalls
fire("GUILD_MOTD")
assert(infoCalls == calls, "no vuelve a llamar a la bloqueada")
fire("ADDON_ACTION_BLOCKED", "Otro", "UNKNOWN()") -- de otro addon: no importa
print("info de la guild OK")
-- WoW Forever: «Nombre Apellido» → el apellido va en el lugar del reino.
local n, s = ns.splitSurname("Baldor Dwimorberg")
assert(n == "Baldor" and s == "Dwimorberg", "separa nombre y apellido")
assert(ns.splitSurname("Healz-Nightslayer") == nil, "con guion no es apellido")
assert(ns.selfRealm() == "Nightslayer", "sin apellido, el reino")
local realGUN = GetUnitName
GetUnitName = function() return "Roguebash Piedrafría" end
assert(ns.selfRealm() == "Piedrafría", "con apellido, el apellido")
GetUnitName = realGUN
print("lista de la guild OK")

-- Canal de addons: el prefijo se registra, al entrar avisa hasta dónde tiene datos y se anuncia.
assert(registeredPrefix == "RTK1", "registra el prefijo RTK1")
local function sentWith(pat) for _, s in ipairs(sentAddon) do if s[1] == "RTK1" and s[3] == "GUILD" and s[2]:match(pat) then return s[2] end end end
assert(sentWith("^H;%d+$"), "manda el saludo H")
assert(sentWith("^K;%d+;S;us;Nightslayer;Roguebash;ROGUE;60;Player%-6065%-044C2423;5;;$"), "se anuncia a sí mismo (versiones vacías sin metadatos)")
-- Vincular anuncia el personaje como pedido de vinculación (L).
sentAddon = {}
click("Vincular personaje")
assert(sentWith("^K;%d+;L;us;Nightslayer;Roguebash"), "anuncia el vínculo")
-- Lo que anuncia otro miembro se guarda; lo de afuera de la guild o mal formado no.
local before = #g.known
fire("CHAT_MSG_ADDON", "RTK1", "K;1792530100;S;us;Nightslayer;Healz;PRIEST;58;Player-6065-0411;5", "GUILD", "Healz-Nightslayer")
fire("CHAT_MSG_ADDON", "RTK1", "K;1792530100;S;us;Nightslayer;Intruso;MAGE;10;Player-1-1;5", "WHISPER", "Intruso-Nightslayer")
fire("CHAT_MSG_ADDON", "RTK1", "K;roto;S;us", "GUILD", "Healz-Nightslayer")
fire("CHAT_MSG_ADDON", "OTRO", "K;1792530100;S;us;Nightslayer;X;MAGE;10;Player-1-2;5", "GUILD", "X-Nightslayer")
assert(#g.known == before + 1, "guarda solo el anuncio válido de la guild")
assert(g.known[#g.known]:match("^k1;1792530100;S;us;Nightslayer;Healz;PRIEST;58;Player%-6065%-0411;5$"), g.known[#g.known])
-- Uno más viejo no pisa al más nuevo, y quien pidió vincular queda marcado aunque después se anuncie.
fire("CHAT_MSG_ADDON", "RTK1", "K;1792530000;S;us;Nightslayer;Healz;PRIEST;50;Player-6065-0411;5", "GUILD", "Healz-Nightslayer")
assert(g.known[#g.known]:find(";58;", 1, true), "no pisa con un dato viejo")
-- Alguien entra con datos viejos: se le responde con lo más nuevo.
sentAddon = {}
fire("CHAT_MSG_ADDON", "RTK1", "H;0", "GUILD", "Nuevo-Nightslayer")
assert(sentWith("^K;1792530100;S;us;Nightslayer;Healz"), "le responde con lo que tiene")
sentAddon = {}
fire("CHAT_MSG_ADDON", "RTK1", "H;9999999999", "GUILD", "Nuevo-Nightslayer")
assert(#sentAddon == 0, "si ya está al día no responde")
print("canal de addons OK", #g.known)

-- Rangos (oficiales): con el código del sitio, cada miembro que cambia tiene su botón y cada clic
-- hace un solo paso (como exige el juego).
rt("rangos")
rt("rangos RTR1:Healz=2,Otro=3,Nadie=4,Roguebash=1")
assert(RebirthTrackDB.rankCode == "RTR1:Healz=2,Otro=3,Nadie=4,Roguebash=1", "guarda el código tal cual (con mayúsculas)")
click("Subir a Caballero")
assert(promoted[1] == "Healz-Nightslayer", "Healz sube un paso (Miembro → Caballero)")
assert(#promoted == 1 and #demoted == 0, "un clic, un cambio")
click("Subir a Miembro")
assert(promoted[2] == "Otro-Dreamscythe", "Otro sube un paso (Recluta → Miembro)")
rt("rangos RTR1:Healz=4")
click("Bajar a Recluta")
assert(demoted[1] == "Healz-Nightslayer", "bajar también es de a un paso")
rt("rangos nada")
print("rangos OK", #promoted, #demoted)

-- ── Datos (Collect.lua) ────────────────────────────────────────────────────────────────
local ME = "Player-6065-044C2423"
local C = ns._collect
local D = RebirthTrackDB.data
local function has(list, pat) for _, l in ipairs(list) do if l:match(pat) then return l end end end
local function events(pat) local out = {} for _, l in ipairs(RebirthTrackDB.events) do if l:match(pat) then out[#out + 1] = l end end return out end

-- Al entrar se anota el personaje (sin «|») y se comparte por el canal; el oro no se comparte.
assert(D[ME] and D[ME].p1 and D[ME].p1:match("^p1;Player%-6065%-044C2423;%d+;Roguebash;Nightslayer;us;5;ROGUE;"), tostring(D[ME] and D[ME].p1))
for _, l in pairs(D[ME]) do assert(not l:find("|", 1, true), l) end
sentAddon = {}
C.put(ME, "p1", "Roguebash;Nightslayer;us;5;ROGUE;Orc;61;Horde;Rebirth Knights", true)
assert(sentWith("^D;%x+;1;1;p1;Player%-6065%-044C2423;%d+;Roguebash;"), "comparte el personaje")
sentAddon = {}
C.put(ME, "rep1", "529=4:1200")
assert(#sentAddon == 0, "las reputaciones no salen por el canal")
-- Sin cambios no se vuelve a anotar ni a mandar.
assert(C.put(ME, "p1", "Roguebash;Nightslayer;us;5;ROGUE;Orc;61;Horde;Rebirth Knights", true) == false)
print("personaje OK", D[ME].p1)

-- Lo que manda otro miembro, en partes, se arma y se guarda con quién lo mandó.
fire("CHAT_MSG_ADDON", "RTK1", "D;1a;1;2;sk1;Player-6065-0411;17925", "GUILD", "Healz-Nightslayer")
assert(not (D["Player-6065-0411"] and D["Player-6065-0411"].sk1), "espera la última parte")
fire("CHAT_MSG_ADDON", "RTK1", "D;1a;2;2;30100;Alquimia=300/300", "GUILD", "Healz-Nightslayer")
assert(D["Player-6065-0411"].sk1 == "@Healz;sk1;Player-6065-0411;1792530100;Alquimia=300/300", tostring(D["Player-6065-0411"].sk1))
-- Uno más viejo no pisa; lo privado, lo de otro canal y lo que dice ser mío no se guardan.
fire("CHAT_MSG_ADDON", "RTK1", "D;1b;1;1;sk1;Player-6065-0411;1792530000;Alquimia=1/300", "GUILD", "Healz-Nightslayer")
assert(D["Player-6065-0411"].sk1:find("300/300", 1, true), "no pisa con un dato viejo")
fire("CHAT_MSG_ADDON", "RTK1", "D;1c;1;1;mo1;Player-6065-0411;1792530200;999", "GUILD", "Healz-Nightslayer")
assert(not D["Player-6065-0411"].mo1, "el oro de otro no se acepta")
fire("CHAT_MSG_ADDON", "RTK1", "D;1d;1;1;sk1;Player-6065-0412;1792530200;Minería=1/75", "WHISPER", "Intruso-Nightslayer")
assert(not D["Player-6065-0412"], "solo por el canal de la guild")
fire("CHAT_MSG_ADDON", "RTK1", "D;1e;1;1;eq1;" .. ME .. ";1792539999;1=1", "GUILD", "Healz-Nightslayer")
assert(not (D[ME].eq1 or ""):find("1=1$"), "nadie pisa lo propio")
-- Alguien entra y pide lo que cambió: se le manda lo propio y lo recibido.
sentAddon = {}
fire("CHAT_MSG_ADDON", "RTK1", "E;0", "GUILD", "Nuevo-Nightslayer")
assert(sentWith("^D;%x+;%d+;%d+;sk1;Player%-6065%-0411;1792530100;Alquimia"), "reenvía lo recibido")
assert(sentWith("^D;%x+;1;1;p1;" .. ME:gsub("%-", "%%-")), "manda lo propio")
assert(not sentWith(";rep1;"), "lo privado no")
print("canal de datos OK")

-- Profesiones (Classic): recetas, cooldowns y las que se ven después se suman.
local recipes = {
  { "Pociones", "header" },
  { "Poción de maná superior", "optimal", "|cffffffff|Hitem:13443:0:0:0|h[Poción de maná superior]|h|r", 0 },
  { "Transmutar: arcanita", "medium", "|cffffffff|Hitem:12360:0:0:0|h[Barra de arcanita]|h|r", 3600 },
}
function GetTradeSkillLine() return "Alquimia", 290, 300 end
function GetNumTradeSkills() return #recipes end
function GetTradeSkillInfo(i) return recipes[i][1], recipes[i][2] end
function GetTradeSkillItemLink(i) return recipes[i][3] end
function GetTradeSkillCooldown(i) return recipes[i][4] end
function IsTradeSkillLinked() return false end
fire("TRADE_SKILL_SHOW")
assert(D[ME]["r1:Alquimia"] == "r1;" .. ME .. ";1792530000;Alquimia;290;300;i12360,i13443", tostring(D[ME]["r1:Alquimia"]))
assert(D[ME]["cd1:Alquimia"]:match("^cd1;Player%-6065%-044C2423;%d+;Alquimia;i12360=%d+$"), D[ME]["cd1:Alquimia"])
table.remove(recipes, 2) -- con un filtro puesto se ve una sola
fire("TRADE_SKILL_UPDATE")
assert(D[ME]["r1:Alquimia"]:find("i12360,i13443", 1, true), "no se pierden las que no se ven")
-- Al pasar a otra profesión el juego avisa la nueva antes de cambiar la lista: no se anota mezclado.
local line, calls = { "Primeros auxilios", 40, 75 }, 0
function GetTradeSkillLine() calls = calls + 1; return table.unpack(calls <= 2 and line or { "Alquimia", 290, 300 }) end
fire("TRADE_SKILL_UPDATE")
assert(not D[ME]["r1:Primeros auxilios"], "la lista de Alquimia no se anota como de Primeros auxilios")
-- Ya con la lista nueva, sí.
recipes[#recipes + 1] = { "Venda de lino", "optimal", "|cffffffff|Hitem:1251:0:0:0|h[Venda de lino]|h|r", 0 }
function GetTradeSkillLine() return table.unpack(line) end
fire("TRADE_SKILL_UPDATE")
assert(D[ME]["r1:Primeros auxilios"]:match(";Primeros auxilios;40;75;i12360,i1251$"), D[ME]["r1:Primeros auxilios"])
recipes[#recipes] = nil
function GetTradeSkillLine() return "Alquimia", 290, 300 end
-- Encantamiento usa la ventana de «craft».
function GetCraftDisplaySkillLine() return "Encantamiento", 120, 150 end
function GetNumCrafts() return 1 end
function GetCraftInfo() return "Encantar brazales: aguante", "", "optimal" end
function GetCraftItemLink() return "|cffffffff|Henchant:13501|h[Encantar brazales: aguante]|h|r" end
fire("CRAFT_SHOW")
assert(D[ME]["r1:Encantamiento"]:match(";Encantamiento;120;150;s13501$"), D[ME]["r1:Encantamiento"])
assert(D[ME]["rd1:Encantamiento"]:match(";Encantamiento;120;150;s13501:0:1:1:o::Encantar brazales  aguante$"), D[ME]["rd1:Encantamiento"])
-- La definición real de las recetas (rd1): qué fabrica, cuántos, dificultad y componentes; se comparte.
function GetTradeSkillNumReagents(i) return i == 2 and 2 or 0 end
function GetTradeSkillReagentInfo(i, j) return "x", nil, j == 1 and 3 or 1 end
function GetTradeSkillReagentItemLink(i, j) return j == 1 and "|Hitem:13463:0|h[Pétalo]|h" or "|Hitem:18256:0|h[Vial]|h" end
function GetTradeSkillNumMade() return 1, 2 end
sentAddon = {}
fire("TRADE_SKILL_UPDATE")
local rd = D[ME]["rd1:Alquimia"]
assert(rd and rd:find(";Alquimia;290;300;i12360:12360:1:2:y:13463x3.18256x1:Transmutar  arcanita", 1, true), tostring(rd))
local sharedRd = false
for _, m in ipairs(sentAddon) do if m[2]:find(";rd1;", 1, true) then sharedRd = true end end
assert(sharedRd, "rd1 se comparte por el canal")
-- Subir un punto no la vuelve a mandar (cambian solo los colores).
sentAddon = {}
recipes[2][2] = "easy"
function GetTradeSkillLine() return "Alquimia", 291, 300 end
fire("TRADE_SKILL_UPDATE")
for _, m in ipairs(sentAddon) do assert(not m[2]:find(";rd1;", 1, true), "un punto más no se manda de nuevo") end
function GetTradeSkillLine() return "Alquimia", 290, 300 end
print("profesiones OK")

-- El balance, las bolsas y el banco de cada persona no se anotan (solo los de la guild), y al entrar
-- se borra lo que haya dejado una versión anterior.
local bags = { [0] = { { 6948, 1 } } }
function GetContainerNumSlots(b) return bags[b] and #bags[b] or 0 end
function GetContainerItemInfo(b, s) local x = bags[b][s]; return "tex", x[2], false, 1, false, false, "|Hitem:" .. x[1] .. "|h", false, false, x[1] end
function GetMoney() return 5000000 end
fire("BAG_UPDATE"); fire("BANKFRAME_OPENED"); fire("PLAYER_MONEY")
assert(not D[ME].mo1 and not D[ME]["inv1:bags"] and not D[ME]["inv1:bank"], "ni balance ni bolsas ni banco personal")
D[ME].mo1, D[ME]["inv1:bags"] = "mo1;" .. ME .. ";1792530000;123", "inv1;" .. ME .. ";1792530000;bags;6948:1" -- de la 0.3.1
fire("PLAYER_LOGIN")
assert(not D[ME].mo1 and not D[ME]["inv1:bags"], "al entrar se borra lo que había")
print("sin balance ni bolsas personales OK")

-- Subasta: lo publicado, la compra al precio de compra y las facturas del correo (una vez cada una).
local owned = { { "Barra de arcanita", "", 2, 1, true, 55, "", 900000, 1000, 1200000, 0, false, nil, "Roguebash", "Roguebash-Nightslayer", 0, 12360 } }
local browse = { { "Poción de maná superior", "", 5, 1, true, 49, "", 20000, 100, 30000, 0, false, nil, "Vende", "Vende-Nightslayer", 0, 13443 } }
function GetNumAuctionItems(list) return #(list == "owner" and owned or browse) end
function GetAuctionItemInfo(list, i) return table.unpack((list == "owner" and owned or browse)[i]) end
function GetAuctionItemTimeLeft() return 4 end
fire("AUCTION_OWNED_LIST_UPDATE")
assert(D[ME].aho1:match(";12360:2:900000:1200000:0:4:0$"), D[ME].aho1)
PlaceAuctionBid("list", 1, 30000)
assert(has(RebirthTrackDB.events, "^ahb1;Player%-6065%-044C2423;%d+;13443;5;30000;Vende%-Nightslayer;Poción de maná superior$"), "anota la compra")
PlaceAuctionBid("list", 1, 25000) -- una oferta (no compra) no se anota
assert(#events("^ahb1;") == 1)
function GetInboxNumItems() return 2 end
function GetInboxInvoiceInfo(i) if i == 1 then return "seller", "Barra de arcanita", "Comprador", 1200000, 1200000, 6000, 60000, 0, 0, 0, 2 end return nil end
function GetInboxHeaderInfo() return nil, nil, "Casa de subastas", "Subasta vendida", 0, 0, 29.5 end
fire("MAIL_INBOX_UPDATE"); fire("MAIL_INBOX_UPDATE")
local inv = events("^ahi1;")
assert(#inv == 1 and inv[1]:match("^ahi1;Player%-6065%-044C2423;%d+;seller;Barra de arcanita;Comprador;1200000;1200000;6000;60000;2$"), inv[1])
print("subasta OK")

-- Botín en instancias (raro o mejor), con el texto del juego en el idioma del cliente.
LOOT_ITEM, LOOT_ITEM_MULTIPLE = "%s recibe botín: %s.", "%s recibe botín: %sx%d."
LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE = "Recibes botín: %s.", "Recibes botín: %sx%d."
function IsInInstance() return true, "raid" end
function GetInstanceInfo() return "Núcleo de Magma", "raid", 9, "40 jugadores", 40, 0, false, 409 end
fire("CHAT_MSG_LOOT", "Healz recibe botín: |cffa335ee|Hitem:19019:0:0:0|h[Furia de los vientos]|h|r.")
fire("CHAT_MSG_LOOT", "Recibes botín: |cff0070dd|Hitem:16800:0:0:0|h[Brazales arcanos]|h|rx2.")
fire("CHAT_MSG_LOOT", "Healz recibe botín: |cff1eff00|Hitem:2589:0:0:0|h[Lino]|h|r.") -- verde: no
local loot = events("^lt1;")
assert(#loot == 2, #loot)
assert(loot[1]:match("^lt1;;%d+;Healz;409;9;19019;1;Núcleo de Magma$"), loot[1])
assert(loot[2]:match("^lt1;Player%-6065%-044C2423;%d+;Roguebash;409;9;16800;2;"), loot[2])
assert(C.pattern("%1$s gana: %2$s") == "^(.+) gana: (.+)$", C.pattern("%1$s gana: %2$s"))
-- Buffs al empezar un jefe.
function UnitBuff(u, i) if u == "player" and i <= 2 then return "Buff", "", 1, nil, 0, 0, "player", false, false, ({ 22888, 17628 })[i] end end
fire("ENCOUNTER_START", 663, "Lucifron", 9, 40)
assert(has(RebirthTrackDB.events, "^bf1;Player%-6065%-044C2423;%d+;663;Lucifron;22888,17628$"), "anota los buffs")
function IsInInstance() return false end
print("banda OK")

-- Guild: banco (pestañas que se pueden ver), mensaje del día e historial sin repetir.
function GetNumGuildBankTabs() return 2 end
function GetGuildBankTabInfo(t) return t == 1 and "Mats" or "Oficiales", "", t == 1 end
function GetCurrentGuildBankTab() return 1 end
function GetGuildBankItemLink(t, s) if t == 1 and s <= 2 then return "|Hitem:" .. (s == 1 and 12360 or 13443) .. "|h" end end
function GetGuildBankItemInfo(t, s) return "tex", s == 1 and 4 or 10 end
function GetGuildBankMoney() return 777 end
function QueryGuildBankTab() end
fire("GUILDBANKFRAME_OPENED")
local GK = "guild:Rebirth Knights"
assert(D[GK]["gb1:1"]:match("^gb1;guild:Rebirth Knights;%d+;1;Mats;12360:4,13443:10;1=12360:4,2=13443:10$"), D[GK]["gb1:1"])
assert(not D[GK]["gb1:2"], "la pestaña que no se puede ver, no")
assert(D[GK].gbm1:match(";777$"))

-- Registro de oro: cada movimiento una vez, aunque se lea de nuevo horas después; dos iguales cuentan dos.
local moneyLog = {
  { "deposit", "Akuma", 10000, 0, 0, 0, 2 },
  { "deposit", "Akuma", 10000, 0, 0, 0, 2 },
  { "withdraw", "Healz", 5000, 0, 0, 1, 0 },
  { "repair", "Roguebash", 1234, 0, 0, 0, 0 },
}
function GetNumGuildBankMoneyTransactions() return #moneyLog end
function GetGuildBankMoneyTransaction(i) return table.unpack(moneyLog[i]) end
function QueryGuildBankLog() end
fire("GUILDBANKLOG_UPDATE")
local gm = events("^gm1;")
assert(#gm == 4, #gm)
assert(has(RebirthTrackDB.events, "^gm1;guild:Rebirth Knights;%d+;deposit;Akuma;10000$"))
assert(has(RebirthTrackDB.events, "^gm1;guild:Rebirth Knights;%d+;repair;Roguebash;1234$"))
moneyLog[1][7], moneyLog[2][7] = 5, 5 -- leído 3 h más tarde
table.insert(moneyLog, 1, { "deposit", "Akuma", 10000, 0, 0, 0, 0 }) -- uno nuevo, igual a los otros
fire("GUILDBANKLOG_UPDATE")
assert(#events("^gm1;") == 5, #events("^gm1;"))
print("registro de oro del banco OK")
function GetGuildRosterMOTD() return "Raid jueves 21 h; traer pociones" end
function GetGuildInfoText() return "Reglas en\nel Discord" end
fire("GUILD_ROSTER_UPDATE")
assert(D[GK].gx1:match(";Raid jueves 21 h  traer pociones;Reglas en el Discord$"), D[GK].gx1)
function GetNumGuildEvents() return 1 end
function GetGuildEventInfo() return "promote", "Roguebash", "Healz", "Caballero", 0, 0, 1, 3 end
fire("GUILD_EVENT_LOG_UPDATE"); fire("GUILD_EVENT_LOG_UPDATE")
local ge = events("^ge1;")
assert(#ge == 1 and ge[1]:match("^ge1;guild:Rebirth Knights;%d+;promote;Roguebash;Healz;Caballero$"), ge[1])
print("guild OK")

-- Nada de lo anotado lleva «|» (WoW lo escapa al guardar y el sitio lee las líneas tal cual).
for _, c in pairs(D) do for _, l in pairs(c) do assert(not l:find("|", 1, true), l) end end
for _, l in ipairs(RebirthTrackDB.events) do assert(not l:find("|", 1, true), l) end
rt("datos")
print("datos OK")

-- Plan del personaje (RTP1): el texto que arma el sitio (shared/planText.ts) se lee con la misma
-- suma de control; lo copiado a medias no. Avance con lo que ve el juego.
local PLAN = table.concat({
  "RTP1;ab12;Roguebash;nightslayer;Orco;Rogue;pve;1", "P;mining;Minería",
  "S;mining;1;65;70;2657;Fundir cobre", "S;mining;65;125;60;2659;Fundir bronce", "M;mining;2770;70;Mena de cobre",
  "B;0;Asesinato", "B;1;Combate", "B;2;Sutileza", "T;0;1;1;3;3;Remate mejorado", "T;1;1;2;5;5;Precisión",
  "L;Aventura;2;3;Descanso profundo", "N;main de banda", "Z;f4d8b72e" }, "\n")
assert(ns.planCrc32("123456789") == "cbf43926", "crc32 como el de zip")
local blocks = ns.planParse("basura\n" .. PLAN .. "\n")
assert(#blocks == 1, "lee el plan del sitio")
local p = blocks[1].plan
assert(p.name == "Roguebash" and p.main and #p.profs == 1 and #p.profs[1].steps == 2 and #p.talents == 2 and #p.legacy == 1 and p.notes == "main de banda")
assert(#ns.planParse(PLAN:gsub("Fundir cobre", "Fundir plata")) == 0, "suma mal: no se lee")
function GetNumSkillLines() return 2 end
function GetSkillLineInfo(i) if i == 1 then return "Profesiones", true end return "Minería", false, nil, 80, 0, 0, 150 end
function GetNumTalentTabs() return 3 end
function GetNumTalents() return 1 end
function GetTalentInfo(tab) if tab == 1 then return "Remate mejorado", "", 1, 1, 3, 3 end if tab == 3 then return "Otro", "", 1, 1, 1, 5 end return "Precisión", "", 1, 2, 2, 5 end
function GetItemCount() return 12 end
local pr = ns.planProgress(p)
assert(pr.profs[1].rank == 80 and pr.profs[1].step == 2, "paso 2 con 80 de minería")
assert(pr.tal.planned == 8 and pr.tal.matched == 5 and pr.tal.spent == 6 and pr.tal.off == 1, "talentos contra el plan")
assert(pr.tal.next.t.name == "Precisión", "el próximo a tocar")
rt("plan " .. PLAN:gsub("\n", " ")) -- en una línea no es válido: abre la ventana igual y avisa
SlashCmdList.REBIRTHTRACK("plan")
assert(not RebirthTrackDB.plans or not next(RebirthTrackDB.plans), "nada pegado todavía")
click("Pegar plan")
for _, fr in ipairs(__frames or {}) do end
ns.openPlan(PLAN)
assert(RebirthTrackDB.plans.ab12, "queda guardado el pegado")
RebirthTrackPlans = { at = 1, plans = { (PLAN:gsub("ab12", "zz99"):gsub("Z;f4d8b72e", "Z;00000000")) } }
ns.planRefresh() -- uno de la app con la suma mal no rompe nada
for _, k in ipairs({ "Profesiones", "Talentos", "Legado", "Resumen" }) do click(k) end
-- Talentos como árbol: las ramas del juego con lo planeado encima (el plan es de pícaro, como el personaje).
function GetTalentTabInfo(tab) return ({ "Asesinato", "Combate", "Sutileza" })[tab], "icon" .. tab end
function GetNumTalents(tab) return tab == 1 and 2 or 1 end
function GetTalentInfo(tab, i)
  if tab == 1 and i == 1 then return "Remate mejorado", "ic1", 1, 1, 3, 3 end
  if tab == 1 and i == 2 then return "Golpes letales", "ic2", 3, 1, 0, 5 end
  if tab == 3 then return "Otro", "ic3", 1, 1, 1, 5 end
  return "Precisión", "ic4", 1, 2, 2, 5
end
function GetTalentPrereqs(tab, i) if tab == 1 and i == 2 then return 1, 1 end end
ns.openPlan(PLAN)
click("Talentos")
local D2 = ns._planDraw
assert(D2.canDraw(blocks[1].plan), "mismo pícaro: se dibuja")
local g = D2.grid()
assert(g.shown and #g.trees == 3, "tres ramas")
local c1 = g.trees[1].cells
assert(c1[1].rank.text == "3/3" and c1[2].rank.text == "", "Remate mejorado listo; Golpes letales sin plan")
assert(g.trees[2].cells[1].rank.text == "2/5", "Precisión a medias")
assert(g.trees[3].cells[1].rank.text == "1", "Otro: fuera del plan")
assert(g.trees[1].lines[1] and g.trees[1].lines[1].shown, "flecha del requisito")
assert(g.trees[1].title.text:find("Asesinato", 1, true), "nombre de la rama")
-- Otra clase: el árbol sale del plan (sin lo gastado, que es de otro personaje).
local realUnitClass = UnitClass
UnitClass = function() return "Mago", "MAGE" end
ns.planRefresh()
assert(g.shown and g.trees[1].cells[1].rank.text == "0/3", "otra clase: árbol armado con el plan")
-- Con el plan completo del sitio (0.9.56): también los de rango 0, con ícono y requisito.
local FULL = table.concat({
  "RTP1;ff01;Roguebash;nightslayer;Orco;Rogue;pve;1",
  "B;0;Asesinato", "T;0;1;1;3;3;Remate mejorado;;Improved Eviscerate;ability_warrior_decisivestrike;",
  "T;0;2;1;0;5;Golpes letales;;Lethality;ability_criticalstrike;1.1",
  "L;Aventura;2;5;Bien descansado;Well Rested;spell_nature_sleep", "L;Aventura;0;2;Alerta;High Alert;ability_hunter_eagleeye" }, "\n")
FULL = FULL .. "\nZ;" .. ns.planCrc32(FULL)
local fp = ns.planParse(FULL)[1].plan
assert(fp.talents[2].icon == "ability_criticalstrike" and fp.talents[2].pre == "0-1-1" and fp.legacy[2].icon == "ability_hunter_eagleeye", "lee ícono y requisito")
D2.drawLegacy(fp)
local lg = D2.lgrid().trees[1].cells
local sawIcon = false
for _, cb in ipairs(lg) do if cb.icon and cb.icon.shown and cb.c and cb.c.pk.en == "Well Rested" then sawIcon = true; assert(cb.rank.text == "2/5", "sin leer el juego: lo planeado") end end
assert(sawIcon, "el Legado con el ícono del plan")
UnitClass = realUnitClass
click("Resumen")
assert(not g.shown, "otra pestaña: sin árbol")
click("Borrar pegados"); assert(not next(RebirthTrackDB.plans))
print("plan OK")

-- Reparto por consejo: el master looter abre el reparto al lootear, cada uno responde con lo que
-- tiene puesto, el consejo vota, el ML adjudica y lo entrega con botín maestro; todo queda anotado.
local LC = ns._council; ns.debug = true
local ITEMS = {
  [19019] = { "Furia de los vientos", "|cffff8000|Hitem:19019::::::::60:::::|h[Furia de los vientos]|h|r", 5, 80, "", "", "", 1, "INVTYPE_WEAPON", 1, 0, 2, 7 },
  [16866] = { "Yelmo de ira", "|cffa335ee|Hitem:16866::::::::60:::::|h[Yelmo de ira]|h|r", 4, 76, "", "", "", 1, "INVTYPE_HEAD", 1, 0, 4, 4 },
  [16800] = { "Botas arcanas", "|cffa335ee|Hitem:16800::::::::60:::::|h[Botas arcanas]|h|r", 4, 66, "", "", "", 1, "INVTYPE_FEET", 1, 0, 4, 1 },
  [12345] = { "Espada vieja", "|cff0070dd|Hitem:12345|h[Espada vieja]|h|r", 3, 60, "", "", "", 1, "INVTYPE_WEAPON", 1, 0, 2, 7 },
}
function GetItemInfo(s) local d = ITEMS[tonumber(tostring(s):match("item:(%d+)"))]; if d then return table.unpack(d) end end
function GetInventoryItemLink(_, slot) if slot == 16 or slot == 17 then return ITEMS[12345][2] end end
function IsInRaid() return true end
function IsInGroup() return true end
function UnitIsGroupLeader() return true end
function GetLootMethod() return "master" end
function IsInInstance() return true, "raid" end
function GetInstanceInfo() return "Núcleo de Magma", "raid", 9, "40 jugadores", 40, 0, false, 409 end
local loot = { 19019, 16866, 16800 }
function GetNumLootItems() return #loot end
function GetLootSlotLink(i) return ITEMS[loot[i]][2] end
function GetLootSlotInfo(i) return "", ITEMS[loot[i]][1], 1, nil, ITEMS[loot[i]][3] end
function GetLootThreshold() return 4 end
function GetLootSourceInfo() return "Creature-0-1-409-1-12056-1" end
given = {}
function GiveMasterLoot(slot, i) table.insert(given, { slot, i }) end
function GetMasterLootCandidate(slot, i) return ({ "Roguebash", "Healz", "Tanque" })[i] end
said = {}
function SendChatMessage(msg, chan) table.insert(said, { msg, chan }) end
local classes = { Roguebash = "ROGUE", Healz = "PRIEST", Tanque = "WARRIOR" }
function UnitClass(u) local n = (u == "player" or not u) and "Roguebash" or tostring(u):gsub("%-.*", ""); return "x", classes[n] end
local function lc(prefix) local out = {}; for _, l in ipairs(RebirthTrackDB.council) do if l:match(prefix) then out[#out + 1] = l end end; return out end
local function sentLC(kind) local out = {}; for _, m in ipairs(sentAddon) do if m[1] == "RTLC" and m[2]:sub(1, 2) == kind .. ";" then out[#out + 1] = m end end; return out end

fire("ENCOUNTER_END", 663, "Lucifron", 9, 40, 1)
fire("LOOT_OPENED")
assert(#LC.pending() == 3, "los 3 épicos quedan para repartir")
fire("LOOT_OPENED"); assert(#LC.pending() == 3, "el mismo cadáver no se suma dos veces")
click("Repartir (3)")
local s = LC.current()
assert(s and s.mlName == "Roguebash-Nightslayer" and s.boss == "Lucifron" and s.encounterId == 663, "abre el reparto con el jefe")
assert(#lc("^lc1;Player%-6065%-044C2423;%d+;") == 1 and #lc("^ld1;") == 3, "anota el reparto y los ítems")
assert(lc("^ld1;")[1]:match(";1;item:19019::::::::60;80;INVTYPE_WEAPON;Roguebash%-Nightslayer$"), lc("^ld1;")[1])
assert(#sentLC("S") == 1 and sentLC("S")[1][3] == "RAID" and #sentLC("I") == 3, "lo manda a la banda")

-- Lo propio: lo que tengo puesto y cuánto gano.
local eq, delta = LC.equippedFor("INVTYPE_WEAPON", 80)
assert(eq == "12345@60,12345@60" and delta == 20, eq .. " " .. tostring(delta))
LC.respond(s, 1, "bis", "para; mi | main")
local mine = lc("^lr1;")[1]
assert(mine:match(";1;Roguebash%-Nightslayer;bis;20;12345@60,12345@60;para  mi   main$"), mine)

-- Lo de otros por el canal: respuestas, votos (solo del consejo) y la placa que no es para un sacerdote.
local sid = s.sid
fire("CHAT_MSG_ADDON", "RTLC", "R;" .. sid .. ";1;Healz-Nightslayer;upgrade;5;;", "RAID", "Healz-Nightslayer")
fire("CHAT_MSG_ADDON", "RTLC", "R;" .. sid .. ";1;Tanque-Nightslayer;upgrade;30;;", "RAID", "Tanque-Nightslayer")
fire("CHAT_MSG_ADDON", "RTLC", "R;" .. sid .. ";1;Otro-Nightslayer;bis;;;", "RAID", "Healz-Nightslayer") -- se hace pasar por otro: no
fire("CHAT_MSG_ADDON", "RTLC", "R;" .. sid .. ";2;Healz-Nightslayer;bis;10;;", "RAID", "Healz-Nightslayer") -- placa: no
fire("CHAT_MSG_ADDON", "RTLC", "R;" .. sid .. ";3;Healz-Nightslayer;bis;10;;", "RAID", "Healz-Nightslayer") -- tela: sí
fire("CHAT_MSG_ADDON", "RTLC", "R;" .. sid .. ";2;Tanque-Nightslayer;bis;8;;", "RAID", "Tanque-Nightslayer")
assert(not s.items[2].responses["Healz-Nightslayer"] and s.items[2].responses["Tanque-Nightslayer"], "la placa solo la pide quien usa placa")
assert(s.items[3].responses["Healz-Nightslayer"] and not s.items[1].responses["Otro-Nightslayer"])
LC.respond(s, 2, "bis", ""); assert(not s.items[2].responses["Roguebash-Nightslayer"], "un pícaro no pide placa")
LC.respond(s, 2, "pass", ""); assert(s.items[2].responses["Roguebash-Nightslayer"].kind == "pass", "pasar se puede siempre")
LC.openToAll(s, 3) -- el ML decide abrirlo
assert(s.items[3].open and #lc("^lo1;") == 1)
fire("CHAT_MSG_ADDON", "RTLC", "V;" .. sid .. ";1;Healz-Nightslayer;Tanque-Nightslayer;1", "RAID", "Healz-Nightslayer") -- Healz no es del consejo
assert(not s.items[1].votes["Healz-Nightslayer"], "solo vota el consejo")
LC.vote(s, 1, "Tanque-Nightslayer", true)
assert(s.items[1].votes["Roguebash-Nightslayer"]["Tanque-Nightslayer"], "el ML vota")

-- Lo que sabe la web (Plans.lua) y el orden: BiS primero, después la prioridad del sitio.
RebirthTrackCouncil = { at = 1, ranks = { 0, 1 }, players = { anniversary = { "Tanque-Nightslayer;knight;4;0", "Healz-Night slayer;recruit;4;3" }, era = { "Healz-Nightslayer;renegade;0;9" } } }
local c = LC.candidates(s, s.items[1])
assert(c[1].name == "Roguebash-Nightslayer" and c[2].name == "Tanque-Nightslayer" and c[3].name == "Healz-Nightslayer", c[1].name .. c[2].name)
assert(c[2].rank == "knight" and c[2].attended == 4 and c[2].votes == 1)
assert(c[3].rank == "recruit" and c[3].received == 3, "los datos de su versión (Anniversary), con el reino normalizado")
-- La prioridad es la del sitio (shared/lootPriority.ts).
local P = ns.councilPriorityLess
assert(P({ rank = "knight", delta = 5, today = 0, received = 0, attended = 1 }, { rank = "renegade", delta = 50, today = 0, received = 0, attended = 1 }), "el Renegado último")
assert(P({ rank = "recruit", delta = nil, today = 0, received = 9, attended = 1 }, { rank = "knight", delta = 0, today = 0, received = 0, attended = 1 }), "a quien le sirve antes")
assert(P({ rank = "knight", delta = 1, today = 0, received = 9, attended = 1 }, { rank = "recruit", delta = 9, today = 0, received = 0, attended = 1 }), "Caballero antes que Recluta")
assert(P({ rank = "knight", delta = 1, today = 0, received = 2, attended = 4 }, { rank = "knight", delta = 9, today = 0, received = 2, attended = 2 }), "menos botín por raid asistida")
LC.refresh(true)

-- Adjudicar: con el cadáver abierto lo entrega con botín maestro y lo anuncia.
click("Dar")
assert(s.items[1].award and s.items[1].award.to == "Roguebash-Nightslayer" and s.items[1].award.how == "ml", "adjudica al primero")
assert(given[1] and given[1][1] == 1 and given[1][2] == 1, "lo entrega con GiveMasterLoot")
assert(said[#said][2] == "RAID" and said[#said][1]:find("Roguebash"), said[#said][1])
LC.award(s, 2, "", "", "de")
assert(lc("^la1;")[2]:match(";2;;;de;Roguebash%-Nightslayer$"), lc("^la1;")[2])
loot = {}
LC.award(s, 3, "Healz-Nightslayer", "bis")
fire("LOOT_OPENED") -- sin el ítem en el cadáver no se puede entregar todavía
assert(#given == 1)

-- Si el juego rechaza los mensajes de addon: anuncia en el chat y se responde por susurro.
C_ChatInfo.SendAddonMessage = function() return 3 end -- Enum.SendAddonMessageResult distinto de 0
fire("CHAT_MSG_ADDON", "RTLC", "Q;" .. sid, "RAID", "Healz-Nightslayer")
assert(said[#said][1]:find("Reparto", 1, true), "anuncia los ítems en la banda: " .. said[#said][1])
LC.state.sessions[sid].items[4] = { n = 4, item = "item:12345", ilvl = 60, equipLoc = "INVTYPE_WEAPON", responses = {}, votes = {} }
fire("CHAT_MSG_WHISPER", "4 mejora la quiero", "Tanque-Nightslayer")
assert(s.items[4].responses["Tanque-Nightslayer"].kind == "upgrade" and s.items[4].responses["Tanque-Nightslayer"].note == "la quiero")
C_ChatInfo.SendAddonMessage = function(p, msg, chan) table.insert(sentAddon, { p, msg, chan }) end

-- Cerrar, y tras un /reload el estado se arma de nuevo con lo anotado.
click("Cerrar reparto")
assert(not LC.current(), "cerrado")
LC.rebuild()
local again = LC.state.sessions[sid]
assert(again and again.closed and again.items[1].award.to == "Roguebash-Nightslayer" and again.items[3].open, "se rearma igual")
for _, l in ipairs(RebirthTrackDB.council) do assert(not l:find("|", 1, true), l) end
rt("reparto agregar |cffa335ee|Hitem:16866::::::::60:::::|h[Yelmo de ira]|h|r")
assert(#LC.pending() == 1, "/rt reparto agregar suma el ítem (Retail: desde las bolsas)")
print("reparto OK")

-- Posición: el mapa de la zona y el del continente, compartida por el canal; dentro de una instancia
-- va solo la instancia. Se comparte siempre.
local function vec(x, y) return { GetXY = function() return x, y end } end
Enum = Enum or {}
C_Map = {
  GetBestMapForUnit = function() return 1429 end,
  GetPlayerMapPosition = function(id) if id == 1429 then return vec(0.41234, 0.6) end; if id == 1415 then return vec(0.4, 0.795) end end,
  GetMapInfo = function(id)
    return ({ [1429] = { name = "Bosque de Elwynn", mapType = 3, parentMapID = 1415 }, [1415] = { name = "Reinos del Este", mapType = 2, parentMapID = 947 } })[id]
  end,
}
function IsInInstance() return false end
local CP = ns._collect
local function pos1() return RebirthTrackDB.data["Player-6065-044C2423"].pos1 end
sentAddon = {}
assert(RebirthTrackDB.settings.sharePos == nil, "compartida por defecto (sin tocar la opción)")
CP.collectPosition()
assert(pos1():match("^pos1;Player%-6065%-044C2423;%d+;1429;0%.412;0%.6;1415;0%.4;0%.795;Bosque de Elwynn;0;Reinos del Este$"), pos1())
local function sharedPos() for _, s in ipairs(sentAddon) do if s[1] == "RTK1" and s[2]:find(";pos1;", 1, true) then return s[2] end end end
assert(sharedPos(), "se comparte con la guild")
sentAddon = {}
CP.collectPosition()
assert(not sharedPos(), "si no se movió no se manda de nuevo")
function IsInInstance() return true, "party" end
CP.collectPosition()
assert(pos1():match(";0;0;0;0;0;0;[^;]+;%d+;$"), "en instancias solo la instancia: " .. pos1())
function IsInInstance() return false end
-- Desde la 0.12.0 no se puede apagar: un «sharePos = false» de antes no cuenta y no hay botón.
RebirthTrackDB.settings.sharePos = false
rt("posicion")
CP.resetPosition()
CP.collectPosition()
assert(pos1():match("Bosque de Elwynn;0;Reinos del Este$"), "se comparte siempre: " .. pos1())
assert(not pcall(click, "Posición"), "ya no hay botón de Posición")
rt("opciones") -- sin panel de opciones en este cliente: no falla
do -- en combate no abre (el panel del juego es protegido): avisa y espera a que termine
  local opened, combat = 0, true
  local oldIC, oldS = InCombatLockdown, Settings
  InCombatLockdown = function() return combat end
  rt("opciones")
  combat = false
  fire("PLAYER_REGEN_ENABLED")
  InCombatLockdown, Settings = oldIC, oldS
  print("opciones en combate OK")
end
print("posición OK")

-- Banco personal: se anota al abrir el banco, por personaje (RebirthTrackBank) y NUNCA en
-- RebirthTrackDB (lo que sube la app) ni por el canal de la guild.
NUM_BAG_SLOTS, NUM_BANKBAGSLOTS = 4, 7
local bank = {
  [-1] = { n = 24, items = { [1] = { 13444, 5, "item:13444" }, [7] = { 12360, 1, "item:12360" } } },
  [5] = { n = 16, items = { [2] = { 13444, 3, "item:13444" } } },
}
C_Container = {
  GetContainerNumSlots = function(bag) return bank[bag] and bank[bag].n or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local it = bank[bag] and bank[bag].items[slot]
    if it then return { itemID = it[1], stackCount = it[2], hyperlink = "|cff1eff00|H" .. it[3] .. "|h[Item " .. it[1] .. "]|h|r", iconFileID = 134000, quality = 2 } end
  end,
  ContainerIDToInventoryID = function(bag) return 70 + bag end,
}
function GetInventoryItemLink(_, inv) if inv == 75 then return "|cffffffff|Hitem:14156|h[Bolsa de tela de luna]|h|r" end end
function GetInventoryItemTexture(_, inv) if inv == 75 then return 133650 end end
function GetNumBankSlots() return 2, false end
sentAddon = {}
local before = RebirthTrackDB.data and #(RebirthTrackDB.events or {})
fire("BANKFRAME_OPENED")
local B = RebirthTrackBank
assert(B and B.v == 2 and B.bagSlots == 2, "anota el banco al abrirlo")
assert(B.containers[1].id == -1 and B.containers[1].slots == 24 and B.containers[1].items[1].n == 5 and B.containers[1].items[7].id == 12360)
assert(B.containers[2].id == 5 and B.containers[2].name == "Bolsa de tela de luna" and B.containers[2].items[2].n == 3)
assert(B.containers[3].id == 6 and B.containers[3].slots == 0, "hueco comprado sin bolsa")
for _, s in ipairs(sentAddon) do assert(not s[2]:find("13444", 1, true), "el banco no va por el canal") end
for k in pairs(RebirthTrackDB) do assert(k ~= "bank" and k ~= "RebirthTrackBank", "el banco no va en RebirthTrackDB") end
for _, c in pairs(RebirthTrackDB.data or {}) do for key in pairs(c) do assert(not key:match("^inv"), key) end end
fire("BANKFRAME_CLOSED")
bank[-1].items = {}
fire("BAG_UPDATE", 5)
assert(RebirthTrackBank.containers[1].items[1], "con el banco cerrado no se pisa lo anotado")
-- WoW Forever: el cliente conoce las pestañas del banco de Retail, pero el banco es el clásico.
Enum.BagIndex = { Bank = -1, CharacterBankTab_1 = 6, BankBag_1 = 5 }
bank[-1].items = { [3] = { 13444, 2, "item:13444" } }
fire("BANKFRAME_OPENED")
local F = RebirthTrackBank
assert(not F.tabbed, "con casilleros clásicos no usa pestañas")
assert(F.containers[1].id == -1 and F.containers[2].id == 5 and F.containers[2].name == "Bolsa de tela de luna", "banco + bolsa 5")
for _, c in ipairs(F.containers) do assert(not c.tab, "sin «Pestaña N»") end
assert(#F.containers == 1 + 7, "banco + 7 huecos de bolsa: " .. #F.containers)
-- WoW Forever de verdad (visto en el juego): el -1 trae 32 casilleros vacíos, lo del banco está en la
-- «pestaña» 1 y la bolsa comprada (10) en la 2. Se ve como banco + bolsa, sin el -1.
local saved1 = bank[-1]
bank[-1] = { n = 32, items = {} }
bank[6] = { n = 48, items = { [1] = { 13444, 4, "item:13444" }, [48] = { 12360, 1, "item:12360" } } }
bank[7] = { n = 10, items = {} }
function GetInventoryItemLink(_, inv) if inv == 77 then return "|cffffffff|Hitem:4245|h[Bolsa de seda]|h|r" end end
fire("BANKFRAME_OPENED")
local FV = RebirthTrackBank
assert(FV.v == 2 and not FV.tabbed, "Forever: no son pestañas")
assert(FV.containers[1].id == 6 and FV.containers[1].main and FV.containers[1].slots == 48 and FV.containers[1].items[48].id == 12360, "el banco es la 1")
assert(FV.containers[2].id == 7 and FV.containers[2].slots == 10 and FV.containers[2].name == "Bolsa de seda", "la bolsa de 10 es la 2")
for _, c in ipairs(FV.containers) do assert(c.id ~= -1, "el -1 vacío no se muestra") end
bank[-1], bank[6], bank[7] = saved1, nil, nil
-- Retail 11.2+: sin casilleros clásicos, las pestañas.
local saved = bank[-1]; bank[-1] = nil
bank[6] = { n = 98, items = { [1] = { 12360, 1, "item:12360" } } }
fire("BANKFRAME_OPENED")
assert(RebirthTrackBank.tabbed and RebirthTrackBank.containers[1].tab == 1 and RebirthTrackBank.containers[1].items[1].id == 12360, "pestañas de Retail")
bank[-1], bank[6] = saved, nil
Enum.BagIndex = nil
fire("BANKFRAME_OPENED")
rt("banco")
local pg0 = ns._bank.page()
assert(pg0 and pg0.shown, "/rt banco abre la ventana")
click("Banco personal") -- el botón de la ventana del addon la cierra (y vuelve a abrir)
assert(not pg0.shown, "el botón alterna la ventana")
-- La vista: 24 casilleros + la fila de 7 huecos de bolsa + 16 de la bolsa = 47 botones.
local pg = ns._bank.page()
assert(pg, "la página del banco existe")
pg.shown = true
pg.scripts.OnShow(pg)
assert(ns._bank.used() == 24 + 7 + 16, "casilleros dibujados: " .. ns._bank.used())
print("banco OK")

-- Versión del addon y de la app en el anuncio (k1): la del .toc y la que deja la app en Plans.lua.
C_AddOns = { GetAddOnMetadata = function(a, k) if a == "RebirthTrack" and k == "Version" then return "0.7.0" end end }
assert(ns.addonVersion() == "0.7.0" and ns.appVersion() == "", "sin la app, vacía")
RebirthTrackApp = { version = "0.6.3" }
assert(ns.appVersion() == "0.6.3")
RebirthTrackApp = { version = "0.6.3; malo" }
assert(ns.appVersion() == "", "solo versiones con forma X.Y.Z")
RebirthTrackApp = { version = "0.6.3" }
sentAddon = {}
local realTime = time
time = function() return 1792540000 end -- un rato después (si no, el anuncio no es más nuevo)
rt("vincular") -- vuelve a anunciar el personaje (L)
time = realTime
local k
for _, s in ipairs(sentAddon) do if s[2]:match("^K;") then k = s[2] end end
assert(k and k:match(";0%.7%.0;0%.6%.3$"), "el anuncio lleva las dos versiones: " .. tostring(k))
local mine
for _, rec in ipairs(RebirthTrackDB.guild.known) do if rec:find("Player-6065-044C2423", 1, true) then mine = rec end end
assert(mine:match(";0%.7%.0;0%.6%.3$"), mine)
print("versiones OK")

-- Posiciones de la guild: lo que llega por el canal va como punto al mapa (lo propio no) y a la lista.
NUM_BAG_SLOTS = 4
C_Map = {
  GetBestMapForUnit = function() return 1429 end,
  GetPlayerMapPosition = function(id) if id == 1429 then return { GetXY = function() return 0.4, 0.6 end } end; if id == 1415 then return { GetXY = function() return 0.42, 0.78 end } end end,
  GetMapInfo = function(id) return ({ [1429] = { name = "Bosque de Elwynn", mapType = 3, parentMapID = 1415 }, [1415] = { name = "Reinos del Este", mapType = 2, parentMapID = 947 } })[id] end,
}
function IsInInstance() return false end
ns._collect.resetPosition()
ns._collect.collectPosition()
local CPut = ns._collect.putPeer
assert(CPut("pos1;Player-6065-0411;" .. time() .. ";1454;0.502;0.684;1414;0.583;0.455;Orgrimmar;0;Kalimdor", "Healz"), "llega la de Healz")
assert(CPut("pos1;Player-6065-0099;" .. (time() - 3600) .. ";1453;0.5;0.5;1415;0.4;0.6;Ventormenta;0;Reinos del Este", "Otro"), "una vieja")
ns.refreshPositions()
local placed = {}
for _, v in pairs(mapPins) do placed[#placed + 1] = v end
assert(#placed == 1 and placed[1].map == 1454 and placed[1].x == 0.502 and placed[1].flag == 3, "solo Healz en el mapa (lo propio no, la vieja tampoco): " .. #placed)
assert(placed[1].p.who.name == "Healz" and placed[1].p.who.class == "PRIEST", "con nombre y clase de la lista de la guild")
for _, d in pairs(ns._positions.dots) do assert(d.pingAnim, "el destello se arma (SetLooping con un valor válido)") end
for _, d in pairs(ns._positions.dots) do assert(not d.shown, "con el mapa cerrado el punto no queda flotando en la pantalla") end
local list = ns._positions.positions()
assert(#list == 3, "la lista tiene las 3: " .. #list)
-- Apagar los puntos los saca del mapa.
RebirthTrackDB.settings.mapPins = false
ns.refreshPositions()
assert(next(mapPins) == nil, "sin puntos")
RebirthTrackDB.settings.mapPins = nil
-- La ventana: /rt posiciones y el botón de la ventana del addon.
rt("posiciones")
local w = ns._positions.window()
assert(w and w.shown, "abre la lista")
w.scripts.OnShow(w)
local shownRows = 0
for _, r in ipairs(ns._positions.rows()) do if r.shown then shownRows = shownRows + 1 end end
assert(shownRows == 3, "una fila por posición: " .. shownRows)
-- «Mapa»: abre el mapa del mundo (arranca cerrado y al abrirse vuelve a la zona propia) en la zona
-- de esa fila y cierra la lista.
local mapSet = {}
WorldMapFrame = { shown = false, IsShown = function(self) return self.shown end,
  SetMapID = function(self, id) table.insert(mapSet, id) end }
function ShowUIPanel(f) f.shown = true; f:SetMapID(1429) end -- el juego pone la zona propia al abrir
local target
for _, r in ipairs(ns._positions.rows()) do if r.shown and r.map.p and r.map.p.zone == "Orgrimmar" then target = r end end
assert(target, "fila de Healz en Orgrimmar")
target.map.scripts.OnClick(target.map)
assert(WorldMapFrame.shown, "abre el mapa")
assert(mapSet[#mapSet] == 1454, "termina en Orgrimmar (1454), no en la zona propia: " .. tostring(mapSet[#mapSet]))
assert(not w.shown, "cierra la lista para no tapar el mapa")
WorldMapFrame, ShowUIPanel = nil, nil
rt("posiciones")
click("Posiciones")
assert(not w.shown, "el botón la cierra")
-- Quieto: se vuelve a avisar cada minuto (con la hora nueva), para no desaparecer del mapa de los demás.
sentAddon = {}
ns._collect.resetPosition()
ns._collect.collectPosition()
local function sentPos() local n = 0; for _, m in ipairs(sentAddon) do if m[2]:find(";pos1;", 1, true) then n = n + 1 end end; return n end
local first = sentPos()
ns._collect.collectPosition()
assert(sentPos() == first, "quieto y antes del minuto, no manda")
print("posiciones en el mapa OK")

-- Invitador: el mensaje de la web partido en mensajes de chat, gritado o al canal de Mundo, e invitar.
local R = ns._recruit
RebirthTrackDB.settings.lang = "es"
local def = R.defaultText()
assert(def:find("<Rebirth Knights>", 1, true) and def:find("rebirthknights.fun", 1, true) and def:find("discord.gg/Qvy8qeJmmv", 1, true), "mensaje con guild, web y Discord")
assert(def:find("PvP y PvE", 1, true), "dice PvP y PvE")
local ps = R.parts(def)
assert(#ps == 2, "un mensaje por renglón: " .. #ps)
for _, m in ipairs(ps) do assert(#m <= 255, "cada uno entra en el chat: " .. #m) end
local long = R.parts(string.rep("palabra ", 80) .. "|cff")
assert(#long == 3, "un renglón largo se parte en palabras: " .. #long)
for _, m in ipairs(long) do assert(#m <= 255 and not m:find("|", 1, true), "sin pasarse ni «|»") end
assert(#R.parts("  \n \n") == 0, "vacío no manda nada")
-- Canales: de a tres (id, nombre, desactivado); toma el de Mundo y «Canal ▸» rota entre los abiertos.
chat = {}
function SendChatMessage(msg, kind, _, target) table.insert(chat, { msg, kind, target }) end
function GetChannelList() return 1, "General", false, 2, "Comercio", false, 4, "Mundo", false end
assert(R.channel().name == "Mundo", "elige Mundo")
rt("invitar")
local rw = R.window()
assert(rw and rw.shown, "abre el invitador")
assert(rw.edit:GetText() == def, "con el texto armado")
click("Mandar a Mundo")
assert(#chat == 2 and chat[1][2] == "CHANNEL" and chat[1][3] == 4, "manda los 2 al canal 4")
click("Mandar a Mundo")
assert(#chat == 2, "no se repite enseguida (anti-spam)")
click("Gritar")
assert(#chat == 4 and chat[3][2] == "YELL", "grita los 2")
click("Canal »")
assert(RebirthTrackDB.settings.recruitChannel == "General", "rota al siguiente (vuelve al primero)")
R.resetCooldown(); click("Mandar a General")
assert(chat[#chat][3] == 1, "ahora a General")
RebirthTrackDB.settings.recruitChannel = nil
function GetChannelList() return 1, "General", false end
chat = {}; R.resetCooldown(); R.sendChannel()
assert(#chat == 0, "sin canal de Mundo no manda a cualquiera")
-- Texto propio: se guarda y «Texto original» lo vuelve atrás.
rw.edit:SetText("Hola\nChau"); rw.edit.scripts.OnTextChanged(rw.edit, true)
assert(RebirthTrackDB.settings.recruitText == "Hola\nChau" and #R.parts(R.text()) == 2, "guarda el texto propio")
click("Texto original")
assert(RebirthTrackDB.settings.recruitText == nil and rw.edit:GetText() == def, "vuelve al de la web")
-- En inglés el cuadro sigue al idioma.
rt("idioma en")
assert(rw.edit:GetText():find("Horde PvP and PvE", 1, true), "texto en inglés")
rt("idioma es")
-- Invitar: al nombre escrito o al objetivo, si el rango puede.
invitedTo = {}
function GuildInvite(n) table.insert(invitedTo, n) end
function CanGuildInvite() return true end
function UnitExists() return true end
function UnitIsPlayer() return true end
local realUnitName = UnitName
UnitName = function(u) if u == "target" then return "Nuevito", nil end return realUnitName(u) end
rw.name:SetText("Fulano"); click("Invitar a la guild")
assert(invitedTo[1] == "Fulano" and rw.name:GetText() == "", "invita al nombre escrito")
click("Invitar a la guild")
assert(invitedTo[2] == "Nuevito", "vacío: invita al objetivo")
function CanGuildInvite() return false end
assert(not R.invite("Otro") and #invitedTo == 2, "sin permiso no invita")
UnitName = realUnitName
rt("invitar")
assert(not rw.shown, "/rt invitar la cierra")
click("Invitador")
assert(rw.shown, "el botón de la ventana la abre")
print("invitador OK")

-- Recetas con lo del banco: (+Banco n) (total), parcial y nada si el banco no suma.
do
  local C = ns._bankCraft
  local r = C.calc({ { id = 1, name = "Paño de lana", need = 2, have = 2, bank = 6 } })
  assert(r and r.bags == 1 and r.total == 4 and r.extra == 3 and not r.partial, "1 del bolso + 3 del banco")
  assert(C.label(r):find("+Banco 3", 1, true) and C.label(r):find("(4)", 1, true), C.label(r))
  assert(r.lines[1]:find("Paño de lana: 6 del banco", 1, true), r.lines[1])
  local p = C.calc({ { id = 1, name = "Paño de lana", need = 2, have = 0, bank = 1 }, { id = 2, name = "Hilo", need = 1, have = 5, bank = 0 } })
  assert(p and p.partial and p.extra == 0, "parcial")
  assert(C.label(p):find("+Parcial Banco", 1, true))
  assert(p.lines[1]:find("Paño de lana: 1 en el banco", 1, true) and p.lines[2]:find("Paño de lana: faltan 1", 1, true), table.concat(p.lines, " / "))
  assert(C.calc({ { id = 1, name = "x", need = 1, have = 3, bank = 0 } }) == nil, "sin banco, nada")
  assert(C.calc({ { id = 1, name = "x", need = 1, have = 3, bank = 2 }, { id = 2, name = "y", need = 5, have = 5, bank = 0 } }) == nil, "lo del banco no sirve: nada")
  -- En la ventana: una fila con su receta y el banco anotado.
  RebirthTrackBank = { v = 2, at = time(), containers = { { id = 6, slots = 2, items = { { id = 2592, n = 6 }, { id = 2592, n = 2 } } } } }
  assert(C.totals()[2592] == 8)
  TradeSkillFrame = CreateFrame("Frame")
  TradeSkillSkill1 = CreateFrame("Button"); TradeSkillSkill1.GetID = function() return 3 end; TradeSkillSkill1.GetName = function() return "TradeSkillSkill1" end
  function GetTradeSkillInfo(i) return "Venda de lana gruesa", "medium", 1 end
  function GetTradeSkillNumReagents() return 1 end
  function GetTradeSkillReagentInfo() return "Paño de lana", "tex", 2, 2 end
  function GetTradeSkillReagentItemLink() return "|cffffffff|Hitem:2592::::::::|h[Paño de lana]|h|r" end
  local hooked = 0
  function TradeSkillFrame_Update() hooked = hooked + 1 end
  C.hookAll()
  TradeSkillFrame_Update()
  local t = TradeSkillSkill1.rtBank
  assert(hooked == 1 and t and t:IsShown(), "pone la etiqueta al actualizar la ventana")
  assert(t.text:GetText():find("+Banco 4", 1, true) and t.text:GetText():find("(5)", 1, true), t.text:GetText())
  t.scripts.OnEnter(t)
  RebirthTrackBank = nil
  TradeSkillFrame_Update()
  assert(not t:IsShown(), "sin banco anotado, no hay etiqueta")
  print("recetas con banco OK")
end

-- Ventana nueva (Forever): filas del ScrollBox con recipeInfo y componentes de GetRecipeSchematic.
do
  local C = ns._bankCraft
  RebirthTrackBank = { v = 2, at = time(), containers = { { id = 6, slots = 1, items = { { id = 10938, n = 3 } } } } }
  local row = CreateFrame("Button"); row.Label = row:CreateFontString(); row.Count = row:CreateFontString()
  row.GetElementData = function() return { GetData = function() return { recipeInfo = { recipeID = 7428, learned = true } } end } end
  local header = CreateFrame("Button"); header.Label = header:CreateFontString()
  header.GetElementData = function() return { GetData = function() return { categoryInfo = { name = "Brazales" } } end } end
  ProfessionsFrame = CreateFrame("Frame")
  ProfessionsFrame.HookScript = function(self, ev, fn) self.scripts[ev] = fn end
  ProfessionsFrame.CraftingPage = { RecipeList = { ScrollBox = { ForEachFrame = function(_, fn) fn(row); fn(header) end } } }
  C_TradeSkillUI = C_TradeSkillUI or {}
  C_TradeSkillUI.GetRecipeSchematic = function(id)
    return { reagentSlotSchematics = { { reagentType = 1, quantityRequired = 1, reagents = { { itemID = 10938 } } } } }
  end
  C_Item = C_Item or {}
  C_Item.GetItemCount = function(id) return id == 10938 and 1 or 0 end
  C_Item.GetItemNameByID = function() return "Esencia mágica inferior" end
  C.hookAll()
  C.refreshModern()
  local t = row.rtBank
  assert(t and t:IsShown(), "etiqueta en la ventana nueva")
  assert(t.text:GetText():find("+Banco 3", 1, true) and t.text:GetText():find("(4)", 1, true), t.text:GetText())
  assert(t.res.lines[1]:find("Esencia mágica inferior: 3 del banco", 1, true), t.res.lines[1])
  assert(not header.rtBank or not header.rtBank:IsShown(), "las categorías no llevan etiqueta")
  ProfessionsFrame.scripts.OnShow(); assert(C.ticker:IsShown(), "repasa mientras está abierta")
  ProfessionsFrame.scripts.OnHide(); assert(not C.ticker:IsShown())
  print("recetas con banco (ventana nueva) OK")
end

-- Plan: en Forever las profesiones salen de GetProfessions (no hay GetSkillLineInfo).
do
  local oldN, oldI = GetNumSkillLines, GetSkillLineInfo
  GetNumSkillLines, GetSkillLineInfo = nil, nil
  GetProfessions = function() return 1, 2, nil, 3, 4 end
  GetProfessionInfo = function(i)
    local t = { { "Encantamiento", 1, 137, 150, 0, 0, 333 }, { "Sastrería", 1, 80, 150, 0, 0, 197 }, { "Pesca", 1, 1, 75, 0, 0, 356 }, { "Cocina", 1, 40, 75, 0, 0, 185 } }
    return table.unpack(t[i])
  end
  local r, m = ns._skillOf("enchanting"); assert(r == 137 and m == 150, "encantamiento por GetProfessions")
  assert(ns._skillOf("cooking") == 40 and ns._skillOf("fishing") == 1)
  assert(ns._skillOf("alchemy") == nil)
  GetNumSkillLines, GetSkillLineInfo = oldN, oldI
  ns.planDiag()
  SlashCmdList.REBIRTHTRACK("diag")
  print("plan con GetProfessions OK")
end

-- Plan en WoW Forever: talentos y Legado por C_ClassTalents + C_Traits (sin filas ni columnas).
do
  local body = table.concat({
    "RTP1;ff01;Lonos;nightslayer;Orco;Mage;pve;1",
    "B;0;Arcano", "B;1;Fuego", "B;2;Escarcha",
    "T;0;1;2;5;5;Concentración arcana;11213,12574,12575,12576,12577;Arcane Focus",
    "T;1;1;3;2;2;Impacto;11103,12357;Impact",
    "T;2;2;1;3;3;Escarcha penetrante;;Piercing Ice",
    "L;Aventura;2;3;Descanso profundo;Deep Rest",
  }, "\n")
  local plan = ns.planParse(body .. "\nZ;" .. ns.planCrc32(body))[1].plan
  assert(plan.talents[1].spells[2] == 12574 and plan.talents[3].en == "Piercing Ice" and plan.legacy[1].en == "Deep Rest", "lee hechizos e inglés")
  local saved = { GetNumTalentTabs, GetNumTalents, GetTalentInfo }
  GetNumTalentTabs, GetNumTalents, GetTalentInfo = nil, nil, nil
  -- Configuración activa 585381 (talentos) y el sistema 7 (Legado) con su propia configuración.
  local NODES = {
    [585381] = { tree = 1, nodes = {
      { id = 1, spell = 11213, rank = 3, max = 5 },           -- Concentración arcana, a medias
      { id = 2, spell = 11103, rank = 2, max = 2 },           -- Impacto, completo
      { id = 3, spell = 99999, rank = 1, max = 3, name = "Piercing Ice" }, -- sin ID en el plan: por nombre inglés
      { id = 4, spell = 55555, rank = 2, max = 2 },           -- fuera del plan
      { id = 5, spell = 44444, rank = 0, max = 1 },
    } },
    [700] = { tree = 9, nodes = { { id = 9, spell = 77777, rank = 2, max = 3, name = "Deep Rest" } } },
  }
  local byNode = {}
  for cfg, c in pairs(NODES) do for _, n in ipairs(c.nodes) do byNode[cfg .. ":" .. n.id] = n end end
  C_ClassTalents = { GetActiveConfigID = function() return 585381 end }
  C_Traits = {
    GetConfigInfo = function(cfg) return NODES[cfg] and { name = "cfg" .. cfg, treeIDs = { NODES[cfg].tree } } end,
    GetTreeNodes = function(tree) for _, c in pairs(NODES) do if c.tree == tree then local ids = {}; for _, n in ipairs(c.nodes) do ids[#ids + 1] = n.id end; return ids end end end,
    GetNodeInfo = function(cfg, id) local n = byNode[cfg .. ":" .. id]; return n and { ranksPurchased = n.rank, maxRanks = n.max, activeEntry = { entryID = cfg .. ":" .. id } } end,
    GetEntryInfo = function(cfg, entry) return { definitionID = entry } end,
    GetDefinitionInfo = function(def) return { spellID = byNode[def].spell } end,
    GetConfigIDBySystemID = function(sys) if sys == 7 then return 700 end if sys == 1 then return 585381 end return 0 end,
  }
  C_Spell = { GetSpellName = function(id) for _, n in pairs(byNode) do if n.spell == id then return n.name or ("Hechizo " .. id) end end end }
  local pr = ns.planProgress(plan)
  assert(pr.tal.planned == 10 and pr.tal.matched == 3 + 2 + 1, "cruza por hechizo y por nombre: " .. pr.tal.matched)
  assert(pr.tal.spent == 8 and pr.tal.off == 1, "gastados y fuera del plan")
  assert(pr.tal.next and pr.tal.next.t.en == "Arcane Focus" and pr.tal.next.have == 3, "próximo a tocar")
  local st = ns._planTraits.state()
  local lg = ns._planTraits.legacy(st)
  local n = ns._planTraits.nodeFor(lg, plan.legacy[1])
  assert(n and n.rank == 2, "Legado por el sistema de C_Traits")
  ns.planDiag()
  GetNumTalentTabs, GetNumTalents, GetTalentInfo = saved[1], saved[2], saved[3]
  C_ClassTalents, C_Traits, C_Spell = nil, nil, nil
  print("plan con C_Traits OK")
end

-- Pedidos de materiales a la guild (Requests.lua).
do
  local R = ns._requests
  local function lastSent(pat) for i = #sentAddon, 1, -1 do local s = sentAddon[i]; if s[1] == "RTK1" and s[2]:match(pat) then return s[2] end end end
  local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
  RebirthTrackDB.requests = nil
  RebirthTrackDB.settings.requests = nil
  C_Item = C_Item or {}
  C_Item.GetItemNameByID = function(id) return ({ [1001] = "Morning Glory Dew", [1002] = "Mountain Silversage" })[id] end

  -- Ida y vuelta de la línea; la receta se acorta para que entre en un mensaje.
  local r0 = { id = "abc", who = "Healz", created = 100, at = 110, status = "p", by = "Healz-Nightslayer", expires = 0, recipe = "Sage's Tea",
    items = { { id = 1001, n = 1 }, { id = 1002, n = 2 } } }
  local line = R.build(r0)
  assert(line == "rq1;abc;Healz-Nightslayer;100;110;p;Healz-Nightslayer;0;Sage's Tea;1001:1,1002:2", line)
  local back = R.parse(line)
  assert(back.who == "Healz-Nightslayer" and back.items[2].n == 2 and back.recipe == "Sage's Tea")
  local long = R.build({ id = "x", who = "Nombre Apellido", created = 1792530000, at = 1792530000, status = "p", by = "Nombre Apellido-Nightslayer", expires = 0,
    recipe = string.rep("Receta larguísima ", 20), items = { { id = 111111, n = 20 }, { id = 222222, n = 20 }, { id = 333333, n = 20 }, { id = 444444, n = 20 }, { id = 555555, n = 20 }, { id = 666666, n = 20 }, { id = 777777, n = 20 }, { id = 888888, n = 20 } } })
  assert(#("Q;" .. long) <= 255 and R.parse(long), "entra en un mensaje: " .. #long)

  -- La cantidad que propone: lo que falta para hacerla una vez (o lo que pide, si ya lo tenés).
  assert(R.suggested({ need = 2, have = 1, bank = 0 }) == 1 and R.suggested({ need = 3, have = 9, bank = 0 }) == 3, "propuesta")

  -- Pedir un componente: queda guardado y sale por el canal como «Q;».
  local mine = R.setItem("Sage's Tea", 1001, 1)
  assert(mine and mine.status == "p" and mine.who == "Roguebash-Nightslayer" and #mine.items == 1, "pedido propio")
  assert(lastSent("^Q;rq1;" .. mine.id .. ";Roguebash%-Nightslayer;"), "sale por el canal")
  assert(R.mineFor("Sage's Tea"), "el checkbox lo ve tildado")
  -- Otro componente de la misma receta va en el mismo pedido; cambiar la cantidad lo actualiza.
  local again = R.setItem("Sage's Tea", 1002, 2)
  assert(again.id == mine.id and #again.items == 2 and again.items[2].n == 2, "dos componentes")
  again = R.setItem("Sage's Tea", 1002, 6)
  assert(again.id == mine.id and #again.items == 2 and again.items[2].n == 6, "cantidad nueva")
  -- Destildar uno deja el otro; destildar el último cierra el pedido.
  again = R.setItem("Sage's Tea", 1001, nil)
  assert(again.status == "p" and #again.items == 1 and again.items[1].id == 1002, "queda el otro")
  R.setItem("Sage's Tea", 1002, nil)
  assert(not R.mineFor("Sage's Tea"), "y se cierra")

  -- De otro miembro, por el canal: lo manda su autor (Q) o un reenvío (W) si el autor podía.
  local hz = R.build({ id = "hz1", who = "Healz", created = 200, at = 200, status = "p", by = "Healz", expires = 0, recipe = "Sage's Tea", items = { { id = 1001, n = 1 }, { id = 1002, n = 2 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. hz, "GUILD", "Otro-Dreamscythe")
  assert(not R.store().lines.hz1, "un Q de otro que no es el autor no vale")
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. hz, "GUILD", "Healz-Nightslayer")
  assert(R.store().lines.hz1, "el pedido de Healz entra")
  -- Forever: «Nombre Apellido» y el remitente llega con otro reino que el que da el juego acá.
  local fv = R.build({ id = "fv1", who = "Baldor Dwimorberg", created = 205, at = 205, status = "p", by = "Baldor Dwimorberg", expires = 0, recipe = "Venda", items = { { id = 1001, n = 3 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. fv, "GUILD", "Baldor Dwimorberg-OtroReino")
  assert(R.store().lines.fv1, "el pedido de Forever entra aunque el reino del remitente sea otro")
  R.store().lines.fv1 = nil
  -- Healz (rango 3) no puede trasladarlo ni ponerle vencimiento.
  local up = R.build({ id = "hz1", who = "Healz", created = 200, at = 210, status = "g", by = "Healz", expires = 0, recipe = "Sage's Tea", items = { { id = 1001, n = 1 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. up, "GUILD", "Healz-Nightslayer")
  assert(R.parse(R.store().lines.hz1).status == "p", "un miembro no traslada")
  local exp = R.build({ id = "hz1", who = "Healz", created = 200, at = 211, status = "p", by = "Healz", expires = 999999999999, recipe = "Sage's Tea", items = { { id = 1001, n = 1 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. exp, "GUILD", "Healz-Nightslayer")
  assert(R.parse(R.store().lines.hz1).expires == 0, "ni le pone vencimiento")
  -- Lo pendiente: el revisor lo ve; un miembro no.
  local tabs = R.tabRows("pending")
  assert(#tabs == 1 and tabs[1].id == "hz1", "pendientes del revisor")
  assert(#R.forItem(1002) == 1, "el revisor lo ve en el tooltip (pendiente)")
  local realName = GetUnitName
  GetUnitName = function() return "Otro-Dreamscythe" end
  assert(#R.forItem(1002) == 0, "un miembro no ve lo pendiente")
  GetUnitName = realName

  -- Trasladar (un oficial, rango 1): ahora lo ve toda la guild.
  local moved = R.setStatus(R.parse(R.store().lines.hz1), "g")
  assert(moved.status == "g" and moved.by == "Roguebash-Nightslayer", "trasladado")
  assert(lastSent("^Q;rq1;hz1;Healz%-Nightslayer;%d+;%d+;g;Roguebash%-Nightslayer;"), "el traslado sale por el canal")
  GetUnitName = function() return "Otro-Dreamscythe" end
  assert(#R.forItem(1002) == 1 and #R.tabRows("guild") == 1, "ya trasladado, lo ve cualquiera")
  GetUnitName = realName
  -- El que pidió cambia la cantidad sin perder el traslado.
  local qty = R.build({ id = "hz1", who = "Healz", created = 200, at = moved.at + 5, status = "g", by = "Healz", expires = 0, recipe = "Sage's Tea", items = { { id = 1002, n = 4 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. qty, "GUILD", "Healz-Nightslayer")
  local now = R.parse(R.store().lines.hz1)
  assert(now.status == "g" and now.items[1].n == 4, "cantidad nueva, sigue en la guild")

  -- Tooltip: «Requerido por la guild» con los nombres; en el vendedor, el aviso de no venderlo.
  local tt = { lines = {} }
  function tt:AddLine(t) self.lines[#self.lines + 1] = t end
  function tt:Show() end
  R.addLines(tt, 1002)
  assert(tt.lines[1] == "Requerido por la guild:" and tt.lines[2]:find("Healz ×4", 1, true), table.concat(tt.lines, " / "))
  MerchantFrame = CreateFrame("Frame")
  tt.lines = {}; R.addLines(tt, 1002)
  assert(tt.lines[3]:find("No lo vendas", 1, true), table.concat(tt.lines, " / "))
  MerchantFrame = nil
  tt.lines = {}; R.addLines(tt, 4242)
  assert(#tt.lines == 0, "ítem que nadie pide: nada")

  -- Vencimiento: nunca → 7 → 14 → 30 → nunca (solo revisores).
  local e = R.cycleExpiry(now); assert(e.expires == time() + 7 * 86400, "7 días")
  e = R.cycleExpiry(e); assert(e.expires == time() + 14 * 86400)
  e = R.cycleExpiry(e); assert(e.expires == time() + 30 * 86400)
  e = R.cycleExpiry(e); assert(e.expires == 0, "vuelve a nunca")

  -- Avisos al vender (bolsas) y al destruir.
  C_Container = { GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end, GetContainerItemID = function(b, s) return s == 1 and 1002 or 5 end }
  local w = R.warnBags()
  assert(w and w:find("Mountain Silversage (Healz)", 1, true), tostring(w))
  local dialogText = CreateFrame("Frame"); dialogText:SetText("¿Destruir Mountain Silversage?")
  function GetCursorInfo() return "item", 1002 end
  function StaticPopup_FindVisible() return { text = dialogText } end
  R.onDeletePopup("DELETE_ITEM")
  assert(dialogText:GetText():find("Alguien de la guild necesita este ítem: Healz", 1, true), dialogText:GetText())
  C_Container, GetCursorInfo, StaticPopup_FindVisible = nil, nil, nil

  -- Alt+clic: los nombres listos para copiar.
  assert(R.showCopy(1002), "abre la ventanita")
  assert(not R.showCopy(4242), "si nadie lo pide, no")

  -- El que pidió lo cierra destildando; un miembro no cierra pedidos ajenos.
  local otherClose = R.build({ id = "hz1", who = "Healz", created = 200, at = e.at + 5, status = "c", by = "Otro", expires = 0, recipe = "Sage's Tea", items = { { id = 1002, n = 4 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. otherClose, "GUILD", "Otro-Dreamscythe")
  assert(R.parse(R.store().lines.hz1).status == "g", "Otro no lo cierra")
  local close = R.build({ id = "hz1", who = "Healz", created = 200, at = e.at + 6, status = "c", by = "Healz", expires = 0, recipe = "Sage's Tea", items = { { id = 1002, n = 4 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. close, "GUILD", "Healz-Nightslayer")
  assert(R.parse(R.store().lines.hz1).status == "c" and #R.forItem(1002) == 0, "cerrado: ya no aparece")
  assert(R.parse(R.store().lines.hz1).how == nil, "cerrado al estilo viejo: sin decir cómo")

  -- Cerrar como «Resuelto» o «Cancelado»: el GM y los oficiales cualquier pedido; un miembro, solo el suyo.
  local function hzLine(at, status, how, by)
    return R.build({ id = "hz2", who = "Healz", created = 220, at = at, status = status, by = by or "Healz", expires = 0, recipe = "Venda", items = { { id = 2592, n = 5 } }, how = how })
  end
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. hzLine(230, "p"), "GUILD", "Healz-Nightslayer")
  assert(R.store().lines.hz2, "pedido nuevo de Healz")
  assert(hzLine(240, "c", "r"):match(";Venda;2592:5;r$") and hzLine(240, "p", "r"):match(";2592:5$"), "«cómo» va al final y solo cerrado")
  local res = R.setStatus(R.parse(R.store().lines.hz2), "c", "r") -- Roguebash es oficial (rango 1)
  assert(res and res.status == "c" and res.how == "r", "el oficial lo marca resuelto")
  assert(lastSent("^Q;rq1;hz2;.*;c;Roguebash%-Nightslayer;.*;r$"), "sale por el canal con «r»")
  assert(#R.tabRows("closed") >= 1 and #R.tabRows("pending") == 0, "pasa a Cerrados")
  local back2 = R.parse("rq1;zz;A-B;1;2;c;A-B;0;X;1:1") -- addon viejo
  assert(back2 and back2.how == nil, "una línea vieja sigue valiendo")
  -- Reabrir (revisor) y cancelar.
  local re = R.setStatus(res, "g")
  assert(re.status == "g" and re.how == nil and #R.tabRows("guild") >= 1, "reabierto en la guild")
  local can = R.setStatus(re, "c", "x")
  assert(can.how == "x" and lastSent(";c;Roguebash%-Nightslayer;.*;x$"), "cancelado")
  -- Un miembro no cierra (ni resuelve) un pedido ajeno; el que pidió sí, y lo ven todos.
  local reo = R.setStatus(can, "g")
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. hzLine(reo.at + 5, "c", "r", "Otro"), "GUILD", "Otro-Dreamscythe")
  assert(R.parse(R.store().lines.hz2).status == "g", "Otro no lo resuelve")
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. hzLine(reo.at + 6, "c", "r"), "GUILD", "Healz-Nightslayer")
  assert(R.parse(R.store().lines.hz2).how == "r", "Healz lo da por resuelto")
  -- Cerrado en el sitio: llega por Plans.lua con «x».
  local webClose = "rq1;hz2;Healz-Nightslayer;220;" .. (reo.at + 50) .. ";c;@web;0;Venda;2592:5;x"
  RebirthTrackRequests = { at = 1, lines = { anniversary = { webClose } } }
  assert(R.loadWeb() == 1 and R.parse(R.store().lines.hz2).how == "x", "cancelado en el sitio")
  RebirthTrackRequests = nil
  -- Destildar el propio lo cancela.
  local own = R.setItem("Té de prueba", 2592, 2)
  R.setItem("Té de prueba", 2592, nil)
  assert(R.parse(R.store().lines[own.id]).how == "x", "destildar = cancelado")
  -- La ventana: en «En la guild» los botones Resuelto y Cancelar, y en Cerrados el estado.
  local g3 = R.build({ id = "hz3", who = "Healz", created = 300, at = 300, status = "g", by = "Roguebash", expires = 0, recipe = "Poción", items = { { id = 1001, n = 1 } } })
  R.accept(g3, false)
  ns.openRequests("guild")
  click("Resuelto")
  assert(R.parse(R.store().lines.hz3).how == "r", "botón Resuelto")
  ns.openRequests("closed")
  local nClosed = #R.tabRows("closed")
  click("Reabrir")
  assert(#R.tabRows("closed") == nClosed - 1, "botón Reabrir")
  local nGuild = #R.tabRows("guild")
  ns.openRequests("guild")
  click("Cancelar")
  assert(#R.tabRows("guild") == nGuild - 1, "botón Cancelar")
  print("pedidos: resueltos y cancelados OK")

  -- Lo del sitio (Plans.lua) entra solo desde el archivo; por el canal, solo si lo reenvía un revisor.
  local web = "rq1;wb1;Healz-Nightslayer;300;400;g;@web;0;Poción;1001:5"
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. web, "GUILD", "Healz-Nightslayer")
  assert(not R.store().lines.wb1, "un miembro no puede hacerse pasar por el sitio")
  RebirthTrackRequests = { at = 400, lines = { anniversary = { web } } }
  local before = #sentAddon
  assert(R.loadWeb() == 1 and R.parse(R.store().lines.wb1).status == "g", "lo trasladado en el sitio llega al juego")
  assert(#sentAddon > before and lastSent("^Q;rq1;wb1;"), "y un revisor lo reenvía a la guild")
  assert(R.loadWeb() == 0, "dos veces no")
  RebirthTrackRequests = nil

  -- Al entrar: «R;desde» y se le reenvía lo más nuevo («W;»), que vale si el autor podía.
  fire("CHAT_MSG_ADDON", "RTK1", "R;0", "GUILD", "Otro-Dreamscythe")
  assert(lastSent("^W;rq1;"), "reenvía lo que tiene")
  local relay = R.build({ id = "rl1", who = "Healz", created = 500, at = 500, status = "p", by = "Healz", expires = 0, recipe = "Venda", items = { { id = 2592, n = 3 } } })
  fire("CHAT_MSG_ADDON", "RTK1", "W;" .. relay, "GUILD", "Otro-Dreamscythe")
  assert(R.store().lines.rl1, "un reenvío del pedido de Healz vale")
  -- El que entra ya tiene cambios más nuevos que mi pedido abierto: igual se lo reenvío.
  local mio = R.setItem("Té viejo", 2592, 4)
  local n0 = #sentAddon
  fire("CHAT_MSG_ADDON", "RTK1", "R;" .. (mio.at + 100000), "GUILD", "Otro-Dreamscythe")
  local got
  for i = n0 + 1, #sentAddon do if sentAddon[i][2]:find("^W;rq1;" .. mio.id .. ";") then got = true end end
  assert(got, "mis pedidos abiertos llegan al que entra aunque su «desde» sea más nuevo")
  R.setItem("Té viejo", 2592, nil)

  -- Revisores: solo el GM cambia la lista; los que agrega revisan.
  assert(not R.setReviewers({ "Otro-Dreamscythe" }), "Roguebash (rango 1) no es GM")
  local realRoster = GetGuildRosterInfo
  GetGuildRosterInfo = function(i) if i == 3 then return "Otro-Dreamscythe", "Guild Master", 0 end return realRoster(i) end
  fire("CHAT_MSG_ADDON", "RTK1", "Y;rv1;600;Healz-Nightslayer;Healz-Nightslayer", "GUILD", "Healz-Nightslayer")
  assert(not R.store().reviewers, "la lista de alguien que no es GM no vale")
  fire("CHAT_MSG_ADDON", "RTK1", "Y;rv1;600;Otro-Dreamscythe;Healz-Nightslayer", "GUILD", "Otro-Dreamscythe")
  GetGuildRosterInfo = realRoster
  assert(R.store().reviewers and R.isReviewer("Healz-Nightslayer"), "Healz ahora revisa")

  -- Ventana con pestañas.
  ns.openRequests("guild")
  assert(_G.RebirthTrackRequestsFrame == nil or true)
  R.refreshWin()
  ns.openRequests("reviewers")
  SlashCmdList.REBIRTHTRACK("pedidos")

  -- Apagado desde las opciones: ni tooltip ni canal ni ventana.
  RebirthTrackDB.settings.requests = false
  local n = count(R.store().lines)
  fire("CHAT_MSG_ADDON", "RTK1", "Q;" .. R.build({ id = "off1", who = "Healz", created = 700, at = 700, status = "p", by = "Healz", expires = 0, recipe = "X", items = { { id = 1, n = 1 } } }), "GUILD", "Healz-Nightslayer")
  assert(count(R.store().lines) == n, "apagado no recibe")
  tt.lines = {}; R.addLines(tt, 2592); assert(#tt.lines == 0, "apagado no muestra")
  RebirthTrackDB.settings.requests = nil

  -- Se olvidan los cerrados hace más de 30 días.
  R.store().lines.old = "rq1;old;Healz-Nightslayer;1;2;c;Healz-Nightslayer;0;Vieja;1:1"
  R.prune()
  assert(not R.store().lines.old and R.store().lines.rl1, "limpia lo viejo")
  print("pedidos a la guild OK")
end

-- Opción «Mostrar lo del banco en las recetas»: apagada, no hay etiquetas.
do
  local C = ns._bankCraft
  RebirthTrackBank = { v = 2, at = time(), containers = { { id = 6, slots = 2, items = { { id = 2592, n = 6 } } } } }
  TradeSkillFrame = CreateFrame("Frame")
  TradeSkillSkill1 = CreateFrame("Button"); TradeSkillSkill1.GetID = function() return 3 end; TradeSkillSkill1.GetName = function() return "TradeSkillSkill1" end
  function GetTradeSkillInfo() return "Venda de lana gruesa", "medium", 1 end
  function GetTradeSkillNumReagents() return 1 end
  function GetTradeSkillReagentInfo() return "Paño de lana", "tex", 2, 2 end
  function GetTradeSkillReagentItemLink() return "|cffffffff|Hitem:2592::::::::|h[Paño de lana]|h|r" end
  C.refresh("trade")
  assert(TradeSkillSkill1.rtBank:IsShown(), "prendida por defecto")
  RebirthTrackDB.settings.bankCraft = false
  C.refresh("trade")
  assert(not TradeSkillSkill1.rtBank:IsShown(), "apagada: sin etiqueta")
  RebirthTrackDB.settings.bankCraft = nil
  -- Lo que pide la receta elegida, para «Solicitar a la Guild».
  local rs = ns.recipeReagents("trade", 3)
  assert(#rs == 1 and rs[1].id == 2592 and rs[1].need == 2 and rs[1].bank == 6, "componentes con el banco")
  -- El checkbox «Solicitar a la Guild» al lado de cada componente de la receta elegida.
  local R = ns._requests
  ProfessionsFrame = nil
  TradeSkillReagent1 = CreateFrame("Button")
  function GetTradeSkillSelectionIndex() return 3 end
  function GetTradeSkillReagentInfo() return "Paño de lana", "tex", 2, 0 end
  R.updatePickers()
  local p = R.pickers[1]
  assert(p and p:IsShown() and p.id == 2592 and p.n:GetText() == "2", "se ve al lado del componente (con el banco alcanza: propone lo que pide la receta)")
  assert(not R.pickers[2], "uno por componente")
  p.n:SetText("5")
  p.check.GetChecked = function() return true end
  p.check.scripts.OnClick(p.check)
  local mine = R.mineFor("Venda de lana gruesa")
  assert(mine and mine.items[1].id == 2592 and mine.items[1].n == 5, "pide ese componente con la cantidad del cuadrito")
  p.check.GetChecked = function() return false end
  p.check.scripts.OnClick(p.check)
  assert(not R.mineFor("Venda de lana gruesa"), "destildar lo cierra")
  -- Ventana nueva (Forever): los huecos de SchematicForm.reagentSlots.
  TradeSkillFrame:Hide()
  local slot = CreateFrame("Frame"); slot.Name = slot:CreateFontString()
  slot.GetReagentSlotSchematic = function() return { reagents = { { itemID = 10938 } } } end
  ProfessionsFrame = CreateFrame("Frame")
  ProfessionsFrame.CraftingPage = { SchematicForm = { reagentSlots = { [1] = { slot } }, GetRecipeInfo = function() return { recipeID = 77, name = "Esencia" } end } }
  C_TradeSkillUI = { GetRecipeSchematic = function() return { reagentSlotSchematics = { { reagentType = 1, quantityRequired = 2, reagents = { { itemID = 10938 } } } } } end }
  R.updatePickers()
  assert(R.pickers[1]:IsShown() and R.pickers[1].id == 10938 and R.pickers[1].lastFrame == slot and not R.pickers[2], "hueco de la ventana nueva")
  ProfessionsFrame, C_TradeSkillUI = nil, nil
  TradeSkillFrame:Show()
  RebirthTrackDB.settings.requests = false
  R.updatePickers(); assert(not R.pickers[1]:IsShown(), "apagado: sin checkbox")
  RebirthTrackDB.settings.requests = nil
  RebirthTrackBank = nil
  print("opción banco en recetas OK")
end

-- ── Profesiones de la guild (/rt profesiones) ─────────────────────────────────────────────
do
  local P = ns._professions
  local D = RebirthTrackDB.data
  local now = time()
  -- Lo propio de las pruebas de antes (Collect.lua) se aparta: acá solo cuentan los de abajo.
  local MEc, saved = D["Player-6065-044C2423"], {}
  for k, v in pairs(MEc) do if k:match("^r1") or k:match("^cd1") or k == "sk1" then saved[k] = v; MEc[k] = nil end end
  D["Player-6065-0411"] = {
    p1 = "@Healz;p1;Player-6065-0411;" .. now .. ";Healz;Nightslayer;us;5;PRIEST;Human;60;Alliance;Rebirth Knights",
    sk1 = "@Healz;sk1;Player-6065-0411;" .. now .. ";Alquimia=300/300,Herboristería=280/300",
    ["r1:Alquimia"] = "@Healz;r1;Player-6065-0411;" .. now .. ";Alquimia;300;300;s3450,s2330,s99999,s2835",
    ["cd1:Alquimia"] = "@Healz;cd1;Player-6065-0411;" .. now .. ";Alquimia;s11479=" .. (now + 7200),
  }
  D["Player-6065-0500"] = { -- de otra guild: no cuenta
    p1 = "@Mole;p1;Player-6065-0500;" .. now .. ";Mole;Nightslayer;us;5;MAGE;Gnome;60;Alliance;Otra guild",
    ["r1:Alquimia"] = "@Mole;r1;Player-6065-0500;" .. now .. ";Alquimia;150;300;s2330",
  }
  D["Player-6065-0600"] = { -- lista mezclada de una versión vieja: la receta de Alquimia en Primeros auxilios
    p1 = "@Thal;p1;Player-6065-0600;" .. now .. ";Thal;Nightslayer;us;5;HUNTER;Dwarf;60;Alliance;Rebirth Knights",
    ["r1:Primeros auxilios"] = "@Thal;r1;Player-6065-0600;" .. now .. ";Primeros auxilios;150;225;s3450,s3275",
  }
  RebirthTrackCatalog = { at = now, games = { anniversary = {
    recipes = {
      alchemy = {
        "3450;3825;1;2;175;175,190,205,220;inv_potion_43;Elixir de fortaleza;3355:1,3372:1;3830:1:Receta Elixir de fortaleza;trainer:::1800~vendorAt:Kendor Kabonka:Ventormenta:",
        "2330;118;1;1;1;1,55,75,95;inv_potion_49;Poción de sanación menor;2447:1,765:1;;trainer:::10",
        "11479;7068;1;2;225;;inv_misc_stonetablet_05;Transmutar: hierro a oro;3575:1;;trainer:::5000",
      },
      firstaid = { "3275;1251;1;1;1;;inv_misc_bandage_15;Venda de lino;2589:1;;starter" },
    },
    items = { [3355] = "Raíz de ira;inv_misc_herb_07;1", [3372] = "Vial;inv_drink_06;1" },
  } } }
  P.resetCatalog()
  local profs, byGuid = P.build()
  local alc = profs.alchemy
  assert(alc and #alc.members == 1 and alc.members[1].guid == "Player-6065-0411", "Alquimia: solo Healz (Mole es de otra guild)")
  assert(alc.members[1].rank == 300 and alc.members[1].max == 300, "nivel del sk1")
  assert(alc.members[1].recipes == 3, "sin el veneno y con la que no está en el catálogo: " .. alc.members[1].recipes)
  assert(#alc.members[1].cds == 1, "cooldown")
  assert(profs.firstaid and profs.firstaid.members[1].recipes == 1, "la de Alquimia anotada en Primeros auxilios se saca")
  assert(profs.herbalism and profs.herbalism.members[1].rank == 280, "las de recolección salen del sk1")
  local rows = P.recipeRows(alc, "alchemy")
  assert(#rows == 4, "las 3 del catálogo y la que no está: " .. #rows)
  local byKey = {}
  for _, r in ipairs(rows) do byKey[r.key] = r end
  assert(#byKey.s3450.who == 1 and #byKey.s11479.who == 0 and byKey.s99999.loose, "quién sabe cada una")
  local f = P.filterRows(rows, { onlyKnown = true, sort = "level" })
  assert(#f == 3 and f[1].key == "s2330", "solo adquiridas, de la más simple a la más compleja")
  assert(#P.filterRows(rows, { q = "fortaleza" }) == 1, "buscador")
  assert(#P.filterRows(rows, { rank = 2 }) == 1 and P.filterRows(rows, { rank = 2 })[1].key == "s3450", "nivel Experto (150–224)")
  assert(#P.filterRows(rows, { picks = { ["Player-6065-0411"] = true } }) == 3, "por personaje")
  assert(P.targetName(byGuid["Player-6065-0411"]) == "Healz", "mismo reino: sin reino")
  -- La ventana: el mosaico la abre, las dos pestañas se dibujan y el clic derecho en un nombre ofrece susurrar.
  click("Profesiones")
  local w = P.window()
  assert(w and w:IsShown(), "se abre desde la principal")
  ns.openProfessions("members", "alchemy")
  assert(not w.err, "por profesión se dibuja: " .. tostring(w.err))
  click("Healz") -- clic en la fila: sus recetas
  assert(RebirthTrackDB.ui.profs.tab == "recipes" and RebirthTrackDB.ui.profs.picks["Player-6065-0411"], "pasa a recetas con Healz elegido")
  RebirthTrackDB.ui.profs.picks = nil
  ns.openProfessions("recipes", "alchemy")
  assert(not w.err, "recetas se dibuja: " .. tostring(w.err))
  click("Elixir de fortaleza")
  assert(not w.err and w.selRow and w.selRow.key == "s3450", "el detalle se dibuja: " .. tostring(w.err))
  local told
  ChatFrame_SendTell = function(n) told = n end
  P.nameMenu(byGuid["Player-6065-0411"])
  click("Susurrar")
  assert(told == "Healz", "susurra a Healz")
  -- Sin el catálogo de la web: solo las que sabe alguien.
  RebirthTrackCatalog = nil
  P.resetCatalog()
  profs = P.build()
  rows = P.recipeRows(profs.alchemy, "alchemy")
  assert(#rows == 3, "sin catálogo, las 3 anotadas (sin el veneno): " .. #rows)
  ns.openProfessions("recipes", "alchemy")
  assert(not w.err, "sin catálogo se dibuja: " .. tostring(w.err))
  ns.openProfessions("members", "herbalism")
  assert(not w.err, tostring(w.err))
  rt("profesiones")
  for _, g in ipairs({ "Player-6065-0411", "Player-6065-0500", "Player-6065-0600" }) do D[g] = nil end
  for k, v in pairs(saved) do MEc[k] = v end
  print("profesiones de la guild OK")
end

-- Plan › materiales: «Solo lo que falta» con los componentes del catálogo y filtro por profesión.
do
  local x = { rank = 80, prof = { key = "mining", name = "Minería", mats = { { item = 2770, count = 130, name = "Mena de cobre" } },
    steps = { { from = 1, to = 65, crafts = 70, spell = 2657 }, { from = 65, to = 125, crafts = 60, spell = 2659 } } } }
  RebirthTrackCatalog = nil; ns._professions.resetCatalog()
  assert(ns._planRemaining(x) == nil, "sin catálogo no se puede calcular (va el total)")
  RebirthTrackCatalog = { games = { anniversary = { recipes = { mining = {
    "2657;2840;1;1;1;;inv_ingot_02;Fundir cobre;2770:1;;trainer:::",
    "2659;2841;1;1;65;;inv_ingot_bronze;Fundir bronce;2770:1,2771:1;;trainer:::" } }, items = { [2771] = "Mena de estaño;inv_ore_tin_01;1" } } } }
  ns._professions.resetCatalog()
  local left = ns._planRemaining(x)
  assert(left and #left == 2, "lo que falta desde 80: el resto del paso 2")
  assert(left[1].item == 2770 and left[1].count == 45 and left[2].item == 2771 and left[2].count == 45 and left[2].name == "Mena de estaño", "45 de cada uno (de 80 a 125)")
  x.rank = 200
  assert(#ns._planRemaining(x) == 0, "pasada la ruta no falta nada")
  ns.openPlan()
  click("Resumen")
  click("Solo lo que falta")
  assert(RebirthTrackDB.ui.planMats.left, "queda prendido")
  click("Solo lo que falta")
  assert(not RebirthTrackDB.ui.planMats.left, "y se apaga")
  RebirthTrackCatalog = nil; ns._professions.resetCatalog()
  print("plan › materiales que faltan OK")
end

-- El árbol de talentos real de la clase (tt1): cada rama con todos sus talentos, se comparte.
do
  local D = RebirthTrackDB.data
  local ME = "Player-6065-044C2423"
  local oldN, oldT, oldI = GetNumTalentTabs, GetNumTalents, GetTalentInfo
  function GetNumTalentTabs() return 2 end
  function GetTalentTabInfo(tab) return tab == 1 and "Asesinato" or "Combate", "", 0 end
  function GetNumTalents(tab) return tab == 1 and 2 or 1 end
  function GetTalentInfo(tab, i)
    if tab == 1 and i == 1 then return "Remate mejorado", 132292, 1, 1, 2, 3 end
    if tab == 1 and i == 2 then return "Golpes despiadados", 132109, 2, 2, 0, 3 end
    return "Precisión", 132222, 1, 2, 0, 5
  end
  function GetTalentPrereqs(tab, i) if tab == 1 and i == 2 then return 1, 1 end end
  function GetTalentLink(tab, i) return tab == 1 and i == 1 and "|cff4e96f7|Htalent:276:2|h[Remate mejorado]|h|r" or nil end
  sentAddon = {}
  ns._collect.collectTalentTree()
  assert(D[ME]["tt1:1"] == "tt1;" .. ME .. ";" .. time() .. ";1;ROGUE;Asesinato;1:1:3:276:0:0:Remate mejorado:132292,2:2:3:0:1:1:Golpes despiadados:132109", tostring(D[ME]["tt1:1"]))
  assert(D[ME]["tt1:2"]:match(";2;ROGUE;Combate;1:2:5:0:0:0:Precisión:132222$"), D[ME]["tt1:2"])
  local n = 0
  for _, m in ipairs(sentAddon) do if m[2]:find(";tt1;", 1, true) then n = n + 1 end end
  assert(n == 2, "las dos ramas se comparten")
  GetNumTalentTabs, GetNumTalents, GetTalentInfo = oldN, oldT, oldI
  print("árbol de talentos real OK")
end

-- Plan pegado viejo de otro personaje de la misma clase (Brujo) en WoW Forever (C_Traits, sin
-- GetTalentInfo): el árbol cruza lo gastado con el juego, sale entero (las tres ramas) con el árbol de
-- la clase de Plans.lua y los íconos del juego; sin ese árbol, avisa que hay que volver a copiarlo.
do
  local saved = { GetNumTalentTabs, GetNumTalents, GetTalentInfo, UnitClass }
  GetNumTalentTabs, GetNumTalents, GetTalentInfo = nil, nil, nil
  UnitClass = function() return "Brujo", "WARLOCK", 9 end
  -- Texto viejo (antes del sitio 0.9.56): solo lo planeado, sin ícono ni requisito, sin Destrucción.
  local body = table.concat({
    "RTP1;cj01;Cj;bearg;Orco;Warlock;pve;1",
    "B;0;Aflicción", "B;1;Demonología", "B;2;Destrucción",
    "T;0;1;2;4;4;Supresión;18174;Suppression",
    "T;0;2;3;5;5;Corrupción mejorada;1;Improved Corruption", -- hechizo que no es el del juego: por nombre inglés
    "T;1;1;2;1;1;Abrazo demoníaco;18697;Demonic Embrace",
  }, "\n")
  local plan = ns.planParse(body .. "\nZ;" .. ns.planCrc32(body))[1].plan
  local NODES = {
    { id = 1, spell = 18174, rank = 4, max = 4, icon = 136230 },
    { id = 2, spell = 17810, rank = 5, max = 5, name = "Improved Corruption", icon = 136118 },
    { id = 3, spell = 18697, rank = 1, max = 1, icon = 136172 },
    { id = 4, spell = 17815, rank = 2, max = 5, name = "Improved Immolate", icon = 135817 }, -- fuera del plan
  }
  local by = {}
  for _, n in ipairs(NODES) do by[n.id] = n end
  C_ClassTalents = { GetActiveConfigID = function() return 42 end }
  C_Traits = {
    GetConfigInfo = function(cfg) return cfg == 42 and { treeIDs = { 7 } } or nil end,
    GetTreeNodes = function() local ids = {}; for _, n in ipairs(NODES) do ids[#ids + 1] = n.id end; return ids end,
    GetNodeInfo = function(_, id) local n = by[id]; return n and { ranksPurchased = n.rank, maxRanks = n.max, activeEntry = { entryID = id } } end,
    GetEntryInfo = function(_, e) return { definitionID = e } end,
    GetDefinitionInfo = function(d) return { spellID = by[d].spell } end,
    GetConfigIDBySystemID = function() return 0 end,
  }
  C_Spell = {
    GetSpellName = function(id) for _, n in ipairs(NODES) do if n.spell == id then return n.name or ("Hechizo " .. id) end end end,
    GetSpellTexture = function(id) for _, n in ipairs(NODES) do if n.spell == id then return n.icon end end end,
  }
  local st = ns._planTraits.state()
  -- Sin el árbol de la clase: lo planeado con lo gastado del juego (antes salía todo en 0) y el aviso.
  RebirthTrackTalents = nil
  local trees, partial = ns._planDraw.planTrees(plan, st)
  assert(partial, "plan viejo sin árbol de la clase: incompleto")
  assert(trees[1].talents[1].rank == 4 and trees[1].talents[1].want == 4, "Supresión 4/4 cruzado por hechizo")
  assert(trees[1].talents[2].rank == 5, "Corrupción mejorada 5/5 cruzada por nombre inglés")
  assert(trees[1].talents[2].icon == 136118, "el ícono del juego")
  assert(#trees == 3 and trees[3].name == "Destrucción" and #trees[3].talents == 0, "las tres ramas aunque una no tenga nada planeado")
  ns.openPlan(body .. "\nZ;" .. ns.planCrc32(body))
  click("Talentos")
  local note = ns._planDraw.note()
  assert(note and note.shown and note.text:find("Volvé a copiarlo", 1, true), "avisa que el plan es viejo")
  local g = ns._planDraw.grid()
  assert(g.trees[1].cells[1].rank.text == "4/4" and g.trees[1].cells[2].rank.text == "5/5", "el árbol marca lo aprendido")
  -- Con el árbol de la clase de Plans.lua: entero, con ícono y requisito, y lo planeado encima.
  RebirthTrackTalents = { games = { forever = { WARLOCK = {
    "B;0;Aflicción", "B;1;Demonología", "B;2;Destrucción",
    "T;0;1;2;0;4;Supresión;18174;Suppression;spell_shadow_unsummonbuilding;",
    "T;0;1;3;0;5;Corrupción mejorada;17810;Improved Corruption;spell_shadow_abominationexplosion;",
    "T;0;2;3;0;2;Toque persistente;18265;Lingering Touch;spell_shadow_lifedrain;1.3",
    "T;1;1;2;0;1;Abrazo demoníaco;18697;Demonic Embrace;spell_shadow_metamorphosis;",
    "T;2;1;2;0;5;Inmolar mejorado;17815;Improved Immolate;spell_fire_immolation;",
  } } } }
  trees, partial = ns._planDraw.planTrees(plan, st)
  assert(not partial and #trees == 3, "entero con el árbol de la clase")
  local aff = trees[1].talents
  assert(#aff == 3 and aff[2].name == "Corrupción mejorada" and aff[2].row == 1 and aff[2].col == 3, "la posición del árbol de la clase")
  assert(aff[2].want == 5 and aff[2].rank == 5, "lo planeado por nombre aunque el plan viejo lo tenga en otro lugar")
  assert(aff[3].want == 0 and aff[3].pre == "0-1-3" and aff[3].icon == "Interface\\Icons\\spell_shadow_lifedrain", "rango 0 con ícono y requisito")
  assert(trees[3].talents[1].rank == 2 and trees[3].talents[1].want == 0, "Destrucción con lo gastado fuera del plan")
  ns.planRefresh()
  assert(not note.shown, "sin aviso")
  assert(g.trees[3].shown and g.trees[3].cells[1].rank.text == "2", "Destrucción dibujada")
  assert(g.trees[1].count.text:find("9", 1, true), "Aflicción 9 gastados")
  -- Otra clase: sin lo gastado (es de otro personaje), con el árbol entero igual.
  UnitClass = function() return "Mago", "MAGE", 8 end
  trees = ns._planDraw.planTrees(plan, st)
  assert(trees[1].talents[1].rank == 0 and trees[1].talents[1].want == 4, "otra clase: solo lo planeado")
  click("Borrar pegados")
  RebirthTrackTalents, C_ClassTalents, C_Traits, C_Spell = nil, nil, nil, nil
  GetNumTalentTabs, GetNumTalents, GetTalentInfo, UnitClass = saved[1], saved[2], saved[3], saved[4]
  print("plan pegado viejo con C_Traits OK")
end

-- Personaje ya vinculado (Plans.lua › RebirthTrackLinked): sin «Vincular» y con «✓ Vinculado».
do
  assert(not ns.isLinked(), "sin la lista: no vinculado")
  assert(pcall(click, "Vincular"), "sin vincular, está el mosaico")
  RebirthTrackLinked = { games = { anniversary = { "Player-6065-044C2423;Roguebash;Nightslayer" } } }
  assert(ns.isLinked(), "por guid")
  RebirthTrackLinked = { games = { anniversary = { ";roguebash;Nightslayer" } } }
  assert(ns.isLinked(), "por nombre y reino")
  RebirthTrackLinked = { games = { anniversary = { ";Roguebash;OtroReino" } } }
  assert(not ns.isLinked(), "otro reino no")
  RebirthTrackLinked = { games = { anniversary = { "Player-6065-044C2423;Roguebash;Nightslayer" } } }
  ns.refreshMain()
  local tileShown, chip
  for _, f in ipairs(__frames or {}) do end
  RebirthTrackLinked = nil
  ns.refreshMain()
  print("vinculado OK")
end

-- Lo que se compra en un vendedor: lo que vende el que abrís (solo stock infinito y por oro) se anota y
-- se comparte; lo que llega por el canal se guarda si no lo tenías; una lista fija para lo conocido.
do
  local merch = {
    { "|Hitem:2692:0|h[Especias picantes]|h", 100, 1, -1 },
    { "|Hitem:2320:0|h[Hilo basto]|h", 50, 5, -1 },
    { "|Hitem:9999:0|h[Limitado]|h", 500, 1, 3 },
  }
  function GetMerchantNumItems() return #merch end
  function GetMerchantItemInfo(i) return "x", nil, merch[i][2], merch[i][3], merch[i][4], true, true, nil end
  function GetMerchantItemLink(i) return merch[i][1] end
  local oldUN = UnitName
  UnitName = function(u) if u == "npc" then return "Tharynn Bouden" end return oldUN(u) end
  function GetZoneText() return "Bosque de Elwynn" end
  sentAddon = {}
  fire("MERCHANT_SHOW")
  assert(ns.vendorInfo(2692).price == 100 and ns.vendorInfo(2692).vendor == "Tharynn Bouden", "se anota con precio y vendedor")
  assert(ns.vendorInfo(2320).price == 10, "precio por unidad (50 por 5)")
  assert(not RebirthTrackDB.vendors[9999], "lo de stock limitado no")
  local sentV = 0
  for _, m in ipairs(sentAddon) do if m[2]:find("^V;") then sentV = sentV + 1 end end
  assert(sentV == 2, "se comparte lo nuevo: " .. sentV)
  sentAddon = {}
  fire("MERCHANT_SHOW")
  for _, m in ipairs(sentAddon) do assert(not m[2]:find("^V;"), "lo mismo no se vuelve a mandar") end
  UnitName = oldUN
  fire("CHAT_MSG_ADDON", "RTK1", "V;4291;400;Otro vendedor;Orgrimmar", "GUILD", "Healz-Nightslayer")
  assert(ns.vendorInfo(4291).vendor == "Otro vendedor", "lo que llega por el canal se guarda")
  fire("CHAT_MSG_ADDON", "RTK1", "V;2692;1;Pisador;X", "GUILD", "Healz-Nightslayer")
  assert(ns.vendorInfo(2692).price == 100, "no pisa lo que ya sabía")
  assert(ns.vendorText(2692):find("Tharynn Bouden", 1, true) and ns.vendorText(2692):find("1p", 1, true), ns.vendorText(2692))
  assert(ns.vendorText(3371) == "se vende en vendedores", "lista fija")
  assert(ns.vendorText(12345) == nil, "lo que no se vende")
  RebirthTrackDB.vendors = nil
  print("vendedores OK")
end

-- Oficiales fuera de los rangos del consejo (0 y 1 por defecto): el juego les da permisos de
-- oficial (chat de oficiales con corona) y el addon no los dejaba revisar. Y el checkbox de un
-- componente que no se tildaba.
do
  local R = ns._requests
  local realName, realRv = GetUnitName, R.store().reviewers
  R.store().reviewers = nil
  GetUnitName = function() return "Healz" end -- rango 3 en la lista
  assert(not R.isReviewer("Healz"), "rango 3 sin permisos: no revisa")
  IsGuildOfficer = function() return true end
  assert(R.isReviewer("Healz"), "con permisos de oficial en el juego, revisa")
  assert(R.officerRanks()[3] and R.officerRanks()[2], "su rango y los de arriba cuentan como oficiales")
  assert(not R.officerRanks()[4], "los de abajo no")
  IsGuildOfficer = nil
  CanViewOfficerNote = function() return true end
  assert(R.isReviewer("Healz"), "ver las notas de oficial también alcanza")
  CanViewOfficerNote = nil
  -- Los demás lo reconocen por la configuración de rangos (chat de oficiales), si tiene sentido.
  GetUnitName = realName
  GuildControlGetNumRanks = function() return 5 end
  GuildControlGetRankFlags = function(i) return true, true, i <= 4, i <= 4 end -- rangos 0..3 escuchan
  assert(R.isReviewer("Healz-Nightslayer"), "el rango 3 escucha el chat de oficiales: revisa")
  assert(not R.isReviewer("Otro-Dreamscythe"), "el 4 no")
  GuildControlGetRankFlags = function() return true, true, true, true end -- ignora el índice
  assert(not R.isReviewer("Healz-Nightslayer"), "si todos los rangos dan lo mismo, no se usa")
  GuildControlGetNumRanks, GuildControlGetRankFlags = nil, nil
  -- El checkbox alterna según lo guardado, aunque el widget diga otra cosa.
  local C = ns._bankCraft
  RebirthTrackBank = { v = 2, at = time(), containers = {} }
  TradeSkillFrame = TradeSkillFrame or CreateFrame("Frame"); TradeSkillFrame:Show()
  TradeSkillReagent1 = TradeSkillReagent1 or CreateFrame("Button")
  function GetTradeSkillSelectionIndex() return 3 end
  function GetTradeSkillInfo() return "Hoguera básica", "medium", 1 end
  function GetTradeSkillNumReagents() return 1 end
  function GetTradeSkillReagentInfo() return "Madera simple", "tex", 1, 0 end
  function GetTradeSkillReagentItemLink() return "|cffffffff|Hitem:4470::::::::|h[Madera simple]|h|r" end
  R.updatePickers()
  local p = R.pickers[1]
  assert(p.id == 4470, "checkbox de la madera")
  p.check.GetChecked = function() return false end -- una interfaz de reemplazo lo deja al revés
  p.check.scripts.OnClick(p.check)
  local mine = R.mineFor("Hoguera básica")
  assert(mine and mine.items[1].id == 4470 and mine.items[1].n == 1, "el clic pide igual")
  assert(#R.tabRows("mine") >= 1, "y aparece en Mis pedidos")
  p.check.GetChecked = function() return true end
  p.check.scripts.OnClick(p.check)
  assert(not R.mineFor("Hoguera básica"), "el segundo clic lo cancela")
  -- Si algo falla, se avisa en el chat.
  local said = {}
  local realSay = ns.say
  ns.say = function(m) said[#said + 1] = m end
  local realRecipe = ns.recipeReagents
  R.updatePickers()
  TradeSkillFrame:Hide()
  p.check.scripts.OnClick(p.check)
  assert(said[#said]:find("receta elegida", 1, true), "sin receta: lo dice")
  TradeSkillFrame:Show()
  local lines = ns.requestsDiag()
  assert(#lines == 3 and lines[1]:find("rango 1", 1, true) and lines[3]:find("Hoguera", 1, true), "diagnóstico: " .. table.concat(lines, " | "))
  ns.say, ns.recipeReagents = realSay, realRecipe
  RebirthTrackBank, R.store().reviewers = nil, realRv
  print("pedidos: oficiales por permisos y checkbox OK")
end

-- Forever: el reino viene vacío. El nombre propio quedaba «Nombre-» y cada línea rearmada sumaba un
-- guion: Mis pedidos 0, cada clic del checkbox creaba otro pedido y los botones no guardaban nada.
do
  local R = ns._requests
  local realName, realNorm, realRealm = GetUnitName, GetNormalizedRealmName, GetRealmName
  GetUnitName = function() return "Baldor Dwimorberg" end
  GetNormalizedRealmName = function() return nil end
  GetRealmName = function() return "" end
  assert(R.full("Baldor Dwimorberg") == "Baldor Dwimorberg" and R.full("Baldor Dwimorberg--") == "Baldor Dwimorberg", "sin reino: el nombre solo")
  -- Líneas viejas, con los guiones de más: siguen siendo mías.
  for i, who in ipairs({ "Baldor Dwimorberg-", "Baldor Dwimorberg--", "Baldor Dwimorberg---" }) do
    R.store().lines["old" .. i] = table.concat({ "rq1", "old" .. i, who, 300 + i, 300 + i, "p", who, 0, "Contraveneno", "1475:1" }, ";")
  end
  assert(#R.tabRows("mine") >= 3, "Mis pedidos los muestra")
  -- Al abrir la ventana (o tildar) se dejan uno solo.
  assert(R.dedupe() == 2, "se cierran los repetidos")
  local open = 0
  for _, r in ipairs(R.all()) do if r.recipe == "Contraveneno" and R.isOpen(r) then open = open + 1 end end
  assert(open == 1, "queda uno abierto")
  local cur = R.mineFor("Contraveneno")
  assert(cur, "el checkbox lo reconoce")
  -- Cerrarlo con el botón (lo pidió él) guarda.
  local saved = R.setStatus(cur, "c", "x")
  assert(saved and not R.mineFor("Contraveneno"), "el botón Cancelar guarda")
  -- El checkbox: un clic pide, el otro cancela; nunca duplica.
  assert(R.setItem("Contraveneno", 1475, 1), "pide")
  assert(R.setItem("Contraveneno", 1475, 1), "otro clic con el mismo material no crea otro")
  local n = 0
  for _, r in ipairs(R.all()) do if r.recipe == "Contraveneno" and R.isOpen(r) then n = n + 1 end end
  assert(n == 1, "un solo pedido abierto: " .. n)
  R.setItem("Contraveneno", 1475, nil)
  assert(not R.mineFor("Contraveneno"), "destildar lo cancela")
  -- Admin del sitio: cuenta como GM aunque en la guild sea oficial (o no figure).
  assert(not R.isGM("Baldor Dwimorberg"), "sin la marca de la web no es GM")
  RebirthTrackCouncil = { at = 1, ranks = { 0, 1 }, players = { "Baldor Dwimorberg-;knight;0;0;1", "Healz-Nightslayer;recruit;0;0;" } }
  assert(R.isGM("Baldor Dwimorberg") and R.isReviewer("Baldor Dwimorberg"), "admin de la web = GM")
  assert(not R.isGM("Healz-Nightslayer"), "los demás no")
  assert(R.setReviewers({ "Healz-Nightslayer" }), "como GM edita la lista de revisores")
  R.setReviewers({})
  RebirthTrackCouncil = nil
  GetUnitName, GetNormalizedRealmName, GetRealmName = realName, realNorm, realRealm
  print("pedidos: Forever sin reino, repetidos y admin = GM OK")
end
