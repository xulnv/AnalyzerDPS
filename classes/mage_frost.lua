local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

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
local SPELL_POTION_JADE_SERPENT = 105702
local SPELL_LIVING_BOMB = 44457
local SPELL_NETHER_TEMPEST = 114923

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
    if spellId == SPELL_FINGERS_OF_FROST and buff.stacks and buff.stacks > 0 then
      fight.procs.fofExpired = fight.procs.fofExpired + buff.stacks
    end
    if spellId == SPELL_BRAIN_FREEZE and not buff.consumed then
      fight.procs.bfExpired = fight.procs.bfExpired + 1
    end
  end
  if fight.procs.bfRemovedAt then
    fight.procs.bfExpired = fight.procs.bfExpired + 1
    fight.procs.bfRemovedAt = nil
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
  analyzer:AddEventLog(now, "Icy Veins", SPELL_ICY_VEINS)
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
  analyzer:AddEventLog(now, "Frozen Orb", SPELL_FROZEN_ORB)
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
    analyzer:AddEventLog(now, "Alter Time (optymalnie)", SPELL_ALTER_TIME)
  else
    analyzer:AddEventLog(now, "Alter Time (slaby timing)", SPELL_ALTER_TIME)
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

  if spellId == SPELL_WATER_ELEMENTAL then
    fight.flags.waterElementalActive = true
    analyzer:AddEventLog(now, "Water Elemental", SPELL_WATER_ELEMENTAL)
  end

  if spellId == SPELL_ICE_LANCE then
    local buff = fight.buffs[SPELL_FINGERS_OF_FROST]
    if buff and buff.stacks and buff.stacks > 0 then
      fight.counts.iceLanceWithFof = fight.counts.iceLanceWithFof + 1
      fight.procs.fofChargesUsed = fight.procs.fofChargesUsed + 1
      buff.stacks = math.max(buff.stacks - 1, 0)
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
        analyzer:AddEventLog(now, "Brain Freeze proc", SPELL_BRAIN_FREEZE)
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
        analyzer:AddEventLog(now, "Brain Freeze odswiezony", SPELL_BRAIN_FREEZE)
        analyzer:PlayAlertSound(SOUND_KEY_BRAIN_FREEZE, now)
      end
    end
    if spellId == SPELL_POTION_JADE_SERPENT then
      local lastPotion = fight.cooldowns.potionLast or 0
      if (now - lastPotion) > 0.5 then
        fight.cooldowns.potionLast = now
        analyzer:AddEventLog(now, "Potion of the Jade Serpent", SPELL_POTION_JADE_SERPENT)
      end
    end
    if spellId == SPELL_INVOCERS_ENERGY then
      fight.flags.invokersEnergySeen = true
    end
    if spellId == SPELL_FINGERS_OF_FROST and gainedFof then
      analyzer:AddEventLog(now, string.format("Fingers of Frost x%d", stacks), SPELL_FINGERS_OF_FROST)
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
  if not fight.bombSpellId then
    fight.bombSpellId = spellId
  end
  if fight.bombSpellId ~= spellId then
    return
  end
  if not fight.primaryTargetGUID then
    fight.primaryTargetGUID = destGUID
  end
  if destGUID and fight.primaryTargetGUID and destGUID ~= fight.primaryTargetGUID then
    return
  end
  if destGUID then
    fight.targets[destGUID] = true
  end

  local spellName = GetSpellInfo(spellId) or "Bomb"
  local debuff = fight.debuffs[spellId]
  if subevent == "SPELL_AURA_APPLIED" then
    fight.debuffs[spellId] = { since = now, targetGUID = destGUID }
    analyzer:AddEventLog(now, spellName .. " nalozony", spellId)
  elseif subevent == "SPELL_AURA_REFRESH" then
    if debuff and debuff.since then
      fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (now - debuff.since)
    end
    fight.debuffs[spellId] = { since = now, targetGUID = destGUID }
    analyzer:AddEventLog(now, spellName .. " odswiezony", spellId)
  elseif subevent == "SPELL_AURA_REMOVED" then
    if debuff and debuff.since then
      fight.debuffUptime[spellId] = (fight.debuffUptime[spellId] or 0) + (now - debuff.since)
    end
    fight.debuffs[spellId] = nil
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
    utils.AddIssue(issues, "Walka zbyt krotka na sensowna analize. Potrzebujesz co najmniej 15s.")
    return {
      score = 0,
      metrics = metrics,
      issues = issues,
    }
  end

  local fofUtil = utils.SafePercent(fofUsed, fofGained)
  local fofStatus = utils.StatusForPercent(fofUtil, 0.80, 0.65)
  AddMetric(
    "Fingers of Frost wykorzystanie",
    SPELL_FINGERS_OF_FROST,
    string.format("%s (%d/%d)", utils.FormatPercent(fofUtil), fofUsed, fofGained),
    fofUtil,
    fofStatus,
    fofStatus == "bad" and "Niskie wykorzystanie Fingers of Frost. Trzymaj Ice Lance na proci, nie spamuj Ice Lance bez Fingers of Frost i nie pozwalaj wygasac ladunkom."
      or (fofStatus == "warn" and "Srednie wykorzystanie Fingers of Frost. Staraj sie szybciej wydawac proci i unikaj Ice Lance bez Fingers of Frost." or nil),
    fofStatus == "bad" and 12 or (fofStatus == "warn" and 6 or 0)
  )

  local bfUtil = utils.SafePercent(bfUsed, bfProcs)
  local bfStatus = utils.StatusForPercent(bfUtil, 0.80, 0.60)
  AddMetric(
    "Brain Freeze wykorzystanie",
    SPELL_BRAIN_FREEZE,
    string.format("%s (%d/%d)", utils.FormatPercent(bfUtil), bfUsed, bfProcs),
    bfUtil,
    bfStatus,
    bfStatus == "bad" and "Zbyt wiele Brain Freeze wygasa. Po proc'u wrzuc Frostfire Bolt zaraz po biezacym spelle, nie trzymaj proca."
      or (bfStatus == "warn" and "Czesc Brain Freeze nie jest zuzywana. Priorytetuj Frostfire Bolt po proc'u." or nil),
    bfStatus == "bad" and 12 or (bfStatus == "warn" and 6 or 0)
  )

  local ilFofRatio = utils.SafePercent(fight.counts.iceLanceWithFof, iceLance)
  local ilStatus = utils.StatusForPercent(ilFofRatio, 0.75, 0.60)
  AddMetric(
    "Ice Lance na Fingers of Frost",
    SPELL_ICE_LANCE,
    string.format("%s (%d/%d)", utils.FormatPercent(ilFofRatio), fight.counts.iceLanceWithFof, iceLance),
    ilFofRatio,
    ilStatus,
    ilStatus == "bad" and "Za duzo Ice Lance bez Fingers of Frost w singlu. Ice Lance zostaw na proci, a bez Fingers of Frost castuj Frostbolt."
      or (ilStatus == "warn" and "Wciaz za duzo Ice Lance bez Fingers of Frost. Zmien priorytet na Frostbolt." or nil),
    ilStatus == "bad" and 10 or (ilStatus == "warn" and 5 or 0)
  )

  local castCore = frostbolt + iceLance + ffb
  local frostboltShare = utils.SafePercent(frostbolt, castCore)
  local fbStatus = utils.StatusForPercent(frostboltShare, 0.45, 0.35)
  if context.isSingleTarget then
    AddMetric(
      "Frostbolt udzial",
      SPELL_FROSTBOLT,
      utils.FormatPercent(frostboltShare),
      frostboltShare,
      fbStatus,
      fbStatus == "bad" and "Za malo Frostbolt w singlu. To glowny filler; utrzymuj casty i nie przerywaj bez potrzeby."
        or (fbStatus == "warn" and "Niski udzial Frostbolt. Zmniejsz Ice Lance bez Fingers of Frost i trzymaj glowny filler." or nil),
      fbStatus == "bad" and 10 or (fbStatus == "warn" and 4 or 0)
    )
  else
    AddMetric(
      "Frostbolt udzial (AoE)",
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
      "Icy Veins uzycia",
      SPELL_ICY_VEINS,
      string.format("%d/%d", icyVeins, expectedIcyVeins),
      math.min(icyPercent or 0, 1),
      icyStatus,
      icyVeins == 0 and context.duration >= 25 and "Brak Icy Veins w walce. Uzywaj na pullu i potem na cooldown, najlepiej z procami i trinketami."
        or (icyVeins < expectedIcyVeins and "Za malo Icy Veins. Staraj sie wciskac na cooldown, bez trzymania zbyt dlugo." or nil),
      icyVeins == 0 and 12 or (icyVeins < expectedIcyVeins and 6 or 0)
    )
  end

  local expectedFrozenOrb = utils.ExpectedUses(context.duration, COOLDOWN_FROZEN_ORB, 15)
  local orbPercent = utils.SafePercent(frozenOrb, expectedFrozenOrb)
  local orbStatus = utils.StatusForPercent(orbPercent, 1.0, 0.7)
  if expectedFrozenOrb > 0 then
    AddMetric(
      "Frozen Orb uzycia",
      SPELL_FROZEN_ORB,
      string.format("%d/%d", frozenOrb, expectedFrozenOrb),
      math.min(orbPercent or 0, 1),
      orbStatus,
      frozenOrb == 0 and context.duration >= 20 and "Brak Frozen Orb. To mocny cooldown generujacy Fingers of Frost; uzywaj na cooldown."
        or (frozenOrb < expectedFrozenOrb and "Za malo Frozen Orb. Wciskaj na cooldown, nawet w singlu." or nil),
      frozenOrb == 0 and 10 or (frozenOrb < expectedFrozenOrb and 4 or 0)
    )
  end

  local alterTotal = fight.counts.alterTimeTotal or (fight.spells[SPELL_ALTER_TIME] or 0)
  local alterGood = fight.counts.alterTimeGood or 0
  if alterTotal > 0 then
    local alterUtil = utils.SafePercent(alterGood, alterTotal)
    local alterStatus = utils.StatusForPercent(alterUtil, 0.70, 0.50)
    AddMetric(
      "Alter Time timing",
      SPELL_ALTER_TIME,
      string.format("%s (%d/%d)", utils.FormatPercent(alterUtil), alterGood, alterTotal),
      alterUtil,
      alterStatus,
      alterStatus == "bad" and "Alter Time uzywane poza oknem mocy. Wciskaj podczas Icy Veins i z Brain Freeze + Fingers of Frost lub 2x Fingers of Frost, by zduplikowac najmocniejsze proci."
        or (alterStatus == "warn" and "Alter Time nie zawsze w optymalnym oknie. Staraj sie laczyc je z Icy Veins i mocnymi procami." or nil),
      alterStatus == "bad" and 8 or (alterStatus == "warn" and 4 or 0)
    )
  elseif context.duration >= 30 then
    utils.AddIssue(issues, "Brak Alter Time. Uzywaj go podczas Icy Veins i mocnych procow (Brain Freeze + Fingers of Frost lub 2x Fingers of Frost), zeby zyskac dodatkowe buffy i proci.")
    score = utils.Clamp(score - 6, 0, 100)
  end

  local invokersUptime = utils.SafePercent(fight.buffUptime[SPELL_INVOCERS_ENERGY] or 0, context.duration) or 0
  local invokersStatus = utils.StatusForPercent(invokersUptime, 0.85, 0.70)
  AddMetric(
    "Invoker's Energy uptime",
    SPELL_INVOCERS_ENERGY,
    utils.FormatPercent(invokersUptime),
    invokersUptime,
    invokersStatus,
    invokersStatus == "bad" and "Za niski uptime Invoker's Energy (Evocation). Odnawiaj buff przed wygasnieciem."
      or (invokersStatus == "warn" and "Uptime Invoker's Energy moglby byc lepszy. Pilnuj odswiezenia." or nil),
    invokersStatus == "bad" and 10 or (invokersStatus == "warn" and 5 or 0)
  )

  if context.duration >= 20 and not fight.flags.waterElementalActive then
    utils.AddIssue(issues, "Brak Water Elemental. Upewnij sie, ze pet jest aktywny przez cala walke.")
    score = utils.Clamp(score - 6, 0, 100)
  end

  if fight.bombSpellId then
    local bombUptime = utils.SafePercent(fight.debuffUptime[fight.bombSpellId] or 0, context.duration)
    local bombStatus = utils.StatusForPercent(bombUptime, 0.85, 0.70)
    local bombName = GetSpellInfo(fight.bombSpellId) or "Bomb"
    AddMetric(
      "Bomb uptime (" .. bombName .. ")",
      fight.bombSpellId,
      utils.FormatPercent(bombUptime),
      bombUptime,
      bombStatus,
      bombStatus == "bad" and "Slaby uptime bomby na glownym celu. Odnawiaj 1-2s przed wygasnieciem, nie pozwalaj spasc."
        or (bombStatus == "warn" and "Uptime bomby moglby byc lepszy. Pilnuj odswiezenia przed wygasnieciem." or nil),
      bombStatus == "bad" and 8 or (bombStatus == "warn" and 4 or 0)
    )
  elseif context.isSingleTarget then
    utils.AddIssue(issues, "Brak aktywnej bomby (Living Bomb/Nether Tempest) na glownym celu. To staly DPS w singlu, utrzymuj ja caly czas.")
    score = utils.Clamp(score - 6, 0, 100)
  end

  if fight.procs.bfExpired > 0 then
    utils.AddIssue(issues, string.format("Brain Freeze wygaslo: %d. Zareaguj szybciej na proci i wrzucaj Frostfire Bolt po biezacym castcie.", fight.procs.bfExpired))
  end
  if fight.procs.fofExpired > 0 then
    utils.AddIssue(issues, string.format("Fingers of Frost wygaslo z %d ladunkami. Wydawaj proci szybciej i unikaj capowania 2 stackow.", fight.procs.fofExpired))
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

  local hasInvoker = utils.PlayerHasAuraBySpellId(SPELL_INVOCERS_ENERGY)
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

local function CheckPlayerBuff(spellId)
  if not spellId then return false, 0 end
  for i = 1, 40 do
    local name, _, count, _, _, _, _, _, _, auraSpellId = UnitBuff("player", i)
    if not name then break end
    if auraSpellId == spellId then
      return true, count or 1
    end
  end
  return false, 0
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

  local hasInvoker = CheckPlayerBuff(SPELL_INVOCERS_ENERGY)
  if not hasInvoker and duration > 10 then
    return "Brak Invoker's Energy - odswiez Evocation."
  end

  if UnitExists and not UnitExists("pet") and duration > 8 then
    return "Summon Water Elemental!"
  end

  local hasBrainFreeze, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE)
  if not hasBrainFreeze then
    hasBrainFreeze, _ = CheckPlayerBuff(SPELL_BRAIN_FREEZE_ALT)
  end
  if hasBrainFreeze then
    return "BF! Frostfire Bolt!"
  end

  local hasFoF, fofStacks = CheckPlayerBuff(SPELL_FINGERS_OF_FROST)
  if hasFoF then
    if fofStacks >= 2 then
      return "FoF x2! Ice Lance!"
    else
      return "FoF! Ice Lance!"
    end
  end

  if utils.IsSpellReady(SPELL_ICY_VEINS) and duration > 10 then
    return "Icy Veins gotowe - uzyj na cooldown!"
  end

  if utils.IsSpellReady(SPELL_FROZEN_ORB) and duration > 8 then
    return "Frozen Orb gotowy - wrzuc na cooldown!"
  end

  local bombSpellId = fight.bombSpellId or SPELL_LIVING_BOMB
  if bombSpellId and duration > 3 then
    local hasAnyBomb = fight.debuffs[bombSpellId] ~= nil or fight.debuffs[SPELL_NETHER_TEMPEST] ~= nil
    
    if not hasAnyBomb then
      return "Naloz bombe na jakiegos moba!"
    end
    
    if UnitExists("target") then
      local hasBomb, bombRemaining = CheckTargetDebuff(bombSpellId)
      local hasNT, ntRemaining = CheckTargetDebuff(SPELL_NETHER_TEMPEST)
      
      if hasBomb and bombRemaining > 0 and bombRemaining < 4 then
        return "Living Bomb wygasa na celu!"
      elseif hasNT and ntRemaining > 0 and ntRemaining < 4 then
        return "Nether Tempest wygasa na celu!"
      end
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

  local hasInvoker = CheckPlayerBuff(SPELL_INVOCERS_ENERGY)
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

Analyzer:RegisterClassModule("MAGE", module)



