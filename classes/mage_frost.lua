local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

-- Helper function for translations
local function L(key)
  return Analyzer:L(key)
end

module.name = "Mage - Frost"
module.class = "MAGE"
module.specKey = "frost"
module.specIndex = 3

local SPELL_FROSTBOLT = 116
local SPELL_ICE_LANCE = 30455
local SPELL_FROSTFIRE_BOLT = 44614
local SPELL_FROZEN_ORB = 84714
local SPELL_ICY_VEINS = 131078
local SPELL_ICY_VEINS_ALT = 12472
local SPELL_ALTER_TIME = 108978
local SPELL_FINGERS_OF_FROST = 44544
local SPELL_BRAIN_FREEZE = 44549
local SPELL_BRAIN_FREEZE_ALT = 57761
local SPELL_WATER_ELEMENTAL = 31687
local SPELL_INVOCERS_ENERGY = 116257
local SPELL_INVOCERS_ENERGY_ALT = 116267
local INVOCERS_ENERGY_NAME = "Invoker's Energy"
local SPELL_POTION_JADE_SERPENT = 105702
local SPELL_LIVING_BOMB = 44457
local SPELL_NETHER_TEMPEST = 114923
local SPELL_EVOCATION = 12051
local SPELL_FROST_BOMB = 112948
local SPELL_MIRROR_IMAGE = 55342
local SPELL_TIME_WARP = 80353
local SPELL_BERSERKING = 26297
local SPELL_BLOOD_FURY = 33697

local COOLDOWN_ICY_VEINS = 180
local COOLDOWN_FROZEN_ORB = 60
local BF_CONSUME_WINDOW = 0.3

local SOUND_KEY_ALTER_TIME = "alterTime"
local SOUND_KEY_FINGERS_OF_FROST = "fingersOfFrost"
local SOUND_KEY_BRAIN_FREEZE = "brainFreeze"

local TRACKED_BUFFS = {
  [SPELL_FINGERS_OF_FROST] = true,
  [SPELL_BRAIN_FREEZE] = true,
  [SPELL_BRAIN_FREEZE_ALT] = true,
  [SPELL_ICY_VEINS] = true,
  [SPELL_ICY_VEINS_ALT] = true,
  [SPELL_INVOCERS_ENERGY] = true,
  [SPELL_INVOCERS_ENERGY_ALT] = true,
  [SPELL_POTION_JADE_SERPENT] = true,
  [SPELL_ALTER_TIME] = true,
}

local TRACKED_DEBUFFS = {
  [SPELL_LIVING_BOMB] = true,
  [SPELL_NETHER_TEMPEST] = true,
}

local ALTER_TIME_NAME = GetSpellInfo(SPELL_ALTER_TIME)

local function IsAlterTimeSpellId(spellId)
  if not spellId then
    return false
  end
  if spellId == SPELL_ALTER_TIME then
    return true
  end
  local baseName = ALTER_TIME_NAME or GetSpellInfo(SPELL_ALTER_TIME)
  if not baseName then
    return false
  end
  local name = GetSpellInfo(spellId)
  if not name then
    return false
  end
  return name == baseName
end

local function NormalizeBuffSpellId(spellId)
  if spellId == SPELL_BRAIN_FREEZE_ALT then
    return SPELL_BRAIN_FREEZE
  end
  if spellId == SPELL_ICY_VEINS_ALT then
    return SPELL_ICY_VEINS
  end
  if spellId == SPELL_INVOCERS_ENERGY_ALT then
    return SPELL_INVOCERS_ENERGY
  end
  if IsAlterTimeSpellId(spellId) then
    return SPELL_ALTER_TIME
  end
  return spellId
end

function module.SupportsSpec(analyzer)
  if analyzer.player.class ~= module.class then
    return false
  end
  local specKey = utils.NormalizeSpecKey(analyzer.player.specName)
  return analyzer.player.specId == 64
    or analyzer.player.specIndex == module.specIndex
    or specKey == module.specKey
end

function module.OnPlayerInit(analyzer)
  if analyzer.player.class ~= module.class then
    return
  end
  if analyzer.player.specName == "Unknown" and IsSpellKnown then
    if IsSpellKnown(SPELL_FROZEN_ORB) or IsSpellKnown(SPELL_WATER_ELEMENTAL) then
      analyzer.player.specName = "Frost"
      analyzer.player.specId = analyzer.player.specId or 64
      analyzer.player.specIndex = analyzer.player.specIndex or 3
    end
  end
end

function module.GetDefaultSettings()
  return {
    sounds = {
      [SOUND_KEY_ALTER_TIME] = { enabled = true, sound = "Sound\\Interface\\RaidWarning.ogg" },
      [SOUND_KEY_FINGERS_OF_FROST] = { enabled = true, sound = "Sound\\Interface\\MapPing.ogg" },
      [SOUND_KEY_BRAIN_FREEZE] = { enabled = true, sound = "Sound\\Interface\\ReadyCheck.ogg" },
    },
  }
end

function module.GetSoundOptions()
  return {
    { key = SOUND_KEY_ALTER_TIME, label = "Alter Time" },
    { key = SOUND_KEY_FINGERS_OF_FROST, label = "Fingers of Frost (Ice Lance)" },
    { key = SOUND_KEY_BRAIN_FREEZE, label = "Brain Freeze (Frostfire Bolt)" },
  }
end

function module.GetHintSpellId()
  return SPELL_ALTER_TIME
end

function module.GetHintText()
  return "Uzyj Alter Time teraz"
end

function module.IsTrackedBuffSpell(spellId)
  if TRACKED_BUFFS[spellId] == true then
    return true
  end
  return IsAlterTimeSpellId(spellId)
end

function module.IsTrackedDebuffSpell(spellId)
  return TRACKED_DEBUFFS[spellId] == true
end

function module.NormalizeBuffSpellId(spellId)
  return NormalizeBuffSpellId(spellId)
end

function module.InitFight(_, fight)
  fight.procs = {
    fofChargesGained = 0,
    fofChargesUsed = 0,
    fofExpired = 0,
    bfProcs = 0,
    bfUsed = 0,
    bfExpired = 0,
    bfRemovedAt = nil,
  }
  fight.counts = {
    iceLanceWithFof = 0,
    ffbWithBf = 0,
    alterTimeTotal = 0,
    alterTimeGood = 0,
  }
  fight.cooldowns = {
    icyVeinsLast = 0,
    frozenOrbLast = 0,
    alterTimeLast = 0,
    potionLast = 0,
  }
  fight.hints = {
    lastAlterHint = 0,
    lastAlterCast = 0,
  }
  fight.bombSpellId = nil
  fight.flags = fight.flags or {}
  fight.flags.invokersEnergySeen = false
  fight.flags.waterElementalActive = false
  
  -- Inicjalizacja APL rotation tracking
  fight.rotation = {
    totalCasts = 0,
    optimalCasts = 0,
    suboptimalCasts = 0,
    mistakes = {},
    penaltySum = 0,
  }
end

function module.OnFightStart(analyzer, startTime)
  if utils.PlayerHasAuraBySpellId(SPELL_ICY_VEINS) or utils.PlayerHasAuraBySpellId(SPELL_ICY_VEINS_ALT) then
    module.RegisterIcyVeinsUse(analyzer, startTime)
  end
  if UnitExists and UnitExists("pet") then
    analyzer.fight.flags.waterElementalActive = true
  end
end

function module.FinalizeFight(_, fight, endTime)
  for spellId, buff in pairs(fight.buffs) do
    -- FoF wygasa tylko jeśli nie było BF (priorytet: BF > FoF)
    if spellId == SPELL_FINGERS_OF_FROST and buff.stacks and buff.stacks > 0 then
      local hasBF = fight.buffs[SPELL_BRAIN_FREEZE] and not fight.buffs[SPELL_BRAIN_FREEZE].consumed
      if not hasBF then
        fight.procs.fofExpired = fight.procs.fofExpired + buff.stacks
      end
    end
    if spellId == SPELL_BRAIN_FREEZE and not buff.consumed then
      fight.procs.bfExpired = fight.procs.bfExpired + 1
    end
  end
  if fight.procs.bfRemovedAt then
    fight.procs.bfExpired = fight.procs.bfExpired + 1
    fight.procs.bfRemovedAt = nil
  end
  
  -- Finalizuj debuffs (per-target tracking)
  for debuffKey, debuff in pairs(fight.debuffs) do
    if debuff and debuff.since then
      -- Wyciągnij spellId z klucza (format: "spellId_targetGUID")
      local spellId = tonumber(string.match(debuffKey, "^(%d+)_"))
      if spellId then
        fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (endTime - debuff.since)
      end
    end
  end
end

function module.ExpirePendingBrainFreeze(analyzer, now)
  local fight = analyzer.fight
  if not fight then
    return
  end
  local removedAt = fight.procs.bfRemovedAt
  if not removedAt then
    return
  end
  if (now - removedAt) >= BF_CONSUME_WINDOW then
    fight.procs.bfExpired = fight.procs.bfExpired + 1
    fight.procs.bfRemovedAt = nil
  end
end

function module.RegisterIcyVeinsUse(analyzer, now)
  local fight = analyzer.fight
  if not fight then
    return
  end
  local last = fight.cooldowns.icyVeinsLast or 0
  if (now - last) <= 0.5 then
    return
  end
  fight.spells[SPELL_ICY_VEINS] = (fight.spells[SPELL_ICY_VEINS] or 0) + 1
  fight.cooldowns.icyVeinsLast = now
  analyzer:AddTimelineEvent(SPELL_ICY_VEINS, now, "cooldown")
  analyzer:AddEventLog(now, L("EVENT_ICY_VEINS"), SPELL_ICY_VEINS)
end

function module.RegisterFrozenOrbUse(analyzer, now)
  local fight = analyzer.fight
  if not fight then
    return
  end
  local last = fight.cooldowns.frozenOrbLast or 0
  if (now - last) <= 0.5 then
    return
  end
  fight.spells[SPELL_FROZEN_ORB] = (fight.spells[SPELL_FROZEN_ORB] or 0) + 1
  fight.cooldowns.frozenOrbLast = now
  analyzer:AddTimelineEvent(SPELL_FROZEN_ORB, now, "cooldown")
  analyzer:AddEventLog(now, L("EVENT_FROZEN_ORB"), SPELL_FROZEN_ORB)
end

function module.HandleAlterTimeUse(analyzer, now)
  local fight = analyzer.fight
  if not fight then
    return
  end
  local last = fight.cooldowns.alterTimeLast or 0
  if (now - last) <= 0.5 then
    return
  end
  fight.cooldowns.alterTimeLast = now
  fight.hints.lastAlterCast = now
  analyzer:PlayAlertSound(SOUND_KEY_ALTER_TIME, now)
  if analyzer.ui and analyzer.ui.hintFrame then
    analyzer.ui.hintFrame:Hide()
  end
  local fof = fight.buffs[SPELL_FINGERS_OF_FROST]
  local bf = fight.buffs[SPELL_BRAIN_FREEZE]
  local icy = fight.buffs[SPELL_ICY_VEINS]
  local fofCharges = fof and fof.stacks or 0
  local hasKeyProcs = (fofCharges >= 1 and bf)
  local hasDoubleFof = fofCharges >= 2
  local icyActive = icy ~= nil
  local goodTiming = icyActive and (hasKeyProcs or hasDoubleFof)
  local hintTime = fight.hints.lastAlterHint or 0
  local usedAfterHint = hintTime > 0 and (now - hintTime) <= 4
  if usedAfterHint then
    goodTiming = true
  end
  fight.counts.alterTimeTotal = (fight.counts.alterTimeTotal or 0) + 1
  analyzer:AddTimelineEvent(SPELL_ALTER_TIME, now, "cooldown")
  if goodTiming then
    fight.counts.alterTimeGood = (fight.counts.alterTimeGood or 0) + 1
    analyzer:AddEventLog(now, L("EVENT_ALTER_TIME_GOOD"), SPELL_ALTER_TIME)
  else
    analyzer:AddEventLog(now, L("EVENT_ALTER_TIME_BAD"), SPELL_ALTER_TIME)
  end
end

function module.TrackSpellCast(analyzer, spellId, timestamp)
  local fight = analyzer.fight
  if not fight then
    return
  end
  local now = utils.NormalizeTimestamp(timestamp)
  module.ExpirePendingBrainFreeze(analyzer, now)
  local spells = fight.spells
  if spellId ~= SPELL_ICY_VEINS and spellId ~= SPELL_ICY_VEINS_ALT and spellId ~= SPELL_FROZEN_ORB then
    spells[spellId] = (spells[spellId] or 0) + 1
  end

  if spellId == SPELL_ALTER_TIME or IsAlterTimeSpellId(spellId) then
    module.HandleAlterTimeUse(analyzer, now)
  end
  
  if spellId == SPELL_EVOCATION then
    fight.flags.invokersEnergySeen = true
    analyzer:AddEventLog(now, L("EVENT_EVOCATION"), SPELL_EVOCATION)
  end

  if spellId == SPELL_WATER_ELEMENTAL then
    fight.flags.waterElementalActive = true
    analyzer:AddEventLog(now, L("EVENT_WATER_ELEMENTAL"), SPELL_WATER_ELEMENTAL)
  end

  if spellId == SPELL_ICE_LANCE then
    local buff = fight.buffs[SPELL_FINGERS_OF_FROST]
    if buff and buff.stacks and buff.stacks > 0 then
      -- Podczas Icy Veins, Ice Lance ma 3 instancje DMG (multistrike)
      -- Tylko pierwsza konsumuje proc - ignoruj kolejne w krótkim czasie
      local lastIceLance = fight.cooldowns.iceLanceLast or 0
      if (now - lastIceLance) > 0.1 then
        fight.counts.iceLanceWithFof = fight.counts.iceLanceWithFof + 1
        fight.procs.fofChargesUsed = fight.procs.fofChargesUsed + 1
        buff.stacks = math.max(buff.stacks - 1, 0)
        fight.cooldowns.iceLanceLast = now
      end
    end
  end

  if spellId == SPELL_FROSTFIRE_BOLT then
    local buff = fight.buffs[SPELL_BRAIN_FREEZE]
    if buff then
      fight.counts.ffbWithBf = fight.counts.ffbWithBf + 1
      fight.procs.bfUsed = fight.procs.bfUsed + 1
      buff.consumed = true
      buff.stacks = 0
    else
      local removedAt = fight.procs.bfRemovedAt
      if removedAt and (now - removedAt) <= BF_CONSUME_WINDOW then
        fight.counts.ffbWithBf = fight.counts.ffbWithBf + 1
        fight.procs.bfUsed = fight.procs.bfUsed + 1
        fight.procs.bfRemovedAt = nil
      end
    end
  end

  if spellId == SPELL_ICY_VEINS or spellId == SPELL_ICY_VEINS_ALT then
    module.RegisterIcyVeinsUse(analyzer, now)
  elseif spellId == SPELL_FROZEN_ORB then
    module.RegisterFrozenOrbUse(analyzer, now)
  end
  
  -- APL: Ewaluuj cast i zapisz wynik
  local coreSpells = {
    [SPELL_FROSTBOLT] = true,
    [SPELL_ICE_LANCE] = true,
    [SPELL_FROSTFIRE_BOLT] = true,
    [SPELL_FROZEN_ORB] = true,
    [SPELL_ICY_VEINS] = true,
    [SPELL_ICY_VEINS_ALT] = true,
    [SPELL_LIVING_BOMB] = true,
    [SPELL_NETHER_TEMPEST] = true,
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
  spellId = NormalizeBuffSpellId(spellId)
  local now = utils.NormalizeTimestamp(timestamp)
  module.ExpirePendingBrainFreeze(analyzer, now)
  if subevent == "SPELL_AURA_APPLIED"
    or subevent == "SPELL_AURA_APPLIED_DOSE"
    or subevent == "SPELL_AURA_REFRESH" then
    if spellId == SPELL_ALTER_TIME or IsAlterTimeSpellId(spellId) then
      module.HandleAlterTimeUse(analyzer, now)
    end
    local stacks = amount or 1
    local buff = fight.buffs[spellId]
    local gainedFof = false
    if not buff then
      buff = {
        stacks = stacks,
        since = now,
      }
      fight.buffs[spellId] = buff
      if spellId == SPELL_FINGERS_OF_FROST then
        fight.procs.fofChargesGained = fight.procs.fofChargesGained + stacks
        analyzer:AddTimelineEvent(spellId, now, "proc")
        gainedFof = true
      elseif spellId == SPELL_BRAIN_FREEZE then
        fight.procs.bfProcs = fight.procs.bfProcs + 1
        analyzer:AddTimelineEvent(spellId, now, "proc")
        analyzer:AddEventLog(now, L("EVENT_BF_PROC"), SPELL_BRAIN_FREEZE)
        analyzer:PlayAlertSound(SOUND_KEY_BRAIN_FREEZE, now)
      end
    else
      local previous = buff.stacks or 0
      buff.stacks = stacks
      if spellId == SPELL_FINGERS_OF_FROST and stacks > previous then
        fight.procs.fofChargesGained = fight.procs.fofChargesGained + (stacks - previous)
        gainedFof = true
      end
      if spellId == SPELL_BRAIN_FREEZE then
        analyzer:AddEventLog(now, L("EVENT_BF_REFRESH"), SPELL_BRAIN_FREEZE)
        analyzer:PlayAlertSound(SOUND_KEY_BRAIN_FREEZE, now)
      end
    end
    if spellId == SPELL_POTION_JADE_SERPENT then
      local lastPotion = fight.cooldowns.potionLast or 0
      if (now - lastPotion) > 0.5 then
        fight.cooldowns.potionLast = now
        -- Sprawdź czy to prepot (przed walką) czy potka w trakcie
        local timeSinceFightStart = now - fight.startTime
        if timeSinceFightStart > 2 then
          -- Potka użyta w trakcie walki (nie prepot)
          fight.flags.usedPotionInCombat = true
          analyzer:AddEventLog(now, L("EVENT_POTION_COMBAT"), SPELL_POTION_JADE_SERPENT)
        else
          -- Prepot (przed walką lub na początku)
          fight.flags.usedPrepot = true
          analyzer:AddEventLog(now, L("EVENT_POTION_PREPOT"), SPELL_POTION_JADE_SERPENT)
        end
      end
    end
    if spellId == SPELL_INVOCERS_ENERGY or spellId == SPELL_INVOCERS_ENERGY_ALT then
      fight.flags.invokersEnergySeen = true
      analyzer:AddEventLog(now, L("EVENT_EVOCATION"), spellId)
    end
    if spellId == SPELL_FINGERS_OF_FROST and gainedFof then
      analyzer:AddEventLog(now, string.format(L("EVENT_FOF_PROC"), stacks), SPELL_FINGERS_OF_FROST)
      analyzer:PlayAlertSound(SOUND_KEY_FINGERS_OF_FROST, now)
    end
    if spellId == SPELL_ICY_VEINS then
      module.RegisterIcyVeinsUse(analyzer, now)
    end
    if spellId == SPELL_FINGERS_OF_FROST or spellId == SPELL_BRAIN_FREEZE or spellId == SPELL_ICY_VEINS then
      module.MaybeShowAlterTimeHint(analyzer, now)
    end
  elseif subevent == "SPELL_AURA_REMOVED" then
    local buff = fight.buffs[spellId]
    if buff then
      if buff.since then
        fight.buffUptime[spellId] = (fight.buffUptime[spellId] or 0) + (now - buff.since)
      end
      if spellId == SPELL_FINGERS_OF_FROST and buff.stacks and buff.stacks > 0 then
        fight.procs.fofExpired = fight.procs.fofExpired + buff.stacks
      end
      if spellId == SPELL_BRAIN_FREEZE and not buff.consumed then
        fight.procs.bfRemovedAt = now
      end
    end
    fight.buffs[spellId] = nil
  end
end

function module.TrackDebuff(analyzer, subevent, spellId, destGUID, destName, timestamp)
  local fight = analyzer.fight
  if not fight then
    return
  end
  local now = utils.NormalizeTimestamp(timestamp)
  
  -- Ustaw bombSpellId przy pierwszym użyciu
  if not fight.bombSpellId then
    fight.bombSpellId = spellId
  end
  
  -- Ignoruj inne spelle bomb
  if fight.bombSpellId ~= spellId then
    return
  end
  
  -- Ustaw primary target jeśli nie ma
  if not fight.primaryTargetGUID and destGUID then
    fight.primaryTargetGUID = destGUID
  end
  
  -- Dodaj target do listy
  if destGUID then
    fight.targets[destGUID] = true
  end
  
  -- Śledź debuff per target (nie tylko primary)
  local targetKey = destGUID or "unknown"
  local debuffKey = spellId .. "_" .. targetKey
  
  local spellName = GetSpellInfo(spellId) or "Bomb"
  local debuff = fight.debuffs[debuffKey]
  
  if subevent == "SPELL_AURA_APPLIED" then
    fight.debuffs[debuffKey] = { since = now, targetGUID = destGUID }
    analyzer:AddEventLog(now, string.format(L("EVENT_BOMB_APPLIED"), spellName), spellId)
  elseif subevent == "SPELL_AURA_REFRESH" then
    if debuff and debuff.since then
      fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (now - debuff.since)
    end
    fight.debuffs[debuffKey] = { since = now, targetGUID = destGUID }
    analyzer:AddEventLog(now, string.format(L("EVENT_BOMB_REFRESHED"), spellName), spellId)
  elseif subevent == "SPELL_AURA_REMOVED" then
    if debuff and debuff.since then
      fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (now - debuff.since)
    end
    fight.debuffs[debuffKey] = nil
  end
end

function module.MaybeShowAlterTimeHint(analyzer, timestamp)
  local fight = analyzer.fight
  if not fight or not analyzer.ui or not analyzer.ui.hintFrame then
    return
  end
  local now = utils.NormalizeTimestamp(timestamp)
  if (now - (fight.hints.lastAlterHint or 0)) < 15 then
    return
  end
  if (now - (fight.hints.lastAlterCast or 0)) < 10 then
    return
  end
  if not utils.IsSpellReady(SPELL_ALTER_TIME) then
    return
  end

  local fof = fight.buffs[SPELL_FINGERS_OF_FROST]
  local bf = fight.buffs[SPELL_BRAIN_FREEZE]
  local icy = fight.buffs[SPELL_ICY_VEINS]
  local fofCharges = fof and fof.stacks or 0
  local hasKeyProcs = (fofCharges >= 1 and bf)
  local hasDoubleFof = fofCharges >= 2
  local icyActive = icy ~= nil

  if icyActive and (hasKeyProcs or hasDoubleFof) then
    local hint = analyzer.ui.hintFrame
    hint.icon:SetTexture(utils.GetSpellIcon(SPELL_ALTER_TIME))
    hint.text:SetText(module.GetHintText())
    hint.text:SetTextColor(1.00, 0.90, 0.20)
    hint:Show()
    fight.hints.lastAlterHint = now
    if C_Timer and C_Timer.After then
      C_Timer.After(3, function()
        if hint:IsShown() then
          hint:Hide()
        end
      end)
    end
  end
end

function module.ShouldTrackSummonSpell(spellId)
  return spellId == SPELL_FROZEN_ORB or spellId == SPELL_WATER_ELEMENTAL
end

function module.IsPrecombatBuffSpell(spellId)
  return spellId == SPELL_POTION_JADE_SERPENT
end

function module.IsPrecombatCastSpell(spellId)
  return spellId == SPELL_EVOCATION
end

function module.Analyze(analyzer, fight, context)
  local metrics = {}
  local issues = {}
  local score = 100

  local frostbolt = fight.spells[SPELL_FROSTBOLT] or 0
  local iceLance = fight.spells[SPELL_ICE_LANCE] or 0
  local ffb = fight.spells[SPELL_FROSTFIRE_BOLT] or 0
  local frozenOrb = fight.spells[SPELL_FROZEN_ORB] or 0
  local icyVeins = fight.spells[SPELL_ICY_VEINS] or 0

  local fofGained = fight.procs.fofChargesGained
  local fofUsed = fight.procs.fofChargesUsed
  local bfProcs = fight.procs.bfProcs
  local bfUsed = fight.procs.bfUsed

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

  if context.duration < 15 then
    utils.AddIssue(issues, L("MAGE_FIGHT_TOO_SHORT"))
    return {
      score = 0,
      metrics = metrics,
      issues = issues,
    }
  end

  local fofUtil = utils.SafePercent(fofUsed, fofGained)
  local fofStatus = utils.StatusForPercent(fofUtil, 0.80, 0.65)
  AddMetric(
    L("METRIC_FOF_USAGE"),
    SPELL_FINGERS_OF_FROST,
    string.format("%s (%d/%d)", utils.FormatPercent(fofUtil), fofUsed, fofGained),
    fofUtil,
    fofStatus,
    fofStatus == "bad" and L("MAGE_FOF_LOW")
      or (fofStatus == "warn" and L("MAGE_FOF_MEDIUM") or nil),
    fofStatus == "bad" and 12 or (fofStatus == "warn" and 6 or 0)
  )

  local bfUtil = utils.SafePercent(bfUsed, bfProcs)
  local bfStatus = utils.StatusForPercent(bfUtil, 0.80, 0.60)
  AddMetric(
    L("METRIC_BF_USAGE"),
    SPELL_BRAIN_FREEZE,
    string.format("%s (%d/%d)", utils.FormatPercent(bfUtil), bfUsed, bfProcs),
    bfUtil,
    bfStatus,
    bfStatus == "bad" and L("MAGE_BF_LOW")
      or (bfStatus == "warn" and L("MAGE_BF_MEDIUM") or nil),
    bfStatus == "bad" and 12 or (bfStatus == "warn" and 6 or 0)
  )

  local ilFofRatio = utils.SafePercent(fight.counts.iceLanceWithFof, iceLance)
  local ilStatus = utils.StatusForPercent(ilFofRatio, 0.75, 0.60)
  AddMetric(
    L("METRIC_IL_ON_FOF"),
    SPELL_ICE_LANCE,
    string.format("%s (%d/%d)", utils.FormatPercent(ilFofRatio), fight.counts.iceLanceWithFof, iceLance),
    ilFofRatio,
    ilStatus,
    ilStatus == "bad" and L("MAGE_IL_WITHOUT_FOF_HIGH")
      or (ilStatus == "warn" and L("MAGE_IL_WITHOUT_FOF_MEDIUM") or nil),
    ilStatus == "bad" and 10 or (ilStatus == "warn" and 5 or 0)
  )

  local castCore = frostbolt + iceLance + ffb
  local frostboltShare = utils.SafePercent(frostbolt, castCore)
  local fbStatus = utils.StatusForPercent(frostboltShare, 0.45, 0.35)
  if context.isSingleTarget then
    AddMetric(
      L("METRIC_FROSTBOLT_SHARE"),
      SPELL_FROSTBOLT,
      utils.FormatPercent(frostboltShare),
      frostboltShare,
      fbStatus,
      fbStatus == "bad" and L("MAGE_FROSTBOLT_LOW")
        or (fbStatus == "warn" and L("MAGE_FROSTBOLT_MEDIUM") or nil),
      fbStatus == "bad" and 10 or (fbStatus == "warn" and 4 or 0)
    )
  else
    AddMetric(
      L("METRIC_FROSTBOLT_SHARE_AOE"),
      SPELL_FROSTBOLT,
      utils.FormatPercent(frostboltShare),
      frostboltShare,
      "info",
      nil,
      0
    )
  end

  local expectedIcyVeins = utils.ExpectedUses(context.duration, COOLDOWN_ICY_VEINS, 20)
  local icyPercent = utils.SafePercent(icyVeins, expectedIcyVeins)
  local icyStatus = utils.StatusForPercent(icyPercent, 1.0, 0.7)
  if expectedIcyVeins > 0 then
    AddMetric(
      L("METRIC_ICY_VEINS_USES"),
      SPELL_ICY_VEINS,
      string.format("%d/%d", icyVeins, expectedIcyVeins),
      math.min(icyPercent or 0, 1),
      icyStatus,
      icyVeins == 0 and context.duration >= 25 and L("MAGE_ICY_VEINS_NONE")
        or (icyVeins < expectedIcyVeins and L("MAGE_ICY_VEINS_LOW") or nil),
      icyVeins == 0 and 12 or (icyVeins < expectedIcyVeins and 6 or 0)
    )
  end

  local expectedFrozenOrb = utils.ExpectedUses(context.duration, COOLDOWN_FROZEN_ORB, 15)
  local orbPercent = utils.SafePercent(frozenOrb, expectedFrozenOrb)
  local orbStatus = utils.StatusForPercent(orbPercent, 1.0, 0.7)
  if expectedFrozenOrb > 0 then
    AddMetric(
      L("METRIC_FROZEN_ORB_USES"),
      SPELL_FROZEN_ORB,
      string.format("%d/%d", frozenOrb, expectedFrozenOrb),
      math.min(orbPercent or 0, 1),
      orbStatus,
      frozenOrb == 0 and context.duration >= 20 and L("MAGE_FROZEN_ORB_NONE")
        or (frozenOrb < expectedFrozenOrb and L("MAGE_FROZEN_ORB_LOW") or nil),
      frozenOrb == 0 and 10 or (frozenOrb < expectedFrozenOrb and 4 or 0)
    )
  end

  local alterTotal = fight.counts.alterTimeTotal or (fight.spells[SPELL_ALTER_TIME] or 0)
  local alterGood = fight.counts.alterTimeGood or 0
  if alterTotal > 0 then
    local alterUtil = utils.SafePercent(alterGood, alterTotal)
    local alterStatus = utils.StatusForPercent(alterUtil, 0.70, 0.50)
    AddMetric(
      L("METRIC_ALTER_TIME_TIMING"),
      SPELL_ALTER_TIME,
      string.format("%s (%d/%d)", utils.FormatPercent(alterUtil), alterGood, alterTotal),
      alterUtil,
      alterStatus,
      alterStatus == "bad" and L("MAGE_ALTER_TIME_BAD")
        or (alterStatus == "warn" and L("MAGE_ALTER_TIME_MEDIUM") or nil),
      alterStatus == "bad" and 8 or (alterStatus == "warn" and 4 or 0)
    )
  elseif context.duration >= 30 then
    utils.AddIssue(issues, L("MAGE_ALTER_TIME_NONE"))
    score = utils.Clamp(score - 6, 0, 100)
  end

  -- Invoker's Energy może być pod dwoma ID, sprawdź oba
  local invokersUptime1 = fight.buffUptime[SPELL_INVOCERS_ENERGY] or 0
  local invokersUptime2 = fight.buffUptime[SPELL_INVOCERS_ENERGY_ALT] or 0
  local invokersUptimeTotal = invokersUptime1 + invokersUptime2
  local invokersUptime = utils.SafePercent(invokersUptimeTotal, context.duration) or 0
  local invokersStatus = utils.StatusForPercent(invokersUptime, 0.85, 0.70)
  AddMetric(
    L("METRIC_INVOKERS_UPTIME"),
    SPELL_INVOCERS_ENERGY,
    utils.FormatPercent(invokersUptime),
    invokersUptime,
    invokersStatus,
    invokersStatus == "bad" and L("MAGE_INVOKERS_LOW")
      or (invokersStatus == "warn" and L("MAGE_INVOKERS_MEDIUM") or nil),
    invokersStatus == "bad" and 10 or (invokersStatus == "warn" and 5 or 0)
  )

  if context.duration >= 20 and not fight.flags.waterElementalActive then
    utils.AddIssue(issues, L("MAGE_NO_PET"))
    score = utils.Clamp(score - 6, 0, 100)
  end
  
  -- Sprawdź prepotke
  if context.duration >= 15 then
    if not fight.cooldowns.potionLast then
      utils.AddIssue(issues, L("MAGE_NO_PREPOT"))
      score = utils.Clamp(score - 8, 0, 100)
    elseif fight.flags.usedPotionInCombat and not fight.flags.usedPrepot then
      utils.AddIssue(issues, L("MAGE_POTION_IN_COMBAT"))
      score = utils.Clamp(score - 10, 0, 100)
    end
  end

  if fight.bombSpellId then
    local bombUptime = utils.SafePercent(fight.debuffUptime[fight.bombSpellId] or 0, context.duration)
    local bombStatus = utils.StatusForPercent(bombUptime, 0.85, 0.70)
    local bombName = GetSpellInfo(fight.bombSpellId) or "Bomb"
    AddMetric(
      string.format(L("METRIC_BOMB_UPTIME"), bombName),
      fight.bombSpellId,
      utils.FormatPercent(bombUptime),
      bombUptime,
      bombStatus,
      bombStatus == "bad" and L("MAGE_BOMB_LOW")
        or (bombStatus == "warn" and L("MAGE_BOMB_MEDIUM") or nil),
      bombStatus == "bad" and 8 or (bombStatus == "warn" and 4 or 0)
    )
  elseif context.isSingleTarget then
    utils.AddIssue(issues, L("MAGE_NO_BOMB"))
    score = utils.Clamp(score - 6, 0, 100)
  end

  if fight.procs.bfExpired > 0 then
    utils.AddIssue(issues, string.format(L("MAGE_BF_EXPIRED"), fight.procs.bfExpired))
  end
  if fight.procs.fofExpired > 0 then
    utils.AddIssue(issues, string.format(L("MAGE_FOF_EXPIRED"), fight.procs.fofExpired))
  end

  local totalCasts = frostbolt + iceLance + ffb + frozenOrb
  local avgCastTime = 1.8
  local expectedCasts = math.floor(context.duration / avgCastTime)
  if expectedCasts > 0 then
    local castEfficiency = utils.SafePercent(totalCasts, expectedCasts)
    local castStatus = utils.StatusForPercent(castEfficiency, 0.85, 0.70)
    AddMetric(
      "Efektywnosc castowania",
      nil,
      string.format("%d/%d castow (%.0f%%)", totalCasts, expectedCasts, (castEfficiency or 0) * 100),
      math.min(castEfficiency or 0, 1),
      castStatus,
      castStatus == "bad" and "Za malo castow. Minimalizuj przerwy w DPS - unikaj zbednego ruchu i downtime."
        or (castStatus == "warn" and "Srednia ilosc castow. Staraj sie castowac bez przerw." or nil),
      castStatus == "bad" and 15 or (castStatus == "warn" and 8 or 0)
    )
  end

  -- APL Rotation Accuracy - nowa metryka z systemu priorytetow
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
      
      -- Dodaj top 3 bledy rotacji do issues
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

  -- Zawsze zwracaj score, nawet na początku walki
  local score = 100

  local hasInvoker = CheckInvokersEnergy()
  if not hasInvoker and duration > 10 then
    score = score - 15
  end

  if UnitExists and not UnitExists("pet") then
    score = score - 10
  end

  if fight.bombSpellId and not fight.debuffs[fight.bombSpellId] and duration > 4 then
    score = score - 10
  end

  if fight.procs then
    if fight.procs.fofExpired and fight.procs.fofExpired > 0 then
      score = score - math.min(12, fight.procs.fofExpired * 3)
    end
    if fight.procs.bfExpired and fight.procs.bfExpired > 0 then
      score = score - math.min(12, fight.procs.bfExpired * 4)
    end
  end

  if score < 0 then
    score = 0
  end

  return score
end

local function CheckPlayerBuff(spellId, searchName)
  if not spellId and not searchName then return false, 0 end
  for i = 1, 40 do
    local name, _, count, _, _, expirationTime, _, _, _, auraSpellId = UnitBuff("player", i)
    if not name then break end
    if auraSpellId == spellId then
      return true, count or 1, expirationTime
    end
    -- Szukaj po nazwie jesli spell ID nie pasuje
    if searchName and name and name:lower():find(searchName:lower(), 1, true) then
      return true, count or 1, expirationTime
    end
  end
  return false, 0, 0
end

local function CheckInvokersEnergy()
  -- Sprawdz po spell ID
  local has1, count1 = CheckPlayerBuff(SPELL_INVOCERS_ENERGY)
  if has1 then return true, count1 end
  local has2, count2 = CheckPlayerBuff(SPELL_INVOCERS_ENERGY_ALT)
  if has2 then return true, count2 end
  -- Sprawdz po nazwie jako fallback
  local has3, count3 = CheckPlayerBuff(nil, "Invoker")
  if has3 then return true, count3 end
  return false, 0
end

local function CheckTargetDebuff(spellId, searchName)
  if not UnitExists("target") then return false, 0 end
  if not spellId and not searchName then return false, 0 end
  
  -- Pobierz nazwe spella jesli mamy spell ID
  local spellName = spellId and GetSpellInfo(spellId) or nil
  
  for i = 1, 40 do
    local name, _, _, _, _, expirationTime, _, caster, _, _, auraSpellId = UnitDebuff("target", i)
    if not name then break end
    
    -- Sprawdz czy debuff jest od gracza
    if caster == "player" then
      -- Sprawdz po spell ID
      if spellId and auraSpellId == spellId then
        local remaining = expirationTime and (expirationTime - GetTime()) or 0
        return true, remaining
      end
      -- Sprawdz po nazwie spella
      if spellName and name == spellName then
        local remaining = expirationTime and (expirationTime - GetTime()) or 0
        return true, remaining
      end
      -- Sprawdz po custom searchName
      if searchName and name:lower():find(searchName:lower(), 1, true) then
        local remaining = expirationTime and (expirationTime - GetTime()) or 0
        return true, remaining
      end
    end
  end
  return false, 0
end

-- Sprawdz dowolna bombe na target (Living Bomb, Nether Tempest, Frost Bomb)
local function CheckAnyBombOnTarget()
  local hasBomb, bombRemaining = CheckTargetDebuff(SPELL_LIVING_BOMB, "Living Bomb")
  if hasBomb then return true, bombRemaining, SPELL_LIVING_BOMB end
  
  local hasNT, ntRemaining = CheckTargetDebuff(SPELL_NETHER_TEMPEST, "Nether Tempest")
  if hasNT then return true, ntRemaining, SPELL_NETHER_TEMPEST end
  
  local hasFB, fbRemaining = CheckTargetDebuff(SPELL_FROST_BOMB, "Frost Bomb")
  if hasFB then return true, fbRemaining, SPELL_FROST_BOMB end
  
  return false, 0, nil
end

function module.GetLiveAdvice(analyzer, fight)
  if not fight then
    return ""
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasInvoker = CheckInvokersEnergy()
  if not hasInvoker and duration > 10 then
    return L("ADVICE_USE_INVOKERS")
  end

  if UnitExists and not UnitExists("pet") and duration > 8 then
    return L("ADVICE_SUMMON_PET")
  end

  local hasBrainFreeze, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE)
  if not hasBrainFreeze then
    hasBrainFreeze, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE_ALT)
  end
  if hasBrainFreeze then
    return L("ADVICE_USE_BF")
  end

  local hasFoF, fofStacks = CheckPlayerBuff(SPELL_FINGERS_OF_FROST)
  if hasFoF then
    return L("ADVICE_USE_FOF")
  end

  if utils.IsSpellReady(SPELL_ICY_VEINS) and duration > 10 then
    return L("ADVICE_USE_ICY_VEINS")
  end

  if utils.IsSpellReady(SPELL_FROZEN_ORB) and duration > 8 then
    return L("ADVICE_USE_FROZEN_ORB")
  end

  local bombSpellId = fight.bombSpellId or SPELL_LIVING_BOMB
  if bombSpellId and duration > 3 and UnitExists("target") then
    local hasBomb, bombRemaining = CheckTargetDebuff(bombSpellId)
    local hasNT, ntRemaining = CheckTargetDebuff(SPELL_NETHER_TEMPEST)
    local hasFB, fbRemaining = CheckTargetDebuff(SPELL_FROST_BOMB)
    
    -- Sprawdź czy target ma jakąkolwiek bombę
    local hasAnyBombOnTarget = hasBomb or hasNT or hasFB
    
    if not hasAnyBombOnTarget then
      -- Tylko jeśli target jest wrogiem
      if UnitCanAttack("player", "target") then
        local bombName = GetSpellInfo(bombSpellId) or "Bomb"
        return string.format(L("ADVICE_USE_BOMB"), bombName)
      end
    elseif hasBomb and bombRemaining > 0 and bombRemaining < 4 then
      local bombName = GetSpellInfo(bombSpellId) or "Living Bomb"
      return string.format(L("ADVICE_REFRESH_BOMB"), bombName)
    elseif hasNT and ntRemaining > 0 and ntRemaining < 4 then
      local bombName = GetSpellInfo(SPELL_NETHER_TEMPEST) or "Nether Tempest"
      return string.format(L("ADVICE_REFRESH_BOMB"), bombName)
    elseif hasFB and fbRemaining > 0 and fbRemaining < 4 then
      local bombName = GetSpellInfo(SPELL_FROST_BOMB) or "Frost Bomb"
      return string.format(L("ADVICE_REFRESH_BOMB"), bombName)
    end
  end

  return ""
end

function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then
    return nil
  end

  local now = GetTime()
  local duration = now - fight.startTime

  local hasInvoker = CheckInvokersEnergy()
  if not hasInvoker and duration > 10 then
    return SPELL_EVOCATION
  end

  if UnitExists and not UnitExists("pet") and duration > 8 then
    return SPELL_WATER_ELEMENTAL
  end

  local hasBrainFreeze, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE)
  if not hasBrainFreeze then
    hasBrainFreeze, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE_ALT)
  end
  if hasBrainFreeze then
    return SPELL_FROSTFIRE_BOLT
  end

  local hasFoF, fofStacks = CheckPlayerBuff(SPELL_FINGERS_OF_FROST)
  if hasFoF then
    return SPELL_ICE_LANCE
  end

  if utils.IsSpellReady(SPELL_ICY_VEINS) and duration > 10 then
    return SPELL_ICY_VEINS
  end

  if utils.IsSpellReady(SPELL_FROZEN_ORB) and duration > 8 then
    return SPELL_FROZEN_ORB
  end

  local bombSpellId = fight.bombSpellId or SPELL_LIVING_BOMB
  if bombSpellId and duration > 3 then
    local hasAnyBomb = fight.debuffs[bombSpellId] ~= nil or fight.debuffs[SPELL_NETHER_TEMPEST] ~= nil
    
    if not hasAnyBomb then
      return bombSpellId
    end
    
    if UnitExists("target") then
      local hasBomb, bombRemaining = CheckTargetDebuff(bombSpellId)
      local hasNT, ntRemaining = CheckTargetDebuff(SPELL_NETHER_TEMPEST)
      
      if hasBomb and bombRemaining > 0 and bombRemaining < 4 then
        return bombSpellId
      elseif hasNT and ntRemaining > 0 and ntRemaining < 4 then
        return SPELL_NETHER_TEMPEST
      end
    end
  end

  return nil
end

-- =============================================================================
-- APL (Action Priority List) - Idealna rotacja Frost Mage bazowana na wowsims
-- https://github.com/wowsims/mop
-- =============================================================================

local APL_PRIORITY = {
  -- Priorytet 1: Cooldowny ofensywne
  {
    id = "frozen_orb",
    spellId = SPELL_FROZEN_ORB,
    name = "Frozen Orb",
    condition = function(state)
      return state.frozenOrbReady
    end,
    priority = 1,
    category = "cooldown",
    description = "Frozen Orb on CD - generuje Fingers of Frost",
  },
  {
    id = "icy_veins",
    spellId = SPELL_ICY_VEINS,
    name = "Icy Veins",
    condition = function(state)
      return state.icyVeinsReady
    end,
    priority = 2,
    category = "cooldown",
    description = "Icy Veins on CD - burst DPS",
  },
  {
    id = "mirror_image",
    spellId = SPELL_MIRROR_IMAGE,
    name = "Mirror Image",
    condition = function(state)
      return state.mirrorImageReady and state.icyVeinsActive
    end,
    priority = 3,
    category = "cooldown",
    description = "Mirror Image podczas Icy Veins",
  },
  
  -- Priorytet 2: Alter Time w optymalnym oknie
  {
    id = "alter_time_optimal",
    spellId = SPELL_ALTER_TIME,
    name = "Alter Time (optimal)",
    condition = function(state)
      return state.alterTimeReady 
        and state.icyVeinsActive 
        and (state.fofStacks >= 2 or (state.fofStacks >= 1 and state.brainFreezeActive))
    end,
    priority = 4,
    category = "cooldown",
    description = "Alter Time podczas Icy Veins + proci",
  },
  
  -- Priorytet 3: Proci - Brain Freeze ma najwyzszy priorytet
  {
    id = "frostfire_bolt_bf",
    spellId = SPELL_FROSTFIRE_BOLT,
    name = "Frostfire Bolt (BF)",
    condition = function(state)
      return state.brainFreezeActive
    end,
    priority = 5,
    category = "proc",
    description = "Frostfire Bolt - zuzyj Brain Freeze natychmiast",
  },
  
  -- Priorytet 4: Ice Lance z Fingers of Frost
  {
    id = "ice_lance_fof2",
    spellId = SPELL_ICE_LANCE,
    name = "Ice Lance (FoF x2)",
    condition = function(state)
      return state.fofStacks >= 2
    end,
    priority = 6,
    category = "proc",
    description = "Ice Lance - masz 2 stacki FoF, wydaj jeden!",
  },
  {
    id = "ice_lance_fof1",
    spellId = SPELL_ICE_LANCE,
    name = "Ice Lance (FoF)",
    condition = function(state)
      return state.fofStacks >= 1
    end,
    priority = 7,
    category = "proc",
    description = "Ice Lance - zuzyj Fingers of Frost",
  },
  
  -- Priorytet 5: Maintenance - bomba i Invoker's Energy
  {
    id = "bomb_refresh",
    spellId = SPELL_LIVING_BOMB,
    name = "Bomb (refresh)",
    condition = function(state)
      return state.bombMissing or state.bombExpiring
    end,
    priority = 8,
    category = "maintenance",
    description = "Odswiez bombe na celu",
  },
  {
    id = "evocation_refresh",
    spellId = SPELL_EVOCATION,
    name = "Evocation",
    condition = function(state)
      return not state.invokersActive and state.evocationReady and state.duration > 10
    end,
    priority = 9,
    category = "maintenance",
    description = "Odswiez Invoker's Energy",
  },
  
  -- Priorytet 6: Filler
  {
    id = "frostbolt",
    spellId = SPELL_FROSTBOLT,
    name = "Frostbolt",
    condition = function(state)
      return true
    end,
    priority = 10,
    category = "filler",
    description = "Frostbolt - glowny filler",
  },
}

local function GetCurrentState(analyzer, fight)
  local state = {
    duration = 0,
    fofStacks = 0,
    brainFreezeActive = false,
    icyVeinsActive = false,
    invokersActive = false,
    bombMissing = false,
    bombExpiring = false,
    frozenOrbReady = false,
    icyVeinsReady = false,
    alterTimeReady = false,
    mirrorImageReady = false,
    evocationReady = false,
    petActive = true,
  }
  
  if not fight then return state end
  
  local now = GetTime()
  state.duration = now - (fight.startTime or now)
  
  -- Sprawdz buffy
  local hasFoF, fofCount = CheckPlayerBuff(SPELL_FINGERS_OF_FROST)
  state.fofStacks = hasFoF and (fofCount or 1) or 0
  
  local hasBF1, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE)
  local hasBF2, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE_ALT)
  state.brainFreezeActive = hasBF1 or hasBF2
  
  local hasIV1, _ = CheckPlayerBuff(SPELL_ICY_VEINS)
  local hasIV2, _ = CheckPlayerBuff(SPELL_ICY_VEINS_ALT)
  state.icyVeinsActive = hasIV1 or hasIV2
  
  state.invokersActive = CheckInvokersEnergy()
  
  -- Sprawdz cooldowny
  state.frozenOrbReady = utils.IsSpellReady(SPELL_FROZEN_ORB)
  state.icyVeinsReady = utils.IsSpellReady(SPELL_ICY_VEINS) or utils.IsSpellReady(SPELL_ICY_VEINS_ALT)
  state.alterTimeReady = utils.IsSpellReady(SPELL_ALTER_TIME)
  state.mirrorImageReady = utils.IsSpellReady(SPELL_MIRROR_IMAGE)
  state.evocationReady = utils.IsSpellReady(SPELL_EVOCATION)
  
  -- Sprawdz pet
  state.petActive = UnitExists and UnitExists("pet") or false
  
  -- Sprawdz bombe na target
  if UnitExists("target") and state.duration > 3 then
    local hasBomb, bombRemaining, bombType = CheckAnyBombOnTarget()
    
    if not hasBomb then
      state.bombMissing = true
    elseif bombRemaining > 0 and bombRemaining < 4 then
      state.bombExpiring = true
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
  
  return APL_PRIORITY[#APL_PRIORITY] -- Frostbolt jako fallback
end

function module.GetAPLPriorityList()
  return APL_PRIORITY
end

function module.GetRotationState(analyzer, fight)
  return GetCurrentState(analyzer, fight)
end

-- Sprawdza czy cast gracza byl optymalny wedlug APL
function module.EvaluateCast(analyzer, fight, spellId, timestamp)
  if not fight or not spellId then return nil end
  
  local state = GetCurrentState(analyzer, fight)
  local optimalAction = module.GetNextAPLAction(analyzer, fight)
  
  if not optimalAction then return nil end
  
  local result = {
    wasOptimal = false,
    castSpellId = spellId,
    optimalSpellId = optimalAction.spellId,
    optimalAction = optimalAction,
    penalty = 0,
    reason = nil,
  }
  
  -- Sprawdz czy cast byl optymalny
  if spellId == optimalAction.spellId then
    result.wasOptimal = true
    return result
  end
  
  -- Sprawdz czy cast jest akceptowalny (w tej samej kategorii lub wyzszym priorytecie)
  for _, action in ipairs(APL_PRIORITY) do
    if action.spellId == spellId and action.condition(state) then
      -- Gracz uzywal spella ktory tez jest aktywny w APL
      if action.priority <= optimalAction.priority + 2 then
        result.wasOptimal = true -- Akceptowalne
        return result
      end
    end
  end
  
  -- Cast nie byl optymalny - okresl kare
  local castName = GetSpellInfo(spellId) or "Unknown"
  local optimalName = optimalAction.name or GetSpellInfo(optimalAction.spellId) or "Unknown"
  
  -- Kluczowe bledy
  if state.brainFreezeActive and spellId == SPELL_FROSTBOLT then
    result.penalty = 3
    result.reason = "Frostbolt zamiast Frostfire Bolt z Brain Freeze"
  elseif state.fofStacks >= 2 and spellId == SPELL_FROSTBOLT then
    result.penalty = 2
    result.reason = "Frostbolt z 2 stackami FoF - ryzyko utraty proca"
  elseif spellId == SPELL_ICE_LANCE and state.fofStacks == 0 then
    result.penalty = 4
    result.reason = "Ice Lance bez Fingers of Frost - slaby damage"
  elseif optimalAction.category == "cooldown" and spellId == SPELL_FROSTBOLT then
    result.penalty = 1
    result.reason = "Cooldown gotowy ale nie uzyty: " .. optimalName
  else
    result.penalty = 1
    result.reason = "Optymalne bylo: " .. optimalName
  end
  
  return result
end

-- Inicjalizacja trackingu rotacji
function module.InitRotationTracking(fight)
  if not fight then return end
  fight.rotation = fight.rotation or {
    totalCasts = 0,
    optimalCasts = 0,
    suboptimalCasts = 0,
    mistakes = {},
    penaltySum = 0,
  }
end

-- Zapisz wynik ewaluacji casta
function module.RecordCastEvaluation(fight, evaluation, timestamp)
  if not fight or not fight.rotation or not evaluation then return end
  
  fight.rotation.totalCasts = fight.rotation.totalCasts + 1
  
  if evaluation.wasOptimal then
    fight.rotation.optimalCasts = fight.rotation.optimalCasts + 1
  else
    fight.rotation.suboptimalCasts = fight.rotation.suboptimalCasts + 1
    fight.rotation.penaltySum = fight.rotation.penaltySum + (evaluation.penalty or 0)
    
    if evaluation.reason then
      table.insert(fight.rotation.mistakes, {
        time = timestamp,
        spell = evaluation.castSpellId,
        reason = evaluation.reason,
        penalty = evaluation.penalty,
      })
      -- Limit mistakes array
      if #fight.rotation.mistakes > 50 then
        table.remove(fight.rotation.mistakes, 1)
      end
    end
  end
end

-- Metryka rotacji do analizy
function module.GetRotationScore(fight)
  if not fight or not fight.rotation then return nil end
  
  local rot = fight.rotation
  if rot.totalCasts == 0 then return nil end
  
  local accuracy = rot.optimalCasts / rot.totalCasts
  local avgPenalty = rot.penaltySum / math.max(1, rot.suboptimalCasts)
  
  -- Score: 100% accuracy = 100, kazdy procent mniej = -1 punkt
  -- Dodatkowa kara za ciezkie bledy (wysoki avgPenalty)
  local score = accuracy * 100
  score = score - (avgPenalty * rot.suboptimalCasts * 0.5)
  
  return {
    score = math.max(0, math.min(100, score)),
    accuracy = accuracy,
    totalCasts = rot.totalCasts,
    optimalCasts = rot.optimalCasts,
    suboptimalCasts = rot.suboptimalCasts,
    mistakes = rot.mistakes,
  }
end

-- Rozszerz GetLiveAdvice o info z APL
local originalGetLiveAdvice = module.GetLiveAdvice
function module.GetLiveAdvice(analyzer, fight)
  if not fight then return "" end
  
  -- Najpierw sprawdz krytyczne rzeczy
  local now = GetTime()
  local duration = now - fight.startTime
  
  if not CheckPlayerBuff(SPELL_INVOCERS_ENERGY) and duration > 10 then
    return "Brak Invoker's Energy - odswiez Evocation!"
  end
  
  if UnitExists and not UnitExists("pet") and duration > 8 then
    return "Summon Water Elemental!"
  end
  
  -- Uzyj APL do advice
  local nextAction = module.GetNextAPLAction(analyzer, fight)
  if nextAction then
    if nextAction.category == "proc" or nextAction.category == "cooldown" then
      return nextAction.description
    end
  end
  
  return ""
end

-- Rozszerz GetAdviceSpellIcon o info z APL
local originalGetAdviceSpellIcon = module.GetAdviceSpellIcon  
function module.GetAdviceSpellIcon(analyzer, fight)
  if not fight then return nil end
  
  local now = GetTime()
  local duration = now - fight.startTime
  
  if not CheckPlayerBuff(SPELL_INVOCERS_ENERGY) and duration > 10 then
    return SPELL_EVOCATION
  end
  
  if UnitExists and not UnitExists("pet") and duration > 8 then
    return SPELL_WATER_ELEMENTAL
  end
  
  local nextAction = module.GetNextAPLAction(analyzer, fight)
  if nextAction and nextAction.category ~= "filler" then
    return nextAction.spellId
  end
  
  return nil
end

Analyzer:RegisterClassModule("MAGE", module)



