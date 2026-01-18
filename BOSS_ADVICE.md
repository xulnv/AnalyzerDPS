# Boss-Specific Advice System - Throne of Thunder

## Framework Architecture

### Boss Detection
```lua
-- In AnalyzerDPS.lua
Analyzer.bossDatabase = {
  -- Throne of Thunder
  [68476] = { name = "Horridon", instance = "Throne of Thunder", difficulty = nil },
  [68905] = { name = "Council of Elders", instance = "Throne of Thunder", difficulty = nil },
  [69465] = { name = "Tortos", instance = "Throne of Thunder", difficulty = nil },
  [68068] = { name = "Megaera", instance = "Throne of Thunder", difficulty = nil },
  [68397] = { name = "Ji-Kun", instance = "Throne of Thunder", difficulty = nil },
  [69712] = { name = "Durumu the Forgotten", instance = "Throne of Thunder", difficulty = nil },
  [68036] = { name = "Primordius", instance = "Throne of Thunder", difficulty = nil },
  [68078] = { name = "Dark Animus", instance = "Throne of Thunder", difficulty = nil },
  [69017] = { name = "Iron Qon", instance = "Throne of Thunder", difficulty = nil },
  [68191] = { name = "Twin Consorts", instance = "Throne of Thunder", difficulty = nil },
  [68698] = { name = "Lei Shen", instance = "Throne of Thunder", difficulty = nil },
  [69473] = { name = "Ra-den", instance = "Throne of Thunder", difficulty = nil },
}

function Analyzer:GetBossAdviceForClass(bossId, class, spec)
  -- Returns boss-specific advice for given class/spec
end
```

## Throne of Thunder - Boss-Specific Advice

### **Horridon**

#### **Mage (All Specs)**
- **Remove Curse**: Dispel "Venom Bolt Volley" from raid members (Dire Call adds)
- **AoE Priority**: Switch to adds during door phases
- **Positioning**: Stay spread for Frozen Orb value

#### **Warlock (All Specs)**
- **Gateway**: Place between boss and door positions
- **AoE**: Maximize cleave on adds during door phases
- **Healthstones**: Distribute before pull

#### **Hunter (All Specs)**
- **Tranquilizing Shot**: Remove enrage from Direhorn Spirit
- **Multi-DoT**: Maintain DoTs on Horridon + current door adds
- **Misdirect**: Help tanks with add pickups

#### **Priest - Shadow**
- **Dispel Magic**: Remove "Venom Bolt Volley" (if talented)
- **Multi-DoT**: Maintain DoTs on boss + adds
- **Vampiric Embrace**: Use during high raid damage

#### **Death Knight (Frost/Unholy)**
- **Death Grip**: Pull adds to tank
- **AoE**: Howling Blast/Pestilence for add packs
- **Anti-Magic Shell**: Absorb Frozen Orb damage

### **Council of Elders**

#### **All DPS**
- **Target Priority**: Focus empowered boss
- **Interrupt**: Frostbite (Frost King), Quicksand (Sand King)
- **Avoid**: Shadowed Soul stacks

#### **Mage - Frost**
- **Blink**: Escape Quicksand quickly
- **Ice Block**: Clear Shadowed Soul stacks
- **Spellsteal**: Steal buffs from bosses (if safe)

#### **Rogue (All Specs)**
- **Cloak of Shadows**: Immune to Shadowed Soul
- **Kick**: Interrupt Frostbite/Quicksand
- **Feint**: Reduce AoE damage

### **Tortos**

#### **All Ranged DPS**
- **Turtle Kicking**: Help kick turtles to interrupt Furious Stone Breath
- **Bat Priority**: Kill Vampiric Cave Bats immediately
- **Positioning**: Stay spread for Rockfall

#### **Hunter (All Specs)**
- **Disengage**: Quick repositioning for turtle kicks
- **Deterrence**: Survive Rockfall if caught
- **Multi-DoT**: Maintain on boss + bats

#### **Mage (All Specs)**
- **Blink**: Reposition for turtle kicks
- **Slow**: Slow bats for easier kills
- **Ice Block**: Survive Rockfall emergency

### **Megaera**

#### **All DPS**
- **Head Priority**: Focus called head (usually Flaming > Frozen > Venomous)
- **Rampage**: Burn hard during Rampage phase
- **Positioning**: Move for breath attacks

#### **Mage - Fire**
- **Combustion**: Save for Rampage phase
- **Living Bomb**: Multi-DoT all active heads
- **Dragon's Breath**: Stun adds if needed

#### **Warlock - Destruction**
- **Havoc**: Cleave between heads
- **Dark Soul**: Use during Rampage
- **Rain of Fire**: AoE on stacked heads

### **Ji-Kun**

#### **All DPS**
- **Nest Priority**: Kill eggs in nests quickly
- **Feed Young**: Interrupt/kill Feed Young adds
- **Positioning**: Don't fall off platform

#### **Hunter (All Specs)**
- **Aspect of the Hawk**: DPS on boss from platform
- **Disengage**: Safe nest jumping
- **Multi-DoT**: Boss + Feed Young adds

#### **Druid - Balance**
- **Typhoon**: Knock Feed Young off platform
- **Starfall**: AoE eggs in nests
- **Wild Mushroom**: Place in nest for eggs

### **Durumu the Forgotten**

#### **All DPS**
- **Maze Phase**: Follow beam, kill adds
- **Eye Sore**: Stack for dispels
- **Disintegration Beam**: Avoid at all costs

#### **Mage (All Specs)**
- **Blink**: Navigate maze quickly
- **Slow**: Slow Crimson Fog adds
- **Ice Block**: Emergency survival

#### **Priest - Shadow**
- **Dispersion**: Survive Disintegration Beam
- **Mind Sear**: AoE Crimson Fog
- **Vampiric Embrace**: Heal during maze

### **Primordius**

#### **All DPS**
- **Mutation Stacks**: Collect beneficial mutations
- **Pool Priority**: Kill Viscous Horror pools
- **Burn Phase**: DPS hard with full mutations

#### **Melee DPS**
- **Malformed Blood**: Move out for explosion
- **Mutation Management**: Balance offensive/defensive mutations

#### **Ranged DPS**
- **Pool Soaking**: Help soak pools if needed
- **Spread**: Avoid Caustic Gas overlap

### **Dark Animus**

#### **All DPS**
- **Add Priority**: Kill small > medium > large golems
- **Anima Ring**: Avoid standing in rings
- **Interrupts**: Interrupt Matter Swap

#### **Hunter (All Specs)**
- **Misdirect**: Help tank with add pickups
- **Tranquilizing Shot**: Remove enrage if talented
- **Feign Death**: Drop threat if needed

#### **Mage (All Specs)**
- **Spellsteal**: Steal Anima buffs from golems
- **AoE**: Maximize on small golems
- **Blink**: Avoid Anima Rings

### **Iron Qon**

#### **All DPS**
- **Dog Priority**: Kill Ro'shak (fire dog) first
- **Storm Cloud**: Move out of tornados
- **Burn Phase**: DPS hard in final phase

#### **Ranged DPS**
- **Spread**: Minimize Lightning Storm damage
- **Arcing Lightning**: Don't chain to others

#### **Melee DPS**
- **Impale**: Move out quickly
- **Whirling Winds**: Avoid tornados

### **Twin Consorts**

#### **All DPS**
- **Phase Priority**: Lu'lin (moon) first, then Suen (sun)
- **Star Management**: Collect stars for damage buff
- **Beast Priority**: Kill Celestial Protectors

#### **Mage - Arcane**
- **Arcane Power**: Use with star buff stacks
- **Evocation**: Mana management crucial
- **Slow**: Slow beasts

#### **Warlock (All Specs)**
- **Gateway**: Place for star collection
- **Havoc**: Cleave between bosses
- **Healthstones**: Use during Ice Comet

### **Lei Shen**

#### **All DPS**
- **Phase 1**: Burn boss, avoid Thunderstruck
- **Phase 2**: Kill Diffusion Chain add, stack for Static Shock
- **Phase 3**: Burn boss, manage Helm of Command

#### **Mage (All Specs)**
- **Spellsteal**: Steal Static Shock buff
- **Ice Block**: Survive Overcharge
- **Blink**: Reposition for mechanics

#### **Priest - Shadow**
- **Dispersion**: Survive Overcharge
- **Mass Dispel**: Remove Static Shock (if needed)
- **Vampiric Embrace**: Heal during transitions

#### **Hunter (All Specs)**
- **Deterrence**: Survive Overcharge
- **Disengage**: Reposition quickly
- **Misdirect**: Help with Diffusion Chain add

### **Ra-den (Heroic Only)**

#### **All DPS**
- **Phase 1**: Burn to 40% before Unstable Vita
- **Vita Management**: Balance damage to avoid wipe
- **Anima Management**: Collect orbs carefully

#### **Ranged DPS**
- **Spread**: Minimize Materials of Creation damage
- **Orb Collection**: Ranged collects Anima orbs

## Implementation Plan

### Phase 1: Data Structure
```lua
-- In each class module
module.bossAdvice = {
  [68476] = { -- Horridon
    priority = "AoE adds during door phases",
    mechanics = {
      "Remove Curse on Venom Bolt Volley",
      "Spread for Frozen Orb",
    },
    cooldowns = "Save for door phases",
  },
}
```

### Phase 2: Integration
```lua
function module.GetBossAdvice(analyzer, fight, bossId)
  if not module.bossAdvice[bossId] then
    return nil
  end
  return module.bossAdvice[bossId]
end
```

### Phase 3: UI Display
- Add boss advice section in report
- Show boss-specific tips in mini window
- Color-code by importance (red = critical, yellow = important, white = helpful)

## Priority Implementation Order

1. **Horridon** - First boss, most common
2. **Council of Elders** - Complex mechanics
3. **Lei Shen** - Final boss, most important
4. **Ji-Kun** - Unique mechanics
5. **Durumu** - Maze mechanics
6. **Remaining bosses** - As needed

## Notes
- Boss advice should be concise (1-2 lines max)
- Focus on class-specific mechanics (dispels, interrupts, utilities)
- Avoid generic advice ("do more DPS")
- Update based on player feedback
