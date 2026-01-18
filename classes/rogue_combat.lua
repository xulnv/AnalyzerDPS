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
  if spellId == SPELL_DEEP_INSIGHT then
    return {
      soundKey = SOUND_KEY_DEEP_INSIGHT,
      priority = 3,
    }
  elseif spellId == SPELL_ADRENALINE_RUSH then
    return {
      soundKey = SOUND_KEY_ADRENALINE_RUSH,
      priority = 2,
    }
  elseif spellId == SPELL_KILLING_SPREE then
    return {
      soundKey = SOUND_KEY_KILLING_SPREE,
      priority = 2,
    }
  end
  return nil
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
  fight.rotation = {totalCasts=0,optimalCasts=0,suboptimalCasts=0,mistakes={},penaltySum=0}
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
  local cS={[SPELL_SINISTER_STRIKE]=true,[SPELL_REVEALING_STRIKE]=true,[SPELL_EVISCERATE]=true,[SPELL_SLICE_AND_DICE]=true,[SPELL_RUPTURE]=true}
  if cS[spellId] and fight.rotation then local ev=module.EvaluateCast(analyzer,fight,spellId,now)if ev then module.RecordCastEvaluation(fight,ev,now)end end
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

function module.Analyze(analyzer, fight, context)
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

  if fight.rotation and fight.rotation.totalCasts>0 then local rS=module.GetRotationScore(fight)if rS then local rA=rS.accuracy or 0 local rSt=utils.StatusForPercent(rA,0.85,0.70)AddMetric("Dokladnosc rotacji (APL)",nil,string.format("%.0f%% (%d/%d)",rA*100,rS.optimalCasts,rS.totalCasts),rA,rSt,rSt=="bad"and"Niska dokladnosc."or(rSt=="warn"and"Srednia dokladnosc."or nil),rSt=="bad"and 10 or(rSt=="warn"and 5 or 0))if rS.mistakes and #rS.mistakes>0 then local mC={}for _,mk in ipairs(rS.mistakes)do mC[mk.reason or"Unknown"]=(mC[mk.reason or"Unknown"]or 0)+1 end local sM={}for r,ct in pairs(mC)do table.insert(sM,{reason=r,count=ct})end table.sort(sM,function(x,y)return x.count>y.count end)for j=1,math.min(3,#sM)do local mk=sM[j]if mk.count>=2 then utils.AddIssue(issues,string.format("Blad rotacji (%dx): %s",mk.count,mk.reason))end end end end end

  score = utils.Clamp(score, 0, 100)

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

  -- Simple score based on active buffs/debuffs
  local hasRevealingStrike = false
  for guid, debuff in pairs(fight.debuffs or {}) do
    if debuff[SPELL_REVEALING_STRIKE] and debuff[SPELL_REVEALING_STRIKE].active then
      hasRevealingStrike = true
      break
    end
  end

  if not hasRevealingStrike then
    score = score - 20
  end

  local hasSliceAndDice = false
  if fight.buffs and fight.buffs[SPELL_SLICE_AND_DICE] and fight.buffs[SPELL_SLICE_AND_DICE].active then
    hasSliceAndDice = true
  end

  if not hasSliceAndDice then
    score = score - 20
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

  local hasDeepInsight = CheckPlayerBuff(SPELL_DEEP_INSIGHT)
  if hasDeepInsight then
    return "Deep Insight! Burst teraz!"
  end

  local hasSliceAndDice = CheckPlayerBuff(SPELL_SLICE_AND_DICE)
  if not hasSliceAndDice and duration > 3 then
    return "Odswiez Slice and Dice!"
  end

  if UnitExists("target") then
    local hasRevealingStrike = CheckTargetDebuff(SPELL_REVEALING_STRIKE)
    if not hasRevealingStrike and duration > 2 then
      return "Naloz Revealing Strike!"
    end

    local hasRupture = CheckTargetDebuff(SPELL_RUPTURE)
    if not hasRupture and duration > 10 then
      return "Naloz Rupture!"
    end
  end

  if utils.IsSpellReady(SPELL_ADRENALINE_RUSH) and duration > 15 then
    return "Adrenaline Rush gotowe!"
  end

  if utils.IsSpellReady(SPELL_KILLING_SPREE) and duration > 15 then
    return "Killing Spree gotowe!"
  end

  if utils.IsSpellReady(SPELL_SHADOW_BLADES) and duration > 10 then
    return "Shadow Blades gotowe!"
  end

  return ""
end

function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasDeepInsight = CheckPlayerBuff(SPELL_DEEP_INSIGHT)
  if hasDeepInsight then
    return SPELL_SINISTER_STRIKE
  end

  local hasSliceAndDice = CheckPlayerBuff(SPELL_SLICE_AND_DICE)
  if not hasSliceAndDice and duration > 3 then
    return SPELL_SLICE_AND_DICE
  end

  if UnitExists("target") then
    local hasRevealingStrike = CheckTargetDebuff(SPELL_REVEALING_STRIKE)
    if not hasRevealingStrike and duration > 2 then
      return SPELL_REVEALING_STRIKE
    end

    local hasRupture = CheckTargetDebuff(SPELL_RUPTURE)
    if not hasRupture and duration > 10 then
      return SPELL_RUPTURE
    end
  end

  if utils.IsSpellReady(SPELL_ADRENALINE_RUSH) and duration > 15 then
    return SPELL_ADRENALINE_RUSH
  end

  if utils.IsSpellReady(SPELL_KILLING_SPREE) and duration > 15 then
    return SPELL_KILLING_SPREE
  end

  if utils.IsSpellReady(SPELL_SHADOW_BLADES) and duration > 10 then
    return SPELL_SHADOW_BLADES
  end

  return nil
end

local APL_PRIORITY={{id="snd_m",spellId=SPELL_SLICE_AND_DICE,name="SnD",condition=function(s)return s.cp>=1 and s.sndMissing and s.duration>3 end,priority=1,category="buff"},{id="rs_m",spellId=SPELL_REVEALING_STRIKE,name="Revealing Strike",condition=function(s)return s.rsMissing and s.duration>2 end,priority=2,category="debuff"},{id="rup_m",spellId=SPELL_RUPTURE,name="Rupture",condition=function(s)return s.cp>=5 and s.rupMissing and s.duration>10 end,priority=3,category="finisher"},{id="evis_5cp",spellId=SPELL_EVISCERATE,name="Eviscerate(5CP)",condition=function(s)return s.cp>=5 and s.deepInsight end,priority=4,category="finisher"},{id="evis",spellId=SPELL_EVISCERATE,name="Eviscerate",condition=function(s)return s.cp>=5 end,priority=5,category="finisher"},{id="rs_r",spellId=SPELL_REVEALING_STRIKE,name="RS(refresh)",condition=function(s)return s.rsExpiring end,priority=6,category="debuff"},{id="ss",spellId=SPELL_SINISTER_STRIKE,name="Sinister Strike",condition=function(s)return true end,priority=7,category="builder"}}
local function GCS(a,f)local s={duration=0,cp=0,sndMissing=false,rsMissing=false,rsExpiring=false,rupMissing=false,deepInsight=false}if not f then return s end local n=GetTime()s.duration=n-(f.startTime or n)if UnitPower then s.cp=UnitPower("player",4)end s.sndMissing=not CheckPlayerBuff(SPELL_SLICE_AND_DICE)s.deepInsight=CheckPlayerBuff(SPELL_DEEP_INSIGHT)if UnitExists("target")and s.duration>2 then local hasRS,rsR=CheckTargetDebuff(SPELL_REVEALING_STRIKE)local hasRup=CheckTargetDebuff(SPELL_RUPTURE)s.rsMissing=not hasRS s.rsExpiring=hasRS and rsR>0 and rsR<4 s.rupMissing=not hasRup end return s end
function module.GetNextAPLAction(a,f)local s=GCS(a,f)for _,act in ipairs(APL_PRIORITY)do if act.condition(s)then return act end end return APL_PRIORITY[#APL_PRIORITY]end
function module.GetAPLPriorityList()return APL_PRIORITY end
function module.GetRotationState(a,f)return GCS(a,f)end
function module.EvaluateCast(a,f,sid,ts)local nA=module.GetNextAPLAction(a,f)if not nA then return nil end local isO=(nA.spellId==sid)local pen=0 local rsn=""if not isO then local cP=nil for _,act in ipairs(APL_PRIORITY)do if act.spellId==sid then cP=act.priority break end end if cP then pen=math.abs(nA.priority-cP)*2 rsn=string.format("Powinienes: %s",nA.name)else pen=5 rsn="Spell poza APL"end end return{isOptimal=isO,penalty=pen,reason=rsn,expectedSpell=nA.spellId,expectedName=nA.name,actualSpell=sid}end
function module.RecordCastEvaluation(f,ev,ts)if not f.rotation then return end f.rotation.totalCasts=f.rotation.totalCasts+1 if ev.isOptimal then f.rotation.optimalCasts=f.rotation.optimalCasts+1 else f.rotation.suboptimalCasts=f.rotation.suboptimalCasts+1 f.rotation.penaltySum=f.rotation.penaltySum+ev.penalty table.insert(f.rotation.mistakes,{timestamp=ts,reason=ev.reason,penalty=ev.penalty,expected=ev.expectedName})end end
function module.GetRotationScore(f)if not f.rotation or f.rotation.totalCasts==0 then return nil end return{accuracy=f.rotation.optimalCasts/f.rotation.totalCasts,totalCasts=f.rotation.totalCasts,optimalCasts=f.rotation.optimalCasts,suboptimalCasts=f.rotation.suboptimalCasts,mistakes=f.rotation.mistakes,penaltySum=f.rotation.penaltySum}end

Analyzer:RegisterClassModule(module.class, module)
