dofile(arg[1] or "tests/wowstub.lua") -- stubs de la API de WoW
local chunk = assert(loadfile(arg[2] or "RebirthTrack/RebirthTrack.lua"))
local ns = {} -- como en WoW: los archivos del addon comparten esta tabla
chunk("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Collect.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Plan.lua"))("RebirthTrack", ns)
assert(loadfile("RebirthTrack/Council.lua"))("RebirthTrack", ns)
fire("ADDON_LOADED", "RebirthTrack")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
local rt = SlashCmdList.REBIRTHTRACK
for _, c in ipairs({ "", "help", "ayuda", "mostrar", "status", "estado", "vincular", "link", "registrar", "detener", "mazmorras", "dungeons", "ocultar", "show", "borrar", "minimapa", "minimap", "cualquiera" }) do
  print("== /rt " .. c); rt(c)
end
for _, b in ipairs({ "Vincular personaje", "Estado", "Detener registro", "Registrar ahora", "Mazmorras", "Ayuda", "Volver" }) do print("== click " .. b); click(b) end
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
print("lista de la guild OK")

-- Canal de addons: el prefijo se registra, al entrar avisa hasta dónde tiene datos y se anuncia.
assert(registeredPrefix == "RTK1", "registra el prefijo RTK1")
local function sentWith(pat) for _, s in ipairs(sentAddon) do if s[1] == "RTK1" and s[3] == "GUILD" and s[2]:match(pat) then return s[2] end end end
assert(sentWith("^H;%d+$"), "manda el saludo H")
assert(sentWith("^K;%d+;S;us;Nightslayer;Roguebash;ROGUE;60;Player%-6065%-044C2423;5$"), "se anuncia a sí mismo")
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
-- Encantamiento usa la ventana de «craft».
function GetCraftDisplaySkillLine() return "Encantamiento", 120, 150 end
function GetNumCrafts() return 1 end
function GetCraftInfo() return "Encantar brazales: aguante", "", "optimal" end
function GetCraftItemLink() return "|cffffffff|Henchant:13501|h[Encantar brazales: aguante]|h|r" end
fire("CRAFT_SHOW")
assert(D[ME]["r1:Encantamiento"]:match(";Encantamiento;120;150;s13501$"), D[ME]["r1:Encantamiento"])
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
RebirthTrackCouncil = { at = 1, ranks = { 0, 1 }, players = { "Tanque-Nightslayer;knight;4;0", "Healz-Nightslayer;recruit;4;3" } }
local c = LC.candidates(s, s.items[1])
assert(c[1].name == "Roguebash-Nightslayer" and c[2].name == "Tanque-Nightslayer" and c[3].name == "Healz-Nightslayer", c[1].name .. c[2].name)
assert(c[2].rank == "knight" and c[2].attended == 4 and c[2].votes == 1)
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
