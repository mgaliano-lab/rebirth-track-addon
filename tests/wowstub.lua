-- Simulación mínima de la API de WoW para correr el addon fuera del juego.
local handlers, frames = {}, {}
local function newObj()
  local o = { shown = true, scripts = {}, text = "" }
  return setmetatable(o, { __index = function(t, k)
    if not k:match("^%u") then return nil end -- como en WoW: solo los métodos existen, los campos propios no
    return function(self, ...)
      if k == "SetScript" then local name, fn = ...; self.scripts[name] = fn
      elseif k == "RegisterEvent" then table.insert(handlers, self)
      elseif k == "SetText" then local v = ...; if v == nil then error("SetText(nil)") end; self.text = v
      elseif k == "GetText" then return self.text
      elseif k == "Show" then self.shown = true
      elseif k == "Hide" then self.shown = false
      elseif k == "IsShown" then return self.shown
      elseif k == "SetShown" then self.shown = ...
      elseif k == "CreateFontString" or k == "CreateTexture" then return newObj()
      elseif k == "GetWidth" then return 140
      elseif k == "GetCenter" then return 1000, 700
      elseif k == "GetEffectiveScale" then return 1
      elseif k == "GetPoint" then return "CENTER", nil, "CENTER", 10, 20
      end
    end
  end })
end
function CreateFrame(kind, name, parent, tmpl) local f = newObj(); f.SetBackdrop = function() end; f.StartMoving = function() end; table.insert(frames, f); return f end
UIParent = newObj(); CharacterFrame = newObj(); GameTooltip = newObj(); Minimap = newObj()
function GetCursorPosition() return 1050, 760 end
BackdropTemplateMixin = {}
StaticPopupDialogs = {}; function StaticPopup_Show(n) print("[popup] " .. n) end
function ReloadUI() print("[reload]") end
C_Timer = { After = function(_, fn) fn() end }
local logging, cvars = false, { advancedCombatLogging = "0" }
function GetCVar(k) return cvars[k] end
function SetCVar(k, v) cvars[k] = v end
function LoggingCombat(v) if v ~= nil then logging = v end return logging end
function UnitName() return "Roguebash", nil end
function GetRealmName() return "Nightslayer" end
function UnitClass() return "Pícaro", "ROGUE" end
function UnitLevel() return 60 end
function UnitGUID() return "Player-6065-044C2423" end
function GetBuildInfo() return "2.5.6", "1", "", 20506 end
function GetCurrentRegion() return 1 end
WOW_PROJECT_ID = 5
function GetInstanceInfo() return "Sima Ígnea", "party", 1, "Normal", 5, 0, false, 389 end
function IsInRaid() return false end
function IsInGroup() return false end
function GetNumGroupMembers() return 0 end
function GetNumSubgroupMembers() return 0 end
function CombatLogGetCurrentEventInfo() return nil end
function time() return 1792530000 end
SlashCmdList = {}
function fire(event, ...) for _, f in ipairs(handlers) do if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end end
function click(label) for _, f in ipairs(frames) do if type(f.text) == "string" and f.text:find(label, 1, true) and f.scripts.OnClick then f.scripts.OnClick(f); return true end end error("no hay botón " .. label) end
function shownWindow() return _G.__ui end
