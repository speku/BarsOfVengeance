-- Vengeance Demon Hunter WeakAura for displaying your accumulated health
-- includes: Soul Shards, Soul Cleave, Soul Carver, Feast of Souls, Devour Souls
-- and Soul Barrier

-- and your accumulated pain
-- includes: Immolation Aura, Metamorphosis


------------------------------------ IDs --------------------------------------
local FoS = 207697 -- Feast of Souls
local SCl = 203798 -- Soul Cleave
local SCa = 207407 -- Soul Carver
local BT = 203753 -- Blade Turning
local IA = 178740 -- Immolation Aura
local Me = 191427 -- Metamorphosis
local DS = 212821 -- Devour Souls
local FbP = 213017 -- Fueled by Pain
local Sh = 203783 -- Shear
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
local UnitBuff = UnitBuff
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
local background = "background"
local center = "CENTER"
--------------------------------------------------------------------------------


--------------------------------- events ---------------------------------------
local E_SUU = "SPELL_UPDATE_USABLE"
local E_CLEU = "COMBAT_LOG_EVENT_UNFILTERED"
local E_PTU = "PLAYER_TALENT_UPDATE"
local E_SC = "SPELLS_CHANGED"
local E_PEW = "PLAYER_ENTERING_WORLD"
local E_UA = "UNIT_AURA"
local E_UAAC = "UNIT_ABSORB_AMOUNT_CHANGED"
local E_UHF = "UNIT_HEALTH_FREQUENT"
local E_UPF = "UNIT_POWER_FREQUENT"
--------------------------------------------------------------------------------


------------------------ constants --------------------------------------------
local FoSL = {row = 2, column = 1} -- Feast of Souls location in talent pane
local DSC = 1 -- Devour Souls scalar

local soul_cleave_formula = function(ap) return ap * 5 end -- formula for calculating the minimal heal of Soul Cleave
local soul_cleave_min_cost = 30 -- the minimal cost of Soul Cleave
local soul_cleave_max_cost = 60 -- the maximal cost of Soul Cleave
local soul_carver_soul_fragment_count = 5 -- how many Soul Fragments are spawned by Soul Carver
local immolation_aura_pain_gain = 20 -- how much pain is gained over the duration of Immolation Aura
local metamorphosis_pain_gain = 15 * 7 -- how much pain is generated over the duration of Metamorphosis
local fueled_by_pain_gain = 5 * 7 -- how much pain is generated over the duration of Fueled by Pain procs
local blade_turning_gain = 10 * 0.5 -- how much extra pain is generated by Blade Turning


local lvlToStrata = {
  [1] = "BACKGROUND",
  [2] = "LOW",
  [3] = "MEDIUM",
  [4] = "HIGH",
  [5] = "DIALOG",
  [6] = "FULLSCREEN",
  [7] = "FULLSCREEN_DIALOG",
  [8] = "TOOLTIP"
}
-------------------------------------------------------------------------------


-------------------------- frames ---------------------------------------------
local frame = CreateFrame(f,nil,UIParent)
local pwrFrame = CreateFrame(f,nil,frame)
local hpFrame = CreateFrame(f,nil,frame)
-------------------------------------------------------------------------------


------------------------ forward declarations ----------------------------------
local dfs
local sections


--------------------------------------------------------------------------------

local function UpdateAvailability(self,func,e,...)
    if e == E_SUU then
      local s = GetSpellCooldown(spell)
      if s and s == 0 and not self.available then
        self.available = true
        func()
      end
    elseif e == E_CLEU then
      if select(2,...) == "SPELL_CAST_SUCCESS" and select(4,...) == UnitGUID(p) and select(13,...) == self.spell then
        self.available = false
        func()
      end
    end
end

------------------------------- settings ---------------------------------------

-- default settings
local dfs = {
  pwr = {
    pre = {
      IA = {lvl = 2, clr = {0,1,0,1,1}, events = {E_CLEU, E_SUU}, gain = immolation_aura_pain_gain, Update = function(self,e,...)
        UpdateSpellAvailability(self,function() self.value = self.available and immolation_aura_pain_gain or 0 end,e,...)
      end}
    },
    gain = {
      IA = {lvl = 4, clr = pwrGainClr, events = {E_UA}, gain = immolation_aura_pain_gain, Update = function(self)

      end},
      BT = {lvl = 5, clr = pwrGainClr, events = {E_UA}, gain = blade_turning_gain, Update = function(self)
      end},
      Me = {lvl = 3, clr = pwrGainClr, events = {E_UA}, gain = metamorphosis_pain_gain, Update = function(self)
      end}
    },
    current = {
      powerCurrent = {lvl = 6, clr = {1,1,0,1}, events = {E_UPF}, Update = function(self)
        self.value = UnitHealth(p)
        local nowMax = UnitHealthMax(p)
        if nowMax ~= self.maxValue then
          self.maxValue = nowMax
          for type,ids in pairs(sections[self.res]) do
            for id,_ in pairs(ids) do
                  sections[res][type][id]:TriggerUpdate("maxValue", nowMax)
            end
          end
        end
      end
    }
    background = {
      powerBackground = {lvl = 1, clr = {0,0,0,0.5}, w = 200, h = 20, x = 0, y = -50, sbt = "Interface\\AddOns\\VengeanceBars\\media\\texture.tga", lrIA = 1, clrID = 0.6},
    },
  },

  hp = {
    pre = {
      FoS = {lvl = 4, clr = {0,0.6,0,1}, events = {E_UPF}, Update = function(self)

      end},
      Scl = {lvl = 5, clr = {0,1,0,1}, events = {E_UPF}, healSpell = GetSpellInfo(Sh), healMulti = function(self) GetSpellCount(self.spell) end, Update = function(self)
        local power = UnitPower(p)
        local power = power > soul_cleave_max_cost and soul_cleave_max_cost or power
        local soulCleaveMinHeal = soul_cleave_formula(GetAP())
        self.value = (soulCleaveMinHeal * (power / soul_cleave_max_cost) * 2 * devour_souls_scalar + self:GetHeal()) * self:GetCrit()
      end},
      SCa = {lvl = 3, clr = {1,0,1,1}, events = {E_CLEU, E_SUU}, healSpell = GetSpellInfo(Sh), healMulti = function() return soul_carver_soul_fragment_count end, Update = function(self,e,...)
        UpdateSpellAvailability(self,function() self.value = self.available and immolation_aura_pain_gain or 0 end,e,...)
      end}
    },
    gain = {
      FoS = {lvl = 6, clr = {0.6,0.6,0.6,1}, events = {E_UA}, Update = function(self)
        self:Gain()
      end}
    },
    current = {
      healthCurrent = {lvl = 7, clr = {1,1,1,1}, events = {E_UHF}, Update = function(self)
        self.value = UnitPower(p)
        local nowMax = UnitPowerMax(p)
        if nowMax ~= self.maxValue then
          self.maxValue = nowMax
          for type,ids in pairs(sections[self.res]) do
            for id,_ in pairs(ids) do
                  sections[res][type][id]:TriggerUpdate("maxValue", nowMax)
            end
          end
        end
      end
    },
    background = {
      healthBackground = {lvl = 1, clr = {0,0,0,0.5}, w = 200, h = 20, x = 0, y = -50, sbt = "Interface\\AddOns\\VengeanceBars\\media\\texture.tga", lrIA = 1, clrID = 0.6},
    },
    absorbs = {
      current = {lvl = 2, clr = {0,1,1,1}, events = {E_UAAC} Update = function(self)
        self.value = UnitGetTotalAbsorbs(p)
      end}
    },
  },

}

defaultSettings.__index = defaultSettings
BarsOfVengeanceUserSettings = setmetatable({},defaultSettings)
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
  enabled = true,
  value = 0,
  maxValue = 0,
  available = false,
  Show = function(self) if self.bar then self.bar:Show() end end,
  Hide = function(self) if self.bar then self.bar:Hide() end end,
  Disable = function(self) if self.bar then self.bar:Disable() end end,
  Enable = function(self) if self.bar then self.bar:Enable() end end,
  Untalent = function(self) self.Disable() self.Hide() self.enabled = false end,
  Talent = function(self) self.Enable() self.Show() self.enabled = true end,

  Gain = function(self,val)
    local buffed,_,_,_,_,duration,expirationTime = UnitBuff(p, self.spell)
    self.value buffed and (expirationTime - GetTime()) / duration * (val and val or gain) or 0
  end,

  GetCrit = function(self)
   return self.crit and (GetCritChance() / 100) + 1 or 1
  end,

  GetHeal = function(self)
    local h1,h2 = GetSpellDescription(select(7,GetSpellInfo(self.healSpell))):match("(%d+),(%d+)")
    return tonumber(h1..h2) * self.healMulti()
  end,

  GetAP = function()
    local b,p,n = UnitAttackPower(p)
    return b + p + n
  end,

  TriggerUpdate = function(self, attr, val)
    self[attr] = val
  end,

  Accumulate = function(self)
    local total = 0
    for type, ids in pairs(dfs[self.res]) do
      for id,_ in pairs(ids) do
        local s = dfs[self.res][type][id]
        if s.lvl <= self.lvl then
          total = total + s.value
        end
      end
    end
    return total
  end,

  Move = function(self)

  end
},




function Section:New(res,type,id)
  local surt = BarsOfVengeanceUserSettings[res][type]
  local su = surt[id]
  local sd = dfs[res][type][id]
  local new = {}
  new.res = res
  new.type = type
  new.id = id
  new.crit = su.crit
  new.events = su.events
  new.gain = sd.gain
  new.spell = GetSpellInfo(id)
  new.healSpell = sd.healSpell or spell
  new.healMulti = sd.healMulti or function() return 1 end
  new.directParent = type == pwr and pwrFrame or hpFrame
  new.Update = sd.Update
  new.bar = CreateFrame("StatusBar",nil,new.directParent)
  new.bar:SetStatusBarTexture(surt.background.sbt)
  new.bar:SetStatusBarColor(unpack(su.clr))
  new.Bar:SetPoint("TOPLEFT")
  new.Bar:SetPoint("BOTTOMRIGHT")
  self.__index = self
  return setmetatable(new, self)
end
-------------------------------------------------------------------------------


------------------------ utility functions ------------------------------------


local function UpdateArtifactTraits()
  local u,e,a=UIParent,"ARTIFACT_UPDATE",C_ArtifactUI
   u:UnregisterEvent(e)
   SocketInventoryItem(16)
   local _,_,rank,_,bonusRank = a.GetPowerInfo(select(7,GetSpellInfo(DS)))
   DSC = 1 + (rank + bonusRank) * 0.03
   Invoke(hp,pre,SCa,select(3,a.GetPowerInfo(Sca)) > 0 and "Talent" or "Untalent")
   a.Clear()
   u:RegisterEvent(e)
end


local function Invoke(res,type,id,...)
  local s = sections[res][type][id]
  if s then
    for _,func in pairs({...}) do
      s[func]()
    end
  end
end


local function UpdateTalents
  local t = select(2, GetTalentTierInfo(FoSL.row, FoSL.column )) == 1
  local func = t and "Talent" or "Untalent"
  Invoke(hp,gain,FoS,func)
  Invoke(hp,pre,FoS,t,func)
end


local function SetupFrames()
  local pwrs = BarsOfVengeanceUserSettings[pwr].background.powerBackground
  local hps = BarsOfVengeanceUserSettings[hp].background.powerBackground

  frame:SetPoint(center)

  pwrFrame:SetWidth(pwrs.w)
  pwrFrame:SetHeight(pwrs.h)
  pwrFrame:SetPoint(center, center, pwrs.x, pwrs.y)

  hpFrame:SetPoint(center, center, hps.x, hps.y
  hpFrame:SetWidth(hps.w)
  hpFrame:SetHeight(hps.h)
end


local function Init()

  local function HookPostUpdate(self)
    local u = self.Update
    self.Update = function(self)
      u(self)
      self.bar.SetValue(self:Accumulate())
    end
  end

  local function GatherEventHandlers(section, storage)
    for _, event in pairs(section.events) do
      if not storage[event] then storage.event = {} end
      table.insert(storage[event], {lvl = section.lvl + section.res == pwr and 10 or 0, handler = section.Update})
    end
  end

  local function CreateEventHandler(frame,storage)
    frame:UnregisterAllEvents()
    local mapping = {}
    for event, handlers in ipairs(storage) do
      table.sort(handlers, function(h1,h2) return h1.lvl > h2.lvl)
      frame:RegisterEvent(event)
      mapping[event] = function(...)
        for _,handler in ipairs(handlers) do
          handler.handler(...)
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
        s:HookPostUpdate()
        GatherEventHandlers(s, eventHandlers)
        sections[res][type][id] = s
      end
    end
  end

  frame:SetScript("OnEvent", CreateEventHandler(frame,eventHandlers))
end
-------------------------------------------------------------------------------


----------------------- value prediction ---------------------------------------


--------------------------------------------------------------------------------
