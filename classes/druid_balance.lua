local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Druid - Balance"
module.class = "DRUID"
module.specKey = "balance"
module.specIndex = 1
module.specId = 102

-- Spell IDs
local SPELL_MOONFIRE = 8921
local SPELL_SUNFIRE = 93402
local SPELL_STARSURGE = 78674
local SPELL_STARFIRE = 2912
local SPELL_WRATH = 5176
local SPELL_STARFALL = 48505
local SPELL_FORCE_OF_NATURE = 106737
local SPELL_CELESTIAL_ALIGNMENT = 112071
local SPELL_INCARNATION = 102560
local SPELL_WILD_MUSHROOM = 88747
local SPELL_SHOOTING_STARS = 93400
local SPELL_LUNAR_ECLIPSE = 48518
local SPELL_SOLAR_ECLIPSE = 48517
local SPELL_ECLIPSE_LUNAR = 48518
local SPELL_ECLIPSE_SOLAR = 48517
local SPELL_MOONKIN_FORM = 24858
local SPELL_POTION_JADE_SERPENT = 105702

local COOLDOWN_STARSURGE = 15
local COOLDOWN_STARFALL = 90
local COOLDOWN_FORCE_OF_NATURE = 60
local COOLDOWN_CELESTIAL_ALIGNMENT = 180

local SOUND_KEY_SHOOTING_STARS = "shootingStars"
local SOUND_KEY_CELESTIAL_ALIGNMENT = "celestialAlignment"

local TRACKED_BUFFS = {
  [SPELL_SHOOTING_STARS] = true,
  [SPELL_LUNAR_ECLIPSE] = true,
  [SPELL_SOLAR_ECLIPSE] = true,
  [SPELL_CELESTIAL_ALIGNMENT] = true,
  [SPELL_INCARNATION] = true,
  [SPELL_MOONKIN_FORM] = true,
  [SPELL_POTION_JADE_SERPENT] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_MOONFIRE] = true,
  [SPELL_SUNFIRE] = true,
}

local TRACKED_CASTS = {
  [SPELL_MOONFIRE] = true,
  [SPELL_SUNFIRE] = true,
  [SPELL_STARSURGE] = true,
  [SPELL_STARFIRE] = true,
  [SPELL_WRATH] = true,
  [SPELL_STARFALL] = true,
  [SPELL_FORCE_OF_NATURE] = true,
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
  if IsSpellKnown and (IsSpellKnown(SPELL_STARSURGE) or IsSpellKnown(SPELL_MOONKIN_FORM)) then
    analyzer.player.specName = "Balance"
    analyzer.player.specId = analyzer.player.specId or module.specId
    analyzer.player.specIndex = analyzer.player.specIndex or module.specIndex
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_SHOOTING_STARS] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_CELESTIAL_ALIGNMENT] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_SHOOTING_STARS, label = "Shooting Stars" },
    { key = SOUND_KEY_CELESTIAL_ALIGNMENT, label = "Celestial Alignment" },
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
  if spellId == SPELL_SHOOTING_STARS then
    return {
      soundKey = SOUND_KEY_SHOOTING_STARS,
      priority = 2,
    }
  elseif spellId == SPELL_CELESTIAL_ALIGNMENT then
    return {
      soundKey = SOUND_KEY_CELESTIAL_ALIGNMENT,
      priority = 3,
    }
  end
  return nil
end

function module.InitFight(_, fight)
  fight.procs = {
    shootingStarsProcs = 0,
    shootingStarsConsumed = 0,
    shootingStarsExpired = 0,
  }
  fight.cooldowns = {
    celestialAlignmentLast = 0,
    starfallLast = 0,
    forceOfNatureLast = 0,
    potionLast = 0,
  }
  fight.castLog = {}
  fight.buffHistory = {}
  fight.debuffHistory = {}
  
  -- APL rotation tracking
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

  if spellId == SPELL_STARSURGE then
    local buff = fight.buffs[SPELL_SHOOTING_STARS]
    if buff and (buff.stacks or 0) > 0 then
      fight.procs.shootingStarsConsumed = fight.procs.shootingStarsConsumed + 1
      buff.consumed = true
      buff.stacks = 0
    end
  elseif spellId == SPELL_STARFALL then
    fight.cooldowns.starfallLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Starfall", spellId)
  elseif spellId == SPELL_FORCE_OF_NATURE then
    fight.cooldowns.forceOfNatureLast = now
    analyzer:AddTimelineEvent(spellId, now, "cooldown")
    analyzer:AddEventLog(now, "Force of Nature", spellId)
  end
  
  -- APL: Ewaluuj cast i zapisz wynik
  local coreSpells = {
    [SPELL_MOONFIRE] = true,
    [SPELL_SUNFIRE] = true,
    [SPELL_STARSURGE] = true,
    [SPELL_STARFIRE] = true,
    [SPELL_WRATH] = true,
    [SPELL_STARFALL] = true,
  }
  
  if coreSpells[spellId] and fight.rotation then
    local evaluation = module.EvaluateCast(analyzer, fight, spellId, now)
    if evaluation then
      module.RecordCastEvaluation(fight, evaluation, now)
    end
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

    if spellId == SPELL_SHOOTING_STARS then
      if not isRefresh then
        fight.procs.shootingStarsProcs = fight.procs.shootingStarsProcs + 1
        analyzer:AddTimelineEvent(spellId, now, "proc")
        analyzer:AddEventLog(now, "Shooting Stars proc", spellId)
      end
      analyzer:PlayAlertSound(SOUND_KEY_SHOOTING_STARS, now)
    elseif spellId == SPELL_CELESTIAL_ALIGNMENT or spellId == SPELL_INCARNATION then
      fight.spells[spellId] = (fight.spells[spellId] or 0) + 1
      fight.cooldowns.celestialAlignmentLast = now
      analyzer:AddTimelineEvent(spellId, now, "cooldown")
      analyzer:AddEventLog(now, "Celestial Alignment", spellId)
      analyzer:PlayAlertSound(SOUND_KEY_CELESTIAL_ALIGNMENT, now)
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
      if spellId == SPELL_SHOOTING_STARS and not buff.consumed then
        fight.procs.shootingStarsExpired = fight.procs.shootingStarsExpired + 1
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

  local moonfireUptime = utils.SafePercent(fight.debuffUptime[SPELL_MOONFIRE] or 0, context.duration)
  local sunfireUptime = utils.SafePercent(fight.debuffUptime[SPELL_SUNFIRE] or 0, context.duration)
  local totalDotUptime = math.max(moonfireUptime, sunfireUptime)
  local dotStatus = utils.StatusForPercent(totalDotUptime, 0.95, 0.85)
  AddMetric(
    "Moonfire/Sunfire uptime",
    SPELL_MOONFIRE,
    utils.FormatPercent(totalDotUptime),
    totalDotUptime,
    dotStatus,
    dotStatus == "bad" and "Slaby uptime dotow. Utrzymuj Moonfire/Sunfire przez cala walke."
      or (dotStatus == "warn" and "Dot uptime moglby byc lepszy. Pilnuj odswiezenia." or nil),
    dotStatus == "bad" and 12 or (dotStatus == "warn" and 6 or 0)
  )

  local shootingStarsProcs = fight.procs.shootingStarsProcs or 0
  local shootingStarsConsumed = fight.procs.shootingStarsConsumed or 0
  if shootingStarsProcs > 0 then
    local ssUtil = utils.SafePercent(shootingStarsConsumed, shootingStarsProcs)
    local ssStatus = utils.StatusForPercent(ssUtil, 0.85, 0.70)
    AddMetric(
      "Shooting Stars wykorzystanie",
      SPELL_SHOOTING_STARS,
      string.format("%s (%d/%d)", utils.FormatPercent(ssUtil), shootingStarsConsumed, shootingStarsProcs),
      ssUtil,
      ssStatus,
      ssStatus == "bad" and "Za duzo Shooting Stars nie jest zuzywane. Castuj Starsurge po procach."
        or (ssStatus == "warn" and "Czesc Shooting Stars sie marnuje. Zuzywaj proci szybciej." or nil),
      ssStatus == "bad" and 10 or (ssStatus == "warn" and 5 or 0)
    )
  end

  local starsurge = fight.spells[SPELL_STARSURGE] or 0
  local expectedStarsurge = utils.ExpectedUses(context.duration, COOLDOWN_STARSURGE, 10)
  if expectedStarsurge > 0 then
    local ssPercent = utils.SafePercent(starsurge, expectedStarsurge)
    local ssStatus = utils.StatusForPercent(ssPercent, 0.80, 0.65)
    AddMetric(
      "Starsurge uzycia",
      SPELL_STARSURGE,
      string.format("%d/%d", starsurge, expectedStarsurge),
      math.min(ssPercent or 0, 1),
      ssStatus,
      ssStatus == "bad" and "Za malo Starsurge. Uzywaj na cooldown."
        or (ssStatus == "warn" and "Starsurge uzywany zbyt rzadko." or nil),
      ssStatus == "bad" and 10 or (ssStatus == "warn" and 5 or 0)
    )
  end

  local starfall = fight.spells[SPELL_STARFALL] or 0
  local expectedStarfall = utils.ExpectedUses(context.duration, COOLDOWN_STARFALL, 10)
  if expectedStarfall > 0 then
    local sfPercent = utils.SafePercent(starfall, expectedStarfall)
    local sfStatus = utils.StatusForPercent(sfPercent, 1.0, 0.7)
    AddMetric(
      "Starfall uzycia",
      SPELL_STARFALL,
      string.format("%d/%d", starfall, expectedStarfall),
      math.min(sfPercent or 0, 1),
      sfStatus,
      starfall < expectedStarfall and "Za malo Starfall. Uzywaj na cooldown."
        or nil,
      starfall < expectedStarfall and 8 or 0
    )
  end

  local celestialAlignment = fight.spells[SPELL_CELESTIAL_ALIGNMENT] or fight.spells[SPELL_INCARNATION] or 0
  local expectedCA = utils.ExpectedUses(context.duration, COOLDOWN_CELESTIAL_ALIGNMENT, 10)
  if expectedCA > 0 then
    local caPercent = utils.SafePercent(celestialAlignment, expectedCA)
    local caStatus = utils.StatusForPercent(caPercent, 1.0, 0.7)
    AddMetric(
      "Celestial Alignment uzycia",
      SPELL_CELESTIAL_ALIGNMENT,
      string.format("%d/%d", celestialAlignment, expectedCA),
      math.min(caPercent or 0, 1),
      caStatus,
      celestialAlignment < expectedCA and "Za malo Celestial Alignment. Uzywaj na cooldown."
        or nil,
      celestialAlignment < expectedCA and 8 or 0
    )
  end

  -- APL Rotation Accuracy
  if fight.rotation and fight.rotation.totalCasts > 0 then
    local rotScore = module.GetRotationScore(fight)
    if rotScore then
      local rotAccuracy = rotScore.accuracy or 0
      local rotStatus = utils.StatusForPercent(rotAccuracy, 0.85, 0.70)
      AddMetric(
        "Dokladnosc rotacji (APL)",
        nil,
        string.format("%.0f%% (%d/%d optymalnych)", rotAccuracy * 100, rotScore.optimalCasts, rotScore.totalCasts),
        rotAccuracy,
        rotStatus,
        rotStatus == "bad" and "Niska dokladnosc rotacji. Sprawdz liste bledow ponizej i popracuj nad priorytetami."
          or (rotStatus == "warn" and "Srednia dokladnosc rotacji. Kilka bledow do poprawy." or nil),
        rotStatus == "bad" and 10 or (rotStatus == "warn" and 5 or 0)
      )
      
      if rotScore.mistakes and #rotScore.mistakes > 0 then
        local mistakeCounts = {}
        for _, mistake in ipairs(rotScore.mistakes) do
          local reason = mistake.reason or "Unknown"
          mistakeCounts[reason] = (mistakeCounts[reason] or 0) + 1
        end
        
        local sortedMistakes = {}
        for reason, count in pairs(mistakeCounts) do
          table.insert(sortedMistakes, {reason = reason, count = count})
        end
        table.sort(sortedMistakes, function(a, b) return a.count > b.count end)
        
        for i = 1, math.min(3, #sortedMistakes) do
          local m = sortedMistakes[i]
          if m.count >= 2 then
            utils.AddIssue(issues, string.format("Blad rotacji (%dx): %s", m.count, m.reason))
          end
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

  if fight.procs and fight.procs.shootingStarsExpired and fight.procs.shootingStarsExpired > 2 then
    score = score - 15
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

  local hasShootingStars = CheckPlayerBuff(SPELL_SHOOTING_STARS)
  if hasShootingStars then
    return "Shooting Stars! Uzyj Starsurge!"
  end

  if UnitExists("target") and duration > 2 then
    local hasMoonfire = CheckTargetDebuff(SPELL_MOONFIRE)
    local hasSunfire = CheckTargetDebuff(SPELL_SUNFIRE)
    if not hasMoonfire and not hasSunfire then
      return "Naloz Moonfire/Sunfire!"
    end
  end

  if utils.IsSpellReady(SPELL_CELESTIAL_ALIGNMENT) and duration > 15 then
    return "Celestial Alignment gotowe!"
  end

  if utils.IsSpellReady(SPELL_STARSURGE) and duration > 5 then
    return "Starsurge gotowy!"
  end

  if utils.IsSpellReady(SPELL_STARFALL) and duration > 10 then
    return "Starfall gotowy!"
  end

  return ""
end

function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasShootingStars = CheckPlayerBuff(SPELL_SHOOTING_STARS)
  if hasShootingStars then
    return SPELL_STARSURGE
  end

  if UnitExists("target") and duration > 2 then
    local hasMoonfire = CheckTargetDebuff(SPELL_MOONFIRE)
    local hasSunfire = CheckTargetDebuff(SPELL_SUNFIRE)
    if not hasMoonfire and not hasSunfire then
      return SPELL_MOONFIRE
    end
  end

  if utils.IsSpellReady(SPELL_CELESTIAL_ALIGNMENT) and duration > 15 then
    return SPELL_CELESTIAL_ALIGNMENT
  end

  if utils.IsSpellReady(SPELL_STARSURGE) and duration > 5 then
    return SPELL_STARSURGE
  end

  if utils.IsSpellReady(SPELL_STARFALL) and duration > 10 then
    return SPELL_STARFALL
  end

  return nil
end

-- =============================================================================
-- APL (Action Priority List) - Balance Druid rotation
-- =============================================================================

local APL_PRIORITY = {
  -- Priorytet 1: Celestial Alignment
  {
    id = "celestial_alignment",
    spellId = SPELL_CELESTIAL_ALIGNMENT,
    name = "Celestial Alignment",
    condition = function(state)
      return state.celestialAlignmentReady and state.duration > 10
    end,
    priority = 1,
    category = "cooldown",
    description = "Celestial Alignment na cooldown",
  },
  
  -- Priorytet 2: Starfall
  {
    id = "starfall",
    spellId = SPELL_STARFALL,
    name = "Starfall",
    condition = function(state)
      return state.starfallReady and state.duration > 10
    end,
    priority = 2,
    category = "cooldown",
    description = "Starfall na cooldown",
  },
  
  -- Priorytet 3: Moonfire/Sunfire (brak)
  {
    id = "dot_missing",
    spellId = SPELL_MOONFIRE,
    name = "Moonfire",
    condition = function(state)
      return state.dotMissing and state.duration > 2
    end,
    priority = 3,
    category = "dot",
    description = "Naloz Moonfire/Sunfire",
  },
  
  -- Priorytet 4: Starsurge z Shooting Stars
  {
    id = "starsurge_proc",
    spellId = SPELL_STARSURGE,
    name = "Starsurge (Shooting Stars)",
    condition = function(state)
      return state.shootingStarsActive
    end,
    priority = 4,
    category = "proc",
    description = "Starsurge z Shooting Stars",
  },
  
  -- Priorytet 5: Starsurge (normalny)
  {
    id = "starsurge",
    spellId = SPELL_STARSURGE,
    name = "Starsurge",
    condition = function(state)
      return state.starsurgeReady
    end,
    priority = 5,
    category = "damage",
    description = "Starsurge na cooldown",
  },
  
  -- Priorytet 6: Starfire w Lunar Eclipse
  {
    id = "starfire_lunar",
    spellId = SPELL_STARFIRE,
    name = "Starfire (Lunar)",
    condition = function(state)
      return state.lunarEclipse
    end,
    priority = 6,
    category = "filler",
    description = "Starfire w Lunar Eclipse",
  },
  
  -- Priorytet 7: Wrath w Solar Eclipse
  {
    id = "wrath_solar",
    spellId = SPELL_WRATH,
    name = "Wrath (Solar)",
    condition = function(state)
      return state.solarEclipse
    end,
    priority = 7,
    category = "filler",
    description = "Wrath w Solar Eclipse",
  },
  
  -- Priorytet 8: Starfire (default)
  {
    id = "starfire",
    spellId = SPELL_STARFIRE,
    name = "Starfire",
    condition = function(state)
      return true
    end,
    priority = 8,
    category = "filler",
    description = "Starfire - filler",
  },
}

local function GetCurrentState(analyzer, fight)
  local state = {
    duration = 0,
    shootingStarsActive = false,
    dotMissing = false,
    lunarEclipse = false,
    solarEclipse = false,
    celestialAlignmentReady = false,
    starfallReady = false,
    starsurgeReady = false,
  }
  
  if not fight then return state end
  
  local now = GetTime()
  state.duration = now - (fight.startTime or now)
  
  -- Sprawdz buffy
  state.shootingStarsActive = CheckPlayerBuff(SPELL_SHOOTING_STARS)
  state.lunarEclipse = CheckPlayerBuff(SPELL_LUNAR_ECLIPSE)
  state.solarEclipse = CheckPlayerBuff(SPELL_SOLAR_ECLIPSE)
  
  -- Sprawdz cooldowny
  state.celestialAlignmentReady = utils.IsSpellReady(SPELL_CELESTIAL_ALIGNMENT)
  state.starfallReady = utils.IsSpellReady(SPELL_STARFALL)
  state.starsurgeReady = utils.IsSpellReady(SPELL_STARSURGE)
  
  -- Sprawdz doty na target
  if UnitExists("target") and state.duration > 2 then
    local hasMoonfire = CheckTargetDebuff(SPELL_MOONFIRE)
    local hasSunfire = CheckTargetDebuff(SPELL_SUNFIRE)
    if not hasMoonfire and not hasSunfire then
      state.dotMissing = true
    end
  end
  
  return state
end

function module.GetNextAPLAction(analyzer, fight)
  local state = GetCurrentState(analyzer, fight)
  
  for _, action in ipairs(APL_PRIORITY) do
    if action.condition(state) then
      return action
    end
  end
  
  return APL_PRIORITY[#APL_PRIORITY]
end

function module.GetAPLPriorityList()
  return APL_PRIORITY
end

function module.GetRotationState(analyzer, fight)
  return GetCurrentState(analyzer, fight)
end

function module.EvaluateCast(analyzer, fight, spellId, timestamp)
  local nextAction = module.GetNextAPLAction(analyzer, fight)
  if not nextAction then
    return nil
  end
  
  local isOptimal = (nextAction.spellId == spellId)
  local penalty = 0
  local reason = ""
  
  if not isOptimal then
    local castPriority = nil
    for _, action in ipairs(APL_PRIORITY) do
      if action.spellId == spellId then
        castPriority = action.priority
        break
      end
    end
    
    if castPriority then
      penalty = math.abs(nextAction.priority - castPriority) * 2
      reason = string.format("Powinienes uzyc: %s (zamiast tego)", nextAction.name)
    else
      penalty = 5
      reason = "Spell poza rotacja APL"
    end
  end
  
  return {
    isOptimal = isOptimal,
    penalty = penalty,
    reason = reason,
    expectedSpell = nextAction.spellId,
    expectedName = nextAction.name,
    actualSpell = spellId,
  }
end

function module.RecordCastEvaluation(fight, evaluation, timestamp)
  if not fight.rotation then return end
  
  fight.rotation.totalCasts = fight.rotation.totalCasts + 1
  
  if evaluation.isOptimal then
    fight.rotation.optimalCasts = fight.rotation.optimalCasts + 1
  else
    fight.rotation.suboptimalCasts = fight.rotation.suboptimalCasts + 1
    fight.rotation.penaltySum = fight.rotation.penaltySum + evaluation.penalty
    
    table.insert(fight.rotation.mistakes, {
      timestamp = timestamp,
      reason = evaluation.reason,
      penalty = evaluation.penalty,
      expected = evaluation.expectedName,
    })
  end
end

function module.GetRotationScore(fight)
  if not fight.rotation or fight.rotation.totalCasts == 0 then
    return nil
  end
  
  local accuracy = fight.rotation.optimalCasts / fight.rotation.totalCasts
  
  return {
    accuracy = accuracy,
    totalCasts = fight.rotation.totalCasts,
    optimalCasts = fight.rotation.optimalCasts,
    suboptimalCasts = fight.rotation.suboptimalCasts,
    mistakes = fight.rotation.mistakes,
    penaltySum = fight.rotation.penaltySum,
  }
end

Analyzer:RegisterClassModule(module.class, module)
