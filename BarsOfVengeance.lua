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
local c = "color"
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
function Setting(lvl, clr, calc, events)
  return {
    enabled = true,
    lvl = lvl,
    calc = calc,
    clr = clr
    events = events
  }
end

-- default settings
local dfs = {
  pwr = {
    pre = {
      IA = Setting({0,1,0,1,1},{E_SUU})
    },
    gain = {
      IA = Setting(pwrGainClr),
      BT = Setting(pwrGainClr),
      Me = Setting(pwrGainClr)
    }
  },

  hp = {
    pre = {
      FoS = Setting({0,0.6,0,1}),
      Scl = Setting({0,1,0,1}),
      SCa = Setting({1,0,1,1})
    },
    gain = {
      FoS = Setting({0.6,0.6,0.6,1})
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

------------------------ structures --------------------------------------------
local Section = {
  parent = frame,
  Show = Function(self) self.bar and self.bar:Show() end
  Hide = Function(self) self.bar and self.bar:Hide() end
  Val = Function(self) return self.calc() end
}


function Section:New(res,type,id)
  local new = {}
  new.id = id
  new.spell = GetSpellInfo(id)
  new.directParent = type == pwr and pwrFrame or hpFrame
  new.calc = dfs[res][type][id].calc
  new.bar = CreateFrame("StatusBar",nil,new.directParent)
  new.bar:SetStatusBarTexture(BarsOfVengeanceUserSettings.sbt)
  new.bar:SetStatusBarColor(unpack(BarsOfVengeanceUserSettings[res][type][id].clr))
  self.__index = self
  return setmetatable(new, self)
end
-------------------------------------------------------------------------------


------------------------ utility functions ------------------------------------
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
-------------------------------------------------------------------------------
