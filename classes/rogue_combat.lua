local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Rogue - Combat"
module.class = "ROGUE"
module.specKey = "combat"
module.specIndex = 2
module.specId = 260

local SPELL_SINISTER_STRIKE = 1752
local SPELL_REVEALING_STRIKE = 84617
local SPELL_EVISCERATE = 2098
local SPELL_SLICE_AND_DICE = 5171
local SPELL_RUPTURE = 1943
local SPELL_ADRENALINE_RUSH = 13750
local SPELL_KILLING_SPREE = 51690
local SPELL_BLADE_FLURRY = 13877
local SPELL_SHADOW_BLADES = 121471
local SPELL_SHALLOW_INSIGHT = 84745
local SPELL_MODERATE_INSIGHT = 84746
local SPELL_DEEP_INSIGHT = 84747
local SPELL_POTION_JADE_SERPENT = 105702

local COOLDOWN_ADRENALINE_RUSH = 180
local COOLDOWN_KILLING_SPREE = 120
local COOLDOWN_SHADOW_BLADES = 180

local SOUND_KEY_DEEP_INSIGHT = "deepInsight"
local SOUND_KEY_ADRENALINE_RUSH = "adrenalineRush"
local SOUND_KEY_KILLING_SPREE = "killingSpree"

local TRACKED_BUFFS = {
  [SPELL_SLICE_AND_DICE] = true,
  [SPELL_ADRENALINE_RUSH] = true,
  [SPELL_KILLING_SPREE] = true,
  [SPELL_BLADE_FLURRY] = true,
  [SPELL_SHADOW_BLADES] = true,
  [SPELL_SHALLOW_INSIGHT] = true,
  [SPELL_MODERATE_INSIGHT] = true,
  [SPELL_DEEP_INSIGHT] = true,
  [SPELL_POTION_JADE_SERPENT] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_REVEALING_STRIKE] = true,
  [SPELL_RUPTURE] = true,
}

local TRACKED_CASTS = {
  [SPELL_SINISTER_STRIKE] = true,
  [SPELL_REVEALING_STRIKE] = true,
  [SPELL_EVISCERATE] = true,
  [SPELL_SLICE_AND_DICE] = true,
  [SPELL_RUPTURE] = true,
  [SPELL_ADRENALINE_RUSH] = true,
  [SPELL_KILLING_SPREE] = true,
  [SPELL_BLADE_FLURRY] = true,
  [SPELL_SHADOW_BLADES] = true,
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
  if IsSpellKnown and (IsSpellKnown(SPELL_REVEALING_STRIKE) or IsSpellKnown(SPELL_BLADE_FLURRY)) then
    analyzer.player.specName = "Combat"
    analyzer.player.specId = analyzer.player.specId or module.specId
    analyzer.player.specIndex = analyzer.player.specIndex or module.specIndex
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_DEEP_INSIGHT] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_ADRENALINE_RUSH] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
      [SOUND_KEY_KILLING_SPREE] = { enabled = true, sound = "Sound\\Interface\\ReadyCheck.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_DEEP_INSIGHT, label = "Deep Insight" },
    { key = SOUND_KEY_ADRENALINE_RUSH, label = "Adrenaline Rush" },
    { key = SOUND_KEY_KILLING_SPREE, label = "Killing Spree" },
  }
end

function module.IsTrackedBuffSpell(spellId)
  return TRACKED_BUFFS[spellId] == true
end

function module.IsTrackedDebuffSpell(spellId)
  return TRACKED_DEBUFFS[spellId] == true
end

function module.InitFight(_, fight)
  fight.counts = {
    eviscerateTotal = 0,
    eviscerateWithReveal = 0,
  }
  fight.cooldowns = {
    adrenalineRushLast = 0,
    killingSpreeLast = 0,
    shadowBladesLast = 0,
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

  if spellId == SPELL_EVISCERATE then
    fight.counts.eviscerateTotal = fight.counts.eviscerateTotal + 1
    local hasReveal = fight.debuffs[SPELL_REVEALING_STRIKE] ~= nil
    if hasReveal then
      fight.counts.eviscerateWithReveal = fight.counts.eviscerateWithReveal + 1
    end
  elseif spellId == SPELL_ADRENALINE_RUSH then
    fight.cooldowns.adrenalineRushLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Adrenaline Rush", spellId)
  elseif spellId == SPELL_KILLING_SPREE then
    fight.cooldowns.killingSpreeLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Killing Spree", spellId)
  elseif spellId == SPELL_SHADOW_BLADES then
    fight.cooldowns.shadowBladesLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Shadow Blades", spellId)
  elseif spellId == SPELL_BLADE_FLURRY then
    analyzer:AddEventLog(now, "Blade Flurry", spellId)
  elseif spellId == SPELL_SLICE_AND_DICE then
    analyzer:AddEventLog(now, "Slice and Dice", spellId)
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

    if buff and buff.since then
      fight.buffUptime[spellId] = (fight.buffUptime[spellId] or 0) + (now - buff.since)
    end

    if not buff then
      buff = { stacks = stacks, since = now }
      fight.buffs[spellId] = buff
    else
      buff.stacks = stacks
      buff.since = now
    end

    local history = EnsureHistory(fight.buffHistory, spellId)
    if buff.historyEntry and not buff.historyEntry.removed then
      buff.historyEntry.removed = now
    end
    buff.historyEntry = { applied = now }
    table.insert(history, buff.historyEntry)

    if spellId == SPELL_DEEP_INSIGHT then
      analyzer:PlayAlertSound(SOUND_KEY_DEEP_INSIGHT, now)
      analyzer:AddEventLog(now, "Deep Insight", spellId)
    elseif spellId == SPELL_ADRENALINE_RUSH then
      analyzer:PlayAlertSound(SOUND_KEY_ADRENALINE_RUSH, now)
    elseif spellId == SPELL_KILLING_SPREE then
      analyzer:PlayAlertSound(SOUND_KEY_KILLING_SPREE, now)
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
      if buff.historyEntry and not buff.historyEntry.removed then
        buff.historyEntry.removed = now
      end
    end
    fight.buffs[spellId] = nil
  end
end

function module.TrackDebuff(analyzer, subevent, spellId, destGUID, destName, timestamp)
  local fight = analyzer.fight
  if not fight or not TRACKED_DEBUFFS[spellId] then
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

  local sndUptime = utils.SafePercent(fight.buffUptime[SPELL_SLICE_AND_DICE] or 0, context.duration)
  local sndStatus = utils.StatusForPercent(sndUptime, 0.90, 0.75)
  AddMetric(
    "Slice and Dice uptime",
    SPELL_SLICE_AND_DICE,
    utils.FormatPercent(sndUptime),
    sndUptime,
    sndStatus,
    sndStatus == "bad" and "Slaby uptime Slice and Dice. Utrzymuj buff prawie caly czas."
      or (sndStatus == "warn" and "Slice and Dice uptime moglby byc wyzszy. Pilnuj odnawiania." or nil),
    sndStatus == "bad" and 12 or (sndStatus == "warn" and 6 or 0)
  )

  local revealUptime = utils.SafePercent(fight.debuffUptime[SPELL_REVEALING_STRIKE] or 0, context.duration)
  local revealStatus = utils.StatusForPercent(revealUptime, 0.90, 0.75)
  AddMetric(
    "Revealing Strike uptime",
    SPELL_REVEALING_STRIKE,
    utils.FormatPercent(revealUptime),
    revealUptime,
    revealStatus,
    revealStatus == "bad" and "Za niski uptime Revealing Strike. Trzymaj debuff na glownym celu."
      or (revealStatus == "warn" and "Uptime Revealing Strike moglby byc lepszy. Pilnuj debuffa." or nil),
    revealStatus == "bad" and 10 or (revealStatus == "warn" and 5 or 0)
  )

  local evisTotal = fight.counts.eviscerateTotal or 0
  local evisWithReveal = fight.counts.eviscerateWithReveal or 0
  if evisTotal > 0 then
    local evisRatio = utils.SafePercent(evisWithReveal, evisTotal)
    local evisStatus = utils.StatusForPercent(evisRatio, 0.90, 0.75)
    AddMetric(
      "Eviscerate z Revealing Strike",
      SPELL_EVISCERATE,
      string.format("%s (%d/%d)", utils.FormatPercent(evisRatio), evisWithReveal, evisTotal),
      evisRatio,
      evisStatus,
      evisStatus == "bad" and "Za duzo Eviscerate bez Revealing Strike. Najpierw utrzymuj debuff."
        or (evisStatus == "warn" and "Czesc Eviscerate bez Revealing Strike. Pilnuj debuffa." or nil),
      evisStatus == "bad" and 8 or (evisStatus == "warn" and 4 or 0)
    )
  end

  local adrenalineRush = fight.spells[SPELL_ADRENALINE_RUSH] or 0
  local expectedAdrenaline = utils.ExpectedUses(context.duration, COOLDOWN_ADRENALINE_RUSH, 10)
  if expectedAdrenaline > 0 then
    local arPercent = utils.SafePercent(adrenalineRush, expectedAdrenaline)
    local arStatus = utils.StatusForPercent(arPercent, 1.0, 0.7)
    AddMetric(
      "Adrenaline Rush uzycia",
      SPELL_ADRENALINE_RUSH,
      string.format("%d/%d", adrenalineRush, expectedAdrenaline),
      math.min(arPercent or 0, 1),
      arStatus,
      adrenalineRush < expectedAdrenaline and "Za malo Adrenaline Rush. Uzywaj na cooldown."
        or nil,
      adrenalineRush < expectedAdrenaline and 6 or 0
    )
  end

  local killingSpree = fight.spells[SPELL_KILLING_SPREE] or 0
  local expectedKilling = utils.ExpectedUses(context.duration, COOLDOWN_KILLING_SPREE, 10)
  if expectedKilling > 0 then
    local ksPercent = utils.SafePercent(killingSpree, expectedKilling)
    local ksStatus = utils.StatusForPercent(ksPercent, 1.0, 0.7)
    AddMetric(
      "Killing Spree uzycia",
      SPELL_KILLING_SPREE,
      string.format("%d/%d", killingSpree, expectedKilling),
      math.min(ksPercent or 0, 1),
      ksStatus,
      killingSpree < expectedKilling and "Za malo Killing Spree. Uzywaj na cooldown."
        or nil,
      killingSpree < expectedKilling and 6 or 0
    )
  end

  local shadowBlades = fight.spells[SPELL_SHADOW_BLADES] or 0
  local expectedShadow = utils.ExpectedUses(context.duration, COOLDOWN_SHADOW_BLADES, 10)
  if expectedShadow > 0 and shadowBlades > 0 then
    local sbPercent = utils.SafePercent(shadowBlades, expectedShadow)
    local sbStatus = utils.StatusForPercent(sbPercent, 1.0, 0.7)
    AddMetric(
      "Shadow Blades uzycia",
      SPELL_SHADOW_BLADES,
      string.format("%d/%d", shadowBlades, expectedShadow),
      math.min(sbPercent or 0, 1),
      sbStatus,
      shadowBlades < expectedShadow and "Za malo Shadow Blades. Uzywaj na cooldown."
        or nil,
      shadowBlades < expectedShadow and 5 or 0
    )
  end

  local bladeFlurryUptime = utils.SafePercent(fight.buffUptime[SPELL_BLADE_FLURRY] or 0, context.duration)
  if context.isMultiTarget then
    local bfStatus = utils.StatusForPercent(bladeFlurryUptime, 0.60, 0.40)
    AddMetric(
      "Blade Flurry uptime (AoE)",
      SPELL_BLADE_FLURRY,
      utils.FormatPercent(bladeFlurryUptime),
      bladeFlurryUptime,
      bfStatus,
      bfStatus == "bad" and "Za niski uptime Blade Flurry na AoE. Utrzymuj wlaczony na kilka celow."
        or (bfStatus == "warn" and "Blade Flurry uptime na AoE moglby byc wyzszy." or nil),
      bfStatus == "bad" and 8 or (bfStatus == "warn" and 4 or 0)
    )
  else
    if bladeFlurryUptime and bladeFlurryUptime > 0.2 then
      utils.AddIssue(issues, "Blade Flurry bylo aktywne w singlu. Wylaczaj, bo spalasz energie.")
      score = utils.Clamp(score - 4, 0, 100)
    end
    AddMetric(
      "Blade Flurry uptime (ST)",
      SPELL_BLADE_FLURRY,
      utils.FormatPercent(bladeFlurryUptime),
      bladeFlurryUptime,
      "info",
      nil,
      0
    )
  end

  local ruptureUptime = utils.SafePercent(fight.debuffUptime[SPELL_RUPTURE] or 0, context.duration)
  AddMetric(
    "Rupture uptime",
    SPELL_RUPTURE,
    utils.FormatPercent(ruptureUptime),
    ruptureUptime,
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
