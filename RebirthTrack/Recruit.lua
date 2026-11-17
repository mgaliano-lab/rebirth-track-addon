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
    count = "%d caracteres · sale en %d mensaje(s)", tooMany = "|cffff4040%d mensajes: es demasiado, acortalo (máximo %d)|r",
    empty = "|cffff4040El mensaje está vacío.|r",
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
  },
  en = {
    title = "Recruiter",
    intro = "The message to bring people into the guild. Edit it if you want: each line goes out as one message. It's sent with a click; links go out as text (they aren't clickable in chat).",
    default = "<%s> Horde PvP and PvE guild on WoW Forever looking for players. We level together, form groups for dungeons and battlegrounds and get ready for raids. All classes and roles, tanks and healers very welcome.\nGood vibes, no toxicity and clear loot rules. Web: %s - Discord: %s - Whisper me for an invite!",
    count = "%d characters · goes out in %d message(s)", tooMany = "|cffff4040%d messages: too many, shorten it (max %d)|r",
    empty = "|cffff4040The message is empty.|r",
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
local function tipOn(b, fn)
  b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(fn(), 1, 1, 1, true); GameTooltip:Show() end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.refreshRecruit()
  if not win then return end
  win.title:SetText(T("title")); win.intro:SetText(T("intro"))
  -- Sin texto propio, el cuadro sigue al idioma (y al nombre de la guild).
  if settings().recruitText == nil and win.edit:GetText() ~= defaultText() then win.edit:SetText(defaultText()) end
  local list = parts(text())
  win.count:SetText(#list == 0 and T("empty") or #list > MAX_PARTS and T("tooMany"):format(#list, MAX_PARTS)
    or T("count"):format(select(2, text():gsub("[^\128-\191\n]", "")), #list))
  win.reset:SetText(T("reset")); win.yell:SetText(T("yell"))
  local c = channel()
  win.send:SetText(c and T("send"):format(c.name) or T("sendNone"))
  win.chan:SetText(T("channel"))
  win.inviteLabel:SetText(T("inviteLabel")); win.invite:SetText(T("invite"))
end

local function create()
  win = CreateFrame("Frame", "RebirthTrackRecruitFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  win:SetSize(500, 380); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG"); win:SetClampedToScreen(true)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  if win.SetBackdrop then
    win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
  win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal"); win.title:SetPoint("TOP", 0, -14)
  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
  win.intro = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  win.intro:SetPoint("TOPLEFT", 18, -36); win.intro:SetPoint("RIGHT", -18, 0); win.intro:SetJustifyH("LEFT")

  -- El texto: un cuadro de varias líneas con scroll, sobre un fondo oscuro.
  local box = CreateFrame("Frame", nil, win, BackdropTemplateMixin and "BackdropTemplate" or nil)
  box:SetPoint("TOPLEFT", 16, -72); box:SetPoint("TOPRIGHT", -16, -72); box:SetHeight(160)
  if box.SetBackdrop then
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0, 0, 0, 0.6)
  end
  local scroll = CreateFrame("ScrollFrame", "RebirthTrackRecruitScroll", box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8); scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  win.edit = CreateFrame("EditBox", nil, scroll)
  win.edit:SetMultiLine(true); win.edit:SetAutoFocus(false); win.edit:SetFontObject(ChatFontNormal or "ChatFontNormal")
  win.edit:SetWidth(420); win.edit:SetMaxLetters(MAX_LEN * MAX_PARTS * 2)
  win.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  win.edit:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local v = self:GetText()
    settings().recruitText = (v ~= defaultText()) and v or nil
    ns.refreshRecruit()
  end)
  scroll:SetScrollChild(win.edit)
  box:EnableMouse(true); box:SetScript("OnMouseDown", function() win.edit:SetFocus() end)

  win.count = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  win.count:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -8); win.count:SetJustifyH("LEFT")
  win.reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.reset:SetSize(130, 22)
  win.reset:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
  win.reset:SetScript("OnClick", function() settings().recruitText = nil; win.edit:SetText(defaultText()); ns.refreshRecruit() end)
  tipOn(win.reset, function() return T("tipReset") end)

  -- Envíos
  win.yell = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.yell:SetSize(110, 26)
  win.yell:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -36)
  win.yell:SetScript("OnClick", function() yell() end)
  tipOn(win.yell, function() return T("tipYell") end)
  win.send = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.send:SetSize(230, 26)
  win.send:SetPoint("LEFT", win.yell, "RIGHT", 8, 0)
  win.send:SetScript("OnClick", function() sendChannel(); ns.refreshRecruit() end)
  tipOn(win.send, function() return T("tipSend") end)
  win.chan = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.chan:SetSize(100, 26)
  win.chan:SetPoint("LEFT", win.send, "RIGHT", 8, 0)
  win.chan:SetScript("OnClick", function() nextChannel(); ns.refreshRecruit() end)
  tipOn(win.chan, function()
    local names = {}
    for _, c in ipairs(channels()) do names[#names + 1] = c.id .. ". " .. c.name end
    return T("tipChannel"):format(#names > 0 and table.concat(names, ", ") or T("noChannels"))
  end)

  -- Invitar a la guild
  win.inviteLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  win.inviteLabel:SetPoint("TOPLEFT", win.yell, "BOTTOMLEFT", 2, -22)
  win.name = CreateFrame("EditBox", nil, win, "InputBoxTemplate"); win.name:SetSize(180, 22); win.name:SetAutoFocus(false)
  win.name:SetPoint("LEFT", win.inviteLabel, "RIGHT", 12, 0)
  win.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  win.name:SetScript("OnEnterPressed", function(self) if invite(self:GetText()) then self:SetText("") end; self:ClearFocus() end)
  win.invite = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.invite:SetSize(150, 24)
  win.invite:SetPoint("LEFT", win.name, "RIGHT", 8, 0)
  win.invite:SetScript("OnClick", function() if invite(win.name:GetText()) then win.name:SetText("") end end)
  tipOn(win.invite, function() return T("tipInvite") end)

  win:Hide() -- (en WoW un marco nuevo arranca visible)
  win:SetScript("OnShow", function() win.edit:SetText(text()); ns.refreshRecruit() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "RebirthTrackRecruitFrame") end
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
