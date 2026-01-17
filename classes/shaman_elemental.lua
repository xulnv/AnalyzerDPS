local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Shaman - Elemental"
module.class = "SHAMAN"
module.specKey = "elemental"
module.specIndex = 1

local SPELL_FLAME_SHOCK = 8050
local SPELL_LAVA_BURST = 51505
local SPELL_EARTH_SHOCK = 8042
local SPELL_LIGHTNING_BOLT = 403
local SPELL_ELEMENTAL_BLAST = 117014
local SPELL_ASCENDANCE = 114050
local SPELL_FIRE_ELEMENTAL_TOTEM = 2894
local SPELL_LAVA_SURGE = 77762
local SPELL_ELEMENTAL_MASTERY = 16166
local SPELL_POTION_JADE_SERPENT = 105702
local SPELL_LIGHTNING_SHIELD = 324

local COOLDOWN_LAVA_BURST = 8
local COOLDOWN_ASCENDANCE = 180
local COOLDOWN_FIRE_ELEMENTAL = 300
local COOLDOWN_ELEMENTAL_BLAST = 12
local COOLDOWN_ELEMENTAL_MASTERY = 90

local FLAME_SHOCK_DURATION = 30
local LAVA_SURGE_CONSUME_WINDOW = 0.3

local SOUND_KEY_LAVA_SURGE = "lavaSurge"
local SOUND_KEY_ASCENDANCE = "ascendance"
local SOUND_KEY_ELEMENTAL_MASTERY = "elementalMastery"

local TRACKED_BUFFS = {
  [SPELL_LAVA_SURGE] = true,
  [SPELL_ASCENDANCE] = true,
  [SPELL_ELEMENTAL_MASTERY] = true,
  [SPELL_POTION_JADE_SERPENT] = true,
  [SPELL_LIGHTNING_SHIELD] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_FLAME_SHOCK] = true,
}

local TRACKED_CASTS = {
  [SPELL_FLAME_SHOCK] = true,
  [SPELL_LAVA_BURST] = true,
  [SPELL_EARTH_SHOCK] = true,
  [SPELL_LIGHTNING_BOLT] = true,
  [SPELL_ELEMENTAL_BLAST] = true,
  [SPELL_FIRE_ELEMENTAL_TOTEM] = true,
}

function module.IsTrackedBuffSpell(spellId)
  return TRACKED_BUFFS[spellId] == true
end

function module.IsTrackedDebuffSpell(spellId)
  return TRACKED_DEBUFFS[spellId] == true
end

function module.IsTrackedCast(spellId)
  return TRACKED_CASTS[spellId] == true
end

function module.ShouldRecordCast(event)
  if not event or not event.spellId then
    return false
  end
  return TRACKED_CASTS[event.spellId] == true
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_LAVA_SURGE, label = "Lava Surge" },
    { key = SOUND_KEY_ASCENDANCE, label = "Ascendance" },
    { key = SOUND_KEY_ELEMENTAL_MASTERY, label = "Elemental Mastery" },
  }
end

function module.GetProcInfo(spellId)
  if spellId == SPELL_LAVA_SURGE then
    return {
      soundKey = SOUND_KEY_LAVA_SURGE,
      label = "Lava Surge",
    }
  elseif spellId == SPELL_ASCENDANCE then
    return {
      soundKey = SOUND_KEY_ASCENDANCE,
      label = "Ascendance",
    }
  elseif spellId == SPELL_ELEMENTAL_MASTERY then
    return {
      soundKey = SOUND_KEY_ELEMENTAL_MASTERY,
      label = "Elemental Mastery",
    }
  end
  return nil
end

function module.SupportsSpec(analyzer)
  if analyzer.player.class ~= module.class then
    return false
  end
  local specKey = utils.NormalizeSpecKey(analyzer.player.specName)
  if specKey == module.specKey then
    return true
  end
  if analyzer.player.specIndex == module.specIndex then
    return true
  end
  return false
end

function module.Analyze(context)
  local casts = context.casts or {}
  local buffs = context.buffs or {}
  local debuffs = context.debuffs or {}
  local fightDuration = context.duration or 0

  if fightDuration < 15 then
    return {
      score = 0,
      metrics = {},
      issues = {},
    }
  end

  local lavaBurstCasts = 0
  local flameShockCasts = 0
  local earthShockCasts = 0
  local lightningBoltCasts = 0
  local elementalBlastCasts = 0
  local fireElementalCasts = 0

  local lavaSurgeProcCount = 0
  local lavaSurgeConsumedCount = 0
  local lavaBurstWithoutFlameShock = 0
  local lavaSurgeWastedCasts = {}

  local flameShockUptimeSeconds = 0
  local ascendanceUptimeSeconds = 0
  local elementalMasteryUptimeSeconds = 0

  for _, cast in ipairs(casts) do
    local spellId = cast.spellId
    if spellId == SPELL_LAVA_BURST then
      lavaBurstCasts = lavaBurstCasts + 1
    elseif spellId == SPELL_FLAME_SHOCK then
      flameShockCasts = flameShockCasts + 1
    elseif spellId == SPELL_EARTH_SHOCK then
      earthShockCasts = earthShockCasts + 1
    elseif spellId == SPELL_LIGHTNING_BOLT then
      lightningBoltCasts = lightningBoltCasts + 1
    elseif spellId == SPELL_ELEMENTAL_BLAST then
      elementalBlastCasts = elementalBlastCasts + 1
    elseif spellId == SPELL_FIRE_ELEMENTAL_TOTEM then
      fireElementalCasts = fireElementalCasts + 1
    end
  end

  local flameShockHistory = debuffs[SPELL_FLAME_SHOCK] or {}
  for _, window in ipairs(flameShockHistory) do
    local start = window.applied or 0
    local finish = window.removed or fightDuration
    flameShockUptimeSeconds = flameShockUptimeSeconds + (finish - start)
  end

  local ascendanceHistory = buffs[SPELL_ASCENDANCE] or {}
  for _, window in ipairs(ascendanceHistory) do
    local start = window.applied or 0
    local finish = window.removed or fightDuration
    ascendanceUptimeSeconds = ascendanceUptimeSeconds + (finish - start)
  end

  local elementalMasteryHistory = buffs[SPELL_ELEMENTAL_MASTERY] or {}
  for _, window in ipairs(elementalMasteryHistory) do
    local start = window.applied or 0
    local finish = window.removed or fightDuration
    elementalMasteryUptimeSeconds = elementalMasteryUptimeSeconds + (finish - start)
  end

  local lavaSurgeHistory = buffs[SPELL_LAVA_SURGE] or {}
  lavaSurgeProcCount = #lavaSurgeHistory

  for _, proc in ipairs(lavaSurgeHistory) do
    local procTime = proc.applied or 0
    local procExpired = proc.removed or (procTime + 10)
    local consumed = false

    for _, cast in ipairs(casts) do
      if cast.spellId == SPELL_LAVA_BURST then
        local castTime = cast.timestamp or 0
        if castTime >= procTime and castTime <= (procTime + LAVA_SURGE_CONSUME_WINDOW) then
          consumed = true
          lavaSurgeConsumedCount = lavaSurgeConsumedCount + 1
          break
        end
      end
    end

    if not consumed and procExpired <= fightDuration then
      table.insert(lavaSurgeWastedCasts, {
        timestamp = procTime,
        duration = procExpired - procTime,
      })
    end
  end

  for _, cast in ipairs(casts) do
    if cast.spellId == SPELL_LAVA_BURST then
      local castTime = cast.timestamp or 0
      local hasFlameShock = false

      for _, window in ipairs(flameShockHistory) do
        local start = window.applied or 0
        local finish = window.removed or fightDuration
        if castTime >= start and castTime <= finish then
          hasFlameShock = true
          break
        end
      end

      if not hasFlameShock then
        lavaBurstWithoutFlameShock = lavaBurstWithoutFlameShock + 1
      end
    end
  end

  local flameShockUptimePercent = (flameShockUptimeSeconds / fightDuration) * 100
  local ascendanceUptimePercent = (ascendanceUptimeSeconds / fightDuration) * 100
  local elementalMasteryUptimePercent = (elementalMasteryUptimeSeconds / fightDuration) * 100

  local expectedFireElementalCasts = math.floor(fightDuration / COOLDOWN_FIRE_ELEMENTAL)
  if fightDuration >= 10 then
    expectedFireElementalCasts = expectedFireElementalCasts + 1
  end

  local expectedAscendanceCasts = math.floor(fightDuration / COOLDOWN_ASCENDANCE)
  if fightDuration >= 10 then
    expectedAscendanceCasts = expectedAscendanceCasts + 1
  end

  local lavaSurgeWastePercent = 0
  if lavaSurgeProcCount > 0 then
    lavaSurgeWastePercent = ((lavaSurgeProcCount - lavaSurgeConsumedCount) / lavaSurgeProcCount) * 100
  end

  local score = 100
  local issues = {}

  if flameShockUptimePercent < 95 then
    table.insert(issues, string.format("Low Flame Shock uptime: %.1f%% (target: 95%%+). Flame Shock is critical for Lava Surge procs.", flameShockUptimePercent))
    score = score - math.min(20, (95 - flameShockUptimePercent))
  end

  if lavaBurstWithoutFlameShock > 0 then
    table.insert(issues, string.format("Cast Lava Burst %d times without Flame Shock on target (50%% damage loss).", lavaBurstWithoutFlameShock))
    score = score - (lavaBurstWithoutFlameShock * 3)
  end

  if lavaSurgeWastePercent > 10 then
    table.insert(issues, string.format("Wasted %.1f%% of Lava Surge procs (%d/%d). Consume procs immediately for maximum DPS.", lavaSurgeWastePercent, lavaSurgeProcCount - lavaSurgeConsumedCount, lavaSurgeProcCount))
    score = score - math.min(15, lavaSurgeWastePercent)
  end

  if fireElementalCasts < expectedFireElementalCasts then
    table.insert(issues, string.format("Fire Elemental used %d/%d times. Use on cooldown for sustained DPS.", fireElementalCasts, expectedFireElementalCasts))
    score = score - (expectedFireElementalCasts - fireElementalCasts) * 5
  end

  if ascendanceHistory and #ascendanceHistory < expectedAscendanceCasts then
    table.insert(issues, string.format("Ascendance used %d/%d times. Use on cooldown for burst windows.", #ascendanceHistory, expectedAscendanceCasts))
    score = score - (expectedAscendanceCasts - #ascendanceHistory) * 5
  end

  local expectedElementalBlastCasts = math.floor(fightDuration / COOLDOWN_ELEMENTAL_BLAST)
  if elementalBlastCasts > 0 and elementalBlastCasts < (expectedElementalBlastCasts * 0.8) then
    table.insert(issues, string.format("Low Elemental Blast usage: %d casts (expected ~%d). Use on cooldown for stat buffs.", elementalBlastCasts, expectedElementalBlastCasts))
    score = score - 5
  end

  score = math.max(0, math.min(100, score))

  local metrics = {
    { label = "Flame Shock Uptime", value = string.format("%.1f%%", flameShockUptimePercent), score = flameShockUptimePercent >= 95 and 100 or (flameShockUptimePercent / 95 * 100) },
    { label = "Lava Burst Casts", value = lavaBurstCasts, score = 100 },
    { label = "Lava Surge Consumed", value = string.format("%d/%d (%.1f%%)", lavaSurgeConsumedCount, lavaSurgeProcCount, lavaSurgeProcCount > 0 and (lavaSurgeConsumedCount / lavaSurgeProcCount * 100) or 0), score = lavaSurgeProcCount > 0 and (lavaSurgeConsumedCount / lavaSurgeProcCount * 100) or 100 },
    { label = "Fire Elemental Casts", value = string.format("%d/%d", fireElementalCasts, expectedFireElementalCasts), score = expectedFireElementalCasts > 0 and (fireElementalCasts / expectedFireElementalCasts * 100) or 100 },
    { label = "Ascendance Uptime", value = string.format("%.1f%%", ascendanceUptimePercent), score = 100 },
    { label = "Earth Shock Casts", value = earthShockCasts, score = 100 },
    { label = "Lightning Bolt Filler", value = lightningBoltCasts, score = 100 },
  }

  if elementalBlastCasts > 0 then
    table.insert(metrics, { label = "Elemental Blast Casts", value = elementalBlastCasts, score = 100 })
  end

  return {
    score = score,
    metrics = metrics,
    issues = issues,
  }
end

Analyzer:RegisterClassModule(module.class, module)
