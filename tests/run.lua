dofile(arg[1] or "tests/wowstub.lua") -- stubs de la API de WoW
local chunk = assert(loadfile(arg[2] or "RebirthTrack/RebirthTrack.lua"))
chunk("RebirthTrack")
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
assert(g.members[1] == "m1;Roguebash;Nightslayer;ROGUE;60;1;Oficial;Player-6065-044C2423;0", g.members[1])
assert(g.members[2]:match("^m1;Healz;Nightslayer;PRIEST;58;3;Miembro;Player%-6065%-0411;%d+$"), g.members[2])
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
