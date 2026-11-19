-- Rebirth Track · Invitador
-- Una ventana (botón «Invitador» de la ventana del addon o /rt invitar) con el mensaje de reclutamiento
-- ya armado: lo mismo que dice la web a quien no es miembro (Horda, PvP y PvE en WoW Forever), la web y
-- la invitación permanente al Discord. Se puede editar antes de mandarlo y se manda con un clic:
-- gritado (/gritar) o al canal de Mundo (o el canal que elijas de los que tenés).
-- El juego solo deja mandar al chat desde un clic del jugador, así que cada envío es un clic (no hay
-- envío automático cada X minutos). Los links salen como texto: en el chat de WoW no son clickeables.
-- Cada renglón del texto es un mensaje; si un renglón pasa los 255 caracteres del chat se parte en
-- palabras. Abajo, «Invitar a la guild» invita al nombre escrito (o a tu objetivo) si tu rango puede.
local ADDON, ns = ...
ns = ns or {}

local WEB = "rebirthknights.fun"
local DISCORD = "discord.gg/Qvy8qeJmmv" -- invitación permanente (sin vencimiento) del Discord de la guild
local MAX_LEN = 255 -- tope de un mensaje de chat
local MAX_PARTS = 4 -- más que esto es spam: no se manda
local COOLDOWN = 30 -- s entre dos envíos al mismo lado, para no quedar silenciado por spam

local TEXTS = {
  es = {
    title = "Invitador",
    intro = "El mensaje para sumar gente a la guild. Editalo si querés: cada renglón sale como un mensaje. Se manda con un clic; los links salen como texto (en el chat no son clickeables).",
    default = "<%s> Guild de la Horda PvP y PvE en WoW Forever busca jugadores. Leveleamos juntos, armamos grupos para mazmorras y campos de batalla y nos preparamos para las raids. Todas las clases y roles, tanques y sanadores muy bienvenidos.\nBuena onda, sin toxicidad y reglas claras de loot. Web: %s - Discord: %s - Susurrame y te invito!",
    count = "%d caracteres · sale en %d mensaje(s)", tooMany = "|cffff7a7e%d mensajes: es demasiado, acortalo (máximo %d)|r",
    empty = "|cffff7a7eEl mensaje está vacío.|r",
    reset = "Texto original", tipReset = "Vuelve al mensaje de la web (con el nombre de tu guild, la web y el Discord).",
    yell = "Gritar", tipYell = "Lo grita (/gritar): lo ven los que están cerca tuyo.",
    send = "Mandar a %s", sendNone = "Mandar al canal",
    tipSend = "Lo manda al canal elegido (por defecto el de Mundo).",
    channel = "Canal ▸", tipChannel = "Cambia a qué canal se manda, entre los que tenés abiertos: %s.",
    noChannels = "no estás en ningún canal (probá /join world)",
    noWorld = "No encuentro el canal de Mundo entre los tuyos: entrá con /join world (o el nombre que use el servidor) o elegí otro con «Canal ▸».",
    wait = "Esperá %d s antes de volver a mandarlo (para que no te silencien por spam).",
    sent = "Mandado (%d mensaje(s)) a %s.", yelled = "Gritado (%d mensaje(s)).",
    inviteLabel = "Invitar a:", invite = "Invitar a la guild", tipInvite = "Le manda la invitación a la guild al nombre escrito (si está vacío, a tu objetivo).",
    noTarget = "Escribí un nombre o seleccioná al personaje.", noRight = "Tu rango de la guild no puede invitar.", noGuild = "No estás en una guild.",
    invited = "Invitación a la guild mandada a %s.",
    msgLabel = "Mensaje · cada renglón sale como un mensaje", namePh = "Nombre",
  },
  en = {
    title = "Recruiter",
    intro = "The message to bring people into the guild. Edit it if you want: each line goes out as one message. It's sent with a click; links go out as text (they aren't clickable in chat).",
    default = "<%s> Horde PvP and PvE guild on WoW Forever looking for players. We level together, form groups for dungeons and battlegrounds and get ready for raids. All classes and roles, tanks and healers very welcome.\nGood vibes, no toxicity and clear loot rules. Web: %s - Discord: %s - Whisper me for an invite!",
    count = "%d characters · goes out in %d message(s)", tooMany = "|cffff7a7e%d messages: too many, shorten it (max %d)|r",
    empty = "|cffff7a7eThe message is empty.|r",
    reset = "Original text", tipReset = "Back to the website's message (with your guild's name, the website and the Discord).",
    yell = "Yell", tipYell = "Yells it (/yell): people near you see it.",
    send = "Send to %s", sendNone = "Send to channel",
    tipSend = "Sends it to the chosen channel (World by default).",
    channel = "Channel ▸", tipChannel = "Changes which channel it goes to, among the ones you have open: %s.",
    noChannels = "you're not in any channel (try /join world)",
    noWorld = "I can't find the World channel among yours: join it with /join world (or the name the server uses) or pick another with «Channel ▸».",
    wait = "Wait %d s before sending it again (so you don't get muted for spam).",
    sent = "Sent (%d message(s)) to %s.", yelled = "Yelled (%d message(s)).",
    inviteLabel = "Invite:", invite = "Invite to guild", tipInvite = "Sends the guild invite to the typed name (if empty, to your target).",
    noTarget = "Type a name or target the character.", noRight = "Your guild rank can't invite.", noGuild = "You're not in a guild.",
    invited = "Guild invite sent to %s.",
    msgLabel = "Message · each line goes out as one message", namePh = "Name",
  },
}
local function T(key) local l = ns.lang and ns.lang() or "es"; return (TEXTS[l] or TEXTS.es)[key] or TEXTS.es[key] end
local function say(msg) if ns.say then ns.say(msg) else print(msg) end end
local function settings() return ns.db().settings end

local function guildName()
  local g = IsInGuild and IsInGuild() and GetGuildInfo and GetGuildInfo("player")
  return (g and g ~= "") and g or "Rebirth Knights"
end
local function defaultText() return T("default"):format(guildName(), WEB, DISCORD) end
local function text() return settings().recruitText or defaultText() end

-- El texto en mensajes de chat: un mensaje por renglón y, si un renglón pasa el tope, se parte en
-- palabras. Sin «|» (en el chat de WoW arranca un código de color y el mensaje no sale).
local function parts(s)
  s = (s or ""):gsub("|", "/"):gsub("\r", "")
  local out = {}
  for raw in (s .. "\n"):gmatch("([^\n]*)\n") do
    local line = raw:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    local cur = ""
    for w in line:gmatch("%S+") do
      local word = w
      while #word > MAX_LEN do -- una palabra eterna (no debería pasar): se corta a la fuerza
        if cur ~= "" then out[#out + 1] = cur; cur = "" end
        out[#out + 1] = word:sub(1, MAX_LEN); word = word:sub(MAX_LEN + 1)
      end
      if cur == "" then cur = word
      elseif #cur + 1 + #word <= MAX_LEN then cur = cur .. " " .. word
      else out[#out + 1] = cur; cur = word end
    end
    if cur ~= "" then out[#out + 1] = cur end
  end
  return out
end

-- Canales abiertos: GetChannelList devuelve (id, nombre, desactivado) de a tres (o de a dos en
-- clientes viejos).
local function channels()
  local raw, out = GetChannelList and { GetChannelList() } or {}, {}
  local i = 1
  while raw[i] ~= nil do
    local id, name = raw[i], raw[i + 1]
    local step = type(raw[i + 2]) == "boolean" and 3 or 2
    if type(id) == "number" and type(name) == "string" and not (step == 3 and raw[i + 2]) then
      out[#out + 1] = { id = id, name = name }
    end
    i = i + step
  end
  return out
end
local function isWorld(name)
  local n = name:lower()
  return n:match("^world") or n:match("^mundo") or n:match("^global")
end
-- El canal elegido (por nombre, porque el número cambia) o el de Mundo.
local function channel()
  local list, want = channels(), settings().recruitChannel
  if want then for _, c in ipairs(list) do if c.name:lower() == want:lower() then return c, list end end end
  for _, c in ipairs(list) do if isWorld(c.name) then return c, list end end
  return nil, list
end

local last = {}
local function cooling(kind)
  local now = GetTime()
  if last[kind] and now - last[kind] < COOLDOWN then say(T("wait"):format(math.ceil(COOLDOWN - (now - last[kind])))); return true end
end
local function ready()
  local list = parts(text())
  if #list == 0 then say(T("empty")); return nil end
  if #list > MAX_PARTS then say(T("tooMany"):format(#list, MAX_PARTS)); return nil end
  return list
end

-- Los dos envíos: van todos los mensajes dentro del mismo clic (el juego exige un clic del jugador;
-- con un temporizador ya no saldrían).
local function yell()
  local list = ready()
  if not list or cooling("yell") then return end
  for _, m in ipairs(list) do SendChatMessage(m, "YELL") end
  last.yell = GetTime()
  say(T("yelled"):format(#list))
end
local function sendChannel()
  local c = channel()
  if not c then say(T("noWorld")); return end
  local list = ready()
  if not list or cooling("channel") then return end
  for _, m in ipairs(list) do SendChatMessage(m, "CHANNEL", nil, c.id) end
  last.channel = GetTime()
  say(T("sent"):format(#list, c.name))
end
local function nextChannel()
  local c, list = channel()
  if #list == 0 then say(T("noWorld")); return end
  local idx = 0
  for i, x in ipairs(list) do if c and x.id == c.id then idx = i end end
  settings().recruitChannel = list[idx % #list + 1].name
end

local function invite(name)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" and UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
    local n, realm = UnitName("target")
    name = (realm and realm ~= "") and (n .. "-" .. realm) or n
  end
  if not (IsInGuild and IsInGuild()) then say(T("noGuild")); return end
  if name == "" then say(T("noTarget")); return end
  if CanGuildInvite and not CanGuildInvite() then say(T("noRight")); return end
  if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(name) else GuildInvite(name) end
  say(T("invited"):format(name))
  return name
end

-- Ventana
local win
local W, H = 520, 460
local EDIT_H = 96 -- alto del cuadro editable
local LINE_H = 20 -- cada mensaje numerado, debajo del cuadro

-- Los mensajes tal como van a salir, numerados (uno por renglón del chat), dentro del mismo panel
-- que el cuadro editable.
local function showLines(list)
  local U = ns.ui
  win.lines = win.lines or {}
  local n = math.min(#list, MAX_PARTS)
  for i = 1, math.max(n, #win.lines) do
    local l = win.lines[i]
    if not l and i <= n then
      l = CreateFrame("Frame", nil, win.box)
      l:SetHeight(LINE_H)
      l:SetPoint("TOPLEFT", 1, -(EDIT_H + 1 + (i - 1) * LINE_H)); l:SetPoint("TOPRIGHT", -1, -(EDIT_H + 1 + (i - 1) * LINE_H))
      U.fill(l, U.C.rowAlt, (i % 2 == 1) and 1 or 0)
      l.no = U.font(l, "GameFontNormalSmall", U.C.gold, "LEFT"); l.no:SetPoint("LEFT", 8, 0); l.no:SetWidth(16)
      l.fs = U.font(l, "GameFontHighlightSmall", U.C.text, "LEFT")
      l.fs:SetPoint("LEFT", 28, 0); l.fs:SetPoint("RIGHT", -8, 0)
      if l.fs.SetWordWrap then l.fs:SetWordWrap(false) end
      win.lines[i] = l
    end
    if l then
      l:SetShown(i <= n)
      if i <= n then l.no:SetText(tostring(i)); l.fs:SetText((list[i]:gsub("|", "/"))) end
    end
  end
  win.sep:SetShown(n > 0)
  win.box:SetHeight(EDIT_H + (n > 0 and (1 + n * LINE_H) or 0) + 2)
end

function ns.refreshRecruit()
  if not win then return end
  local U = ns.ui
  win.title:SetText(T("title")); win.intro:SetText(T("intro"))
  win.msgLabel:SetText(T("msgLabel"))
  -- Sin texto propio, el cuadro sigue al idioma (y al nombre de la guild).
  if settings().recruitText == nil and win.edit:GetText() ~= defaultText() then win.edit:SetText(defaultText()) end
  local list = parts(text())
  local ok = #list > 0 and #list <= MAX_PARTS
  win.count:SetText(#list == 0 and T("empty") or #list > MAX_PARTS and T("tooMany"):format(#list, MAX_PARTS)
    or T("count"):format(select(2, text():gsub("[^\128-\191\n]", "")), #list))
  local cc = ok and U.C.green or U.C.red
  if win.count.SetTextColor then win.count:SetTextColor(cc[1], cc[2], cc[3]) end
  showLines(list)
  win.reset:SetText(T("reset")); win.yell:SetText(T("yell"))
  local c = channel()
  win.send:SetText(c and T("send"):format(c.name) or T("sendNone"))
  win.chan:SetText(T("channel"))
  win.inviteLabel:SetText(T("inviteLabel")); win.invite:SetText(T("invite"))
  if win.name.ph then win.name.ph:SetText(T("namePh")) end
  win.reset.tip, win.yell.tip, win.send.tip, win.invite.tip = T("tipReset"), T("tipYell"), T("tipSend"), T("tipInvite")
  local names = {}
  for _, ch in ipairs(channels()) do names[#names + 1] = ch.id .. ". " .. ch.name end
  win.chan.tip = T("tipChannel"):format(#names > 0 and table.concat(names, ", ") or T("noChannels"))
end

local function create()
  local U = ns.ui
  win = U.window("RebirthTrackRecruitFrame", W, H, T("title"), { point = { "CENTER", 0, 0 } })
  local y = win.top
  win.intro = U.font(win, "GameFontHighlightSmall", U.C.muted, "LEFT")
  win.intro:SetPoint("TOPLEFT", 12, y - 10); win.intro:SetPoint("RIGHT", -12, 0)
  y = y - 48

  -- Encabezado del mensaje: qué es y «Texto original».
  win.reset = U.button(win, T("reset"), nil, function() settings().recruitText = nil; win.edit:SetText(defaultText()); ns.refreshRecruit() end)
  win.reset:SetPoint("TOPRIGHT", -12, y)
  win.msgLabel = U.font(win, "GameFontNormalSmall", U.C.muted, "LEFT")
  win.msgLabel:SetPoint("LEFT", win, "TOPLEFT", 12, y - 11); win.msgLabel:SetPoint("RIGHT", win.reset, "LEFT", -8, 0)
  if win.msgLabel.SetWordWrap then win.msgLabel:SetWordWrap(false) end
  y = y - 28

  -- El panel del mensaje (estilo campo de texto): arriba el cuadro editable con scroll, abajo los
  -- mensajes numerados tal como van a salir.
  local box = CreateFrame("Frame", nil, win)
  box:SetPoint("TOPLEFT", 12, y); box:SetPoint("TOPRIGHT", -12, y); box:SetHeight(EDIT_H + 2)
  U.fill(box, U.C.input, 1)
  box.edgeT = U.edge(box, U.C.btnLine, 1)
  win.box = box
  win.sep = U.hline(box, -EDIT_H, 0)
  local scroll = CreateFrame("ScrollFrame", "RebirthTrackRecruitScroll", box)
  scroll:SetPoint("TOPLEFT", 8, -6); scroll:SetPoint("TOPRIGHT", -8, -6); scroll:SetHeight(EDIT_H - 12)
  win.edit = CreateFrame("EditBox", nil, scroll)
  win.edit:SetMultiLine(true); win.edit:SetAutoFocus(false); win.edit:SetFontObject(ChatFontNormal or "ChatFontNormal")
  win.edit:SetWidth(W - 24 - 16); win.edit:SetMaxLetters(MAX_LEN * MAX_PARTS * 2)
  win.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  win.edit:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local v = self:GetText()
    settings().recruitText = (v ~= defaultText()) and v or nil
    ns.refreshRecruit()
  end)
  win.edit:SetScript("OnEditFocusGained", function() box.edgeT:SetColor(U.C.gold[1], U.C.gold[2], U.C.gold[3], 1) end)
  win.edit:SetScript("OnEditFocusLost", function() box.edgeT:SetColor(U.C.btnLine[1], U.C.btnLine[2], U.C.btnLine[3], 1) end)
  -- Sin la barra de Blizzard: la rueda del mouse mueve el texto y el cursor siempre queda a la vista.
  win.edit:SetScript("OnCursorChanged", function(_, _, cy, _, ch)
    local top = (scroll.GetVerticalScroll and scroll:GetVerticalScroll()) or 0
    local vis = (scroll.GetHeight and scroll:GetHeight()) or 0
    cy, ch = -(cy or 0), ch or 0
    if cy < top then scroll:SetVerticalScroll(cy)
    elseif vis > 0 and cy + ch > top + vis then scroll:SetVerticalScroll(cy + ch - vis) end
  end)
  scroll:SetScrollChild(win.edit)
  if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = (self.GetVerticalScrollRange and self:GetVerticalScrollRange()) or 0
    local cur = (self.GetVerticalScroll and self:GetVerticalScroll()) or 0
    self:SetVerticalScroll(math.max(0, math.min(max, cur - (delta or 0) * 28)))
  end)
  box:EnableMouse(true); box:SetScript("OnMouseDown", function() win.edit:SetFocus() end)

  -- Cuántos caracteres y mensajes (verde si sale, rojo si no).
  win.count = U.font(win, "GameFontHighlightSmall", U.C.green, "LEFT")
  win.count:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -8); win.count:SetPoint("RIGHT", win, "RIGHT", -12, 0)

  -- Envíos: Gritar · Mandar a … (la acción principal, ocupa lo que sobra) · Canal ▸
  win.yell = U.button(win, T("yell"), nil, function() yell() end, { h = 24 })
  win.yell:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -28)
  win.chan = U.button(win, T("channel"), nil, function() nextChannel(); ns.refreshRecruit() end, { h = 24 })
  win.chan:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -28)
  win.send = U.button(win, T("sendNone"), "pri", function() sendChannel(); ns.refreshRecruit() end, { h = 24 })
  win.send:SetPoint("LEFT", win.yell, "RIGHT", 6, 0); win.send:SetPoint("RIGHT", win.chan, "LEFT", -6, 0)

  -- Invitar a la guild, en la barra de abajo.
  local ft = U.footer(win, 44)
  win.inviteLabel = U.font(ft, "GameFontNormalSmall", U.C.text, "LEFT")
  win.inviteLabel:SetPoint("LEFT", 12, 0)
  win.invite = U.button(ft, T("invite"), "pri", function() if invite(win.name:GetText()) then win.name:SetText("") end end, { h = 24 })
  win.invite:SetPoint("RIGHT", -12, 0)
  win.name = U.input(ft, 180, 24, T("namePh"))
  win.name:SetPoint("LEFT", win.inviteLabel, "RIGHT", 8, 0); win.name:SetPoint("RIGHT", win.invite, "LEFT", -8, 0)
  win.name:SetScript("OnEnterPressed", function(self) if invite(self:GetText()) then self:SetText("") end; self:ClearFocus() end)

  win:Hide() -- (en WoW un marco nuevo arranca visible)
  win:SetScript("OnShow", function() win.edit:SetText(text()); ns.refreshRecruit() end)
end

-- /rt invitar y el botón de la ventana del addon: abre o cierra el invitador.
function ns.openRecruit()
  if not win then create() end
  if win:IsShown() then win:Hide() else win:Show(); win.edit:SetText(text()); ns.refreshRecruit() end
end

-- Para las pruebas.
ns._recruit = { parts = parts, channels = channels, channel = channel, text = text, defaultText = defaultText,
  yell = yell, sendChannel = sendChannel, nextChannel = nextChannel, invite = invite, window = function() return win end,
  resetCooldown = function() last = {} end }
