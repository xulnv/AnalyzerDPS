local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Warrior - Arms"
module.class = "WARRIOR"
module.specKey = "arms"
module.specIndex = 1
module.specId = 71

-- MoP 5.4 Arms Warrior Spell IDs
local SPELL_MORTAL_STRIKE = 12294
local SPELL_COLOSSUS_SMASH = 86346
local SPELL_OVERPOWER = 7384
local SPELL_SLAM = 1464
local SPELL_EXECUTE = 5308
local SPELL_REND = 772
local SPELL_SWEEPING_STRIKES = 12328
local SPELL_BLADESTORM = 46924
local SPELL_AVATAR = 107574
local SPELL_RECKLESSNESS = 1719
local SPELL_TASTE_FOR_BLOOD = 56636
local SPELL_SUDDEN_DEATH = 52437
local SPELL_DEADLY_CALM = 85730
local SPELL_HEROIC_STRIKE = 78
local SPELL_THUNDER_CLAP = 6343
local SPELL_WHIRLWIND = 1680
local SPELL_VICTORY_RUSH = 34428
local SPELL_HAMSTRING = 1715
local SPELL_CHARGE = 100
local SPELL_HEROIC_LEAP = 6544
local SPELL_SHOCKWAVE = 46968
local SPELL_SKULL_BANNER = 114207
local SPELL_BLOODBATH = 12292
local SPELL_STORM_BOLT = 107570

-- Buff tracking
local TRACKED_BUFFS = {
  [SPELL_TASTE_FOR_BLOOD] = true,
  [SPELL_SUDDEN_DEATH] = true,
  [SPELL_RECKLESSNESS] = true,
  [SPELL_AVATAR] = true,
  [SPELL_SWEEPING_STRIKES] = true,
  [SPELL_BLADESTORM] = true,
  [SPELL_DEADLY_CALM] = true,
  [SPELL_SKULL_BANNER] = true,
  [SPELL_BLOODBATH] = true,
}

-- Debuff tracking
local TRACKED_DEBUFFS = {
  [SPELL_COLOSSUS_SMASH] = true,
  [SPELL_REND] = true,
  [SPELL_HAMSTRING] = true,
}

-- Cast tracking
local TRACKED_CASTS = {
  [SPELL_MORTAL_STRIKE] = true,
  [SPELL_COLOSSUS_SMASH] = true,
  [SPELL_OVERPOWER] = true,
  [SPELL_SLAM] = true,
  [SPELL_EXECUTE] = true,
  [SPELL_REND] = true,
  [SPELL_HEROIC_STRIKE] = true,
  [SPELL_THUNDER_CLAP] = true,
  [SPELL_WHIRLWIND] = true,
  [SPELL_VICTORY_RUSH] = true,
  [SPELL_SWEEPING_STRIKES] = true,
  [SPELL_BLADESTORM] = true,
  [SPELL_AVATAR] = true,
  [SPELL_RECKLESSNESS] = true,
  [SPELL_DEADLY_CALM] = true,
  [SPELL_CHARGE] = true,
  [SPELL_HEROIC_LEAP] = true,
  [SPELL_SHOCKWAVE] = true,
  [SPELL_SKULL_BANNER] = true,
  [SPELL_BLOODBATH] = true,
  [SPELL_STORM_BOLT] = true,
}

-- Sound keys
local SOUND_KEY_TASTE_FOR_BLOOD = "taste_for_blood"
local SOUND_KEY_SUDDEN_DEATH = "sudden_death"
local SOUND_KEY_COLOSSUS_SMASH = "colossus_smash_fade"

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
    {
      key = SOUND_KEY_TASTE_FOR_BLOOD,
      label = "Taste for Blood Proc",
      default = "none",
    },
    {
      key = SOUND_KEY_SUDDEN_DEATH,
      label = "Sudden Death Proc",
      default = "none",
    },
    {
      key = SOUND_KEY_COLOSSUS_SMASH,
      label = "Colossus Smash Fading",
      default = "none",
    },
  }
end

function module.GetProcInfo(spellId)
  if spellId == SPELL_TASTE_FOR_BLOOD then
    return {
      soundKey = SOUND_KEY_TASTE_FOR_BLOOD,
      priority = 2,
    }
  elseif spellId == SPELL_SUDDEN_DEATH then
    return {
      soundKey = SOUND_KEY_SUDDEN_DEATH,
      priority = 3,
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

function module.InitFight(fight)
  fight.casts = fight.casts or {}
  fight.procs = fight.procs or {}
  fight.debuffs = fight.debuffs or {}
  fight.buffs = fight.buffs or {}

  fight.casts.mortalStrike = 0
  fight.casts.colossusSmash = 0
  fight.casts.overpower = 0
  fight.casts.slam = 0
  fight.casts.execute = 0
  fight.casts.rend = 0
  fight.casts.heroicStrike = 0
  fight.casts.thunderClap = 0
  fight.casts.whirlwind = 0
  fight.casts.sweepingStrikes = 0
  fight.casts.bladestorm = 0
  fight.casts.avatar = 0
  fight.casts.recklessness = 0
  fight.casts.bloodbath = 0
  fight.casts.stormBolt = 0

  fight.procs.tasteForBloodProcs = 0
  fight.procs.tasteForBloodConsumed = 0
  fight.procs.tasteForBloodWasted = 0
  fight.procs.suddenDeathProcs = 0
  fight.procs.suddenDeathConsumed = 0
  fight.procs.suddenDeathWasted = 0

  fight.debuffs.colossusSmashHistory = {}
  fight.debuffs.rendHistory = {}

  fight.buffs.tasteForBloodHistory = {}
  fight.buffs.suddenDeathHistory = {}
  fight.buffs.recklessnessHistory = {}
  fight.buffs.avatarHistory = {}
end

function module.TrackSpellCast(analyzer, fight, event, spellId)
  local now = event.timestamp

  if spellId == SPELL_MORTAL_STRIKE then
    fight.casts.mortalStrike = fight.casts.mortalStrike + 1

    -- Check if Taste for Blood was consumed
    local hasProc = false
    for i = #fight.buffs.tasteForBloodHistory, 1, -1 do
      local history = fight.buffs.tasteForBloodHistory[i]
      if history.applied <= now and (not history.removed or history.removed >= now) then
        hasProc = true
        if not history.consumed then
          history.consumed = now
          fight.procs.tasteForBloodConsumed = fight.procs.tasteForBloodConsumed + 1
        end
        break
      end
    end

  elseif spellId == SPELL_COLOSSUS_SMASH then
    fight.casts.colossusSmash = fight.casts.colossusSmash + 1

  elseif spellId == SPELL_OVERPOWER then
    fight.casts.overpower = fight.casts.overpower + 1

    -- Check if Taste for Blood was consumed
    local hasProc = false
    for i = #fight.buffs.tasteForBloodHistory, 1, -1 do
      local history = fight.buffs.tasteForBloodHistory[i]
      if history.applied <= now and (not history.removed or history.removed >= now) then
        hasProc = true
        if not history.consumed then
          history.consumed = now
          fight.procs.tasteForBloodConsumed = fight.procs.tasteForBloodConsumed + 1
        end
        break
      end
    end

  elseif spellId == SPELL_SLAM then
    fight.casts.slam = fight.casts.slam + 1

  elseif spellId == SPELL_EXECUTE then
    fight.casts.execute = fight.casts.execute + 1

    -- Check if Sudden Death was consumed
    local hasProc = false
    for i = #fight.buffs.suddenDeathHistory, 1, -1 do
      local history = fight.buffs.suddenDeathHistory[i]
      if history.applied <= now and (not history.removed or history.removed >= now) then
        hasProc = true
        if not history.consumed then
          history.consumed = now
          fight.procs.suddenDeathConsumed = fight.procs.suddenDeathConsumed + 1
        end
        break
      end
    end

  elseif spellId == SPELL_REND then
    fight.casts.rend = fight.casts.rend + 1

  elseif spellId == SPELL_HEROIC_STRIKE then
    fight.casts.heroicStrike = fight.casts.heroicStrike + 1

  elseif spellId == SPELL_THUNDER_CLAP then
    fight.casts.thunderClap = fight.casts.thunderClap + 1

  elseif spellId == SPELL_WHIRLWIND then
    fight.casts.whirlwind = fight.casts.whirlwind + 1

  elseif spellId == SPELL_SWEEPING_STRIKES then
    fight.casts.sweepingStrikes = fight.casts.sweepingStrikes + 1

  elseif spellId == SPELL_BLADESTORM then
    fight.casts.bladestorm = fight.casts.bladestorm + 1

  elseif spellId == SPELL_AVATAR then
    fight.casts.avatar = fight.casts.avatar + 1

  elseif spellId == SPELL_RECKLESSNESS then
    fight.casts.recklessness = fight.casts.recklessness + 1

  elseif spellId == SPELL_BLOODBATH then
    fight.casts.bloodbath = fight.casts.bloodbath + 1

  elseif spellId == SPELL_STORM_BOLT then
    fight.casts.stormBolt = fight.casts.stormBolt + 1
  end
end

function module.TrackAura(analyzer, fight, spellId, applied, removed, isRefresh)
  local now = GetTime()

  if spellId == SPELL_TASTE_FOR_BLOOD then
    if applied then
      table.insert(fight.buffs.tasteForBloodHistory, {
        applied = now,
        removed = nil,
        consumed = nil,
      })
      if not isRefresh then
        fight.procs.tasteForBloodProcs = fight.procs.tasteForBloodProcs + 1
        analyzer:AddTimelineEvent(spellId, now, "proc")
        analyzer:AddEventLog(now, "Taste for Blood proc", spellId)
      end
      analyzer:PlayAlertSound(SOUND_KEY_TASTE_FOR_BLOOD, now)
    elseif removed then
      for i = #fight.buffs.tasteForBloodHistory, 1, -1 do
        local history = fight.buffs.tasteForBloodHistory[i]
        if not history.removed then
          history.removed = now
          if not history.consumed then
            fight.procs.tasteForBloodWasted = fight.procs.tasteForBloodWasted + 1
          end
          break
        end
      end
    end

  elseif spellId == SPELL_SUDDEN_DEATH then
    if applied then
      table.insert(fight.buffs.suddenDeathHistory, {
        applied = now,
        removed = nil,
        consumed = nil,
      })
      if not isRefresh then
        fight.procs.suddenDeathProcs = fight.procs.suddenDeathProcs + 1
        analyzer:AddTimelineEvent(spellId, now, "proc")
        analyzer:AddEventLog(now, "Sudden Death proc", spellId)
      end
      analyzer:PlayAlertSound(SOUND_KEY_SUDDEN_DEATH, now)
    elseif removed then
      for i = #fight.buffs.suddenDeathHistory, 1, -1 do
        local history = fight.buffs.suddenDeathHistory[i]
        if not history.removed then
          history.removed = now
          if not history.consumed then
            fight.procs.suddenDeathWasted = fight.procs.suddenDeathWasted + 1
          end
          break
        end
      end
    end

  elseif spellId == SPELL_RECKLESSNESS then
    if applied then
      table.insert(fight.buffs.recklessnessHistory, {
        applied = now,
        removed = nil,
      })
      analyzer:AddTimelineEvent(spellId, now, "buff")
    elseif removed then
      for i = #fight.buffs.recklessnessHistory, 1, -1 do
        local history = fight.buffs.recklessnessHistory[i]
        if not history.removed then
          history.removed = now
          break
        end
      end
    end

  elseif spellId == SPELL_AVATAR then
    if applied then
      table.insert(fight.buffs.avatarHistory, {
        applied = now,
        removed = nil,
      })
      analyzer:AddTimelineEvent(spellId, now, "buff")
    elseif removed then
      for i = #fight.buffs.avatarHistory, 1, -1 do
        local history = fight.buffs.avatarHistory[i]
        if not history.removed then
          history.removed = now
          break
        end
      end
    end
  end
end

function module.TrackDebuff(analyzer, fight, spellId, applied, removed, isRefresh)
  local now = GetTime()

  if spellId == SPELL_COLOSSUS_SMASH then
    if applied then
      table.insert(fight.debuffs.colossusSmashHistory, {
        applied = now,
        removed = nil,
      })
      analyzer:AddTimelineEvent(spellId, now, "debuff")
    elseif removed then
      for i = #fight.debuffs.colossusSmashHistory, 1, -1 do
        local history = fight.debuffs.colossusSmashHistory[i]
        if not history.removed then
          history.removed = now
          analyzer:PlayAlertSound(SOUND_KEY_COLOSSUS_SMASH, now)
          break
        end
      end
    end

  elseif spellId == SPELL_REND then
    if applied then
      table.insert(fight.debuffs.rendHistory, {
        applied = now,
        removed = nil,
      })
      if not isRefresh then
        analyzer:AddTimelineEvent(spellId, now, "debuff")
      end
    elseif removed then
      for i = #fight.debuffs.rendHistory, 1, -1 do
        local history = fight.debuffs.rendHistory[i]
        if not history.removed then
          history.removed = now
          break
        end
      end
    end
  end
end

function module.Analyze(analyzer, fight, context)
  local duration = fight.endTime - fight.startTime

  if duration <= 0 then
    return {
      score = 0,
      metrics = {},
      issues = { "Fight duration too short to analyze." },
    }
  end

  local issues = {}
  local metrics = {}
  local score = 100

  -- Calculate Colossus Smash uptime
  local csUptime = 0
  for _, history in ipairs(fight.debuffs.colossusSmashHistory) do
    local endTime = history.removed or fight.endTime
    csUptime = csUptime + (endTime - history.applied)
  end
  local csUptimePercent = (csUptime / duration) * 100
  metrics.colossusSmashUptime = string.format("%.1f%%", csUptimePercent)

  if csUptimePercent < 50 then
    table.insert(issues, "Colossus Smash uptime bardzo niskie (" .. string.format("%.1f%%", csUptimePercent) .. "). Używaj częściej!")
    score = score - 20
  elseif csUptimePercent < 70 then
    table.insert(issues, "Colossus Smash uptime można poprawić (" .. string.format("%.1f%%", csUptimePercent) .. "). Cel: 70%+")
    score = score - 10
  end

  -- Calculate Rend uptime
  local rendUptime = 0
  for _, history in ipairs(fight.debuffs.rendHistory) do
    local endTime = history.removed or fight.endTime
    rendUptime = rendUptime + (endTime - history.applied)
  end
  local rendUptimePercent = (rendUptime / duration) * 100
  metrics.rendUptime = string.format("%.1f%%", rendUptimePercent)

  if rendUptimePercent < 80 then
    table.insert(issues, "Rend uptime za niskie (" .. string.format("%.1f%%", rendUptimePercent) .. "). Utrzymuj na 95%+!")
    score = score - 15
  elseif rendUptimePercent < 95 then
    table.insert(issues, "Rend uptime można poprawić (" .. string.format("%.1f%%", rendUptimePercent) .. "). Cel: 95%+")
    score = score - 5
  end

  -- Taste for Blood analysis
  if fight.procs.tasteForBloodProcs > 0 then
    local tfbWastePercent = (fight.procs.tasteForBloodWasted / fight.procs.tasteForBloodProcs) * 100
    metrics.tasteForBloodProcs = fight.procs.tasteForBloodProcs
    metrics.tasteForBloodWasted = string.format("%d (%.1f%%)", fight.procs.tasteForBloodWasted, tfbWastePercent)

    if tfbWastePercent > 30 then
      table.insert(issues, "Zmarnowano " .. fight.procs.tasteForBloodWasted .. " proc Taste for Blood! Używaj Mortal Strike/Overpower!")
      score = score - 15
    elseif tfbWastePercent > 10 then
      table.insert(issues, "Zmarnowano " .. fight.procs.tasteForBloodWasted .. " proc Taste for Blood. Staraj się wykorzystać każdy!")
      score = score - 5
    end
  end

  -- Sudden Death analysis
  if fight.procs.suddenDeathProcs > 0 then
    local sdWastePercent = (fight.procs.suddenDeathWasted / fight.procs.suddenDeathProcs) * 100
    metrics.suddenDeathProcs = fight.procs.suddenDeathProcs
    metrics.suddenDeathWasted = string.format("%d (%.1f%%)", fight.procs.suddenDeathWasted, sdWastePercent)

    if sdWastePercent > 20 then
      table.insert(issues, "Zmarnowano " .. fight.procs.suddenDeathWasted .. " proc Sudden Death! Używaj Execute natychmiast!")
      score = score - 15
    elseif sdWastePercent > 5 then
      table.insert(issues, "Zmarnowano " .. fight.procs.suddenDeathWasted .. " proc Sudden Death. Reaguj szybciej!")
      score = score - 5
    end
  end

  -- Cooldown usage
  if fight.casts.recklessness == 0 and duration > 120 then
    table.insert(issues, "Nie użyto Recklessness! Używaj na cooldown w długich walkach.")
    score = score - 10
  end

  if fight.casts.avatar == 0 and duration > 180 then
    table.insert(issues, "Nie użyto Avatar! Używaj na burst damage.")
    score = score - 10
  end

  if fight.casts.bladestorm == 0 and duration > 60 then
    table.insert(issues, "Nie użyto Bladestorm! Dobra ability do AoE i single target.")
    score = score - 5
  end

  -- Cast counts
  metrics.mortalStrikeCasts = fight.casts.mortalStrike
  metrics.colossusSmashCasts = fight.casts.colossusSmash
  metrics.overpowerCasts = fight.casts.overpower
  metrics.slamCasts = fight.casts.slam
  metrics.executeCasts = fight.casts.execute

  if fight.casts.mortalStrike == 0 then
    table.insert(issues, "Nie użyto Mortal Strike! To główna ability Arms!")
    score = score - 30
  end

  if fight.casts.colossusSmash == 0 then
    table.insert(issues, "Nie użyto Colossus Smash! Kluczowy debuff dla damage!")
    score = score - 25
  end

  -- Final score clamping
  if score < 0 then
    score = 0
  end

  if #issues == 0 then
    table.insert(issues, "Świetna rotacja! Kontynuuj dobrą robotę!")
  end

  return {
    score = score,
    metrics = metrics,
    issues = issues,
  }
end

function module.GetLiveScore(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  if duration < 5 then
    return nil
  end

  local score = 100

  -- Check Colossus Smash uptime
  local csUptime = 0
  for _, history in ipairs(fight.debuffs.colossusSmashHistory or {}) do
    local endTime = history.removed or now
    csUptime = csUptime + (endTime - history.applied)
  end
  local csUptimePercent = (csUptime / duration) * 100

  if csUptimePercent < 50 then
    score = score - 20
  elseif csUptimePercent < 70 then
    score = score - 10
  end

  -- Check Rend uptime
  local rendUptime = 0
  for _, history in ipairs(fight.debuffs.rendHistory or {}) do
    local endTime = history.removed or now
    rendUptime = rendUptime + (endTime - history.applied)
  end
  local rendUptimePercent = (rendUptime / duration) * 100

  if rendUptimePercent < 80 then
    score = score - 15
  elseif rendUptimePercent < 95 then
    score = score - 5
  end

  -- Taste for Blood waste
  if fight.procs and fight.procs.tasteForBloodProcs > 0 then
    local tfbWastePercent = (fight.procs.tasteForBloodWasted / fight.procs.tasteForBloodProcs) * 100
    if tfbWastePercent > 30 then
      score = score - 15
    elseif tfbWastePercent > 10 then
      score = score - 5
    end
  end

  if score < 0 then
    score = 0
  end

  return score
end

local function CheckPlayerBuff(spellId)
  if not spellId then return false end
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, auraSpellId = UnitBuff("player", i)
    if not name then break end
    if auraSpellId == spellId then
      return true
    end
  end
  return false
end

local function CheckTargetDebuff(spellId)
  if not spellId or not UnitExists("target") then return false end
  for i = 1, 40 do
    local name, _, _, _, _, _, _, caster, _, _, auraSpellId = UnitDebuff("target", i)
    if not name then break end
    if auraSpellId == spellId and caster == "player" then
      return true
    end
  end
  return false
end

function module.GetLiveAdvice(analyzer, fight)
  if not fight then
    return ""
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasTasteForBlood = CheckPlayerBuff(SPELL_TASTE_FOR_BLOOD)
  if hasTasteForBlood then
    return "TFB Proc! Mortal/Overpower!"
  end

  local hasSuddenDeath = CheckPlayerBuff(SPELL_SUDDEN_DEATH)
  if hasSuddenDeath then
    return "Sudden Death! Execute!"
  end

  local hasColossusSmash = CheckTargetDebuff(SPELL_COLOSSUS_SMASH)
  if not hasColossusSmash and UnitExists("target") and duration > 3 then
    if utils.IsSpellReady(SPELL_COLOSSUS_SMASH) then
      return "Colossus Smash gotowe!"
    end
  end

  local hasRend = CheckTargetDebuff(SPELL_REND)
  if not hasRend and UnitExists("target") and duration > 2 then
    return "Naloz Rend!"
  end

  if utils.IsSpellReady(SPELL_RECKLESSNESS) and duration > 10 then
    return "Recklessness gotowe!"
  end

  if utils.IsSpellReady(SPELL_AVATAR) and duration > 10 then
    return "Avatar gotowe!"
  end

  return ""
end

function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasTasteForBlood = CheckPlayerBuff(SPELL_TASTE_FOR_BLOOD)
  if hasTasteForBlood then
    return SPELL_MORTAL_STRIKE
  end

  local hasSuddenDeath = CheckPlayerBuff(SPELL_SUDDEN_DEATH)
  if hasSuddenDeath then
    return SPELL_EXECUTE
  end

  local hasColossusSmash = CheckTargetDebuff(SPELL_COLOSSUS_SMASH)
  if not hasColossusSmash and UnitExists("target") and duration > 3 then
    if utils.IsSpellReady(SPELL_COLOSSUS_SMASH) then
      return SPELL_COLOSSUS_SMASH
    end
  end

  local hasRend = CheckTargetDebuff(SPELL_REND)
  if not hasRend and UnitExists("target") and duration > 2 then
    return SPELL_REND
  end

  if utils.IsSpellReady(SPELL_RECKLESSNESS) and duration > 10 then
    return SPELL_RECKLESSNESS
  end

  if utils.IsSpellReady(SPELL_AVATAR) and duration > 10 then
    return SPELL_AVATAR
  end

  return nil
end

Analyzer:RegisterClassModule(module.class, module)
