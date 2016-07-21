-- Vengeance Demon Hunter WeakAura for displaying your accumulated health
-- includes: Soul Shards, Soul Cleave, Soul Carver, Feast of Souls, Devour Souls
-- and Soul Barrier

-- and your accumulated pain
-- includes: Immolation Aura, Metamorphosis, Consume Magic


------------------------------------ IDs --------------------------------------
local FoS = 207697 -- Feast of Souls
local SCl = 203798 -- Soul Cleave
local SCa = 207407 -- Soul Carver
local BT = 203753 -- Blade Turning
local IA = 178740 -- Immolation Aura
local Me = 191427 -- Metamorphosis
local DS = 212821 -- Devour Souls
local FbP = 213017 -- Fueled by Pain
-------------------------------------------------------------------------------


------------------- global functions "localized" -------------------------------
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local GetSpellCooldown = GetSpellCooldown
local GetSpellDescription = GetSpellDescription
local GetSpellInfo = GetSpellInfo
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitAttackPower = UnitAttackPower
local GetCritChance = GetCritChance
local GetTime = GetTime
local GetSpellCount = GetSpellCount
-------------------------------------------------------------------------------


------------------- abbreviations/shortcuts -----------------------------------
local p = "player"
local hp = "health"
local pwr = "power"
local pre = "prediction"
local gain = "gain"
local w = "width"
local h = "height"
local x = "x"
local y = "y"
local f = "Frame"
local res = "resource"
local t = "type"
local sbt = "statusBarTexture"
local sbMin = 0
local sbMax = 100
local clrIA = "colorIntensityActive"
local clrID = "colorIntensityDisabled"
local pwrGainClr = {0.6,0.6,0,1}
local hpXOffset = "hpXOffset"
local hpYOffset = "hpYOffset"
local pwrXOffset = "pwrXOffset"
local pwrYOffset = "pwrYOffset"
--------------------------------------------------------------------------------


--------------------------------- events ---------------------------------------
local E_SUU = "SPELL_UPDATE_USABLE"
local E_CLEU = "COMBAT_LOG_EVENT_UNFILTERED"
local E_PTU = "PLAYER_TALENT_UPDATE"
local E_SC = "SPELLS_CHANGED"
local E_PEW = "PLAYER_ENTERING_WORLD"
local E_UA = "UNIT_AURA"
local E_AAC = "UNIT_ABSORB_AMOUNT_CHANGED"
local E_UHF = "UNIT_HEALTH_FREQUENT"
local E_UPF = "UNIT_POWER_FREQUENT"
--------------------------------------------------------------------------------


-------------------------- frames ---------------------------------------------
local frame = CreateFrame(f,nil,UIParent)
local pwrFrame = CreateFrame(f,nil,frame)
local hpFrame = CreateFrame(f,nil,frame)
-------------------------------------------------------------------------------


------------------------------- settings ---------------------------------------
function Setting(lvl, clr, Update, events)
  return {
    enabled = true,
    crit = true,
    lvl = lvl,
    Update = Update,
    clr = clr
    events = events
  }
end

-- default settings
local dfs = {
  pwr = {
    pre = {
      IA = Setting({0,1,0,1,1}, {E_CLEU, E_SUU})
    },
    gain = {
      IA = Setting(pwrGainClr, {E_UA}),
      BT = Setting(pwrGainClr, {E_UA}),
      Me = Setting(pwrGainClr, {E_UA})
    }
  },

  hp = {
    pre = {
      FoS = Setting({0,0.6,0,1}, {E_UPF}),
      Scl = Setting({0,1,0,1}, {E_UPF}),
      SCa = Setting({1,0,1,1}, {E_CLEU, E_SUU})
    },
    gain = {
      FoS = Setting({0.6,0.6,0.6,1}, {E_UA})
    }
  },

  sbt = "Interface\\AddOns\\VengeanceBars\\media\\texture.tga",
  w = 200,
  h = 20,
  x = 0,
  y = -50,
  clrIA = 1,
  clrID = 0.6,

}

defaultSettings.__index = defaultSettings
BarsOfVengeanceUserSettings = setmetatable({},defaultSettings)
-------------------------------------------------------------------------------


------------------------ constants --------------------------------------------
local FoSL = {row = 2, column = 1} -- Feast of Souls location in talent pane
local SCaU = false -- Soul Carver Unlocked
local DSC = 1 -- Devour Souls scalar
local FoST = false -- Feast of Souls talented
-------------------------------------------------------------------------------


------------------------ storage ----------------------------------------------
local sections = {
  hp = {pre = {}, gain = {}},
  pwr = {pre = {}, gain = {}}
}
-------------------------------------------------------------------------------


------------------------ structures --------------------------------------------
local Section = {
  parent = frame,
  value = 0,
  Show = function(self) self.bar and self.bar:Show() end,
  Hide = function(self) self.bar and self.bar:Hide() end,
  Disable = function(self) self.bar and self.bar:Disable(),
  Enable = function(self) self.bar and self.bar:Enable()
}


function Section:New(res,type,id)
  local s = BarsOfVengeanceUserSettings[res][type][id]
  local new = {}
  new.res = res
  new.type = type
  new.id = id
  new.crit = s.crit
  new.events = s.events
  new.spell = GetSpellInfo(id)
  new.directParent = type == pwr and pwrFrame or hpFrame
  new.Update = dfs[res][type][id].Update
  new.bar = CreateFrame("StatusBar",nil,new.directParent)
  new.bar:SetStatusBarTexture(BarsOfVengeanceUserSettings.sbt)
  new.bar:SetStatusBarColor(unpack(s.clr)
  self.__index = self
  return setmetatable(new, self)
end
-------------------------------------------------------------------------------


------------------------ utility functions ------------------------------------
local handler

local function GetAP()
  local b,p,n = UnitAttackPower(p)
  return b + p + n
end


local function GetCrit()
 return crit_enabled and (GetCritChance() / 100) + 1 or 1
end


local function GetHeal(spell,regex)
  local h1,h2 = GetSpellDescription(select(7,GetSpellInfo(spell))):match(regex or "(%d+),(%d+)")
  return tonumber(h1..h2)
end


local function UpdateArtifactTraits()
  local u,e,a=UIParent,"ARTIFACT_UPDATE",C_ArtifactUI
   u:UnregisterEvent(e)
   SocketInventoryItem(16)
   local _,_,rank,_,bonusRank = a.GetPowerInfo(select(7,GetSpellInfo(DS)))
   DSC = 1 + (rank + bonusRank) * 0.03
   ScaU = select(3,a.GetPowerInfo(Sca)) > 0
   a.Clear()
   u:RegisterEvent(e)
end


local function UpdateTalents
  FoST = select(2, GetTalentTierInfo(FoSL.row, FoSL.column )) == 1
end


local function Init()

  local function GatherEventHandlers(section, storage)
    for _, event in section.events do
      if not storage[event] then storage.event = {} end
      table.insert(addstorage[event], section.Update)
    end
  end

  local function CreateEventHandler(storage)
    local mapping = {}
    for event, handlers in pairs(storage) do
      mapping[event] = function(...)
        for _,handler in pairs(handlers) do
          handler(...)
        end
      end
    end
    return function(e,...)
      mapping[e](...)
    end
  end

  local eventHandlers = {}

  for res, type in pairs(dfs) do
    for id, settings in pairs(type) do
      if BarsOfVengeanceUserSettings[res][type][id].enabled then
        local s = Section:New(res,type,id)
        GatherEventHandlers(s, eventHandlers)
        sections[res][type][id] = s
      end
    end
  end

  frame:SetScript("OnEvent", CreateEventHandler(eventHandlers))
end
-------------------------------------------------------------------------------
