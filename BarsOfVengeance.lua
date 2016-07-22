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
local devour_souls_scalar = 1 -- Devour Souls scalar
local soul_cleave_formula = function(ap) return ap * 5 end -- formula for calculating the minimal heal of Soul Cleave
local soul_cleave_min_cost = 30 -- the minimal cost of Soul Cleave
local soul_cleave_max_cost = 60 -- the maximal cost of Soul Cleave
local soul_carver_soul_fragment_count = 5 -- how many Soul Fragments are spawned by Soul Carver
local immolation_aura_pain_gain = 20 -- how much pain is gained over the duration of Immolation Aura
local metamorphosis_pain_gain = 15 * 7 -- how much pain is generated over the duration of Metamorphosis
local fueled_by_pain_gain = 5 * 7 -- how much pain is generated over the duration of Fueled by Pain procs
local blade_turning_gain = 10 * 0.5 -- how much extra pain is generated by Blade Turning

-- maps integers to layers
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
local frame = CreateFrame(f,nil,UIParent) -- parent frame
local pwrFrame = CreateFrame(f,nil,frame) -- power frame
local hpFrame = CreateFrame(f,nil,frame) -- health frame
-------------------------------------------------------------------------------


------------------------ forward declarations ----------------------------------
local dfs
local sections

--------------------------------------------------------------------------------

-- keeps track of spell availability and calls its function parameter upon
-- availability change
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


local function IterateTable(table, func)
    for res, resTable in pairs(table) do
      for type, typeTable in pairs(resTable) do
        for id, idTable in pairs(typeTable) do
          func(res,type,id)
        end
      end
    end
end

------------------------------- settings ---------------------------------------

-- default settings
dfs = {
  [pwr] = { -- settings relating to power "sections" of your bars

    [pre] = { -- power prediction

      [IA] = { -- Immolation Aura
        enabled = true,
        lvl = 2, -- strata
        clr = {0,1,0,1,1}, -- color
        events = {E_CLEU, E_SUU}, -- events that cause the related value/bar to change
        gain = immolation_aura_pain_gain, -- how much pain is gained over the total duration of Immolation Aura
        Update = function(self,e,...) -- function to be triggered upon relevant events -> causes a change in the related sections' value
          UpdateAvailability(self,function() self.value = self.available and immolation_aura_pain_gain or 0 end,e,...)
        end}
    },
    [gain] = { -- definitive power gains of active buffs

      [IA] = { -- Immolation Aura
        enabled = true,
        lvl = 4,
        clr =
        pwrGainClr,
        events = {E_UA},
        gain = immolation_aura_pain_gain,
        Update = function(self)
          self:Gain()
        end},

      [BT] = { -- Blade Turning
        enabled = true,
        lvl = 5,
        clr = pwrGainClr,
        events = {E_UA},
        gain = blade_turning_gain,
        Update = function(self)
          self:Gain()
        end},

      [Me] = { -- Metamorphosis
        enabled = true,
        lvl = 3,
        clr = pwrGainClr,
        events = {E_UA},
        gain = metamorphosis_pain_gain,
        Update = function(self)
          self:Gain(self.available and self.gain or fueled_by_pain_gain)
        end}
    },

    current = { -- current power level

      power = {
        enabled = true,
        lvl = 6,
        clr = {1,1,0,1},
        events = {E_UPF},
        Update = function(self)
          self.value = UnitPower(p)
          local nowMax = UnitPowerMax(p)
          if nowMax ~= self.maxValue then
            self.maxValue = nowMax
            self.bar:SetMinMaxValues(0, nowMax)
            IterateTable(sections, function(res,type,id)
              sections[res][type][id]:TriggerUpdate("maxValue", nowMax)
              sections[res][type][id]:SetMinMaxBarValues(0, nowMax)
            end)
          end
        end
    }
  },

    background = { -- background bar
      background = {
        enabled = true,
        lvl = 1,
        clr = {0,0,0,0.5},
        w = 200, -- width of power bars
        h = 20, -- height of power bars
        x = 0, -- x-offset of power bars from the addons' parent frame
        y = -150, -- equivalent y-offset
        sbt = "Interface\\AddOns\\VengeanceBars\\media\\texture.tga", -- status bar texture used for power bars
        lrIA = 1, -- color saturation of bars of which the underlying spell is meant to be used
        clrID = 0.6}, -- color saturation of bars of which the underlying spell should not be used
    },
  },

  [hp] = { -- health related settings

    [pre] = { -- prediction

      [FoS] = { -- Feast of Souls
        enabled = true,
        lvl = 4,
        clr = {0,0.6,0,1},
        events = {E_UPF},
        Update = function(self)
          local power = sections[pwr].current.power.value
          if power >= soul_cleave_min_cost then
            self:GetHeal()
          else
            self.value = 0
          end
        end},

      [SCl] = { -- Soul Cleave
        enabled = true,
        lvl = 5,
        clr = {0,1,0,1},
        events = {E_UPF},
        healSpell = Sh,
        Update = function(self)
          local power = sections[pwr].current.power.value
          if power >= soul_cleave_min_cost then
            power = power > soul_cleave_max_cost and soul_cleave_max_cost or power
            self:GetHeal(
              GetSpellCount(self.healSpell),
              function()
                return soul_cleave_formula(self:GetAP()) * (power / soul_cleave_max_cost) * 2 * devour_souls_scalar
              end)
          else
            self.value = 0
          end
        end},

      [SCa] = { -- Soul Carver
        enabled = true,
        lvl = 3,
        clr = {1,0,1,1},
        events = {E_CLEU, E_SUU},
        healSpell = GetSpellInfo(Sh),
        Update = function(self,e,...)
          UpdateAvailability(self, function()
            if self.available then
              self:GetHeal(soul_carver_soul_fragment_count)
            else
              self.value = 0
            end
          end,e,...)
        end}
    },

    [gain] = { -- definitive health gains of active buffs

      [FoS] = { -- Feast of Souls
        enabled = true,
        lvl = 6,
        crit = false,
        clr = {0.6,0.6,0.6,1},
        events = {E_UA},
        Update = function(self)
          self:Gain(self:GetHeal(nil,nil,true))
        end}
    },

    current = { -- current health

      health = {
        enabled = true,
        lvl = 7,
        clr = {1,1,1,1},
        events = {E_UHF},
        Update = function(self)
          self.value = UnitHealth(p)
          local nowMax = UnitHealthMax(p)
          if nowMax ~= self.maxValue then
            self.maxValue = nowMax
            self:SetMinMaxBarValues(0, nowMax)
            IterateTable(sections, function(res,type,id)
              sections[res][type][id]:TriggerUpdate("maxValue", nowMax)
              sections[res][type][id]:SetMinMaxBarValues(0, nowMax)
            end)
          end
        end
        }
    },

    background = {

      background = {
        enabled = true,
        lvl = 1,
        clr = {0,0,0,0.5},
        w = 200,
        h = 20,
        x = 0,
        y = -100,
        sbt = "Interface\\AddOns\\VengeanceBars\\media\\texture.tga",
        lrIA = 1,
        clrID = 0.6},
    },

    absorbs = { -- absorbs

      current = {
        enabled = true,
        lvl = 2,
        clr = {0,1,1,1},
        events = {E_UAAC},
        Update = function(self)
          self.value = UnitGetTotalAbsorbs(p)
        end}
    },
  }
}

BarsOfVengeanceUserSettings = setmetatable({},{__index = dfs}) -- only a few settings
-- should be changable by the user, so must stuff is accessed via the meta table
-------------------------------------------------------------------------------


------------------------ storage ----------------------------------------------

-- all currently instantiated sections
sections = {
  [hp] = {[pre] = {}, [gain] = {}, current = {}, absorbs = {}, background = {}},
  [pwr] = {[pre] = {}, [gain] = {}, current = {}, background = {}},
}
-------------------------------------------------------------------------------


------------------------ structures --------------------------------------------

-- a section represents a piece/section of the health display but only pertains to
-- its underlying spell (gain / prediciton)
local Section = {
  parent = frame, --the addon's base frame
  enabled = true, -- whether or not the section is enabled
  value = 0, -- the current value of the section (e.g. for how much your next Soul Cleave would heal you)
  maxValue = 0, -- the max value of the section (usually represents the masimum amount of power / health the player can have)
  available = false, -- if the underlying spell (Soul Carver / Immolation Aura) is available
  crit = true,
  Show = function(self) if self.bar then self.bar:Show() end end,
  Hide = function(self) if self.bar then self.bar:Hide() end end,
  Disable = function(self) if self.bar then self.bar:Hide() end end,
  Enable = function(self) if self.bar then self.bar:Show() end end,
  Untalent = function(self) self:Disable() self:Hide() self.enabled = false end,
  Talent = function(self) self:Enable() self:Show() self.enabled = true end,

  Gain = function(self,val) -- used for guaranteed buff gainsw
    local buffed,_,_,_,_,duration,expirationTime = UnitBuff(p, self.spell)
    self.value = buffed and (expirationTime - GetTime()) / duration * (val and val or self.gain) or 0
  end,

  GetCrit = function(self) -- whether or not crit should be factored in when calculating gains / predictions
   return self.crit and (GetCritChance() / 100) + 1 or 1
  end,

  GetHeal = function(self, baseMulti, additiveHeal, forGain) -- resulting heal of next spell cast (prediction)
    local h1,h2 = GetSpellDescription(self.healSpell):match("(%d+),(%d+)")
    local res = ((additiveHeal and additiveHeal() or 0) + tonumber(h1..h2) * (baseMulti and baseMulti or 1)) * self:GetCrit()
    if forGain then
      return res
    else
      self.value = res
    end
  end,

  GetAP = function() -- attack power
    local b,p,n = UnitAttackPower(p)
    return b + p + n
  end,

  TriggerUpdate = function(self, attr, val) -- used as an external setter for attributes
    self[attr] = val
  end,

  Accumulate = function(self) -- accumulates all values from sections with a lower/equal level compared to the current section
    -- this accumulated value will then be used to represent the value of the associated status bar
    local total = 0
    for type, typeTable in pairs(sections[self.res]) do
      for id, idTable in pairs(typeTable) do
        local s = sections[self.res][type][id]
        if s.lvl > self.lvl then
          total = total + s.value
        elseif s.lvl < self.lvl then
          s:SetBarValue(s:Accumulate())
        end
      end
    end
    return total + self.value
  end,

  Move = function(self)

  end,

  SetMinMaxBarValues = function(self, min, max)
    if self.id ~= background then
      self.bar:SetMinMaxValues(min,max)
    end
  end,

  SetBarValue = function(self, value)
    if self.id ~= background then
      self.bar:SetValue(value)
    end
  end
}

function Section:New(res,type,id) -- constructor for new sections
  local su = BarsOfVengeanceUserSettings[res][type][id]
  local sd = dfs[res][type][id]
  local new = {}
  new.res = res -- related resource type (health/power)
  new.lvl = su.lvl
  new.type = type -- prediction or gain display
  new.id = id -- spell id
  new.crit = su.crit -- crit enabled /disabled
  new.events = su.events -- events that trigger changes in the section's value
  new.gain = sd.gain -- total resource gain of related spell
  new.spell = GetSpellInfo(id) -- localized name of the spell
  new.healSpell = sd.healSpell and sd.healSpell or new.id -- whether or not heals should be predicted according to different spells than the normal one
  new.directParent = type == pwr and pwrFrame or hpFrame -- immediate frame parent (so that power /health frames can be moves as a union )
  new.Update = sd.Update -- updates the underlying value
  new.bar = CreateFrame("StatusBar",nil,new.directParent) -- the related status bar
  new.bar:SetStatusBarTexture(BarsOfVengeanceUserSettings[res].background.background.sbt)
  new.bar:SetStatusBarColor(unpack(su.clr))
  -- new.bar:SetBackdropColor(0,0,0,0)
  new.bar:SetPoint("TOPLEFT")
  new.bar:SetPoint("BOTTOMRIGHT")
  new.bar:SetFrameStrata(lvlToStrata[new.lvl])
  if id == background then
    new.bar:SetMinMaxValues(0,100)
    new.bar:SetValue(100)
  else
    local min, max
    if res == pwr then
      min,max = UnitPower(p),UnitPowerMax(p)
    else
      min,max = UnitHealth(p),UnitHealthMax(p)
    end
    new.bar:SetMinMaxValues(min,max)
  end
  self.__index = self
  return setmetatable(new, self)
end
-------------------------------------------------------------------------------


------------------------ utility functions ------------------------------------

-- reacts to changes of artifact traits
-- relevant for Soul Carver and Devour Souls
local function UpdateArtifactTraits()
  -- print("traits updated")
  -- local u,e,a=UIParent,"ARTIFACT_UPDATE",C_ArtifactUI
  --  u:UnregisterEvent(e)
  --  SocketInventoryItem(16)
  --  print(a.GetPowerInfo(DS))
  --  local _,_,rank,_,bonusRank = a.GetPowerInfo(DS)
  --  devour_souls_scalar = 1 + (rank + bonusRank) * 0.03
  --  Invoke(hp,pre,SCa,select(3,a.GetPowerInfo(Sca)) > 0 and "Talent" or "Untalent")
  --  a.Clear()
  --  u:RegisterEvent(e)
end


-- invokes argumentless methods of sections
local function Invoke(res,type,id,...)
  local s = sections[res][type][id]
  if s then
    for _,func in pairs({...}) do
      s[func](s)
    end
  end
end


-- reacts to talent updates
local function UpdateTalents()
  local t = select(2, GetTalentTierInfo(FoSL.row, FoSL.column )) == 1
  local func = t and "Talent" or "Untalent"
  Invoke(hp,gain,FoS,func)
  Invoke(hp,pre,FoS,func)
end


-- initial setup of frames/bars
local function SetupFrames()
  local pwrs = BarsOfVengeanceUserSettings[pwr].background.background
  local hps = BarsOfVengeanceUserSettings[hp].background.background

  frame:SetPoint("TOPLEFT")
  frame:SetPoint("BOTTOMRIGHT")

  pwrFrame:SetWidth(pwrs.w)
  pwrFrame:SetHeight(pwrs.h)
  pwrFrame:SetPoint(center, frame, center, 100, -500)

  hpFrame:SetPoint(center, frame, center, 20, -100)
  hpFrame:SetWidth(hps.w)
  hpFrame:SetHeight(hps.h)

  frame:Show()
  hpFrame:Show()
  pwrFrame:Show()
end

-- initializes all sections and build a customized event listener
local function Init()

  -- After a section's value was updated by its Update/Handler function,
  -- the value that should be displayed on the related status bar has to be
  -- accumulated and the statusbar needs to be accordingly set.
  -- this function hooks onto the section's update function to achieve just this.
  local function HookPostUpdate(section)
    local u = section.Update
    section.Update = function(section,...)
      u(section,...)
      section:SetBarValue(section:Accumulate())
    end
  end

  -- Creates a mapping of events and according handlers of a section
  local function GatherEventHandlers(section, storage)
    if section.events then
      for _, event in pairs(section.events) do
        if not storage[event] then storage[event] = {} end
        table.insert(storage[event], {lvl = section.lvl + (section.res == pwr and 10 or 0), section = section})
      end
    end
  end

  -- Creates the addon's "OnEvent" event handler
  local function CreateEventHandler(frame,storage)
    frame:UnregisterAllEvents()
    local mapping = {}
    for event, handlers in pairs(storage) do
      table.sort(handlers, function(h1,h2) return h1.lvl > h2.lvl end)
      frame:RegisterEvent(event)
      mapping[event] = function(...)
        for _,handler in ipairs(handlers) do
          handler.section:Update(...)
        end
      end
    end

    -- add section-unrelated event handlers
    mapping[E_PEW] = UpdateArtifactTraits
    mapping[E_SC] = UpdateArtifactTraits
    mapping[E_PTU] = UpdateTalents

    frame:RegisterEvent(E_PEW)
    frame:RegisterEvent(E_SC)
    frame:RegisterEvent(E_PTU)

    return function(f,e,...)
      mapping[e](...)
    end
  end


  local eventHandlers = {}

  for res, resTable in pairs(dfs) do
    for type, typeTable in pairs(resTable) do
      for id, idTable in pairs(typeTable) do
        if BarsOfVengeanceUserSettings[res][type][id].enabled then
          local s = Section:New(res,type,id)
          HookPostUpdate(s)
          GatherEventHandlers(s, eventHandlers)
          sections[res][type][id] = s
        end
      end
    end
  end
  frame:SetScript("OnEvent", CreateEventHandler(frame,eventHandlers))
end

Init()
SetupFrames()
-------------------------------------------------------------------------------
