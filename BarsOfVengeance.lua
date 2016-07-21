------------------------------------ IDs --------------------------------------
local FoS = 207697 -- Feast of Souls
local SCl = -- Soul Cleave
local SCa = -- Soul Carver
local BT = -- Blade Turning
local IAS = -- Immolation Aura spell
local IAB = -- Immolation Aura buff
local Me = -- Metamorphosis
-------------------------------------------------------------------------------


------------------- global functions -----------------------------------------
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local GetSpellCooldown = GetSpellCooldown
local GetSpellDescription = GetSpellDescription
local GetSpellInfo = GetSpellInfo
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
-------------------------------------------------------------------------------


------------------- abbreviations/shortcuts -----------------------------------
local p = "player"
local hp = "health"
local pwr = "power"
local pre = "prediction"
local gain = "gain"
--------------------------------------------------------------------------------


-------------------------- frames ---------------------------------------------


-------------------------------------------------------------------------------


------------------------ structures --------------------------------------------
function Setting(lvl, calc)
  return {
    enabled = true,
    lvl = lvl,
    calc = calc
  }
end

local function Key(id,res,type)
  return {
    id = id,
    res = res,
    type = type
  }
end

local Section = {
  parent =
}

function Section:New(id,type)
  local new = {}
  new.id = id
  new.spell = GetSpellInfo(id)
  return setmetatable(new, self)
end

function Section:Val()
  self.
end
-------------------------------------------------------------------------------


------------------------------- settings ---------------------------------------
local defaultSettings = {
  [Key(FoS,pwr,pre)] = Setting(lvl,calc = ,
  [Key(FoS,pwr,gain)] = Setting(lvl,
  [Key(SCl,hp,pre)] = Setting(),
  [Key(SCa,hp,pre)] = Setting(),
  [Key(BT,pwr,gain)] = Setting(),
  [Key(IAS,pwr,pre)] = Setting(),
  [Key(IAB,pwr,gain)] = Setting(),
  [Key(Me,pwr,gain)] = Setting()
}
defaultSettings.__index = defaultSettings

BarsOfVengeanceUserSettings = setmetatable({},defaultSettings)
-------------------------------------------------------------------------------
