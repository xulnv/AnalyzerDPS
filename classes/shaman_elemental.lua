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
module.specId = 262

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

local COOLDOWN_ASCENDANCE = 180
local COOLDOWN_FIRE_ELEMENTAL = 300
local COOLDOWN_ELEMENTAL_BLAST = 12
local COOLDOWN_ELEMENTAL_MASTERY = 90

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

local function EnsureHistory(container, spellId)
  container[spellId] = container[spellId] or {}
  return container[spellId]
end

local function HasDebuffAtTime(history, timestamp, duration)
  if not history then
    return false
  end
  for _, window in ipairs(history) do
    local start = window.applied or 0
    local finish = window.removed or duration
    if timestamp >= start and timestamp <= finish then
      return true
    end
  end
  return false
end

function module.SupportsSpec(analyzer)
  if analyzer.player.class ~= module.class then
    return false
  end
  if analyzer.player.specId == module.specId then
    return true
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

function module.OnPlayerInit(analyzer)
  if analyzer.player.class ~= module.class then
    return
  end
  if analyzer.player.specName ~= "Unknown" then
    return
  end
  if IsSpellKnown and (IsSpellKnown(SPELL_LAVA_BURST) or IsSpellKnown(SPELL_ELEMENTAL_BLAST)) then
    analyzer.player.specName = "Elemental"
    analyzer.player.specId = analyzer.player.specId or module.specId
    analyzer.player.specIndex = analyzer.player.specIndex or module.specIndex
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_LAVA_SURGE] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_ASCENDANCE] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
      [SOUND_KEY_ELEMENTAL_MASTERY] = { enabled = true, sound = "Sound\\Interface\\ReadyCheck.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_LAVA_SURGE, label = "Lava Surge" },
    { key = SOUND_KEY_ASCENDANCE, label = "Ascendance" },
    { key = SOUND_KEY_ELEMENTAL_MASTERY, label = "Elemental Mastery" },
  }
end

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

function module.GetProcInfo(spellId)
  if spellId == SPELL_LAVA_SURGE then
    return {
      soundKey = SOUND_KEY_LAVA_SURGE,
      priority = 2,
    }
  elseif spellId == SPELL_ASCENDANCE then
    return {
      soundKey = SOUND_KEY_ASCENDANCE,
      priority = 3,
    }
  elseif spellId == SPELL_ELEMENTAL_MASTERY then
    return {
      soundKey = SOUND_KEY_ELEMENTAL_MASTERY,
      priority = 2,
    }
  end
  return nil
end

function module.ShouldTrackSummonSpell(spellId)
  return spellId == SPELL_FIRE_ELEMENTAL_TOTEM
end

function module.InitFight(_, fight)
  fight.procs = {
    lavaSurgeProcs = 0,
    lavaSurgeConsumed = 0,
    lavaSurgeExpired = 0,
  }
  fight.cooldowns = {
    fireElementalLast = 0,
    ascendanceLast = 0,
    elementalMasteryLast = 0,
    potionLast = 0,
  }
  fight.castLog = {}
  fight.buffHistory = {}
  fight.debuffHistory = {}
end

function module.TrackSpellCast(analyzer, spellId, timestamp)
  local fight = analyzer.fight
  if not fight or not TRACKED_CASTS[spellId] then
    return
  end

  local now = utils.NormalizeTimestamp(timestamp)
  fight.spells[spellId] = (fight.spells[spellId] or 0) + 1
  table.insert(fight.castLog, { spellId = spellId, timestamp = now })

  if spellId == SPELL_LAVA_BURST then
    local buff = fight.buffs[SPELL_LAVA_SURGE]
    if buff and (buff.stacks or 0) > 0 then
      fight.procs.lavaSurgeConsumed = fight.procs.lavaSurgeConsumed + 1
      buff.consumed = true
      buff.stacks = 0
    end
  elseif spellId == SPELL_FIRE_ELEMENTAL_TOTEM then
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Fire Elemental Totem", spellId)
  end
end

function module.TrackAura(analyzer, subevent, spellId, amount, timestamp)
  local fight = analyzer.fight
  if not fight then
    return
  end

  local now = utils.NormalizeTimestamp(timestamp)
  if subevent == "SPELL_AURA_APPLIED"
    or subevent == "SPELL_AURA_APPLIED_DOSE"
    or subevent == "SPELL_AURA_REFRESH" then
    local stacks = amount or 1
    local buff = fight.buffs[spellId]
    local isRefresh = (subevent == "SPELL_AURA_REFRESH")

    if buff and isRefresh and buff.since then
      fight.buffUptime[spellId] = (fight.buffUptime[spellId] or 0) + (now - buff.since)
    end

    if not buff then
      buff = { stacks = stacks, since = now }
      fight.buffs[spellId] = buff
    else
      buff.stacks = stacks
      buff.since = buff.since or now
    end

    if isRefresh then
      buff.since = now
    end

    local history = EnsureHistory(fight.buffHistory, spellId)
    if isRefresh and buff.historyEntry and not buff.historyEntry.removed then
      buff.historyEntry.removed = now
    end
    if not buff.historyEntry or isRefresh then
      buff.historyEntry = { applied = now }
      table.insert(history, buff.historyEntry)
    end

    if spellId == SPELL_LAVA_SURGE then
      if not isRefresh then
        fight.procs.lavaSurgeProcs = fight.procs.lavaSurgeProcs + 1
        analyzer:AddTimelineEvent(spellId, now, "proc")
        analyzer:AddEventLog(now, "Lava Surge proc", spellId)
      else
        analyzer:AddEventLog(now, "Lava Surge odswiezony", spellId)
      end
      analyzer:PlayAlertSound(SOUND_KEY_LAVA_SURGE, now)
    elseif spellId == SPELL_ASCENDANCE then
      fight.spells[SPELL_ASCENDANCE] = (fight.spells[SPELL_ASCENDANCE] or 0) + 1
      fight.cooldowns.ascendanceLast = now
      analyzer:AddTimelineEvent(spellId, now, "cooldown")
      analyzer:AddEventLog(now, "Ascendance", spellId)
      analyzer:PlayAlertSound(SOUND_KEY_ASCENDANCE, now)
    elseif spellId == SPELL_ELEMENTAL_MASTERY then
      fight.spells[SPELL_ELEMENTAL_MASTERY] = (fight.spells[SPELL_ELEMENTAL_MASTERY] or 0) + 1
      fight.cooldowns.elementalMasteryLast = now
      analyzer:AddTimelineEvent(spellId, now, "cooldown")
      analyzer:AddEventLog(now, "Elemental Mastery", spellId)
      analyzer:PlayAlertSound(SOUND_KEY_ELEMENTAL_MASTERY, now)
    elseif spellId == SPELL_POTION_JADE_SERPENT then
      local lastPotion = fight.cooldowns.potionLast or 0
      if (now - lastPotion) > 0.5 then
        fight.cooldowns.potionLast = now
        analyzer:AddEventLog(now, "Potion of the Jade Serpent", spellId)
      end
    end
  elseif subevent == "SPELL_AURA_REMOVED" then
    local buff = fight.buffs[spellId]
    if buff then
      if buff.since then
        fight.buffUptime[spellId] = (fight.buffUptime[spellId] or 0) + (now - buff.since)
      end
      if spellId == SPELL_LAVA_SURGE and not buff.consumed then
        fight.procs.lavaSurgeExpired = fight.procs.lavaSurgeExpired + 1
      end
      if buff.historyEntry and not buff.historyEntry.removed then
        buff.historyEntry.removed = now
      end
    end
    fight.buffs[spellId] = nil
  end
end

function module.TrackDebuff(analyzer, subevent, spellId, destGUID, destName, timestamp)
  local fight = analyzer.fight
  if not fight or spellId ~= SPELL_FLAME_SHOCK then
    return
  end

  local now = utils.NormalizeTimestamp(timestamp)
  if not fight.primaryTargetGUID then
    fight.primaryTargetGUID = destGUID
  end
  if destGUID and fight.primaryTargetGUID and destGUID ~= fight.primaryTargetGUID then
    return
  end
  if destGUID then
    fight.targets[destGUID] = true
  end

  local debuff = fight.debuffs[spellId]
  local history = EnsureHistory(fight.debuffHistory, spellId)

  if subevent == "SPELL_AURA_APPLIED" then
    fight.debuffs[spellId] = { since = now, targetGUID = destGUID }
    local entry = { applied = now }
    table.insert(history, entry)
    fight.debuffs[spellId].historyEntry = entry
    analyzer:AddEventLog(now, "Flame Shock nalozony", spellId)
  elseif subevent == "SPELL_AURA_REFRESH" then
    if debuff and debuff.since then
      fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (now - debuff.since)
    end
    if debuff and debuff.historyEntry and not debuff.historyEntry.removed then
      debuff.historyEntry.removed = now
    end
    fight.debuffs[spellId] = { since = now, targetGUID = destGUID }
    local entry = { applied = now }
    table.insert(history, entry)
    fight.debuffs[spellId].historyEntry = entry
    analyzer:AddEventLog(now, "Flame Shock odswiezony", spellId)
  elseif subevent == "SPELL_AURA_REMOVED" then
    if debuff and debuff.since then
      fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (now - debuff.since)
    end
    if debuff and debuff.historyEntry and not debuff.historyEntry.removed then
      debuff.historyEntry.removed = now
    end
    fight.debuffs[spellId] = nil
  end
end

function module.Analyze(_, fight, context)
  local metrics = {}
  local issues = {}
  local score = 100

  if context.duration < 15 then
    utils.AddIssue(issues, "Walka zbyt krotka na sensowna analize. Potrzebujesz co najmniej 15s.")
    return {
      score = 0,
      metrics = metrics,
      issues = issues,
    }
  end

  local function AddMetric(label, spellId, valueText, percent, status, issueText, penalty)
    table.insert(metrics, {
      label = label,
      spellId = spellId,
      valueText = valueText or "",
      percent = percent,
      status = status or "info",
    })
    utils.AddIssue(issues, issueText)
    if penalty and penalty > 0 then
      score = utils.Clamp(score - penalty, 0, 100)
    end
  end

  local lavaBurst = fight.spells[SPELL_LAVA_BURST] or 0
  local flameShock = fight.spells[SPELL_FLAME_SHOCK] or 0
  local earthShock = fight.spells[SPELL_EARTH_SHOCK] or 0
  local lightningBolt = fight.spells[SPELL_LIGHTNING_BOLT] or 0
  local elementalBlast = fight.spells[SPELL_ELEMENTAL_BLAST] or 0
  local fireElemental = fight.spells[SPELL_FIRE_ELEMENTAL_TOTEM] or 0
  local ascendanceUses = fight.spells[SPELL_ASCENDANCE] or 0
  local elementalMasteryUses = fight.spells[SPELL_ELEMENTAL_MASTERY] or 0

  local flameShockUptime = utils.SafePercent(fight.debuffUptime[SPELL_FLAME_SHOCK] or 0, context.duration)
  local flameShockStatus = utils.StatusForPercent(flameShockUptime, 0.95, 0.85)
  AddMetric(
    "Flame Shock uptime",
    SPELL_FLAME_SHOCK,
    utils.FormatPercent(flameShockUptime),
    flameShockUptime,
    flameShockStatus,
    flameShockStatus == "bad" and "Slaby uptime Flame Shock. Staraj sie odnawiac dot przed wygasnieciem i trzymaj na glownym celu."
      or (flameShockStatus == "warn" and "Uptime Flame Shock moglby byc wyzszy. Pilnuj odswiezenia." or nil),
    flameShockStatus == "bad" and 12 or (flameShockStatus == "warn" and 6 or 0)
  )

  local lavaSurgeProcs = fight.procs.lavaSurgeProcs or 0
  local lavaSurgeConsumed = fight.procs.lavaSurgeConsumed or 0
  local lavaSurgeUtil = utils.SafePercent(lavaSurgeConsumed, lavaSurgeProcs)
  local lavaSurgeStatus = utils.StatusForPercent(lavaSurgeUtil, 0.85, 0.70)
  AddMetric(
    "Lava Surge wykorzystanie",
    SPELL_LAVA_SURGE,
    string.format("%s (%d/%d)", utils.FormatPercent(lavaSurgeUtil), lavaSurgeConsumed, lavaSurgeProcs),
    lavaSurgeUtil,
    lavaSurgeStatus,
    lavaSurgeStatus == "bad" and "Za duzo Lava Surge nie jest zuzywane. Castuj Lava Burst zaraz po procach."
      or (lavaSurgeStatus == "warn" and "Czesc Lava Surge sie marnuje. Zuzywaj proci szybciej." or nil),
    lavaSurgeStatus == "bad" and 10 or (lavaSurgeStatus == "warn" and 5 or 0)
  )

  local lavaSurgeExpired = fight.procs.lavaSurgeExpired or 0
  if lavaSurgeExpired > 0 then
    utils.AddIssue(issues, string.format("Lava Surge wygaslo: %d. Staraj sie zuzywac proci szybciej.", lavaSurgeExpired))
  end

  local flameShockHistory = fight.debuffHistory and fight.debuffHistory[SPELL_FLAME_SHOCK] or nil
  local lavaBurstWithoutFlameShock = 0
  if fight.castLog and lavaBurst > 0 then
    for _, cast in ipairs(fight.castLog) do
      if cast.spellId == SPELL_LAVA_BURST then
        if not HasDebuffAtTime(flameShockHistory, cast.timestamp, context.duration) then
          lavaBurstWithoutFlameShock = lavaBurstWithoutFlameShock + 1
        end
      end
    end
  end

  if lavaBurst > 0 then
    local lavaBurstWithFlameShock = lavaBurst - lavaBurstWithoutFlameShock
    local lavaBurstRatio = utils.SafePercent(lavaBurstWithFlameShock, lavaBurst)
    local lavaBurstStatus = utils.StatusForPercent(lavaBurstRatio, 0.90, 0.75)
    AddMetric(
      "Lava Burst z Flame Shock",
      SPELL_LAVA_BURST,
      string.format("%s (%d/%d)", utils.FormatPercent(lavaBurstRatio), lavaBurstWithFlameShock, lavaBurst),
      lavaBurstRatio,
      lavaBurstStatus,
      lavaBurstStatus == "bad" and "Za duzo Lava Burst bez Flame Shock. Utrzymuj FS na celu, inaczej tracisz gwarantowany crit."
        or (lavaBurstStatus == "warn" and "Czesc Lava Burst wchodzi bez Flame Shock. Pilnuj dotu." or nil),
      lavaBurstStatus == "bad" and 10 or (lavaBurstStatus == "warn" and 5 or 0)
    )
  end

  local expectedFireElemental = utils.ExpectedUses(context.duration, COOLDOWN_FIRE_ELEMENTAL, 10)
  if expectedFireElemental > 0 then
    local firePercent = utils.SafePercent(fireElemental, expectedFireElemental)
    local fireStatus = utils.StatusForPercent(firePercent, 1.0, 0.7)
    AddMetric(
      "Fire Elemental uzycia",
      SPELL_FIRE_ELEMENTAL_TOTEM,
      string.format("%d/%d", fireElemental, expectedFireElemental),
      math.min(firePercent or 0, 1),
      fireStatus,
      fireElemental < expectedFireElemental and "Za malo Fire Elemental. Uzywaj na cooldown."
        or nil,
      fireElemental < expectedFireElemental and 6 or 0
    )
  end

  local expectedAscendance = utils.ExpectedUses(context.duration, COOLDOWN_ASCENDANCE, 10)
  if expectedAscendance > 0 then
    local ascendancePercent = utils.SafePercent(ascendanceUses, expectedAscendance)
    local ascendanceStatus = utils.StatusForPercent(ascendancePercent, 1.0, 0.7)
    AddMetric(
      "Ascendance uzycia",
      SPELL_ASCENDANCE,
      string.format("%d/%d", ascendanceUses, expectedAscendance),
      math.min(ascendancePercent or 0, 1),
      ascendanceStatus,
      ascendanceUses < expectedAscendance and "Za malo Ascendance. Uzywaj na cooldown."
        or nil,
      ascendanceUses < expectedAscendance and 6 or 0
    )
  end

  local expectedElementalMastery = utils.ExpectedUses(context.duration, COOLDOWN_ELEMENTAL_MASTERY, 10)
  if expectedElementalMastery > 0 and elementalMasteryUses > 0 then
    local masteryPercent = utils.SafePercent(elementalMasteryUses, expectedElementalMastery)
    local masteryStatus = utils.StatusForPercent(masteryPercent, 1.0, 0.7)
    AddMetric(
      "Elemental Mastery uzycia",
      SPELL_ELEMENTAL_MASTERY,
      string.format("%d/%d", elementalMasteryUses, expectedElementalMastery),
      math.min(masteryPercent or 0, 1),
      masteryStatus,
      elementalMasteryUses < expectedElementalMastery and "Za malo Elemental Mastery. Uzywaj na cooldown."
        or nil,
      elementalMasteryUses < expectedElementalMastery and 5 or 0
    )
  end

  if elementalBlast > 0 then
    local expectedElementalBlast = utils.ExpectedUses(context.duration, COOLDOWN_ELEMENTAL_BLAST, 6)
    local blastPercent = utils.SafePercent(elementalBlast, expectedElementalBlast)
    local blastStatus = utils.StatusForPercent(blastPercent, 0.8, 0.6)
    AddMetric(
      "Elemental Blast uzycia",
      SPELL_ELEMENTAL_BLAST,
      string.format("%d/%d", elementalBlast, expectedElementalBlast),
      math.min(blastPercent or 0, 1),
      blastStatus,
      blastStatus == "bad" and "Za malo Elemental Blast. Wciskaj na cooldown dla buffow do statow."
        or (blastStatus == "warn" and "Elemental Blast uzywany zbyt rzadko. Staraj sie uzywac czesciej." or nil),
      blastStatus == "bad" and 6 or (blastStatus == "warn" and 3 or 0)
    )
  end

  if flameShock == 0 and context.isSingleTarget then
    utils.AddIssue(issues, "Brak Flame Shock. To kluczowy dot dla proca Lava Surge; utrzymuj na glownym celu.")
    score = utils.Clamp(score - 6, 0, 100)
  end

  AddMetric(
    "Earth Shock casty",
    SPELL_EARTH_SHOCK,
    string.format("%d", earthShock),
    nil,
    "info",
    nil,
    0
  )

  AddMetric(
    "Lightning Bolt casty",
    SPELL_LIGHTNING_BOLT,
    string.format("%d", lightningBolt),
    nil,
    "info",
    nil,
    0
  )

  score = utils.Clamp(score, 0, 100)

  return {
    score = score,
    metrics = metrics,
    issues = issues,
  }
end

Analyzer:RegisterClassModule(module.class, module)
