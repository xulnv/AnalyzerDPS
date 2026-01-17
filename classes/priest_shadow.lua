local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Priest - Shadow"
module.class = "PRIEST"
module.specKey = "shadow"
module.specIndex = 3
module.specId = 258

local SPELL_MIND_BLAST = 8205
local SPELL_MIND_FLAY = 15407
local SPELL_SHADOW_WORD_PAIN = 589
local SPELL_VAMPIRIC_TOUCH = 34914
local SPELL_DEVOURING_PLAGUE = 2944
local SPELL_MIND_SPIKE = 73510
local SPELL_SHADOWFIEND = 34433
local SPELL_SHADOW_WORD_DEATH = 32379
local SPELL_HALO = 120517
local SPELL_CASCADE = 121135
local SPELL_DIVINE_STAR = 110744
local SPELL_MIND_SEAR = 48045
local SPELL_SHADOWFORM = 15473
local SPELL_VAMPIRIC_EMBRACE = 15286
local SPELL_DISPERSION = 47585
local SPELL_POTION_JADE_SERPENT = 105702
local SPELL_DARK_ARCHANGEL = 87153
local SPELL_SHADOWY_APPARITION = 147193
local SPELL_SURGE_OF_DARKNESS = 87160
local SPELL_SHADOW_ORB_1 = 77487
local SPELL_SHADOW_ORB_2 = 77486
local SPELL_SHADOW_ORB_3 = 77487

local COOLDOWN_SHADOWFIEND = 180
local COOLDOWN_MIND_BLAST = 8
local COOLDOWN_SHADOW_WORD_DEATH = 10

local SOUND_KEY_SURGE_OF_DARKNESS = "surgeOfDarkness"
local SOUND_KEY_SHADOWFIEND = "shadowfiend"
local SOUND_KEY_VAMPIRIC_EMBRACE = "vampiricEmbrace"

local TRACKED_BUFFS = {
  [SPELL_SHADOWFORM] = true,
  [SPELL_VAMPIRIC_EMBRACE] = true,
  [SPELL_DISPERSION] = true,
  [SPELL_POTION_JADE_SERPENT] = true,
  [SPELL_DARK_ARCHANGEL] = true,
  [SPELL_SURGE_OF_DARKNESS] = true,
  [SPELL_SHADOW_ORB_1] = true,
  [SPELL_SHADOW_ORB_2] = true,
  [SPELL_SHADOW_ORB_3] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_SHADOW_WORD_PAIN] = true,
  [SPELL_VAMPIRIC_TOUCH] = true,
  [SPELL_DEVOURING_PLAGUE] = true,
}

local TRACKED_CASTS = {
  [SPELL_MIND_BLAST] = true,
  [SPELL_MIND_FLAY] = true,
  [SPELL_SHADOW_WORD_PAIN] = true,
  [SPELL_VAMPIRIC_TOUCH] = true,
  [SPELL_DEVOURING_PLAGUE] = true,
  [SPELL_MIND_SPIKE] = true,
  [SPELL_SHADOWFIEND] = true,
  [SPELL_SHADOW_WORD_DEATH] = true,
  [SPELL_HALO] = true,
  [SPELL_CASCADE] = true,
  [SPELL_DIVINE_STAR] = true,
  [SPELL_MIND_SEAR] = true,
  [SPELL_VAMPIRIC_EMBRACE] = true,
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
  if IsSpellKnown and (IsSpellKnown(SPELL_MIND_FLAY) or IsSpellKnown(SPELL_SHADOWFORM)) then
    analyzer.player.specName = "Shadow"
    analyzer.player.specId = analyzer.player.specId or module.specId
    analyzer.player.specIndex = analyzer.player.specIndex or module.specIndex
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_SURGE_OF_DARKNESS] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_SHADOWFIEND] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
      [SOUND_KEY_VAMPIRIC_EMBRACE] = { enabled = true, sound = "Sound\\Interface\\ReadyCheck.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_SURGE_OF_DARKNESS, label = "Surge of Darkness" },
    { key = SOUND_KEY_SHADOWFIEND, label = "Shadowfiend" },
    { key = SOUND_KEY_VAMPIRIC_EMBRACE, label = "Vampiric Embrace" },
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
  if spellId == SPELL_SURGE_OF_DARKNESS then
    return {
      soundKey = SOUND_KEY_SURGE_OF_DARKNESS,
      priority = 2,
    }
  elseif spellId == SPELL_SHADOWFIEND then
    return {
      soundKey = SOUND_KEY_SHADOWFIEND,
      priority = 3,
    }
  elseif spellId == SPELL_VAMPIRIC_EMBRACE then
    return {
      soundKey = SOUND_KEY_VAMPIRIC_EMBRACE,
      priority = 2,
    }
  end
  return nil
end

function module.ShouldTrackSummonSpell(spellId)
  return spellId == SPELL_SHADOWFIEND
end

function module.InitFight(_, fight)
  fight.procs = {
    surgeOfDarknessProcs = 0,
    surgeOfDarknessConsumed = 0,
    surgeOfDarknessExpired = 0,
  }
  fight.counts = {
    mindBlastWithoutOrbs = 0,
    devouringPlagueTotal = 0,
  }
  fight.cooldowns = {
    shadowfiendLast = 0,
    vampiricEmbraceLast = 0,
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

  if spellId == SPELL_MIND_SPIKE then
    local buff = fight.buffs[SPELL_SURGE_OF_DARKNESS]
    if buff and (buff.stacks or 0) > 0 then
      fight.procs.surgeOfDarknessConsumed = fight.procs.surgeOfDarknessConsumed + 1
      buff.consumed = true
      buff.stacks = 0
    end
  elseif spellId == SPELL_MIND_BLAST then
    local hasOrbs = fight.buffs[SPELL_SHADOW_ORB_1] or fight.buffs[SPELL_SHADOW_ORB_2] or fight.buffs[SPELL_SHADOW_ORB_3]
    if not hasOrbs then
      fight.counts.mindBlastWithoutOrbs = fight.counts.mindBlastWithoutOrbs + 1
    end
  elseif spellId == SPELL_DEVOURING_PLAGUE then
    fight.counts.devouringPlagueTotal = fight.counts.devouringPlagueTotal + 1
  elseif spellId == SPELL_SHADOWFIEND then
    fight.cooldowns.shadowfiendLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Shadowfiend", spellId)
    analyzer:PlayAlertSound(SOUND_KEY_SHADOWFIEND, now)
  elseif spellId == SPELL_VAMPIRIC_EMBRACE then
    fight.cooldowns.vampiricEmbraceLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Vampiric Embrace", spellId)
    analyzer:PlayAlertSound(SOUND_KEY_VAMPIRIC_EMBRACE, now)
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
    if isRefresh and buff.historyEntry and not buff.historyEntry.removed then
      buff.historyEntry.removed = now
    end
    if not buff.historyEntry or isRefresh then
      buff.historyEntry = { applied = now }
      table.insert(history, buff.historyEntry)
    end

    if spellId == SPELL_SURGE_OF_DARKNESS then
      if not isRefresh then
        fight.procs.surgeOfDarknessProcs = fight.procs.surgeOfDarknessProcs + 1
        analyzer:AddTimelineEvent(spellId, now, "proc")
        analyzer:AddEventLog(now, "Surge of Darkness proc", spellId)
      else
        analyzer:AddEventLog(now, "Surge of Darkness odswiezony", spellId)
      end
      analyzer:PlayAlertSound(SOUND_KEY_SURGE_OF_DARKNESS, now)
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
      if spellId == SPELL_SURGE_OF_DARKNESS and not buff.consumed then
        fight.procs.surgeOfDarknessExpired = fight.procs.surgeOfDarknessExpired + 1
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
  local spellName = GetSpellInfo(spellId) or "Debuff"

  if subevent == "SPELL_AURA_APPLIED" then
    fight.debuffs[spellId] = { since = now, targetGUID = destGUID }
    local entry = { applied = now }
    table.insert(history, entry)
    fight.debuffs[spellId].historyEntry = entry
    analyzer:AddEventLog(now, spellName .. " nalozony", spellId)
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
    analyzer:AddEventLog(now, spellName .. " odswiezony", spellId)
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

  local swpUptime = utils.SafePercent(fight.debuffUptime[SPELL_SHADOW_WORD_PAIN] or 0, context.duration)
  local swpStatus = utils.StatusForPercent(swpUptime, 0.95, 0.85)
  AddMetric(
    "Shadow Word: Pain uptime",
    SPELL_SHADOW_WORD_PAIN,
    utils.FormatPercent(swpUptime),
    swpUptime,
    swpStatus,
    swpStatus == "bad" and "Slaby uptime Shadow Word: Pain. Utrzymuj dot przez cala walke."
      or (swpStatus == "warn" and "SW:P uptime moglby byc lepszy. Pilnuj odswiezenia." or nil),
    swpStatus == "bad" and 12 or (swpStatus == "warn" and 6 or 0)
  )

  local vtUptime = utils.SafePercent(fight.debuffUptime[SPELL_VAMPIRIC_TOUCH] or 0, context.duration)
  local vtStatus = utils.StatusForPercent(vtUptime, 0.95, 0.85)
  AddMetric(
    "Vampiric Touch uptime",
    SPELL_VAMPIRIC_TOUCH,
    utils.FormatPercent(vtUptime),
    vtUptime,
    vtStatus,
    vtStatus == "bad" and "Slaby uptime Vampiric Touch. Utrzymuj glowny dot przez cala walke."
      or (vtStatus == "warn" and "VT uptime moglby byc wyzszy. Pilnuj odnawiania." or nil),
    vtStatus == "bad" and 12 or (vtStatus == "warn" and 6 or 0)
  )

  local dpUptime = utils.SafePercent(fight.debuffUptime[SPELL_DEVOURING_PLAGUE] or 0, context.duration)
  local dpStatus = utils.StatusForPercent(dpUptime, 0.80, 0.65)
  AddMetric(
    "Devouring Plague uptime",
    SPELL_DEVOURING_PLAGUE,
    utils.FormatPercent(dpUptime),
    dpUptime,
    dpStatus,
    dpStatus == "bad" and "Niski uptime Devouring Plague. Wydawaj Shadow Orby regularnie na DP."
      or (dpStatus == "warn" and "DP uptime moglby byc lepszy. Nie trzymaj orbsow zbyt dlugo." or nil),
    dpStatus == "bad" and 10 or (dpStatus == "warn" and 5 or 0)
  )

  local surgeProcs = fight.procs.surgeOfDarknessProcs or 0
  local surgeConsumed = fight.procs.surgeOfDarknessConsumed or 0
  if surgeProcs > 0 then
    local surgeUtil = utils.SafePercent(surgeConsumed, surgeProcs)
    local surgeStatus = utils.StatusForPercent(surgeUtil, 0.85, 0.70)
    AddMetric(
      "Surge of Darkness wykorzystanie",
      SPELL_SURGE_OF_DARKNESS,
      string.format("%s (%d/%d)", utils.FormatPercent(surgeUtil), surgeConsumed, surgeProcs),
      surgeUtil,
      surgeStatus,
      surgeStatus == "bad" and "Za duzo Surge of Darkness nie jest zuzywane. Castuj Mind Spike instant po procach."
        or (surgeStatus == "warn" and "Czesc Surge of Darkness sie marnuje. Zuzywaj proci szybciej." or nil),
      surgeStatus == "bad" and 8 or (surgeStatus == "warn" and 4 or 0)
    )
  end

  local surgeExpired = fight.procs.surgeOfDarknessExpired or 0
  if surgeExpired > 0 then
    utils.AddIssue(issues, string.format("Surge of Darkness wygaslo: %d. Staraj sie zuzywac proci szybciej.", surgeExpired))
  end

  local mindBlast = fight.spells[SPELL_MIND_BLAST] or 0
  local expectedMindBlast = utils.ExpectedUses(context.duration, COOLDOWN_MIND_BLAST, 6)
  if expectedMindBlast > 0 then
    local mbPercent = utils.SafePercent(mindBlast, expectedMindBlast)
    local mbStatus = utils.StatusForPercent(mbPercent, 0.85, 0.70)
    AddMetric(
      "Mind Blast uzycia",
      SPELL_MIND_BLAST,
      string.format("%d/%d", mindBlast, expectedMindBlast),
      math.min(mbPercent or 0, 1),
      mbStatus,
      mbStatus == "bad" and "Za malo Mind Blast. Uzywaj na cooldown dla Shadow Orbs."
        or (mbStatus == "warn" and "Mind Blast uzywany zbyt rzadko. Wciskaj na cooldown." or nil),
      mbStatus == "bad" and 10 or (mbStatus == "warn" and 5 or 0)
    )
  end

  local shadowfiend = fight.spells[SPELL_SHADOWFIEND] or 0
  local expectedShadowfiend = utils.ExpectedUses(context.duration, COOLDOWN_SHADOWFIEND, 10)
  if expectedShadowfiend > 0 then
    local sfPercent = utils.SafePercent(shadowfiend, expectedShadowfiend)
    local sfStatus = utils.StatusForPercent(sfPercent, 1.0, 0.7)
    AddMetric(
      "Shadowfiend uzycia",
      SPELL_SHADOWFIEND,
      string.format("%d/%d", shadowfiend, expectedShadowfiend),
      math.min(sfPercent or 0, 1),
      sfStatus,
      shadowfiend < expectedShadowfiend and "Za malo Shadowfiend. Uzywaj na cooldown dla DPS i mana regen."
        or nil,
      shadowfiend < expectedShadowfiend and 8 or 0
    )
  end

  local shadowformUptime = utils.SafePercent(fight.buffUptime[SPELL_SHADOWFORM] or 0, context.duration)
  local sfStatus = utils.StatusForPercent(shadowformUptime, 0.98, 0.90)
  AddMetric(
    "Shadowform uptime",
    SPELL_SHADOWFORM,
    utils.FormatPercent(shadowformUptime),
    shadowformUptime,
    sfStatus,
    sfStatus == "bad" and "Zbyt niski uptime Shadowform. Utrzymuj przez cala walke dla dmg bonus."
      or (sfStatus == "warn" and "Shadowform uptime powinien byc wyzszy." or nil),
    sfStatus == "bad" and 8 or (sfStatus == "warn" and 4 or 0)
  )

  local devouringPlague = fight.counts.devouringPlagueTotal or 0
  if devouringPlague == 0 and context.duration >= 20 then
    utils.AddIssue(issues, "Brak Devouring Plague. Wydawaj Shadow Orbs (3 stack) na DP dla DPS.")
    score = utils.Clamp(score - 6, 0, 100)
  end

  local mindFlay = fight.spells[SPELL_MIND_FLAY] or 0
  AddMetric(
    "Mind Flay casty",
    SPELL_MIND_FLAY,
    string.format("%d", mindFlay),
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

  -- Check for active DoTs
  local hasSWP = false
  local hasVT = false
  local hasDP = false

  for guid, debuff in pairs(fight.debuffs or {}) do
    if debuff[SPELL_SHADOW_WORD_PAIN] and debuff[SPELL_SHADOW_WORD_PAIN].active then
      hasSWP = true
    end
    if debuff[SPELL_VAMPIRIC_TOUCH] and debuff[SPELL_VAMPIRIC_TOUCH].active then
      hasVT = true
    end
    if debuff[SPELL_DEVOURING_PLAGUE] and debuff[SPELL_DEVOURING_PLAGUE].active then
      hasDP = true
    end
  end

  if not hasSWP then
    score = score - 15
  end
  if not hasVT then
    score = score - 15
  end
  if not hasDP then
    score = score - 10
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

  local hasSurgeOfDarkness = CheckPlayerBuff(SPELL_SURGE_OF_DARKNESS)
  if hasSurgeOfDarkness then
    return "Surge of Darkness! Mind Spike!"
  end

  if not CheckPlayerBuff(SPELL_SHADOWFORM) and duration > 2 then
    return "Wejdz w Shadowform!"
  end

  if UnitExists("target") then
    local hasSWP = CheckTargetDebuff(SPELL_SHADOW_WORD_PAIN)
    if not hasSWP and duration > 2 then
      return "Naloz Shadow Word: Pain!"
    end

    local hasVT = CheckTargetDebuff(SPELL_VAMPIRIC_TOUCH)
    if not hasVT and duration > 3 then
      return "Naloz Vampiric Touch!"
    end

    local hasDP = CheckTargetDebuff(SPELL_DEVOURING_PLAGUE)
    if not hasDP and duration > 5 then
      return "Odswiez Devouring Plague!"
    end
  end

  if utils.IsSpellReady(SPELL_SHADOWFIEND) and duration > 15 then
    return "Shadowfiend gotowy!"
  end

  if utils.IsSpellReady(SPELL_MIND_BLAST) then
    return "Mind Blast gotowy!"
  end

  return ""
end

function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasSurgeOfDarkness = CheckPlayerBuff(SPELL_SURGE_OF_DARKNESS)
  if hasSurgeOfDarkness then
    return SPELL_MIND_SPIKE
  end

  if not CheckPlayerBuff(SPELL_SHADOWFORM) and duration > 2 then
    return SPELL_SHADOWFORM
  end

  if UnitExists("target") then
    local hasSWP = CheckTargetDebuff(SPELL_SHADOW_WORD_PAIN)
    if not hasSWP and duration > 2 then
      return SPELL_SHADOW_WORD_PAIN
    end

    local hasVT = CheckTargetDebuff(SPELL_VAMPIRIC_TOUCH)
    if not hasVT and duration > 3 then
      return SPELL_VAMPIRIC_TOUCH
    end

    local hasDP = CheckTargetDebuff(SPELL_DEVOURING_PLAGUE)
    if not hasDP and duration > 5 then
      return SPELL_DEVOURING_PLAGUE
    end
  end

  if utils.IsSpellReady(SPELL_SHADOWFIEND) and duration > 15 then
    return SPELL_SHADOWFIEND
  end

  if utils.IsSpellReady(SPELL_MIND_BLAST) then
    return SPELL_MIND_BLAST
  end

  return nil
end

Analyzer:RegisterClassModule(module.class, module)
