local _, Analyzer = ...

if not Analyzer then
  return
end

-- Prepotions for MoP (Mists of Pandaria)
-- Based on class/spec optimal choices

Analyzer.PrepotionData = {
  -- Caster DPS (Int users)
  MAGE = {
    [105702] = true, -- Potion of the Jade Serpent (Int)
  },
  WARLOCK = {
    [105702] = true, -- Potion of the Jade Serpent (Int)
  },
  PRIEST = {
    [105702] = true, -- Potion of the Jade Serpent (Int)
  },
  DRUID = {
    balance = {
      [105702] = true, -- Potion of the Jade Serpent (Int)
    },
    feral = {
      [76089] = true, -- Potion of the Tol'vir (Agi)
    },
  },
  SHAMAN = {
    elemental = {
      [105702] = true, -- Potion of the Jade Serpent (Int)
    },
    enhancement = {
      [76089] = true, -- Potion of the Tol'vir (Agi)
    },
  },
  MONK = {
    windwalker = {
      [76089] = true, -- Potion of the Tol'vir (Agi)
    },
  },
  
  -- Physical DPS (Agi users)
  ROGUE = {
    [76089] = true, -- Potion of the Tol'vir (Agi)
  },
  HUNTER = {
    [76089] = true, -- Potion of the Tol'vir (Agi)
  },
  
  -- Physical DPS (Str users)
  WARRIOR = {
    [76093] = true, -- Potion of Mogu Power (Str)
  },
  DEATHKNIGHT = {
    [76093] = true, -- Potion of Mogu Power (Str)
  },
  PALADIN = {
    retribution = {
      [76093] = true, -- Potion of Mogu Power (Str)
    },
  },
}

-- Helper function to get prepotions for a class/spec
function Analyzer:GetPrepotionsForSpec(classToken, specKey)
  if not classToken then
    return {}
  end
  
  local classData = self.PrepotionData[classToken]
  if not classData then
    return {}
  end
  
  -- Check if there's spec-specific data
  if specKey and type(classData[specKey]) == "table" then
    return classData[specKey]
  end
  
  -- Return class-wide data (filter out spec tables)
  local potions = {}
  for spellId, enabled in pairs(classData) do
    if type(spellId) == "number" and enabled then
      potions[spellId] = true
    end
  end
  
  return potions
end

-- Override IsPrecombatBuffSpell to include prepotions
local originalIsPrecombatBuffSpell = Analyzer.IsPrecombatBuffSpell
function Analyzer:IsPrecombatBuffSpell(spellId)
  if not spellId then
    return false
  end
  
  -- Check original function first
  if originalIsPrecombatBuffSpell and originalIsPrecombatBuffSpell(self, spellId) then
    return true
  end
  
  -- Check if it's a prepotion for current class/spec
  local classToken = self.player and self.player.class
  local specKey = self.activeModule and self.activeModule.specKey
  
  local prepotions = self:GetPrepotionsForSpec(classToken, specKey)
  if prepotions[spellId] then
    return true
  end
  
  -- Fallback: check all common prepotions
  local commonPrepotions = {
    [105702] = true, -- Potion of the Jade Serpent
    [76089] = true,  -- Potion of the Tol'vir
    [76093] = true,  -- Potion of Mogu Power
  }
  
  return commonPrepotions[spellId] == true
end
