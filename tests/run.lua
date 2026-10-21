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
