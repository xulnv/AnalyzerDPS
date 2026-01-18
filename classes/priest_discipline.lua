local _, Analyzer = ...

if not Analyzer then
  return
end

local module = {}
local utils = Analyzer.utils

module.name = "Priest - Discipline"
module.class = "PRIEST"
module.specKey = "discipline"
module.specIndex = 1

function module.IsTrackedBuffSpell(spellId)
  return false
end

function module.IsTrackedDebuffSpell(spellId)
  return false
end

function module.IsTrackedCast(spellId)
  return false
end

function module.ShouldRecordCast(event)
  return false
end

function module.GetSoundOptions()
  return {}
end

function module.GetProcInfo(spellId)
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

function module.Analyze(context)
  return {
    score = 0,
    metrics = {},
    issues = { "Module not yet implemented. Analysis coming soon!" },
  }
end

Analyzer:RegisterClassModule(module.class, module)
