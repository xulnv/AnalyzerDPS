local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Warlock - Affliction"
module.class = "WARLOCK"
module.specKey = "affliction"
module.specIndex = 1
module.specId = 265

local SPELL_AGONY = 980
local SPELL_CORRUPTION = 172
local SPELL_UNSTABLE_AFFLICTION = 30108
local SPELL_HAUNT = 48181
local SPELL_MALEFIC_GRASP = 103103
local SPELL_DRAIN_SOUL = 1120
local SPELL_DARK_SOUL_MISERY = 113860
local SPELL_SUMMON_DOOMGUARD = 18540
local SPELL_SUMMON_TERRORGUARD = 157757
local SPELL_SOUL_SWAP = 86121
local SPELL_LIFE_TAP = 1454
local SPELL_NIGHTFALL = 108558

local COOLDOWN_DARK_SOUL = 120
local COOLDOWN_DOOMGUARD = 600

local SOUND_KEY_NIGHTFALL = "nightfall"
local SOUND_KEY_DARK_SOUL = "darkSoul"

local TRACKED_BUFFS = {
  [SPELL_DARK_SOUL_MISERY] = true,
  [SPELL_NIGHTFALL] = true,
  [SPELL_HAUNT] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_AGONY] = true,
  [SPELL_CORRUPTION] = true,
  [SPELL_UNSTABLE_AFFLICTION] = true,
  [SPELL_HAUNT] = true,
}

local TRACKED_CASTS = {
  [SPELL_AGONY] = true,
  [SPELL_CORRUPTION] = true,
  [SPELL_UNSTABLE_AFFLICTION] = true,
  [SPELL_HAUNT] = true,
  [SPELL_MALEFIC_GRASP] = true,
  [SPELL_DRAIN_SOUL] = true,
  [SPELL_DARK_SOUL_MISERY] = true,
  [SPELL_SUMMON_DOOMGUARD] = true,
  [SPELL_SOUL_SWAP] = true,
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
  if IsSpellKnown and IsSpellKnown(SPELL_MALEFIC_GRASP) then
    analyzer.player.specName = "Affliction"
    analyzer.player.specId = analyzer.player.specId or module.specId
    analyzer.player.specIndex = analyzer.player.specIndex or module.specIndex
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_NIGHTFALL] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_DARK_SOUL] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_NIGHTFALL, label = "Nightfall Proc" },
    { key = SOUND_KEY_DARK_SOUL, label = "Dark Soul Ready" },
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
  if spellId == SPELL_NIGHTFALL then
    return {
      soundKey = SOUND_KEY_NIGHTFALL,
      priority = 3,
    }
  elseif spellId == SPELL_DARK_SOUL_MISERY then
    return {
      soundKey = SOUND_KEY_DARK_SOUL,
      priority = 2,
    }
  end
  return nil
end

function module.InitFight(_, fight)
  fight.counts = {
    maleficGraspTotal = 0,
    drainSoulTotal = 0,
  }
  fight.cooldowns = {
    darkSoulLast = 0,
    doomguardLast = 0,
  }
  fight.castLog = {}
  fight.buffHistory = {}
  fight.debuffHistory = {}
  fight.rotation = {
    totalCasts = 0,
    optimalCasts = 0,
    suboptimalCasts = 0,
    mistakes = {},
    penaltySum = 0,
  }
end

function module.TrackSpellCast(analyzer, spellId, timestamp)
  local fight = analyzer.fight
  if not fight or not TRACKED_CASTS[spellId] then
    return
  end

  local now = utils.NormalizeTimestamp(timestamp)
  fight.spells[spellId] = (fight.spells[spellId] or 0) + 1
  table.insert(fight.castLog, { spellId = spellId, timestamp = now })

  if spellId == SPELL_MALEFIC_GRASP then
    fight.counts.maleficGraspTotal = fight.counts.maleficGraspTotal + 1
  elseif spellId == SPELL_DRAIN_SOUL then
    fight.counts.drainSoulTotal = fight.counts.drainSoulTotal + 1
  elseif spellId == SPELL_DARK_SOUL_MISERY then
    fight.cooldowns.darkSoulLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Dark Soul: Misery", spellId)
  elseif spellId == SPELL_SUMMON_DOOMGUARD then
    fight.cooldowns.doomguardLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Summon Doomguard", spellId)
  elseif spellId == SPELL_HAUNT then
    analyzer:AddEventLog(now, "Haunt", spellId)
  end
  
  local coreSpells = {[SPELL_AGONY]=true,[SPELL_CORRUPTION]=true,[SPELL_UNSTABLE_AFFLICTION]=true,[SPELL_HAUNT]=true,[SPELL_MALEFIC_GRASP]=true,[SPELL_DRAIN_SOUL]=true}
  if coreSpells[spellId] and fight.rotation then
    local evaluation = module.EvaluateCast(analyzer, fight, spellId, now)
    if evaluation then module.RecordCastEvaluation(fight, evaluation, now) end
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

    if spellId == SPELL_NIGHTFALL then
      analyzer:PlayAlertSound(SOUND_KEY_NIGHTFALL, now)
      analyzer:AddEventLog(now, "Nightfall Proc!", spellId)
    elseif spellId == SPELL_DARK_SOUL_MISERY then
      analyzer:PlayAlertSound(SOUND_KEY_DARK_SOUL, now)
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

  local agonyUptime = utils.SafePercent(fight.debuffUptime[SPELL_AGONY] or 0, context.duration)
  local agonyStatus = utils.StatusForPercent(agonyUptime, 0.95, 0.85)
  AddMetric(
    "Agony uptime",
    SPELL_AGONY,
    utils.FormatPercent(agonyUptime),
    agonyUptime,
    agonyStatus,
    agonyStatus == "bad" and "Za niski uptime Agony. Utrzymuj debuff caly czas."
      or (agonyStatus == "warn" and "Agony uptime moglby byc wyzszy." or nil),
    agonyStatus == "bad" and 15 or (agonyStatus == "warn" and 8 or 0)
  )

  local corruptionUptime = utils.SafePercent(fight.debuffUptime[SPELL_CORRUPTION] or 0, context.duration)
  local corruptionStatus = utils.StatusForPercent(corruptionUptime, 0.95, 0.85)
  AddMetric(
    "Corruption uptime",
    SPELL_CORRUPTION,
    utils.FormatPercent(corruptionUptime),
    corruptionUptime,
    corruptionStatus,
    corruptionStatus == "bad" and "Za niski uptime Corruption. Utrzymuj debuff caly czas."
      or (corruptionStatus == "warn" and "Corruption uptime moglby byc wyzszy." or nil),
    corruptionStatus == "bad" and 15 or (corruptionStatus == "warn" and 8 or 0)
  )

  local uaUptime = utils.SafePercent(fight.debuffUptime[SPELL_UNSTABLE_AFFLICTION] or 0, context.duration)
  local uaStatus = utils.StatusForPercent(uaUptime, 0.95, 0.85)
  AddMetric(
    "Unstable Affliction uptime",
    SPELL_UNSTABLE_AFFLICTION,
    utils.FormatPercent(uaUptime),
    uaUptime,
    uaStatus,
    uaStatus == "bad" and "Za niski uptime UA. Utrzymuj debuff caly czas."
      or (uaStatus == "warn" and "UA uptime moglby byc wyzszy." or nil),
    uaStatus == "bad" and 15 or (uaStatus == "warn" and 8 or 0)
  )

  local hauntUptime = utils.SafePercent(fight.debuffUptime[SPELL_HAUNT] or 0, context.duration)
  if (fight.spells[SPELL_HAUNT] or 0) > 0 then
    local hauntStatus = utils.StatusForPercent(hauntUptime, 0.90, 0.75)
    AddMetric(
      "Haunt uptime",
      SPELL_HAUNT,
      utils.FormatPercent(hauntUptime),
      hauntUptime,
      hauntStatus,
      hauntStatus == "bad" and "Za niski uptime Haunt. Uzywaj na cooldown."
        or (hauntStatus == "warn" and "Haunt uptime moglby byc wyzszy." or nil),
      hauntStatus == "bad" and 10 or (hauntStatus == "warn" and 5 or 0)
    )
  end

  local darkSoul = fight.spells[SPELL_DARK_SOUL_MISERY] or 0
  local expectedDS = utils.ExpectedUses(context.duration, COOLDOWN_DARK_SOUL, 10)
  if expectedDS > 0 then
    local dsPercent = utils.SafePercent(darkSoul, expectedDS)
    local dsStatus = utils.StatusForPercent(dsPercent, 1.0, 0.7)
    AddMetric(
      "Dark Soul uzycia",
      SPELL_DARK_SOUL_MISERY,
      string.format("%d/%d", darkSoul, expectedDS),
      math.min(dsPercent or 0, 1),
      dsStatus,
      darkSoul < expectedDS and "Za malo Dark Soul. Uzywaj na cooldown." or nil,
      darkSoul < expectedDS and 8 or 0
    )
  end

  local totalCasts = (fight.counts.maleficGraspTotal or 0) + (fight.counts.drainSoulTotal or 0)
    + (fight.spells[SPELL_AGONY] or 0) + (fight.spells[SPELL_CORRUPTION] or 0)
    + (fight.spells[SPELL_UNSTABLE_AFFLICTION] or 0) + (fight.spells[SPELL_HAUNT] or 0)
  local avgCastTime = 1.5
  local expectedCasts = math.floor(context.duration / avgCastTime)
  if expectedCasts > 0 then
    local castEfficiency = utils.SafePercent(totalCasts, expectedCasts)
    local castStatus = utils.StatusForPercent(castEfficiency, 0.80, 0.65)
    AddMetric(
      "Efektywnosc castowania",
      nil,
      string.format("%d/%d castow (%.0f%%)", totalCasts, expectedCasts, (castEfficiency or 0) * 100),
      math.min(castEfficiency or 0, 1),
      castStatus,
      castStatus == "bad" and "Za malo castow. Minimalizuj downtime - caly czas channeluj Malefic Grasp."
        or (castStatus == "warn" and "Srednia efektywnosc. Staraj sie minimalizowac przerwy w DPS." or nil),
      castStatus == "bad" and 15 or (castStatus == "warn" and 8 or 0)
    )
  end

  if fight.rotation and fight.rotation.totalCasts>0 then
    local rotScore=module.GetRotationScore(fight)
    if rotScore then
      local rotAccuracy=rotScore.accuracy or 0
      local rotStatus=utils.StatusForPercent(rotAccuracy,0.85,0.70)
      AddMetric("Dokladnosc rotacji (APL)",nil,string.format("%.0f%% (%d/%d)",rotAccuracy*100,rotScore.optimalCasts,rotScore.totalCasts),rotAccuracy,rotStatus,rotStatus=="bad"and"Niska dokladnosc rotacji."or(rotStatus=="warn"and"Srednia dokladnosc."or nil),rotStatus=="bad"and 10 or(rotStatus=="warn"and 5 or 0))
      if rotScore.mistakes and #rotScore.mistakes>0 then
        local mC={}
        for _,m in ipairs(rotScore.mistakes)do mC[m.reason or"Unknown"]=(mC[m.reason or"Unknown"]or 0)+1 end
        local sM={}
        for r,c in pairs(mC)do table.insert(sM,{reason=r,count=c})end
        table.sort(sM,function(a,b)return a.count>b.count end)
        for i=1,math.min(3,#sM)do
          local m=sM[i]
          if m.count>=2 then utils.AddIssue(issues,string.format("Blad rotacji (%dx): %s",m.count,m.reason))end
        end
      end
    end
  end

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

  local agonyUptime = utils.SafePercent(fight.debuffUptime[SPELL_AGONY] or 0, duration)
  if agonyUptime < 0.85 then
    score = score - 20
  end

  local corruptionUptime = utils.SafePercent(fight.debuffUptime[SPELL_CORRUPTION] or 0, duration)
  if corruptionUptime < 0.85 then
    score = score - 20
  end

  local uaUptime = utils.SafePercent(fight.debuffUptime[SPELL_UNSTABLE_AFFLICTION] or 0, duration)
  if uaUptime < 0.85 then
    score = score - 20
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

  local hasNightfall = CheckPlayerBuff(SPELL_NIGHTFALL)
  if hasNightfall then
    return "Nightfall! Haunt teraz!"
  end

  if UnitExists("target") then
    local hasAgony, agonyRemaining = CheckTargetDebuff(SPELL_AGONY)
    if not hasAgony and duration > 2 then
      return "Naloz Agony!"
    elseif hasAgony and agonyRemaining > 0 and agonyRemaining < 4 then
      return "Agony wygasa! Odswiez!"
    end

    local hasCorruption, corruptionRemaining = CheckTargetDebuff(SPELL_CORRUPTION)
    if not hasCorruption and duration > 3 then
      return "Naloz Corruption!"
    elseif hasCorruption and corruptionRemaining > 0 and corruptionRemaining < 4 then
      return "Corruption wygasa! Odswiez!"
    end

    local hasUA, uaRemaining = CheckTargetDebuff(SPELL_UNSTABLE_AFFLICTION)
    if not hasUA and duration > 4 then
      return "Naloz Unstable Affliction!"
    elseif hasUA and uaRemaining > 0 and uaRemaining < 3 then
      return "UA wygasa! Odswiez!"
    end

    local hasHaunt = CheckTargetDebuff(SPELL_HAUNT)
    if not hasHaunt and duration > 5 then
      if utils.IsSpellReady(SPELL_HAUNT) then
        return "Haunt gotowe!"
      end
    end
  end

  if utils.IsSpellReady(SPELL_DARK_SOUL_MISERY) and duration > 10 then
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

  local hasNightfall = CheckPlayerBuff(SPELL_NIGHTFALL)
  if hasNightfall then
    return SPELL_HAUNT
  end

  if UnitExists("target") then
    local hasAgony, agonyRemaining = CheckTargetDebuff(SPELL_AGONY)
    if not hasAgony and duration > 2 then
      return SPELL_AGONY
    elseif hasAgony and agonyRemaining > 0 and agonyRemaining < 4 then
      return SPELL_AGONY
    end

    local hasCorruption, corruptionRemaining = CheckTargetDebuff(SPELL_CORRUPTION)
    if not hasCorruption and duration > 3 then
      return SPELL_CORRUPTION
    elseif hasCorruption and corruptionRemaining > 0 and corruptionRemaining < 4 then
      return SPELL_CORRUPTION
    end

    local hasUA, uaRemaining = CheckTargetDebuff(SPELL_UNSTABLE_AFFLICTION)
    if not hasUA and duration > 4 then
      return SPELL_UNSTABLE_AFFLICTION
    elseif hasUA and uaRemaining > 0 and uaRemaining < 3 then
      return SPELL_UNSTABLE_AFFLICTION
    end

    local hasHaunt = CheckTargetDebuff(SPELL_HAUNT)
    if not hasHaunt and duration > 5 then
      if utils.IsSpellReady(SPELL_HAUNT) then
        return SPELL_HAUNT
      end
    end
  end

  if utils.IsSpellReady(SPELL_DARK_SOUL_MISERY) and duration > 10 then
    return SPELL_DARK_SOUL_MISERY
  end

  return nil
end

local APL_PRIORITY={{id="ds",spellId=SPELL_DARK_SOUL_MISERY,name="Dark Soul",condition=function(s)return s.darkSoulReady and s.duration>10 end,priority=1,category="cooldown"},{id="agony_m",spellId=SPELL_AGONY,name="Agony",condition=function(s)return s.agonyMissing and s.duration>2 end,priority=2,category="dot"},{id="corr_m",spellId=SPELL_CORRUPTION,name="Corruption",condition=function(s)return s.corruptionMissing and s.duration>2 end,priority=3,category="dot"},{id="ua_m",spellId=SPELL_UNSTABLE_AFFLICTION,name="UA",condition=function(s)return s.uaMissing and s.duration>3 end,priority=4,category="dot"},{id="haunt_nf",spellId=SPELL_HAUNT,name="Haunt(NF)",condition=function(s)return s.nightfallActive end,priority=5,category="proc"},{id="haunt",spellId=SPELL_HAUNT,name="Haunt",condition=function(s)return s.hauntReady and not s.hauntActive end,priority=6,category="damage"},{id="agony_r",spellId=SPELL_AGONY,name="Agony(r)",condition=function(s)return s.agonyExpiring end,priority=7,category="dot"},{id="corr_r",spellId=SPELL_CORRUPTION,name="Corruption(r)",condition=function(s)return s.corruptionExpiring end,priority=8,category="dot"},{id="ua_r",spellId=SPELL_UNSTABLE_AFFLICTION,name="UA(r)",condition=function(s)return s.uaExpiring end,priority=9,category="dot"},{id="mg",spellId=SPELL_MALEFIC_GRASP,name="Malefic Grasp",condition=function(s)return true end,priority=10,category="filler"}}
local function GetCurrentState(a,f)local s={duration=0,nightfallActive=false,agonyMissing=false,corruptionMissing=false,uaMissing=false,agonyExpiring=false,corruptionExpiring=false,uaExpiring=false,hauntActive=false,hauntReady=false,darkSoulReady=false}if not f then return s end local n=GetTime()s.duration=n-(f.startTime or n)s.nightfallActive=CheckPlayerBuff(SPELL_NIGHTFALL)s.hauntReady=utils.IsSpellReady(SPELL_HAUNT)s.darkSoulReady=utils.IsSpellReady(SPELL_DARK_SOUL_MISERY)if UnitExists("target")and s.duration>2 then local hA,aR=CheckTargetDebuff(SPELL_AGONY)local hC,cR=CheckTargetDebuff(SPELL_CORRUPTION)local hU,uR=CheckTargetDebuff(SPELL_UNSTABLE_AFFLICTION)local hH=CheckTargetDebuff(SPELL_HAUNT)s.agonyMissing=not hA s.corruptionMissing=not hC s.uaMissing=not hU s.hauntActive=hH s.agonyExpiring=hA and aR>0 and aR<4 s.corruptionExpiring=hC and cR>0 and cR<4 s.uaExpiring=hU and uR>0 and uR<3 end return s end
function module.GetNextAPLAction(a,f)local s=GetCurrentState(a,f)for _,act in ipairs(APL_PRIORITY)do if act.condition(s)then return act end end return APL_PRIORITY[#APL_PRIORITY]end
function module.GetAPLPriorityList()return APL_PRIORITY end
function module.GetRotationState(a,f)return GetCurrentState(a,f)end
function module.EvaluateCast(a,f,sid,ts)local nA=module.GetNextAPLAction(a,f)if not nA then return nil end local isOpt=(nA.spellId==sid)local pen=0 local rsn=""if not isOpt then local cP=nil for _,act in ipairs(APL_PRIORITY)do if act.spellId==sid then cP=act.priority break end end if cP then pen=math.abs(nA.priority-cP)*2 rsn=string.format("Powinienes uzyc: %s",nA.name)else pen=5 rsn="Spell poza rotacja APL"end end return{isOptimal=isOpt,penalty=pen,reason=rsn,expectedSpell=nA.spellId,expectedName=nA.name,actualSpell=sid}end
function module.RecordCastEvaluation(f,ev,ts)if not f.rotation then return end f.rotation.totalCasts=f.rotation.totalCasts+1 if ev.isOptimal then f.rotation.optimalCasts=f.rotation.optimalCasts+1 else f.rotation.suboptimalCasts=f.rotation.suboptimalCasts+1 f.rotation.penaltySum=f.rotation.penaltySum+ev.penalty table.insert(f.rotation.mistakes,{timestamp=ts,reason=ev.reason,penalty=ev.penalty,expected=ev.expectedName})end end
function module.GetRotationScore(f)if not f.rotation or f.rotation.totalCasts==0 then return nil end return{accuracy=f.rotation.optimalCasts/f.rotation.totalCasts,totalCasts=f.rotation.totalCasts,optimalCasts=f.rotation.optimalCasts,suboptimalCasts=f.rotation.suboptimalCasts,mistakes=f.rotation.mistakes,penaltySum=f.rotation.penaltySum}end

Analyzer:RegisterClassModule(module.class, module)
