local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Warlock - Demonology"
module.class = "WARLOCK"
module.specKey = "demonology"
module.specIndex = 2
module.specId = 266

local SPELL_CORRUPTION = 172
local SPELL_DOOM = 603
local SPELL_METAMORPHOSIS = 103958
local SPELL_TOUCH_OF_CHAOS = 103964
local SPELL_SOUL_FIRE = 6353
local SPELL_MOLTEN_CORE = 122355
local SPELL_HAND_OF_GULDAN = 105174
local SPELL_DARK_SOUL_KNOWLEDGE = 113861
local SPELL_FEL_FLAME = 77799
local SPELL_SHADOW_BOLT = 686
local SPELL_LIFE_TAP = 1454

local COOLDOWN_DARK_SOUL = 120
local COOLDOWN_HAND_OF_GULDAN = 12

local SOUND_KEY_MOLTEN_CORE = "moltenCore"
local SOUND_KEY_DARK_SOUL = "darkSoul"
local SOUND_KEY_META_READY = "metaReady"

local TRACKED_BUFFS = {
  [SPELL_MOLTEN_CORE] = true,
  [SPELL_METAMORPHOSIS] = true,
  [SPELL_DARK_SOUL_KNOWLEDGE] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_CORRUPTION] = true,
  [SPELL_DOOM] = true,
}

local TRACKED_CASTS = {
  [SPELL_CORRUPTION] = true,
  [SPELL_DOOM] = true,
  [SPELL_METAMORPHOSIS] = true,
  [SPELL_TOUCH_OF_CHAOS] = true,
  [SPELL_SOUL_FIRE] = true,
  [SPELL_HAND_OF_GULDAN] = true,
  [SPELL_DARK_SOUL_KNOWLEDGE] = true,
  [SPELL_FEL_FLAME] = true,
  [SPELL_SHADOW_BOLT] = true,
}

local function EnsureHistory(container, spellId)
  container[spellId] = container[spellId] or {}
  return container[spellId]
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
  if IsSpellKnown and IsSpellKnown(SPELL_METAMORPHOSIS) then
    analyzer.player.specName = "Demonology"
    analyzer.player.specId = analyzer.player.specId or module.specId
    analyzer.player.specIndex = analyzer.player.specIndex or module.specIndex
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_MOLTEN_CORE] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_DARK_SOUL] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
      [SOUND_KEY_META_READY] = { enabled = true, sound = "Sound\\Interface\\AlarmClockWarning3.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_MOLTEN_CORE, label = "Molten Core Proc" },
    { key = SOUND_KEY_DARK_SOUL, label = "Dark Soul Ready" },
    { key = SOUND_KEY_META_READY, label = "Metamorphosis Ready" },
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
  if spellId == SPELL_MOLTEN_CORE then
    return {
      soundKey = SOUND_KEY_MOLTEN_CORE,
      priority = 3,
    }
  elseif spellId == SPELL_DARK_SOUL_KNOWLEDGE then
    return {
      soundKey = SOUND_KEY_DARK_SOUL,
      priority = 2,
    }
  end
  return nil
end

function module.InitFight(_, fight)
  fight.counts = {
    touchOfChaosTotal = 0,
    soulFireTotal = 0,
    soulFireWithMC = 0,
    moltenCoreWasted = 0,
    metaUsages = 0,
  }
  fight.cooldowns = {
    darkSoulLast = 0,
    handOfGuldanLast = 0,
  }
  fight.castLog = {}
  fight.buffHistory = {}
  fight.rotation = {totalCasts=0,optimalCasts=0,suboptimalCasts=0,mistakes={},penaltySum=0}
  fight.debuffHistory = {}
  fight.demonicFuryWaste = 0
end

function module.TrackSpellCast(analyzer, spellId, timestamp)
  local fight = analyzer.fight
  if not fight or not TRACKED_CASTS[spellId] then
    return
  end

  local now = utils.NormalizeTimestamp(timestamp)
  fight.spells[spellId] = (fight.spells[spellId] or 0) + 1
  table.insert(fight.castLog, { spellId = spellId, timestamp = now })

  if spellId == SPELL_TOUCH_OF_CHAOS then
    fight.counts.touchOfChaosTotal = fight.counts.touchOfChaosTotal + 1
  elseif spellId == SPELL_SOUL_FIRE then
    fight.counts.soulFireTotal = fight.counts.soulFireTotal + 1
    local hasMC = fight.buffs[SPELL_MOLTEN_CORE] ~= nil
    if hasMC then
      fight.counts.soulFireWithMC = fight.counts.soulFireWithMC + 1
    end
  elseif spellId == SPELL_METAMORPHOSIS then
    fight.counts.metaUsages = fight.counts.metaUsages + 1
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Metamorphosis", spellId)
  elseif spellId == SPELL_DARK_SOUL_KNOWLEDGE then
    fight.cooldowns.darkSoulLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Dark Soul: Knowledge", spellId)
  elseif spellId == SPELL_HAND_OF_GULDAN then
    fight.cooldowns.handOfGuldanLast = now
    analyzer:AddEventLog(now, "Hand of Gul'dan", spellId)
  elseif spellId == SPELL_DOOM then
    analyzer:AddEventLog(now, "Doom", spellId)
  end
  local cS={[SPELL_CORRUPTION]=true,[SPELL_DOOM]=true,[SPELL_SOUL_FIRE]=true,[SPELL_SHADOW_BOLT]=true,[SPELL_HAND_OF_GULDAN]=true}
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

    if spellId == SPELL_MOLTEN_CORE then
      analyzer:PlayAlertSound(SOUND_KEY_MOLTEN_CORE, now)
      analyzer:AddEventLog(now, "Molten Core Proc!", spellId)
    elseif spellId == SPELL_DARK_SOUL_KNOWLEDGE then
      analyzer:PlayAlertSound(SOUND_KEY_DARK_SOUL, now)
    elseif spellId == SPELL_METAMORPHOSIS then
      analyzer:AddEventLog(now, "Metamorphosis Active", spellId)
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

      if spellId == SPELL_MOLTEN_CORE then
        local soulFireCast = false
        for i = #fight.castLog, 1, -1 do
          local cast = fight.castLog[i]
          if cast.timestamp >= buff.since and cast.timestamp <= now then
            if cast.spellId == SPELL_SOUL_FIRE then
              soulFireCast = true
              break
            end
          end
          if cast.timestamp < buff.since then
            break
          end
        end
        if not soulFireCast then
          fight.counts.moltenCoreWasted = fight.counts.moltenCoreWasted + 1
        end
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

  local doomUptime = utils.SafePercent(fight.debuffUptime[SPELL_DOOM] or 0, context.duration)
  local doomStatus = utils.StatusForPercent(doomUptime, 0.95, 0.85)
  AddMetric(
    "Doom uptime",
    SPELL_DOOM,
    utils.FormatPercent(doomUptime),
    doomUptime,
    doomStatus,
    doomStatus == "bad" and "Za niski uptime Doom. Utrzymuj debuff caly czas (>95%)."
      or (doomStatus == "warn" and "Doom uptime moglby byc wyzszy." or nil),
    doomStatus == "bad" and 20 or (doomStatus == "warn" and 10 or 0)
  )

  local corruptionUptime = utils.SafePercent(fight.debuffUptime[SPELL_CORRUPTION] or 0, context.duration)
  local corruptionStatus = utils.StatusForPercent(corruptionUptime, 0.90, 0.75)
  AddMetric(
    "Corruption uptime",
    SPELL_CORRUPTION,
    utils.FormatPercent(corruptionUptime),
    corruptionUptime,
    corruptionStatus,
    corruptionStatus == "bad" and "Za niski uptime Corruption. Utrzymuj debuff (>90%)."
      or (corruptionStatus == "warn" and "Corruption uptime moglby byc wyzszy." or nil),
    corruptionStatus == "bad" and 15 or (corruptionStatus == "warn" and 8 or 0)
  )

  local metaUptime = utils.SafePercent(fight.buffUptime[SPELL_METAMORPHOSIS] or 0, context.duration)
  local metaStatus = utils.StatusForPercent(metaUptime, 0.50, 0.35)
  AddMetric(
    "Metamorphosis uptime",
    SPELL_METAMORPHOSIS,
    utils.FormatPercent(metaUptime),
    metaUptime,
    metaStatus,
    metaStatus == "bad" and "Za niski uptime Meta. Wchodz w Meta przy 900+ Demonic Fury."
      or (metaStatus == "warn" and "Meta uptime moglby byc wyzszy." or nil),
    metaStatus == "bad" and 15 or (metaStatus == "warn" and 8 or 0)
  )

  local soulFireTotal = fight.counts.soulFireTotal or 0
  local soulFireWithMC = fight.counts.soulFireWithMC or 0
  if soulFireTotal > 0 then
    local mcUsage = utils.SafePercent(soulFireWithMC, soulFireTotal)
    local mcStatus = utils.StatusForPercent(mcUsage, 0.85, 0.65)
    AddMetric(
      "Molten Core usage",
      SPELL_MOLTEN_CORE,
      string.format("%d/%d Soul Fire z MC (%.0f%%)", soulFireWithMC, soulFireTotal, (mcUsage or 0) * 100),
      math.min(mcUsage or 0, 1),
      mcStatus,
      mcStatus == "bad" and "Za malo Soul Fire z Molten Core! Nie marnuj procow."
        or (mcStatus == "warn" and "Uzywaj Soul Fire TYLKO z Molten Core." or nil),
      mcStatus == "bad" and 15 or (mcStatus == "warn" and 8 or 0)
    )
  end

  local moltenCoreWasted = fight.counts.moltenCoreWasted or 0
  if moltenCoreWasted > 2 then
    AddMetric(
      "Molten Core zmarnowane",
      SPELL_MOLTEN_CORE,
      string.format("%d procow", moltenCoreWasted),
      0,
      "bad",
      "Zmarnowales Molten Core procy! Zawsze uzywaj Soul Fire z MC.",
      moltenCoreWasted * 3
    )
  end

  local darkSoul = fight.spells[SPELL_DARK_SOUL_KNOWLEDGE] or 0
  local expectedDS = utils.ExpectedUses(context.duration, COOLDOWN_DARK_SOUL, 10)
  if expectedDS > 0 then
    local dsPercent = utils.SafePercent(darkSoul, expectedDS)
    local dsStatus = utils.StatusForPercent(dsPercent, 1.0, 0.7)
    AddMetric(
      "Dark Soul uzycia",
      SPELL_DARK_SOUL_KNOWLEDGE,
      string.format("%d/%d", darkSoul, expectedDS),
      math.min(dsPercent or 0, 1),
      dsStatus,
      darkSoul < expectedDS and "Za malo Dark Soul. Uzywaj na cooldown." or nil,
      darkSoul < expectedDS and 10 or 0
    )
  end

  local totalCasts = (fight.counts.touchOfChaosTotal or 0) + (fight.counts.soulFireTotal or 0)
    + (fight.spells[SPELL_CORRUPTION] or 0) + (fight.spells[SPELL_DOOM] or 0)
    + (fight.spells[SPELL_SHADOW_BOLT] or 0) + (fight.spells[SPELL_FEL_FLAME] or 0)
    + (fight.spells[SPELL_HAND_OF_GULDAN] or 0)
  local avgCastTime = 1.8
  local expectedCasts = math.floor(context.duration / avgCastTime)
  if expectedCasts > 0 then
    local castEfficiency = utils.SafePercent(totalCasts, expectedCasts)
    local castStatus = utils.StatusForPercent(castEfficiency, 0.75, 0.60)
    AddMetric(
      "Efektywnosc castowania",
      nil,
      string.format("%d/%d castow (%.0f%%)", totalCasts, expectedCasts, (castEfficiency or 0) * 100),
      math.min(castEfficiency or 0, 1),
      castStatus,
      castStatus == "bad" and "Za malo castow. Minimalizuj downtime."
        or (castStatus == "warn" and "Srednia efektywnosc. Staraj sie minimalizowac przerwy w DPS." or nil),
      castStatus == "bad" and 12 or (castStatus == "warn" and 6 or 0)
    )
  end

  local touchOfChaos = fight.counts.touchOfChaosTotal or 0
  if metaUptime > 0.1 then
    AddMetric(
      "Touch of Chaos casts",
      SPELL_TOUCH_OF_CHAOS,
      string.format("%d castow", touchOfChaos),
      math.min((touchOfChaos / 10), 1),
      touchOfChaos > 5 and "good" or (touchOfChaos > 2 and "warn" or "bad"),
      touchOfChaos < 3 and "Za malo Touch of Chaos. W Meta spamuj Touch of Chaos!" or nil,
      touchOfChaos < 3 and 10 or 0
    )
  end

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

  local doomUptime = utils.SafePercent(fight.debuffUptime[SPELL_DOOM] or 0, duration)
  if doomUptime < 0.85 then
    score = score - 25
  end

  local corruptionUptime = utils.SafePercent(fight.debuffUptime[SPELL_CORRUPTION] or 0, duration)
  if corruptionUptime < 0.75 then
    score = score - 15
  end

  local moltenCoreWasted = fight.counts.moltenCoreWasted or 0
  if moltenCoreWasted > 2 then
    score = score - (moltenCoreWasted * 5)
  end

  return utils.Clamp(score, 0, 100)
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
  if not spellId or not UnitExists("target") then return false, 0 end
  for i = 1, 40 do
    local name, _, _, _, _, expirationTime, _, caster, _, _, auraSpellId = UnitDebuff("target", i)
    if not name then break end
    if auraSpellId == spellId and caster == "player" then
      local remaining = expirationTime and (expirationTime - GetTime()) or 0
      return true, remaining
    end
  end
  return false, 0
end

function module.GetLiveAdvice(analyzer, fight)
  if not fight then
    return ""
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasMC = CheckPlayerBuff(SPELL_MOLTEN_CORE)
  if hasMC then
    return "MC! Soul Fire!"
  end

  if UnitExists("target") then
    local hasDoom, doomRemaining = CheckTargetDebuff(SPELL_DOOM)
    if not hasDoom and duration > 2 then
      return "Naloz Doom!"
    elseif hasDoom and doomRemaining > 0 and doomRemaining < 5 then
      return "Doom wygasa! Odswiez!"
    end

    local hasCorruption, corruptionRemaining = CheckTargetDebuff(SPELL_CORRUPTION)
    if not hasCorruption and duration > 3 then
      return "Naloz Corruption!"
    elseif hasCorruption and corruptionRemaining > 0 and corruptionRemaining < 4 then
      return "Corruption wygasa! Odswiez!"
    end
  end

  if utils.IsSpellReady(SPELL_DARK_SOUL_KNOWLEDGE) and duration > 10 then
    return "Dark Soul gotowe!"
  end

  return ""
end

function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasMC = CheckPlayerBuff(SPELL_MOLTEN_CORE)
  if hasMC then
    return SPELL_SOUL_FIRE
  end

  if UnitExists("target") then
    local hasDoom, doomRemaining = CheckTargetDebuff(SPELL_DOOM)
    if not hasDoom and duration > 2 then
      return SPELL_DOOM
    elseif hasDoom and doomRemaining > 0 and doomRemaining < 5 then
      return SPELL_DOOM
    end

    local hasCorruption, corruptionRemaining = CheckTargetDebuff(SPELL_CORRUPTION)
    if not hasCorruption and duration > 3 then
      return SPELL_CORRUPTION
    elseif hasCorruption and corruptionRemaining > 0 and corruptionRemaining < 4 then
      return SPELL_CORRUPTION
    end
  end

  if utils.IsSpellReady(SPELL_DARK_SOUL_KNOWLEDGE) and duration > 10 then
    return SPELL_DARK_SOUL_KNOWLEDGE
  end

  return nil
end

local APL_PRIORITY={{id="ds",spellId=SPELL_DARK_SOUL_KNOWLEDGE,name="Dark Soul",condition=function(s)return s.dsReady and s.duration>10 end,priority=1,category="cooldown"},{id="doom_m",spellId=SPELL_DOOM,name="Doom",condition=function(s)return s.doomMissing and s.duration>2 end,priority=2,category="dot"},{id="sf_mc",spellId=SPELL_SOUL_FIRE,name="Soul Fire(MC)",condition=function(s)return s.moltenCoreActive end,priority=3,category="proc"},{id="corr_m",spellId=SPELL_CORRUPTION,name="Corruption",condition=function(s)return s.corrMissing and s.duration>3 end,priority=4,category="dot"},{id="hog",spellId=SPELL_HAND_OF_GULDAN,name="Hand of Guldan",condition=function(s)return s.hogReady end,priority=5,category="damage"},{id="doom_r",spellId=SPELL_DOOM,name="Doom(r)",condition=function(s)return s.doomExpiring end,priority=6,category="dot"},{id="corr_r",spellId=SPELL_CORRUPTION,name="Corruption(r)",condition=function(s)return s.corrExpiring end,priority=7,category="dot"},{id="sb",spellId=SPELL_SHADOW_BOLT,name="Shadow Bolt",condition=function(s)return true end,priority=8,category="filler"}}
local function GCS(a,f)local s={duration=0,moltenCoreActive=false,doomMissing=false,doomExpiring=false,corrMissing=false,corrExpiring=false,hogReady=false,dsReady=false}if not f then return s end local n=GetTime()s.duration=n-(f.startTime or n)s.moltenCoreActive=CheckPlayerBuff(SPELL_MOLTEN_CORE)s.hogReady=utils.IsSpellReady(SPELL_HAND_OF_GULDAN)s.dsReady=utils.IsSpellReady(SPELL_DARK_SOUL_KNOWLEDGE)if UnitExists("target")and s.duration>2 then local hasDoom,doomR=CheckTargetDebuff(SPELL_DOOM)local hasCorr,corrR=CheckTargetDebuff(SPELL_CORRUPTION)s.doomMissing=not hasDoom s.doomExpiring=hasDoom and doomR>0 and doomR<5 s.corrMissing=not hasCorr s.corrExpiring=hasCorr and corrR>0 and corrR<4 end return s end
function module.GetNextAPLAction(a,f)local s=GCS(a,f)for _,act in ipairs(APL_PRIORITY)do if act.condition(s)then return act end end return APL_PRIORITY[#APL_PRIORITY]end
function module.GetAPLPriorityList()return APL_PRIORITY end
function module.GetRotationState(a,f)return GCS(a,f)end
function module.EvaluateCast(a,f,sid,ts)local nA=module.GetNextAPLAction(a,f)if not nA then return nil end local isO=(nA.spellId==sid)local pen=0 local rsn=""if not isO then local cP=nil for _,act in ipairs(APL_PRIORITY)do if act.spellId==sid then cP=act.priority break end end if cP then pen=math.abs(nA.priority-cP)*2 rsn=string.format("Powinienes: %s",nA.name)else pen=5 rsn="Spell poza APL"end end return{isOptimal=isO,penalty=pen,reason=rsn,expectedSpell=nA.spellId,expectedName=nA.name,actualSpell=sid}end
function module.RecordCastEvaluation(f,ev,ts)if not f.rotation then return end f.rotation.totalCasts=f.rotation.totalCasts+1 if ev.isOptimal then f.rotation.optimalCasts=f.rotation.optimalCasts+1 else f.rotation.suboptimalCasts=f.rotation.suboptimalCasts+1 f.rotation.penaltySum=f.rotation.penaltySum+ev.penalty table.insert(f.rotation.mistakes,{timestamp=ts,reason=ev.reason,penalty=ev.penalty,expected=ev.expectedName})end end
function module.GetRotationScore(f)if not f.rotation or f.rotation.totalCasts==0 then return nil end return{accuracy=f.rotation.optimalCasts/f.rotation.totalCasts,totalCasts=f.rotation.totalCasts,optimalCasts=f.rotation.optimalCasts,suboptimalCasts=f.rotation.suboptimalCasts,mistakes=f.rotation.mistakes,penaltySum=f.rotation.penaltySum}end

Analyzer:RegisterClassModule(module.class, module)
