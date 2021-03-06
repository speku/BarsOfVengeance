-- Vengeance Demon Hunter WeakAura for displaying your accumulated health
-- includes: Soul Shards, Soul Cleave, Soul Carver, Feast of Souls, Devour Souls
-- and Soul Barrier

-- and your accumulated pain
-- includes: Immolation Aura, Metamorphosis


------------------------------------ IDs --------------------------------------
local FoS = 207697 -- Feast of Souls
local SCl = 203798 -- Soul Cleave
local SCa = 207407 -- Soul Carver
local SCaPI = 1096 -- Soul Carver Power Info
local BT = 203753 -- Blade Turning
local IA = 178740 -- Immolation Aura
local Me = 191427 -- Metamorphosis
local DSPI = 1233  -- Devour Souls -> powerID
local FbP = 213017 -- Fueled by Pain
local Sh = 203783 -- Shear
local SF = 203981 -- Soul Fragments
local DB = 162243 -- Demon's Bite
local Pp = 203650 -- Prepared
local VR = 198793 -- Vengeful Retreat
local FB = 213241 -- Felblade
local FR = 195072 -- Fel Rush
local FM = 192939 -- Fel Mastery
local Mo = 206476 -- Momentum
local FD = 212084 -- Fel Devastation
local SB = 227225 -- Soul Barrier
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
local pwrGainClr = {0.6,0.6,0,1}
local hpXOffset = "hpXOffset"
local hpYOffset = "hpYOffset"
local pwrXOffset = "pwrXOffset"
local pwrYOffset = "pwrYOffset"
local background = "background"
local center = "CENTER"
local over = "over"
local CLASS_ID = 12
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
local E_PRD = "PLAYER_REGEN_DISABLED"
local E_PRE = "PLAYER_REGEN_ENABLED"
local E_PSC = "PLAYER_SPECIALIZATION_CHANGED"
local E_SUC = "SPELL_UPDATE_CHARGES"
local E_USCSA = "UNIT_SPELLCAST_CHANNEL_START"
local E_USCSO = "UNIT_SPELLCAST_CHANNEL_STOP"
local E_USCU = "UNIT_SPELLCAST_CHANNEL_UPDATE"
local E_CRU = "COMBAT_RATING_UPDATE"
--------------------------------------------------------------------------------


--------------------------- variables ------------------------------------------
local inCombat = false
local isVengeance = true
--------------------------------------------------------------------------------


------------------------ constants --------------------------------------------
local FoSL = {row = 2, column = 1} -- Feast of Souls location in talent pane
local PpL = {row = 2, column = 1} -- Prepared location
local FBL = {row = 3, column = 1} -- Felblade location
local FML = {row = 1, column = 1} -- Fel Mastery location
local FDL = {row = 6, column = 1} -- Fel Devastation location
local SBL = {row = 7, column = 3} -- Soul Barrier location
local devour_souls_scalar = 1 -- Devour Souls scalar
local soul_cleave_formula = function(ap) return ap * 5.5 end -- formula for calculating the minimal heal of Soul Cleave
local soul_cleave_pattern = "(%d+)%p(%d+),"
local soul_barrier_pattern = "absorbing (%d+)%p(%d+)"
local parseHeal = function(spell,pattern)
  local h1,h2 = GetSpellDescription(spell):match(pattern)
  return tonumber(h1..h2)
end
local soul_cleave_formula_parsed = function(spell) return parseHeal(spell,soul_cleave_pattern) end
local soul_barrier_formula_parsed = function(spell) return parseHeal(spell,soul_barrier_pattern) end
local soul_cleave_min_cost = 30 -- the minimal cost of Soul Cleave
local soul_cleave_max_cost = 60 -- the maximal cost of Soul Cleave
local soul_barrier_cost = 60 -- cost of Soul Barrier
local soul_carver_soul_fragment_count = 5 -- how many Soul Fragments are spawned by Soul Carver
local soul_fragment_cap = 5
local immolation_aura_pain_per_sec = 20/6
local immolation_aura_total_pain = 20
local metamorphosis_pain_per_sec = 7
local metamorphosis_total_gain = 15 * 7
local blade_turning_total_gain = 10 * 0.5 -- how much extra pain is generated by Blade Turning
local maxValue = 5000000
local vengeance_spec_id = 2
local demons_bite_max_fury = 30
local demons_bite_min_fury = 20
local prepared_fury_per_sec = 40 / 5
local prepared_fury_per_tic = 8
local prepared_total_fury = 40
local felblade_pain = 20
local felblade_fury = 30
local update_interval = 0.2
local vengeful_retreat_cd = 15
local fel_mastery_fury = 25
local fel_devastation_pain_cost = 30

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
local UpdateTalents
local UpdateArtifactTraits
local Invoke

--------------------------------------------------------------------------------
local onCD = {}
local onCDFuncs = {
  [VR] = function()
    local s = sections[pwr][pre][VR]
    s.available = true
    s.value = s.gain
  end,
}

local doseAuraEvents = {
  SPELL_AURA_APPLIED = function() return 1 end,
  SPELL_AURA_REMOVED = function() return 0 end,
  SPELL_AURA_REMOVED_DOSE = select,
  SPELL_AURA_APPLIED_DOSE = select
}

local absoluteAuraEvents = {
  SPELL_AURA_APPLIED = true,
  SPELL_AURA_REFRESH = true,
  SPELL_AURA_REMOVED = true,
}


local function filter(table, predicate)
  local res = {}
  for _,v in pairs(table) do
    if predicate(v) then
      tinsert(res,v)
    end
  end
  return res
end


local function map(table, func)
  local res = {}
  for _,v in pairs(table) do
    tinsert(res, func(v))
  end
  return res
end

local function IterateSections(func)
  for res,resTable in pairs(sections) do
    for type,typeTable in pairs(resTable) do
      for id,idTable in pairs(typeTable) do
        func(res,type,id)
      end
    end
  end
end

local function SpecChanged()
  isVengeance = GetSpecialization() == vengeance_spec_id
  IterateSections(function(res,type,id)
    local s = sections[res][type][id]
    if not isVengeance then
      if s.bothEnabled or s.onlyHavoc then
        s:Enable()
      else
        s:Disable()
      end
    else
      if s.bothEnabled or not s.onlyHavoc then
        s:Enable()
      else
        s:Disable()
      end
    end
  end)
end

local otherEvents = {
  PLAYER_ENTERING_WORLD = function(self)
    onCD[VR] = 0
    self:UpdateResource()
    self:AutoVisibility(true)
    self:StatsUpdated()
    UpdateArtifactTraits()
    UpdateTalents()
  end,

  PLAYER_REGEN_DISABLED = function(self)
    inCombat = true
    self:Show()
  end,

  PLAYER_REGEN_ENABLED = function(self)
    inCombat = false
    if self.hideOutOfCombat then
      self:AutoVisibility()
    end
  end,

  PLAYER_SPECIALIZATION_CHANGED = function()
    SpecChanged()
    UpdateTalents()
  end,

  SPELLS_CHANGED = function()
    UpdateArtifactTraits()
  end,

  PLAYER_TALENT_UPDATE = function()
    UpdateTalents()
  end,

  COMBAT_RATING_UPDATE = function(self)
    self:StatsUpdated()
  end
}

local function triggerOther(self,e,...)
  if otherEvents[e] then
    otherEvents[e](self,...)
  end
end

local function normalize(self,value)
  if not (self.id == SCa or self.id == SB or self.id == FD or self.type == absorbs or (self.id == FoS and self.type == pre)) then
    return value > self.actualMaxValue and self.actualMaxValue or value
  end
  return value
end


------------------------------- settings ---------------------------------------

-- default settings
dfs = {

  [pwr] = { -- settings relating to power "sections" of your bars

    [pre] = { -- power prediction

      [IA] = { -- Immolation Aura
        enabled = true,
        lvl = 10, -- strata
        clr = {0,0.6,0,1}, -- color
        events = {E_CLEU, E_SUU, E_PEW, E_PSC}, -- events that cause the related value/bar to change
        gain = immolation_aura_total_pain,
        Update = function(self,e,...) -- function to be triggered upon relevant events -> causes a change in the related sections' value
          self:UpdateAvailability(function() self.value = self.available and self.gain or 0 end,e,...)
        end
      },

      [FM] = { -- Fel Mastery
        enabled = true,
        onlyHavoc = true,
        lvl = 7,
        clr = {0,0.4,0.4,1},
        useClr = {0,1,1,1},
        -- events = {E_CLEU, E_SUU, E_PEW},
        events = {E_SUC, E_PEW, E_PSC},
        gain = fel_mastery_fury,
        auxSpells = {Mo},
        Update = function(self,e,...)
          self.value = GetSpellCharges(FR) > 0 and self.gain or 0
        end,
        useClrPredicate = function(self)
          local charges, maxCharges = GetSpellCharges(FR)
          local pow = sections[pwr].current.power
          return pow.value + self.value <= pow.actualMaxValue and not UnitBuff(p,self.auxSpells[Mo]) and (charges < maxCharges and {0,0.6,0.6,1} or true)
        end,
      },

      -- [DB] = { -- Demon's Bite
      --   enabled = true,
      --   onlyHavoc = true,
      --   lvl = 5,
      --   clr = pwrGainClr,
      --   events = {E_UPF, E_PEW},
      --   Update = function(self,e,...)
      --     self.value = demons_bite_max_fury
      --   end
      -- },

      [FB] = { -- Felblade
        enabled = true,
        bothEnabled = true,
        lvl = 8,
        clr = {0.6,0,0.6,1},
        useClr = {1,0,1,1},
        events = {E_CLEU, E_SUU, E_PEW, E_PSC},
        Update = function(self,e,...)
          self:UpdateAvailability(function() self.value = self.available and (isVengeance and felblade_pain or felblade_fury) or 0 end,e,...)
        end,
        useClrPredicate = function(self)
          local p = sections[pwr].current.power
          return p.value + self.value <= p.actualMaxValue
        end,
        onTalentUpdate = function(self)
          self.value = self.available and (isVengeance and felblade_pain or felblade_fury) or 0
        end
      },

      -- [Me] = { -- Metamorphosis
      --   enabled = true,
      --   lvl = 2,
      --   clr = {0.5,0.25,0,1},
      --   useClr = {1,0.5,0,1},
      --   gain = metamorphosis_total_gain,
      --   events = {E_CLEU, E_SUU, E_PEW, E_PSC},
      --   Update = function(self,e,...)
      --     self:UpdateAvailability(function() self.value = self.available and self.gain or 0 end,e,...)
      --   end,
      --   useClrPredicate = function(self)
      --     local h = sections[hp].current.health
      --     return h.value / (h.actualMaxValue ~= 0 and h.actualMaxValue or 1) < 0.3
      --   end,
      -- },

      [VR] = { -- Vengeful Retreat
        enabled = true,
        onlyHavoc = true,
        lvl = 9, -- strata
        clr = {0,0.4,0,1}, -- color
        useClr = {0,0.6,0,1},
        events = {E_CLEU, E_PEW, E_PSC},
        gain = prepared_total_fury,
        auxSpells = {Mo},
        Update = function(self,e,...)
          self:UpdateAvailability(function() self.value = self.available and self.gain or 0 end,e,...)
        end,
        useClrPredicate = function(self)
          local pow = sections[pwr].current.power
          local fb = sections[pwr][pre][FB]
          return (fb and fb.enabled and fb.available or GetSpellCharges(FR) > 0) and pow.value + (fb and fb.enabled and fb.available and fb.value or 0) + prepared_fury_per_tic <= pow.actualMaxValue and not UnitBuff(p,self.auxSpells[Mo])
        end,
      }
    },

    [gain] = { -- definitive power gains of active buffs

      [IA] = { -- Immolation Aura
        enabled = true,
        lvl = 4,
        clr = pwrGainClr,
        events = {E_UPF, E_PEW, E_PSC},
        gain = immolation_aura_pain_per_sec,
        Update = function(self,e,...)
          self:Gain()
        end
      },

      [Pp] = { -- Prepared
        enabled = true,
        onlyHavoc = true,
        lvl = 6,
        clr = pwrGainClr,
        events = {E_UPF, E_PEW, E_PSC},
        gain = prepared_fury_per_sec,
        Update = function(self,e,...)
          self:Gain()
        end
      },

      [BT] = { -- Blade Turning
        enabled = true,
        lvl = 5,
        clr = pwrGainClr,
        events = {E_UA, E_PEW, E_PSC},
        gain = blade_turning_total_gain,
        Update = function(self,e,...)
          self:Gain(nil,nil,true)
        end
      },

      [Me] = { -- Metamorphosis
        enabled = true,
        lvl = 3,
        clr = pwrGainClr,
        events = {E_UPF, E_PEW, E_PSC}, -- E_SUU, E_CLEU
        gain = metamorphosis_pain_per_sec,
        Update = function(self,e,...)
          self:Gain()
        end
      }
    },

    current = { -- current power level

      power = {
        enabled = true,
        bothEnabled = true,
        lvl = 11,
        clr = {1,1,0,1},
        events = {E_UPF, E_PEW, E_PSC},
        Update = function(self)
          self:UpdateResource()
          self:AutoVisibility()
        end
    }
  },

    background = { -- background bar
      background = {
        enabled = true,
        bothEnabled = true,
        lvl = 1,
        clr = {0,0,0,0.5},
        w = 150, -- width of power bars
        h = 10, -- height of power bars
        x = 0, -- x-offset of power bars from the addons' parent frame
        y = -112.5, -- equivalent y-offset
        sbt = "Interface\\AddOns\\BarsOfVengeance\\media\\texture.tga", -- status bar texture used for power bars
        events = {E_PEW, E_PRE, E_PRD},
        Update = function(self,e,...)
          triggerOther(self,e,...)
        end
      },
    },
  },

  [hp] = { -- health related settings

    [pre] = { -- prediction

      [FoS] = { -- Feast of Souls
        enabled = true,
        lvl = 6,
        clr = {0,0.4,0,1},
        useClr = {0,0.6,0,1},
        events = {E_UPF, E_PEW, E_PSC},
        Update = function(self)
          local sb = sections[hp][pre][SB]
          local power = sections[pwr].current.power.value
          if power >= soul_cleave_min_cost and not (sb.enabled and sb.available) then
            self:GetHeal(1)
          else
            self.value = 0
          end
        end,

        useClrPredicate = function(self)
          local sc = sections[hp][pre][SCl]
          return sc.enabled and sc.healCount and sc.healCount == soul_fragment_cap
        end
      },

      [SCl] = { -- Soul Cleave
        enabled = true,
        crit = false,
        lvl = 8,
        clr = {0,0.6,0,1},
        useClr = {0,1,0,1},
        events = {E_UPF, E_CLEU, E_PEW, E_PSC},
        healSpell = Sh,
        healCountSpell = SF,
        Update = function(self,e,...)
          if e == E_CLEU then
            self:UpdateAura(...)
          end

          local power = sections[pwr].current.power.value
          local sb = sections[hp][pre][SB]

          if power >= (sb.enabled and sb.available and soul_barrier_cost or soul_cleave_min_cost) then
            power = power > soul_cleave_max_cost and soul_cleave_max_cost or power
            function func()
              return sb.enabled and sb.available and 0 or (soul_cleave_formula(self:GetAP()) * (power / soul_cleave_max_cost) * 2 * devour_souls_scalar)
            end
            self:GetHeal(nil,func)
          else
            self.value = 0
          end
        end,

        useClrPredicate = function(self)
          return self.healCount and self.healCount == soul_fragment_cap
        end
      },


      [SB] = { -- Soul Barrier
        enabled = true,
        crit = false,
        lvl = 7,
        multi = 2,
        clr = {0.6,0.6,0,1},
        useClr = {1,1,0,1},
        events = {E_CLEU, E_SUU, E_SC, E_PEW, E_PSC,E_UPF},
        healSpell = GetSpellInfo(Sh),
        healCountSpell = SF,
        Update = function(self,e,...)
          if e == E_CLEU then
            self:UpdateAura(...)
          end
          self:UpdateAvailability(function()
            if self.available then
                self:GetHeal(nil, function() return soul_barrier_formula_parsed(self.spell) end)
            else
              self.value = 0
            end
          end,e,...)
        end,

        useClrPredicate = function(self)
          return self.healCount and self.healCount == soul_fragment_cap
        end
      },


      [SCa] = { -- Soul Carver
        enabled = true,
        lvl = 5,
        clr = {0.6,0,0.6,1},
        useClr = {1,0,1,1},
        crit = false,
        events = {E_CLEU, E_SUU, E_SC, E_PEW, E_PSC},
        healSpell = GetSpellInfo(Sh),
        Update = function(self,e,...)
          self:UpdateAvailability(function()
            if self.available then
              self:GetHeal(soul_carver_soul_fragment_count)
            else
              self.value = 0
            end
          end,e,...)
        end,

        useClrPredicate = function(self)
          local SCa = sections[self.res][self.type][SCa]
          return SCa.enabled and SCa.healCount and SCa.healCount + soul_carver_soul_fragment_count <= soul_fragment_cap
        end
      },

      [FD] = { -- Fel Devastation
        enabled = true,
        lvl = 4,
        clr = {0.5,0.25,0,1},
        useClr = {1,0.5,0,1},
        crit = false,
        events = {E_CLEU, E_SUU, E_PEW, E_PSC},
        Update = function(self,e,...)
          self:UpdateAvailability(function()
            if self.available then
              self:GetHeal(1)
            else
              self.value = 0
            end
          end,e,...)
        end,

        useClrPredicate = function(self)
          local h = sections[hp].current.health
          local p = sections[pwr].current.power
          return self.latestAccumulatedValue <= h.actualMaxValue and p.value >= fel_devastation_pain_cost
        end,
      --   onTalentUpdate = function(self)
      --
      --   end
      },
    },

    [gain] = { -- definitive health gains of active buffs

      [FoS] = { -- Feast of Souls
        enabled = true,
        lvl = 10,
        crit = false,
        clr = {0.6,0.6,0.6,1},
        events = {E_UHF, E_PEW, E_PSC},
        Update = function(self,e,...)
          self:Gain(true,self:GetHeal(1,nil,true))
        end
      },

      [FD] = { -- Fel Devastation
        enabled = true,
        lvl = 9,
        crit = false,
        clr = {0.6,0.6,0.6,1},
        events = {E_UHF, E_PEW, E_USCSA, E_USCSO, E_USCU, E_PSC},
        Update = function(self,e,...)
          if self.enabled then
            local n,_,_,_,startTime,endTime = UnitChannelInfo(p)
            if n == self.spell then
              local duration = endTime - startTime
              local remaining = endTime - GetTime() * 1000
              self.value = (remaining/duration)*self:GetHeal(1,nil,true)
            else
              self.value = 0
            end
          end
        end,
      onTalentUpdate = function(self)
        self.value = 0
      end
      }
    },

    current = { -- current health

      health = {
        enabled = true,
        bothEnabled = true,
        lvl = 11,
        clr = {1,1,1,1},
        events = {E_UHF, E_PEW, E_PSC},
        Update = function(self)
          self:UpdateResource()
          self:AutoVisibility()
        end
      }
    },

    background = {

      background = {
        enabled = true,
        bothEnabled = true,
        lvl = 1,
        clr = {0,0,0,0.5},
        w = 150,
        h = 10,
        x = 0,
        y = -100,
        sbt = "Interface\\AddOns\\BarsOfVengeance\\media\\texture.tga",
        events = {E_PEW, E_PRE, E_PRD, E_PTU, E_SC, E_PSC, E_CRU},
        Update = function(self,e,...)
          triggerOther(self,e,...)
        end
      },
    },

    absorbs = { -- absorbs

      current = {
        enabled = true,
        bothEnabled = true,
        lvl = 3,
        clr = {0,0.6,0.6,1},
        events = {E_UAAC, E_PEW},
        Update = function(self)
          self.value = UnitGetTotalAbsorbs(p)
        end
      },

      over = {
        enabled = true,
        bothEnabled = true,
        lvl = 2,
        clr = {0,1,1,1},
        multi = 2,
      }
    },
  }
}

BarsOfVengeanceUserSettings = setmetatable({},{__index = dfs}) -- only a few settings
-- should be changable by the user, so most stuff is accessed via the meta table
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
  versatility = 1,
  parent = frame, --the addon's base frame
  enabled = true, -- whether or not the section is enabled
  value = 0, -- the current value of the section (e.g. for how much your next Soul Cleave would heal you)
  actualMaxValue = 1, -- the max value of the section (usually represents the maximum amount of power / health the player can have)
  available = false, -- if the underlying spell (Soul Carver / Immolation Aura) is available
  latestAccumulatedValue = 0,
  healCount = 0,
  multi = 1,
  crit = true,
  hideOutOfCombat = true,
  hideHealthThreshold = 100,
  hidePowerThreshold = 0,
  ShowBar = function(self) if self.bar then self.bar:Show() end end,
  HideBar = function(self) if self.bar then self.bar:Hide() end end,
  Show = function(self) self.directParent:Show() end,
  Hide = function(self) self.directParent:Hide() end,
  Disable = function(self)
    self.bar:SetValue(0)
    -- self.latestAccumulatedValue = 0
    self.enabled = false
  end,
  Enable = function(self)
    self.enabled = true
  end,

  Gain = function(self,total,val,absolute) -- used for guaranteed buff gainsw
    if self.enabled then
      local buffed,_,_,_,_,duration,expirationTime = UnitBuff(p, self.spell)
      if buffed then
        local remaining = expirationTime - GetTime()
        if absolute then
          self.value = self.gain
        elseif total then
          self.value = remaining / duration * (val and val or self.gain)
        else
          self.value = remaining * self.gain
        end
      else
        self.value = 0
      end
    end
  end,


  GetCrit = function(self) -- whether or not crit should be factored in when calculating gains / predictions
   return self.crit and (GetCritChance() / 100) + 1 or 1
  end,

  GetHeal = function(self, baseMulti, additiveHeal, forGain) -- resulting heal of next spell cast (prediction)
    if self.enabled then
      local matches = {}
      for match in  GetSpellDescription(self.healSpell):gmatch("(%d+%p%d+)") do
        table.insert(matches,match)
      end
      local h1,h2 = matches[#matches]:match("(%d+)%p(%d+)")
      local res = ((additiveHeal and additiveHeal() or 0) * (self.id ~= 227225 and self.versatility or 1) + tonumber(h1..h2) * (baseMulti and baseMulti or self.healCount)) * self:GetCrit()
      if forGain then
        return res
      else
        self.value = res
      end
    end
  end,

  GetAP = function() -- attack power
    local b,p,n = UnitAttackPower(p)
    return b + p + n
  end,

  GetAbove = function(self)
    if self.above then
      for _,v in ipairs(self.above) do
        if v.enabled then
          return v
        end
      end
    end
  end,

  GetBelow = function(self)
    if self.below then
      for _,v in ipairs(self.below) do
        if v.enabled then
          return v
        end
      end
    end
  end,

  Accumulate = function(self)
    if self.enabled then
      self.latestAccumulatedValue = self:PropagateAbove()
      local func = function(self)
        self:SetBarValue(normalize(self,self.latestAccumulatedValue))
      end
      func(self)
      self:PropagateBelow(0, func, true)
    else
      self.bar:SetValue(0)
    end
  end,

  PropagateAbove = function(self)
    local above = self:GetAbove()
    return self.id ~= background and ((self.enabled and self.value or 0) + (above and above:PropagateAbove() or 0)) or 0
  end,

  PropagateBelow = function(self,valFromAbove, func, initial)
    if not initial then
      self.latestAccumulatedValue = valFromAbove + (self.enabled and self.value or 0)
      if func then
        func(self)
      end
    end

    self:UpdateColor()
    local below = self:GetBelow()

    if below and below.id ~= background then
      below:PropagateBelow(self.latestAccumulatedValue, func,nil,self)
    end
  end,

  Move = function(self)

  end,

  SetBarValue = function(self, value)
    if self.id ~= background then
      if self.id == over then
       local sb = sections[hp][pre][SB].value
       local sca = sections[hp][pre][SCa].value
       local fd = sections[hp][pre][FD].value
       local health = sections[hp].current.health.value
       local maxHealth = sections[hp].current.health.actualMaxValue
       local absorbs = sections[hp].absorbs.current.value
       if absorbs + health + sb + sca + fd <= maxHealth then
        self.bar:SetValue(0)
       else
        self.bar:SetValue((maxHealth + absorbs + sb + sca + fd) / maxHealth * maxValue)
       end
     elseif self.id == 227225 and not self.available then -- Soul Barrier
       self.bar:SetValue(0)
     else
      self.bar:SetValue((self.actualMaxValue ~= 0 and (value/self.actualMaxValue) or 1)*maxValue)
     end
    end
  end,

  SetMaxValue = function(self, actualMaxValue)
    if self.id ~= background then
      self.actualMaxValue = actualMaxValue
      self:SetBarValue(self.latestAccumulatedValue)
    end
  end,

  SetNeighbours = function(self)
    local below = {}
    local above = {}
    for type, typeTable in pairs(sections[self.res]) do
      for id,_ in pairs(typeTable) do
        local other = sections[self.res][type][id]
        if other.lvl < self.lvl then
          table.insert(below, other)
        elseif other.lvl > self.lvl then
          table.insert(above, other)
        end
      end
    end

    table.sort(below, function(s1,s2) return s1.lvl > s2.lvl end)
    table.sort(above, function(s1,s2) return s1.lvl < s2.lvl end)

    self.above = above
    self.below = below
  end,

  UpdateResource = function(self)
    if self.enabled then
        local isPwr = self.res == pwr
        self.value = isPwr and UnitPower(p) or UnitHealth(p)
        local newMax = isPwr and UnitPowerMax(p) or UnitHealthMax(p)
        if newMax ~= self.actualMaxValue then
          self:SetMaxValue(newMax)
          for type, typeTable in pairs(sections[self.res]) do
            for id, idTable in pairs(typeTable) do
              sections[self.res][type][id]:SetMaxValue(newMax)
            end
          end
        end
      end
    end,

    UpdateAura = function(self,...)
      if self.enabled then
        local e =  select(2,...)
        if self.type == pre and doseAuraEvents[e] and select(4,...) == UnitGUID(p) and select(13,...) == self.healCountSpell then
          self.healCount = doseAuraEvents[e](16,...)
        end
      end
    end,

    -- keeps track of spell availability and calls its function parameter upon
    -- availability change
    UpdateAvailability = function(self,func,e,...)
      if self.enabled and self.spell then
        if e == E_SUU then
          local _,d = GetSpellCooldown(self.spell)
          if d and d < 1.5 and not self.available then
            self.available = true
            if func then
              func()
            end
          end
        elseif e == E_CLEU then
          if select(2,...) == "SPELL_CAST_SUCCESS" and select(4,...) == UnitGUID(p) and select(13,...) == self.spell then
            self.available = false
            if func then
              func()
            end
            if self.id == VR then
               onCD[self.id] = GetTime() + vengeful_retreat_cd -- is it common that abilities that aren't affected by the gcd can't be queried for their cd when this event is fired?
            end
          end
        end
      end
    end,

    AutoVisibility = function(self,pew)
      if not inCombat then
          if self.res == pwr then
             if (pew and UnitPower(p) or sections[pwr].current.power.value) <= self.hidePowerThreshold then
               self:Hide()
             else
               self:Show()
             end
          else
            local uhm = UnitHealthMax(p)
            if (pew and UnitHealth(p) or sections[hp].current.health.value) / (pew and uhm ~= 0 and uhm or sections[hp].current.health.actualMaxValue ~= 0 and sections[hp].current.health.actualMaxValue or 1) * 100 >= self.hideHealthThreshold  then
              self:Hide()
            else
              self:Show()
            end
          end
        end
    end,

    StatsUpdated = function(self)
      self.versatility = (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)) / 100 + 1
    end,

    UpdateColor = function(self)
      if self.useClr and self.useClrPredicate then
        local u = self:useClrPredicate()
        if type(u) == "table" then
          self.bar:SetStatusBarColor(unpack(u))
        elseif u then
          self.bar:SetStatusBarColor(unpack(self.useClr))
        else
          self.bar:SetStatusBarColor(unpack(self.clr))
        end
      end
    --  if self.enabled then
    --    if self.useClr and self.useClrPredicate then
    --      if self:useClrPredicate() then
    --       if self.currentClr ~= self.useClr then
    --          self.bar:SetStatusBarColor(unpack(self.useClr))
    --          self.currentClr = self.useClr
    --        end
    --      elseif self.currentClr ~= self.clr then
    --        self.bar:SetStatusBarColor(unpack(self.clr))
    --        self.currentClr = self.clr
    --      end
    --    end
    --  end
    end
}

function Section:New(res,type,id) -- constructor for new sections
  local su = BarsOfVengeanceUserSettings[res][type][id]
  local sd = dfs[res][type][id]
  local n = setmetatable({}, self)
  n.enabled = su.enabled or true
  n.bothEnabled = su.bothEnabled or false
  n.onlyHavoc = su.onlyHavoc
  n.res = res -- related resource type (health/power)
  n.lvl = su.lvl
  n.value = su.value or 0
  n.multi = su.multi or 1
  n.type = type -- prediction or gain display
  n.id = id -- spell id
  n.crit = su.crit -- crit enabled /disabled
  n.events = su.events -- events that trigger changes in the section's value
  n.gain = sd.gain -- total resource gain of related spell
  n.spell = GetSpellInfo(id) -- localized name of the spell
  n.healSpell = sd.healSpell and sd.healSpell or n.id -- whether or not heals should be predicted according to different spells than the normal one
  n.healCountSpell = su.healCountSpell and GetSpellInfo(su.healCountSpell) or GetSpellInfo(n.healSpell)
  n.directParent = res == pwr and pwrFrame or hpFrame -- immediate frame parent (so that power /health frames can be moves as a union )
  n.Update = sd.Update -- updates the underlying value
  n.clr = su.clr
  n.hideOutOfCombat = su.hideOutOfCombat
  n.hideHealthThreshold = su.hideHealthThreshold
  n.hidePowerThreshold = su.hidePowerThreshold
  n.useClr = su.useClr or n.Clr
  n.currentClr = n.clr
  n.useClrPredicate = su.useClrPredicate
  n.onTalentUpdate = su.onTalentUpdate

  if su.auxSpells then
    n.auxSpells = {}
    for _,v in pairs(su.auxSpells) do
      n.auxSpells[v] = GetSpellInfo(v)
    end
  end

  n.bar = CreateFrame("StatusBar",nil,n.directParent) -- the related status bar
  n.bar:SetStatusBarTexture(BarsOfVengeanceUserSettings[res].background.background.sbt)
  n.bar:SetStatusBarColor(unpack(n.clr))
  n.bar:SetPoint("TOPLEFT")
  if n.multi ~= 1 then
    n.bar:SetWidth(n.directParent:GetWidth() * n.multi)
    n.bar:SetHeight(n.directParent:GetHeight())
  else
    n.bar:SetPoint("BOTTOMRIGHT")
  end
  -- n.bar:SetFrameStrata(lvlToStrata[n.lvl])
  n.bar:SetMinMaxValues(0,maxValue * n.multi)
  if id == background then
    n.bar:SetValue(maxValue * n.multi)
  end
  self.__index = self
  return n
end
-------------------------------------------------------------------------------


------------------------ utility functions ------------------------------------

local function OrderSections()

  local function SetRelations(ordered)
    for i,s in ipairs(ordered) do
      local parent = ordered[i+1]
      if parent then
        s.bar:SetParent(parent.bar)
      end
    end
  end

  -- put all sections in an array that can be ordered (lvls in descending order)
  local orderedHp = {}
  local orderedPwr = {}
  IterateSections(function(res,type,id)
    local s = sections[res][type][id]
    if s.res == hp then
      table.insert(orderedHp,s)
    else
      table.insert(orderedPwr,s)
    end
  end)
  -- order the array of sections according to their level
  table.sort(orderedHp, function(s1,s2) return s1.lvl > s2.lvl end)
  table.sort(orderedPwr, function(s1,s2) return s1.lvl > s2.lvl end)
  -- loop over the ordered array and make every section the child of its predecessor with a lower level
  SetRelations(orderedHp)
  SetRelations(orderedPwr)

end

-- reacts to changes of artifact traits
-- relevant for Soul Carver and Devour Souls
function UpdateArtifactTraits()
  local u,e,a=UIParent,"ARTIFACT_UPDATE",C_ArtifactUI
   u:UnregisterEvent(e)
   SocketInventoryItem(16)
   local _,_,rank,_,bonusRank = a.GetPowerInfo(DSPI)
   devour_souls_scalar = 1 + (rank + bonusRank) * 0.03
   Invoke(hp,pre,SCa,select(3,a.GetPowerInfo(SCaPI)) > 0 and "Enable" or "Disable")
   a.Clear()
   u:RegisterEvent(e)
end


-- invokes argumentless methods of sections
function Invoke(res,type,id,...)
  local s = sections[res][type][id]
  if s then
    for _,func in pairs({...}) do
      s[func](s)
    end
  end
end


-- reacts to talent updates
function UpdateTalents(refreshFunc)
  local function core(l,res,type,id)
    local f = select(9, GetTalentInfo(l.row, l.column, GetActiveSpecGroup())) and "Enable" or "Disable"
    Invoke(res,type,id,f)
  end

  if isVengeance then
    core(FoSL,hp,gain,FoS)
    core(FoSL,hp,pre,FoS)
    core(FDL,hp,pre,FD)
    core(FDL,hp,gain,FD)
    core(SBL,hp,pre,SB)
  else
    core(PpL,pwr,pre,VR)
    core(PpL,pwr,gain,Pp)
    core(FML,pwr,pre,FM)
  end
  core(FBL,pwr,pre,FB)

  IterateSections(function(res,type,id)
    local s = sections[res][type][id]
    if s.onTalentUpdate then
      s:onTalentUpdate()
      s:Accumulate()
    end
  end)
end


-- initial setup of frames/bars
local function SetupFrames()
  local pwrs = BarsOfVengeanceUserSettings[pwr].background.background
  local hps = BarsOfVengeanceUserSettings[hp].background.background

  frame:SetPoint("TOPLEFT")
  frame:SetPoint("BOTTOMRIGHT")
  frame:SetFrameStrata("BACKGROUND")

  pwrFrame:SetWidth(pwrs.w)
  pwrFrame:SetHeight(pwrs.h)
  pwrFrame:SetPoint(center, frame, center, pwrs.x, pwrs.y)

  hpFrame:SetPoint(center, frame, center, hps.x, hps.y)
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
      section:Accumulate()
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

    return function(f,e,...)
      mapping[e](e,...)
    end
  end


  local eventHandlers = {}

  for res, resTable in pairs(dfs) do
    for type, typeTable in pairs(resTable) do
      for id, idTable in pairs(typeTable) do
        -- if BarsOfVengeanceUserSettings[res][type][id].enabled then
          local s = Section:New(res,type,id)
          HookPostUpdate(s)
          GatherEventHandlers(s, eventHandlers)
          sections[res][type][id] = s
        -- end
      end
    end
  end

  SpecChanged()
  frame:SetScript("OnEvent", CreateEventHandler(frame,eventHandlers))

  local sinceUpdate = 0
  frame:SetScript("OnUpdate", function(self,elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate >= update_interval then
      sinceUpdate = 0
        local toDelete = {}
        for id,expirationTime in pairs(onCD) do
          if expirationTime and expirationTime <= GetTime() then
            onCDFuncs[id]()
            table.insert(toDelete, id)
          end
        end
        for _,id in ipairs(toDelete) do
          onCD[id] = nil
        end
    end
    end)

  IterateSections(function(res,type,id) sections[res][type][id]:SetNeighbours() end)

end

if select(3,UnitClass(p)) == CLASS_ID then
  SetupFrames()
  Init()
  OrderSections()
end
