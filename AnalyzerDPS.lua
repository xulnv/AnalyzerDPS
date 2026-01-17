local ADDON_NAME, Analyzer = ...

Analyzer = Analyzer or {}
Analyzer.VERSION = "0.70"
Analyzer.fight = nil
Analyzer.lastReport = nil
Analyzer.player = {}
Analyzer.ui = Analyzer.ui or {}
Analyzer.announced = false
Analyzer.announceAttempts = 0
Analyzer.precombatEvents = {}
Analyzer.precombatPotionLast = 0
Analyzer.classModules = Analyzer.classModules or {}
Analyzer.activeModule = Analyzer.activeModule or nil
Analyzer.utils = Analyzer.utils or {}
Analyzer.classModuleTemplates = Analyzer.classModuleTemplates or {}

local MAX_TIMELINE_MARKS = 80
local MAX_EVENT_LOG = 200
local PREPULL_WINDOW = 15

local COLORS = {
  good = { 0.20, 0.90, 0.20 },
  warn = { 1.00, 0.82, 0.00 },
  bad = { 1.00, 0.30, 0.30 },
  info = { 0.80, 0.80, 0.80 },
}

local UI_CLOSE_ICON = "Interface\\AddOns\\AnalyzerDPS\\Media\\UI\\close.png"
local UI_FRAME_COLOR = { 0.05, 0.05, 0.05, 0.92 }
local UI_BORDER_COLOR = { 0, 0, 0, 0.5 }

local SOUND_THROTTLE_WINDOW = 0.2

local DEFAULT_SETTINGS = {
  sounds = {},
  hintPosition = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 140,
  },
  hintUnlocked = false,
  soundChannel = "Master",
  language = "enUS",
}

Analyzer.locales = Analyzer.locales or {}

local ApplyTabButtonSkin
local SetTabSelected

function Analyzer:GetLocale()
  local settings = self.settings or DEFAULT_SETTINGS
  local lang = settings.language or "enUS"
  local locales = self.locales or {}
  return locales[lang] or locales["enUS"] or {}
end

function Analyzer:L(key)
  local locale = self:GetLocale()
  return locale[key] or key
end

local band = bit and bit.band or function()
  return 0
end

local function SafeLower(text)
  if not text then
    return ""
  end
  return string.lower(text)
end

local function NormalizeSpecName(specName)
  if type(specName) ~= "string" or specName == "" then
    return "Unknown"
  end
  return specName
end

local function RoundToTenth(value)
  return math.floor((value or 0) * 10 + 0.5) / 10
end

local function NormalizeSpecKey(specName)
  if type(specName) ~= "string" then
    return ""
  end
  local key = SafeLower(specName)
  key = key:gsub("%s+", "")
  key = key:gsub("[%-_]", "")
  return key
end

local function FormatTimeLabel(delta)
  local rounded = RoundToTenth(delta or 0)
  if rounded < 0 then
    return string.format("-%.1fs", math.abs(rounded))
  end
  return string.format("%.1fs", rounded)
end

local function NormalizeTimestamp(timestamp)
  local now = GetTime()
  if not timestamp then
    return now
  end
  if math.abs(timestamp - now) > 300 then
    return now
  end
  return timestamp
end

local function RainbowText(text)
  local colors = {
    "ff0000",
    "ff7f00",
    "ffff00",
    "00ff00",
    "00ffff",
    "0000ff",
    "8b00ff",
  }
  local out = {}
  local colorIndex = 1
  for i = 1, #text do
    local ch = text:sub(i, i)
    out[#out + 1] = "|cff" .. colors[colorIndex] .. ch
    colorIndex = colorIndex + 1
    if colorIndex > #colors then
      colorIndex = 1
    end
  end
  out[#out + 1] = "|r"
  return table.concat(out)
end

local function GetActiveModule()
  return Analyzer and Analyzer.activeModule
end

local function IsTrackedBuffSpell(spellId)
  local module = GetActiveModule()
  if module and module.IsTrackedBuffSpell then
    return module.IsTrackedBuffSpell(spellId)
  end
  return false
end

local function IsTrackedDebuffSpell(spellId)
  local module = GetActiveModule()
  if module and module.IsTrackedDebuffSpell then
    return module.IsTrackedDebuffSpell(spellId)
  end
  return false
end

local function IsSpellReady(spellId)
  if not spellId then
    return false
  end
  local usable = IsUsableSpell(spellId)
  if not usable then
    return false
  end
  local start, duration, enabled = GetSpellCooldown(spellId)
  if enabled == 0 then
    return false
  end
  if not start or start == 0 then
    return true
  end
  if not duration or duration <= 0 then
    return true
  end
  return (GetTime() - start) >= duration
end

local function PlayerHasAuraBySpellId(spellId)
  if not spellId then
    return false
  end
  if AuraUtil and AuraUtil.FindAuraBySpellId then
    return AuraUtil.FindAuraBySpellId(spellId, "player", "HELPFUL") ~= nil
  end
  for i = 1, 40 do
    local _, _, _, _, _, _, _, _, _, auraSpellId = UnitBuff("player", i)
    if not auraSpellId then
      break
    end
    if auraSpellId == spellId then
      return true
    end
  end
  return false
end

local function IsHostileFlags(flags)
  return flags and band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0) > 0
end

local function ShouldAutoStartFight(subevent, spellId, isPlayerSource, isPlayerDest, isAuraEvent, destFlags)
  if isPlayerSource then
    if subevent == "SPELL_DAMAGE"
      or subevent == "SPELL_PERIODIC_DAMAGE"
      or subevent == "RANGE_DAMAGE" then
      return true
    end
    if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_SUMMON" then
      if IsHostileFlags(destFlags) then
        return true
      end
    end
  end
  if isAuraEvent and isPlayerSource and IsTrackedDebuffSpell(spellId) then
    return true
  end
  if not (UnitAffectingCombat and UnitAffectingCombat("player")) then
    return false
  end
  if isPlayerSource then
    if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_SUMMON" then
      return true
    end
  end
  if isAuraEvent
    and (isPlayerSource or isPlayerDest)
    and (IsTrackedBuffSpell(spellId) or IsTrackedDebuffSpell(spellId)) then
    return true
  end
  return false
end

local function ResolveSpecInfo()
  if GetSpecialization then
    local specIndex = GetSpecialization()
    if specIndex and specIndex > 0 and GetSpecializationInfo then
      local specId, specName = GetSpecializationInfo(specIndex)
      return specId, NormalizeSpecName(specName), specIndex
    end
  end

  if GetPrimaryTalentTree then
    local tree = GetPrimaryTalentTree()
    if tree and GetTalentTabInfo then
      local name = GetTalentTabInfo(tree)
      return nil, NormalizeSpecName(name), tree
    end
  end

  if GetTalentTabInfo then
    local bestPoints = -1
    local bestIndex = nil
    local bestName = nil
    for i = 1, 3 do
      local name, _, points = GetTalentTabInfo(i)
      if points and points > bestPoints then
        bestPoints = points
        bestIndex = i
        bestName = NormalizeSpecName(name)
      end
    end
    return nil, NormalizeSpecName(bestName), bestIndex
  end

  return nil, "Unknown", nil
end

local function Clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function SafePercent(numerator, denominator)
  if not denominator or denominator <= 0 then
    return nil
  end
  return numerator / denominator
end

local function FormatPercent(value)
  if not value then
    return "n/a"
  end
  return string.format("%.0f%%", value * 100)
end

local function StatusForPercent(value, good, warn)
  if not value then
    return "info"
  end
  if value >= good then
    return "good"
  end
  if value >= warn then
    return "warn"
  end
  return "bad"
end

local function ExpectedUses(duration, cooldown, firstWindow)
  if duration < firstWindow then
    return 0
  end
  return 1 + math.floor((duration - firstWindow) / cooldown)
end

local function IsTrainingDummyName(name)
  local lower = SafeLower(name)
  return string.find(lower, "dummy", 1, true) ~= nil
    or string.find(lower, "manekin", 1, true) ~= nil
end

local function CountTableKeys(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

local function CopyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      CopyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

local function GetSpellIcon(spellId)
  return GetSpellTexture(spellId) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function AddIssue(issues, text)
  if text and text ~= "" then
    table.insert(issues, text)
  end
end

Analyzer.utils.SafeLower = SafeLower
Analyzer.utils.NormalizeSpecName = NormalizeSpecName
Analyzer.utils.NormalizeSpecKey = NormalizeSpecKey
Analyzer.utils.RoundToTenth = RoundToTenth
Analyzer.utils.FormatTimeLabel = FormatTimeLabel
Analyzer.utils.NormalizeTimestamp = NormalizeTimestamp
Analyzer.utils.Clamp = Clamp
Analyzer.utils.SafePercent = SafePercent
Analyzer.utils.FormatPercent = FormatPercent
Analyzer.utils.StatusForPercent = StatusForPercent
Analyzer.utils.ExpectedUses = ExpectedUses
Analyzer.utils.AddIssue = AddIssue
Analyzer.utils.GetSpellIcon = GetSpellIcon
Analyzer.utils.IsSpellReady = IsSpellReady
Analyzer.utils.PlayerHasAuraBySpellId = PlayerHasAuraBySpellId
Analyzer.utils.CountTableKeys = CountTableKeys

local PREPULL_POTION_SPELLS = {
  [105702] = true,
}

function Analyzer:IsPrecombatBuffSpell(spellId)
  if not spellId then
    return false
  end
  local module = self.activeModule
  if module and module.IsPrecombatBuffSpell then
    return module.IsPrecombatBuffSpell(spellId) == true
  end
  if PREPULL_POTION_SPELLS[spellId] then
    return true
  end
  local name = GetSpellInfo(spellId)
  if not name then
    return false
  end
  local lower = SafeLower(name)
  return string.find(lower, "potion", 1, true) ~= nil
    or string.find(lower, "mikstura", 1, true) ~= nil
end

function Analyzer:GetPlayerHistoryKey()
  local guid = UnitGUID("player") or (self.player and self.player.guid)
  if guid and guid ~= "" then
    return guid
  end
  local name, realm = UnitFullName and UnitFullName("player") or nil
  if not name then
    name = UnitName("player")
  end
  if not realm or realm == "" then
    realm = GetRealmName and GetRealmName() or ""
  end
  if name and name ~= "" then
    return name .. "-" .. (realm or "")
  end
  return "Unknown"
end

function Analyzer:AddEventLog(timestamp, label, spellId, prepull)
  local fight = self.fight
  if not fight then
    return
  end
  local now = NormalizeTimestamp(timestamp)
  local entry = {
    time = now,
    offset = now - (fight.startTime or now),
    label = label or "",
    spellId = spellId,
    prepull = prepull or false,
  }
  table.insert(fight.eventLog, entry)
  if #fight.eventLog > MAX_EVENT_LOG then
    table.remove(fight.eventLog, 1)
  end
end

function Analyzer:RecordPrecombatEvent(timestamp, label, spellId)
  local now = NormalizeTimestamp(timestamp)
  local last = self.precombatPotionLast or 0
  if (now - last) < 0.5 then
    return
  end
  self.precombatPotionLast = now
  table.insert(self.precombatEvents, {
    time = now,
    label = label or "",
    spellId = spellId,
    prepull = true,
  })
end

function Analyzer:ConsumePrecombatEvents()
  if not self.fight then
    return
  end
  local startTime = self.fight.startTime or GetTime()
  if not self.precombatEvents or #self.precombatEvents == 0 then
    return
  end
  for _, event in ipairs(self.precombatEvents) do
    if (startTime - event.time) <= PREPULL_WINDOW then
      table.insert(self.fight.eventLog, {
        time = event.time,
        offset = event.time - startTime,
        label = event.label,
        spellId = event.spellId,
        prepull = true,
      })
      if #self.fight.eventLog > MAX_EVENT_LOG then
        table.remove(self.fight.eventLog, 1)
      end
      self:AddTimelineEvent(event.spellId, event.time, "prepull")
    end
  end
  self.precombatEvents = {}
end

function Analyzer:GetDetailsDps()
  local details = _G._detalhes
  if type(details) ~= "table" then
    return nil
  end
  local combat = nil
  if details.GetCurrentCombat then
    combat = details:GetCurrentCombat()
  elseif details.tabela_vigente then
    combat = details.tabela_vigente
  end
  if not combat then
    return nil
  end

  local damageContainer = combat[1]
  if not damageContainer then
    return nil
  end
  local actors = damageContainer._ActorTable or damageContainer
  if not actors then
    return nil
  end

  local playerGUID = UnitGUID("player")
  local playerName = UnitName("player")
  local actor = nil
  for _, entry in pairs(actors) do
    if type(entry) == "table" then
      if entry.serial == playerGUID or entry.guid == playerGUID then
        actor = entry
        break
      end
      if entry.nome == playerName or entry.name == playerName then
        actor = entry
      end
    end
  end
  if not actor then
    return nil
  end

  local total = actor.total or actor.total_without_pet or actor.total_damage or actor.damage
  local duration = nil
  if combat.GetCombatTime then
    duration = combat:GetCombatTime()
  elseif combat.GetTime then
    duration = combat:GetTime()
  elseif combat.tempo then
    duration = combat.tempo
  end
  if not total or not duration or duration <= 0 then
    return nil
  end
  return total / duration
end

function Analyzer:GetDpsForReport(fight, duration)
  local detailsDps = self:GetDetailsDps()
  if detailsDps and detailsDps > 0 then
    return detailsDps, "Details"
  end
  if fight and fight.damage and duration and duration > 0 then
    return fight.damage / duration, "Log"
  end
  return nil, "n/a"
end

function Analyzer:AnnounceLoaded()
  if self.announced then
    return
  end
  local player = self.player or {}
  local classLabel = player.className or player.class or "Unknown"
  local specLabel = NormalizeSpecName(player.specName)
  local message = string.format(
    self:L("LOADED"),
    Analyzer.VERSION or "0.0",
    classLabel,
    specLabel
  )
  local coloredMessage = RainbowText(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(coloredMessage)
  else
    print(coloredMessage)
  end
  self.announced = true
end

function Analyzer:QueueAnnounce()
  if self.announced then
    return
  end
  self.announceAttempts = (self.announceAttempts or 0) + 1
  self:InitPlayer()
  if NormalizeSpecName(self.player.specName) ~= "Unknown" or self.announceAttempts >= 10 then
    self:AnnounceLoaded()
    return
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(1, function()
      Analyzer:QueueAnnounce()
    end)
  else
    self:AnnounceLoaded()
  end
end

function Analyzer:InitPlayer()
  local className, class = UnitClass("player")
  local race = UnitRace("player")
  local specId, specName, specIndex = ResolveSpecInfo()
  specName = NormalizeSpecName(specName)

  self.player = {
    guid = UnitGUID("player"),
    className = className or class or "Unknown",
    class = class or "UNKNOWN",
    race = race or "Unknown",
    specIndex = specIndex,
    specId = specId,
    specName = specName,
  }

  self:RunClassModulesHook("OnPlayerInit")
  self:ActivateClassModule()
end

function Analyzer:RegisterClassModule(classToken, module)
  if not classToken or type(module) ~= "table" then
    return
  end
  self.classModules[classToken] = self.classModules[classToken] or {}
  table.insert(self.classModules[classToken], module)
end

function Analyzer:GetClassModules(classToken)
  if not classToken then
    return {}
  end
  return self.classModules[classToken] or {}
end

function Analyzer:RunClassModulesHook(hookName, ...)
  local classToken = self.player and self.player.class or select(2, UnitClass("player"))
  if not classToken then
    return
  end
  local modules = self:GetClassModules(classToken)
  for _, module in ipairs(modules) do
    local handler = module and module[hookName]
    if handler then
      handler(self, ...)
    end
  end
end

function Analyzer:ActivateClassModule()
  local classToken = self.player and self.player.class or select(2, UnitClass("player"))
  if not classToken then
    self.activeModule = nil
    return
  end
  local selected = nil
  local modules = self:GetClassModules(classToken)
  for _, module in ipairs(modules) do
    if module and module.SupportsSpec then
      if module.SupportsSpec(self) then
        selected = module
        break
      end
    else
      selected = module
      break
    end
  end
  self.activeModule = selected
  if selected and selected.OnActivate then
    selected.OnActivate(self)
  end
  self:UpdateHintIcon()
end

function Analyzer:GetHintSpellId()
  local module = self.activeModule
  if module and module.GetHintSpellId then
    return module.GetHintSpellId(self)
  end
  return nil
end

function Analyzer:GetHintText()
  local module = self.activeModule
  if module and module.GetHintText then
    return module.GetHintText(self)
  end
  return "Uzyj umiejetnosci teraz"
end

function Analyzer:UpdateHintIcon()
  local ui = self.ui
  if not ui or not ui.hintFrame then
    return
  end
  local spellId = self:GetHintSpellId()
  if spellId then
    ui.hintFrame.icon:SetTexture(GetSpellIcon(spellId))
  else
    ui.hintFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
end

function Analyzer:InitSettings()
  AnalyzerDPSDB = AnalyzerDPSDB or {}
  if type(AnalyzerDPSDB.settings) ~= "table" then
    AnalyzerDPSDB.settings = {}
  end
  CopyDefaults(AnalyzerDPSDB.settings, DEFAULT_SETTINGS)
  self:ApplyModuleDefaults()
  self.settings = AnalyzerDPSDB.settings
end

function Analyzer:ApplyModuleDefaults()
  local settings = AnalyzerDPSDB and AnalyzerDPSDB.settings
  if not settings then
    return
  end
  for _, modules in pairs(self.classModules) do
    if type(modules) == "table" then
      for _, module in ipairs(modules) do
        if module.GetDefaultSettings then
          CopyDefaults(settings, module.GetDefaultSettings())
        end
      end
    end
  end
  self.settings = AnalyzerDPSDB.settings
end

function Analyzer:EnsureSoundEntry(key)
  if not key then
    return nil
  end
  self.settings = self.settings or {}
  self.settings.sounds = self.settings.sounds or {}
  self.settings.sounds[key] = self.settings.sounds[key] or {}
  return self.settings.sounds[key]
end

function Analyzer:GetSoundOptions()
  local module = self.activeModule
  if module and module.GetSoundOptions then
    return module.GetSoundOptions(self) or {}
  end
  return {}
end

function Analyzer:PlayAlertSound(key, timestamp)
  local settings = self.settings
  if not settings or not settings.sounds then
    return
  end
  local entry = settings.sounds[key]
  if not entry or entry.enabled ~= true then
    return
  end
  local soundPath = entry.sound
  if not soundPath or soundPath == "" then
    return
  end
  local now = NormalizeTimestamp(timestamp)
  self.soundThrottle = self.soundThrottle or {}
  local last = self.soundThrottle[key] or 0
  if (now - last) < SOUND_THROTTLE_WINDOW then
    return
  end
  self.soundThrottle[key] = now
  if PlaySoundFile then
    PlaySoundFile(soundPath, settings.soundChannel or "Master")
  elseif PlaySound then
    PlaySound(soundPath)
  end
end

function Analyzer:PlaySoundPreview(soundPath)
  if not soundPath or soundPath == "" then
    return
  end
  if PlaySoundFile then
    PlaySoundFile(soundPath, (self.settings and self.settings.soundChannel) or "Master")
  elseif PlaySound then
    PlaySound(soundPath)
  end
end

function Analyzer:ApplyHintPosition()
  local ui = self.ui
  if not ui or not ui.hintFrame then
    return
  end
  local settings = self.settings
  if not settings or not settings.hintPosition then
    return
  end
  local pos = settings.hintPosition
  ui.hintFrame:ClearAllPoints()
  ui.hintFrame:SetPoint(
    pos.point or "CENTER",
    UIParent,
    pos.relativePoint or "CENTER",
    pos.x or 0,
    pos.y or 0
  )
end

function Analyzer:SetHintOffset(x, y)
  local settings = self.settings
  if not settings or not settings.hintPosition then
    return
  end
  settings.hintPosition.x = x
  settings.hintPosition.y = y
  self:ApplyHintPosition()
end

function Analyzer:SaveHintPosition(point, relativePoint, x, y)
  local settings = self.settings
  if not settings or not settings.hintPosition then
    return
  end
  settings.hintPosition.point = point or "CENTER"
  settings.hintPosition.relativePoint = relativePoint or "CENTER"
  settings.hintPosition.x = math.floor((x or 0) + 0.5)
  settings.hintPosition.y = math.floor((y or 0) + 0.5)
  self:ApplyHintPosition()
  self:RefreshSettingsUI()
end

function Analyzer:SetHintPreview(enabled)
  local ui = self.ui
  if not ui or not ui.hintFrame then
    return
  end
  if enabled then
    ui.hintPreviewActive = true
    self:UpdateHintIcon()
    ui.hintFrame.text:SetText(self:GetHintText())
    ui.hintFrame.text:SetTextColor(1.00, 0.90, 0.20)
    ui.hintFrame:Show()
    return
  end
  if ui.hintPreviewActive then
    ui.hintFrame:Hide()
  end
  ui.hintPreviewActive = false
end

function Analyzer:RebuildSoundRows(frame)
  if not frame or not frame.CreateSoundRow or not frame.settingsContent then
    return
  end
  for _, row in pairs(frame.soundRows or {}) do
    row:Hide()
    row:SetParent(nil)
  end
  frame.soundRows = {}

  local options = self:GetSoundOptions()
  if frame.soundEmptyText then
    frame.soundEmptyText:SetShown(#options == 0)
  end
  local startY = -150
  local rowSpacing = 60
  for index, option in ipairs(options) do
    if option and option.key and option.label then
      local row = frame.CreateSoundRow(frame.settingsContent, startY - (index - 1) * rowSpacing, option.label, option.key)
      frame.soundRows[option.key] = row
    end
  end
end

function Analyzer:RefreshSettingsUI()
  local ui = self.ui
  if not ui or not ui.frame then
    return
  end
  local settings = self.settings or DEFAULT_SETTINGS
  local frame = ui.frame
  self:RebuildSoundRows(frame)
  frame.isRefreshing = true

  for key, row in pairs(frame.soundRows or {}) do
    local entry = settings.sounds and settings.sounds[key] or {}
    if row.enable then
      row.enable:SetChecked(entry.enabled == true)
    end
    if row.input then
      row.input:SetText(entry.sound or "")
      row.input:SetCursorPosition(0)
    end
  end

  local pos = settings.hintPosition or {}
  if frame.hintXSlider then
    local value = pos.x or 0
    frame.hintXSlider:SetValue(value)
    if frame.hintXSlider.valueText then
      frame.hintXSlider.valueText:SetText(string.format("%d", value))
    end
  end
  if frame.hintYSlider then
    local value = pos.y or 0
    frame.hintYSlider:SetValue(value)
    if frame.hintYSlider.valueText then
      frame.hintYSlider.valueText:SetText(string.format("%d", value))
    end
  end
  if frame.hintUnlockCheck then
    frame.hintUnlockCheck:SetChecked(settings.hintUnlocked == true)
  end
  if frame.hintPreviewCheck then
    frame.hintPreviewCheck:SetChecked(ui.hintPreviewActive == true)
  end

  if frame.languageDropdown then
    local currentLang = settings.language == "plPL" and "Polski" or "English"
    UIDropDownMenu_SetText(frame.languageDropdown, currentLang)
  end
  self:UpdateLanguageFlag(settings.language)

  frame.isRefreshing = false
end

function Analyzer:SwitchReportTab(tabIndex)
  local ui = self.ui
  if not ui or not ui.frame then
    return
  end
  local frame = ui.frame
  frame.reportActiveTab = tabIndex

  for i, tab in ipairs(frame.reportTabs or {}) do
    SetTabSelected(tab, i == tabIndex)
  end

  if frame.reportOverviewContent then
    frame.reportOverviewContent:SetShown(tabIndex == 1)
  end
  if frame.reportLogContent then
    frame.reportLogContent:SetShown(tabIndex == 2)
  end
  if frame.reportHistoryContent then
    frame.reportHistoryContent:SetShown(tabIndex == 3)
  end
end

function Analyzer:SwitchTab(tabIndex)
  local ui = self.ui
  if not ui or not ui.frame then
    return
  end

  local frame = ui.frame
  frame.activeTab = tabIndex

  for i, tab in ipairs(frame.tabs) do
    SetTabSelected(tab, i == tabIndex)
  end

  if frame.reportContent then
    frame.reportContent:Hide()
  end
  if frame.settingsContent then
    frame.settingsContent:Hide()
  end
  if frame.infoContent then
    frame.infoContent:Hide()
  end

  if tabIndex == 1 then
    if frame.reportContent then
      frame.reportContent:Show()
    end
    self:SwitchReportTab(frame.reportActiveTab or 1)
    if frame.hintPreviewCheck then
      frame.hintPreviewCheck:SetChecked(false)
    end
    self:SetHintPreview(false)
  elseif tabIndex == 2 then
    if frame.settingsContent then
      frame.settingsContent:Show()
    end
    self:RefreshSettingsUI()
  elseif tabIndex == 3 then
    if frame.infoContent then
      frame.infoContent:Show()
    end
    if frame.hintPreviewCheck then
      frame.hintPreviewCheck:SetChecked(false)
    end
    self:SetHintPreview(false)
  end
end

function Analyzer:InitLanguageDropdown()
  local frame = self.ui.frame
  if not frame or not frame.languageDropdown then
    return
  end

  UIDropDownMenu_Initialize(frame.languageDropdown, function(self, level)
    local info = UIDropDownMenu_CreateInfo()

    info.text = "English"
    info.value = "enUS"
    info.func = function()
      Analyzer:SetLanguage("enUS")
    end
    info.checked = (Analyzer.settings.language == "enUS")
    UIDropDownMenu_AddButton(info)

    info.text = "Polski"
    info.value = "plPL"
    info.func = function()
      Analyzer:SetLanguage("plPL")
    end
    info.checked = (Analyzer.settings.language == "plPL")
    UIDropDownMenu_AddButton(info)
  end)

  local currentLang = self.settings.language == "plPL" and "Polski" or "English"
  UIDropDownMenu_SetText(frame.languageDropdown, currentLang)
  self:UpdateLanguageFlag(self.settings.language)
end

function Analyzer:SetLanguage(lang)
  if not self.settings then
    return
  end
  self.settings.language = lang
  local langName = lang == "plPL" and "Polski" or "English"
  print(string.format(self:L("LANGUAGE_CHANGED"), langName))

  if self.ui and self.ui.frame and self.ui.frame.languageDropdown then
    UIDropDownMenu_SetText(self.ui.frame.languageDropdown, langName)
  end
  self:UpdateLanguageFlag(lang)
end

local function SetFlagTextures(flag, key, shown)
  local textures = flag and flag[key]
  if not textures then
    return
  end
  for _, texture in ipairs(textures) do
    texture:SetShown(shown)
  end
  if key == "us" and flag.usCanton then
    flag.usCanton:SetShown(shown)
  end
end

function Analyzer:UpdateLanguageFlag(lang)
  local frame = self.ui and self.ui.frame
  if not frame or not frame.languageFlag then
    return
  end
  local flag = frame.languageFlag
  local isPolish = lang == "plPL"
  SetFlagTextures(flag, "pl", isPolish)
  SetFlagTextures(flag, "us", not isPolish)
end

function Analyzer:StartFight(startTimestamp)
  if self.fight then
    return
  end
  self:InitPlayer()
  local startTime = NormalizeTimestamp(startTimestamp)
  self.fight = {
    startTime = startTime,
    endTime = nil,
    spells = {},
    buffs = {},
    buffUptime = {},
    debuffs = {},
    debuffUptime = {},
    timeline = {},
    eventLog = {},
    damage = 0,
    primaryTargetGUID = nil,
    primaryTargetName = nil,
    targets = {},
    kill = false,
    flags = {
      isBoss = false,
      isDummy = false,
    },
  }
  local module = self.activeModule
  if module and module.InitFight then
    module.InitFight(self, self.fight)
  end
  if module and module.OnFightStart then
    module.OnFightStart(self, startTime)
  end
  self:ConsumePrecombatEvents()
end

function Analyzer:FinalizeFight()
  if not self.fight then
    return
  end
  local endTime = self.fight.endTime or GetTime()
  for spellId, buff in pairs(self.fight.buffs) do
    if buff.since then
      self.fight.buffUptime[spellId] = (self.fight.buffUptime[spellId] or 0) + (endTime - buff.since)
    end
  end
  for spellId, debuff in pairs(self.fight.debuffs) do
    if debuff.since then
      self.fight.debuffUptime[spellId] = (self.fight.debuffUptime[spellId] or 0) + (endTime - debuff.since)
    end
  end
  local module = self.activeModule
  if module and module.FinalizeFight then
    module.FinalizeFight(self, self.fight, endTime)
  end
end

function Analyzer:EndFight()
  if not self.fight then
    return
  end
  local fightDuration = GetTime() - self.fight.startTime
  self.fight.endTime = GetTime()
  self:FinalizeFight()
  self:BuildReport()
  self.fight = nil

  if fightDuration >= 5 then
    if self.ui and self.ui.frame and self.lastReport then
      self.ui.frame:Show()
    end
  end
end

function Analyzer:AddTimelineEvent(spellId, timestamp, category)
  local now = NormalizeTimestamp(timestamp)
  table.insert(self.fight.timeline, {
    spellId = spellId,
    timestamp = now,
    offset = now - (self.fight.startTime or now),
    category = category or "cast",
  })
end

function Analyzer:RegisterIcyVeinsUse(now)
  local module = self.activeModule
  if module and module.RegisterIcyVeinsUse then
    module.RegisterIcyVeinsUse(self, now)
  end
end

function Analyzer:RegisterFrozenOrbUse(now)
  local module = self.activeModule
  if module and module.RegisterFrozenOrbUse then
    module.RegisterFrozenOrbUse(self, now)
  end
end

function Analyzer:HandleAlterTimeUse(now)
  local module = self.activeModule
  if module and module.HandleAlterTimeUse then
    module.HandleAlterTimeUse(self, now)
  end
end

function Analyzer:ExpirePendingBrainFreeze(now)
  local module = self.activeModule
  if module and module.ExpirePendingBrainFreeze then
    module.ExpirePendingBrainFreeze(self, now)
  end
end

function Analyzer:TrackDamage(amount)
  if not self.fight then
    return
  end
  if not amount or amount <= 0 then
    return
  end
  self.fight.damage = (self.fight.damage or 0) + amount
end

function Analyzer:TrackSpellCast(spellId, timestamp)
  local module = self.activeModule
  if module and module.TrackSpellCast then
    module.TrackSpellCast(self, spellId, timestamp)
  end
end

function Analyzer:TrackAura(subevent, spellId, amount, timestamp)
  local module = self.activeModule
  if module and module.TrackAura then
    module.TrackAura(self, subevent, spellId, amount, timestamp)
  end
end

function Analyzer:TrackDebuff(subevent, spellId, destGUID, destName, timestamp)
  local module = self.activeModule
  if module and module.TrackDebuff then
    module.TrackDebuff(self, subevent, spellId, destGUID, destName, timestamp)
  end
end

function Analyzer:MaybeShowAlterTimeHint(timestamp)
  local module = self.activeModule
  if module and module.MaybeShowAlterTimeHint then
    module.MaybeShowAlterTimeHint(self, timestamp)
  end
end

function Analyzer:TrackTarget(destGUID, destName, destFlags)
  if not destGUID then
    return
  end
  if not self.fight.primaryTargetGUID then
    self.fight.primaryTargetGUID = destGUID
  end
  if destName and self.fight.primaryTargetGUID == destGUID then
    self.fight.primaryTargetName = destName
  end
  self.fight.targets[destGUID] = true

  if destFlags and band(destFlags, COMBATLOG_OBJECT_TYPE_BOSS or 0) > 0 then
    self.fight.flags.isBoss = true
  end
  if destName and IsTrainingDummyName(destName) then
    self.fight.flags.isDummy = true
  end
end

function Analyzer:BuildReport()
  if not self.fight then
    return
  end

  local fight = self.fight
  local duration = (fight.endTime or GetTime()) - fight.startTime
  local targetCount = CountTableKeys(fight.targets)
  local isMultiTarget = targetCount >= 3
  local isSingleTarget = not isMultiTarget

  local context = {
    duration = duration,
    targetCount = targetCount,
    isSingleTarget = isSingleTarget,
    isMultiTarget = isMultiTarget,
    isBoss = fight.flags.isBoss,
    isDummy = fight.flags.isDummy,
  }

  if not self.player or not self.player.class then
    self:InitPlayer()
  end

  local report = nil
  local module = self.activeModule
  if module and module.Analyze then
    report = module.Analyze(self, fight, context)
  end
  if type(report) ~= "table" then
    report = {
      score = 0,
      metrics = {},
      issues = { "Brak reguly dla tej klasy/speca. Dodajemy je w kolejnym kroku." },
    }
  end

  report.context = context
  report.player = self.player
  report.timeline = fight.timeline
  report.eventLog = fight.eventLog
  report.duration = duration
  report.startTime = fight.startTime

  local dps, dpsSource = self:GetDpsForReport(fight, duration)
  report.dps = dps
  report.dpsSource = dpsSource

  self:StoreFightHistory(report, fight)

  self.lastReport = report
  self:RenderReport(report)
end

function Analyzer:UpdateMetricRow(row, metric)
  local color = COLORS[metric.status] or COLORS.info
  row.icon:SetTexture(GetSpellIcon(metric.spellId))
  row.label:SetText(metric.label)
  row.value:SetText(metric.valueText)
  row.value:SetTextColor(color[1], color[2], color[3])
  row.bar:SetMinMaxValues(0, 1)
  row.bar:SetValue(metric.percent or 0)
  row.bar:SetStatusBarColor(color[1], color[2], color[3])
  row:Show()
end

function Analyzer:RenderTimeline(report)
  local ui = self.ui
  if not ui or not ui.timeline then
    return
  end
  local timeline = ui.timeline
  local width = math.max(timeline:GetWidth(), 1)
  local duration = report.duration or 1
  local prepullWindow = PREPULL_WINDOW or 0
  local span = duration + prepullWindow
  if span <= 0 then
    span = 1
  end
  local index = 1

  for _, event in ipairs(report.timeline or {}) do
    if index > MAX_TIMELINE_MARKS then
      break
    end
    local offset = event.offset
    if offset == nil then
      offset = (event.timestamp - (report.startTime or 0))
    end
    local position = (offset + prepullWindow) / span
    position = Clamp(position, 0, 1)
    local icon = timeline.marks[index]
    icon:SetTexture(GetSpellIcon(event.spellId))
    local size = event.category == "proc" and 16 or 18
    if event.category == "prepull" then
      size = 16
    end
    icon:SetSize(size, size)
    local color = { 1.00, 1.00, 1.00 }
    if event.category == "proc" then
      color = { 0.70, 0.80, 1.00 }
    elseif event.category == "prepull" then
      color = { 1.00, 0.85, 0.30 }
    end
    icon:SetVertexColor(color[1], color[2], color[3])
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", timeline, "LEFT", position * width, 0)
    icon:Show()
    index = index + 1
  end

  for i = index, MAX_TIMELINE_MARKS do
    timeline.marks[i]:Hide()
  end

  if ui.timelineScale then
    ui.timelineScale:SetText(
      string.format(self:L("TIMELINE_SCALE"), prepullWindow, duration)
    )
  end
end

function Analyzer:StoreFightHistory(report, fight)
  if not report or not fight or not report.context then
    return
  end
  if not report.context.isBoss and not report.context.isDummy then
    return
  end
  AnalyzerDPSDB = AnalyzerDPSDB or {}
  AnalyzerDPSDB.fightHistoryByChar = AnalyzerDPSDB.fightHistoryByChar or {}
  local playerKey = self:GetPlayerHistoryKey()
  AnalyzerDPSDB.fightHistoryByChar[playerKey] = AnalyzerDPSDB.fightHistoryByChar[playerKey] or {}
  local history = AnalyzerDPSDB.fightHistoryByChar[playerKey]
  local entry = {
    time = date("%m-%d %H:%M"),
    name = fight.primaryTargetName or "Boss",
    duration = report.duration or 0,
    score = report.score or 0,
    dps = report.dps,
    kill = fight.kill == true,
    isBoss = report.context.isBoss == true,
    isDummy = report.context.isDummy == true,
    playerKey = playerKey,
    playerName = UnitName("player"),
    playerGuid = UnitGUID("player"),
  }
  table.insert(history, 1, entry)
  while #history > 10 do
    table.remove(history)
  end
end

function Analyzer:RenderHistory()
  local ui = self.ui
  if not ui or not ui.historyText or not ui.historyContent then
    return
  end
  local playerKey = self:GetPlayerHistoryKey()
  local history = AnalyzerDPSDB
    and AnalyzerDPSDB.fightHistoryByChar
    and AnalyzerDPSDB.fightHistoryByChar[playerKey]
    or {}
  if #history == 0 then
    ui.historyText:SetText(self:L("NO_HISTORY"))
    ui.historyContent:SetHeight(ui.historyText:GetStringHeight() + 6)
    return
  end
  local lines = {}
  for i, entry in ipairs(history) do
    local name = entry.name or "Boss"
    local duration = entry.duration or 0
    local status = entry.isDummy and self:L("DUMMY") or (entry.kill and self:L("KILL") or self:L("ATTEMPT"))
    local dpsText = entry.dps and entry.dps > 0 and string.format("DPS %.0f", entry.dps) or "DPS n/a"
    local scoreText = string.format("%s %d", self:L("SCORE"), entry.score or 0)
    table.insert(
      lines,
      string.format("%d) %s | %s | %.1fs | %s | %s | %s", i, entry.time or "--", name, duration, status, dpsText, scoreText)
    )
  end
  ui.historyText:SetText(table.concat(lines, "\n"))
  ui.historyContent:SetHeight(ui.historyText:GetStringHeight() + 6)
end

function Analyzer:RenderReport(report)
  local ui = self.ui
  if not ui or not ui.frame then
    return
  end

  if not report or not report.context or not report.player then
    print("AnalyzerDPS: " .. self:L("NO_REPORT"))
    return
  end

  local mode = report.context.isMultiTarget and self:L("MULTI_TARGET") or self:L("SINGLE_TARGET")
  ui.summary:SetText(
    string.format(
      "%s: %s | %s: %s | %s: %s | %s: %s",
      self:L("CLASS"), report.player.class,
      self:L("SPEC"), report.player.specName or "Unknown",
      self:L("RACE"), report.player.race,
      self:L("MODE"), mode
    )
  )
  ui.subsummary:SetText(
    string.format(
      "%s: %.1fs | %s: %d | %s: %s | %s: %s",
      self:L("TIME"), report.duration,
      self:L("TARGETS"), report.context.targetCount,
      self:L("BOSS"), report.context.isBoss and self:L("YES") or self:L("NO"),
      self:L("DUMMY"), report.context.isDummy and self:L("YES") or self:L("NO")
    )
  )

  local scoreColor = COLORS.good
  if report.score < 60 then
    scoreColor = COLORS.bad
  elseif report.score < 80 then
    scoreColor = COLORS.warn
  end
  ui.score:SetText(string.format("Ocena: %d / 100", report.score))
  ui.score:SetTextColor(scoreColor[1], scoreColor[2], scoreColor[3])

  if report.dps and report.dps > 0 then
    ui.dps:SetText(string.format("DPS (%s): %.0f", report.dpsSource or "log", report.dps))
  else
    ui.dps:SetText("DPS: n/a")
  end
  ui.duration:SetText(string.format("Czas walki: %.1fs", report.duration or 0))

  for i = 1, #ui.metricRows do
    local metric = report.metrics[i]
    if metric then
      self:UpdateMetricRow(ui.metricRows[i], metric)
    else
      ui.metricRows[i]:Hide()
    end
  end

  local issuesText = ""
  if #report.issues == 0 then
    issuesText = "Brak krytycznych problemow. Dalsze poprawki to optymalizacje."
  else
    local lines = {}
    for i, issue in ipairs(report.issues) do
      table.insert(lines, string.format("%d) %s", i, issue))
    end
    issuesText = table.concat(lines, "\n")
  end
  ui.issuesText:SetText(issuesText)
  ui.issuesContent:SetHeight(ui.issuesText:GetStringHeight() + 6)

  local logLines = {}
  local events = report.eventLog or {}
  table.sort(events, function(a, b)
    return (a.offset or a.time or 0) < (b.offset or b.time or 0)
  end)
  for i, event in ipairs(events) do
    if i > MAX_EVENT_LOG then
      break
    end
    local delta = event.offset
    if delta == nil then
      delta = (event.time or 0) - (report.startTime or 0)
    end
    local timeLabel = FormatTimeLabel(delta)
    local icon = event.spellId and GetSpellIcon(event.spellId) or nil
    local iconTag = icon and string.format("|T%s:12:12:0:0|t ", icon) or ""
    local label = event.label or ""
    if event.prepull or delta < 0 then
      label = label .. " (prepull)"
    end
    table.insert(logLines, string.format("%s[%s] %s", iconTag, timeLabel, label))
  end
  if #logLines == 0 then
    table.insert(logLines, "Brak logu z uzyc. Wejdz w walke i sprawdz ponownie.")
  end
  ui.logText:SetText(table.concat(logLines, "\n"))
  ui.logContent:SetHeight(ui.logText:GetStringHeight() + 6)

  self:RenderHistory()
  self:RenderTimeline(report)

  if not ui.frame:IsShown() then
    ui.frame:Show()
  end
end

local function ApplyUIButtonSkin(button)
  if not button then
    return
  end
  button:SetSize(16, 16)

  local normal = button:CreateTexture(nil, "BACKGROUND")
  normal:SetAllPoints()
  normal:SetTexture(UI_CLOSE_ICON)
  button:SetNormalTexture(normal)

  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetTexture(UI_CLOSE_ICON)
  highlight:SetVertexColor(1.00, 0.82, 0.20, 1.0)
  button:SetHighlightTexture(highlight)

  local pushed = button:CreateTexture(nil, "ARTWORK")
  pushed:SetAllPoints()
  pushed:SetTexture(UI_CLOSE_ICON)
  pushed:SetVertexColor(1.00, 1.00, 1.00, 0.8)
  button:SetPushedTexture(pushed)
end

ApplyTabButtonSkin = function(button)
  if not button then
    return
  end

  button:SetNormalFontObject("GameFontNormal")
  button:SetHighlightFontObject("GameFontNormal")
  button:SetDisabledFontObject("GameFontDisable")
  if button.Left then
    button.Left:Hide()
  end
  if button.Middle then
    button.Middle:Hide()
  end
  if button.Right then
    button.Right:Hide()
  end
  if button.LeftDisabled then
    button.LeftDisabled:Hide()
  end
  if button.MiddleDisabled then
    button.MiddleDisabled:Hide()
  end
  if button.RightDisabled then
    button.RightDisabled:Hide()
  end

  local skin = button.tabSkin or {}
  button.tabSkin = skin

  if not skin.normal then
    skin.normal = button:CreateTexture(nil, "BACKGROUND")
    skin.normal:SetAllPoints()
    skin.normal:SetTexture("Interface\\Buttons\\WHITE8X8")
    button:SetNormalTexture(skin.normal)
  end
  skin.normal:SetVertexColor(0.18, 0.18, 0.18, 0.85)

  if not skin.highlight then
    skin.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    skin.highlight:SetAllPoints()
    skin.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.highlight:SetVertexColor(0.35, 0.35, 0.35, 0.95)
    button:SetHighlightTexture(skin.highlight)
  end

  if not skin.pushed then
    skin.pushed = button:CreateTexture(nil, "ARTWORK")
    skin.pushed:SetAllPoints()
    skin.pushed:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.pushed:SetVertexColor(0.12, 0.12, 0.12, 0.95)
    button:SetPushedTexture(skin.pushed)
  end

  if not skin.border then
    skin.border = {}

    skin.border.top = button:CreateTexture(nil, "BORDER")
    skin.border.top:SetHeight(1)
    skin.border.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    skin.border.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    skin.border.top:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.top:SetVertexColor(0, 0, 0, 0.35)

    skin.border.bottom = button:CreateTexture(nil, "BORDER")
    skin.border.bottom:SetHeight(1)
    skin.border.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    skin.border.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    skin.border.bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.bottom:SetVertexColor(0, 0, 0, 0.35)

    skin.border.left = button:CreateTexture(nil, "BORDER")
    skin.border.left:SetWidth(1)
    skin.border.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    skin.border.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    skin.border.left:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.left:SetVertexColor(0, 0, 0, 0.35)

    skin.border.right = button:CreateTexture(nil, "BORDER")
    skin.border.right:SetWidth(1)
    skin.border.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    skin.border.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    skin.border.right:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.right:SetVertexColor(0, 0, 0, 0.35)
  end
end

SetTabSelected = function(button, selected)
  if not button then
    return
  end
  local skin = button.tabSkin
  if skin and skin.normal then
    if selected then
      skin.normal:SetVertexColor(0.12, 0.12, 0.12, 0.98)
    else
      skin.normal:SetVertexColor(0.20, 0.20, 0.20, 0.80)
    end
  end
  local text = button:GetFontString()
  if text then
    if selected then
      text:SetTextColor(1.00, 0.85, 0.10)
    else
      text:SetTextColor(0.75, 0.75, 0.75)
    end
  end
end

function Analyzer:ApplyUISkin(frame, options)
  if not frame then
    return
  end
  options = options or {}

  if frame.NineSlice then
    frame.NineSlice:Hide()
  end
  if frame.Bg then
    frame.Bg:Hide()
  end
  if frame.Inset then
    frame.Inset:Hide()
  end
  if frame.InsetBg then
    frame.InsetBg:Hide()
  end
  if frame.TitleBg then
    frame.TitleBg:Hide()
  end
  if frame.TitleBgLeft then
    frame.TitleBgLeft:Hide()
  end
  if frame.TitleBgRight then
    frame.TitleBgRight:Hide()
  end
  if frame.TitleText then
    frame.TitleText:Hide()
  end
  if frame.TopLeftCorner then
    frame.TopLeftCorner:Hide()
  end
  if frame.TopRightCorner then
    frame.TopRightCorner:Hide()
  end
  if frame.BottomLeftCorner then
    frame.BottomLeftCorner:Hide()
  end
  if frame.BottomRightCorner then
    frame.BottomRightCorner:Hide()
  end
  if frame.TopBorder then
    frame.TopBorder:Hide()
  end
  if frame.BottomBorder then
    frame.BottomBorder:Hide()
  end
  if frame.LeftBorder then
    frame.LeftBorder:Hide()
  end
  if frame.RightBorder then
    frame.RightBorder:Hide()
  end

  local skin = frame.uiSkin or {}
  frame.uiSkin = skin

  local color = options.color or UI_FRAME_COLOR
  local border = options.borderColor or UI_BORDER_COLOR
  local alpha = color[4]
  if options.alpha then
    alpha = Clamp(alpha * options.alpha, 0, 1)
  end

  if not skin.bg then
    skin.bg = frame:CreateTexture(nil, "BACKGROUND")
    skin.bg:SetAllPoints(frame)
    skin.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.bg:SetVertexColor(color[1], color[2], color[3], alpha)
  else
    skin.bg:SetVertexColor(color[1], color[2], color[3], alpha)
  end

  if not skin.border then
    skin.border = {}

    skin.border.top = frame:CreateTexture(nil, "BORDER")
    skin.border.top:SetHeight(1)
    skin.border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    skin.border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    skin.border.top:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.top:SetVertexColor(border[1], border[2], border[3], border[4])

    skin.border.bottom = frame:CreateTexture(nil, "BORDER")
    skin.border.bottom:SetHeight(1)
    skin.border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    skin.border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    skin.border.bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.bottom:SetVertexColor(border[1], border[2], border[3], border[4])

    skin.border.left = frame:CreateTexture(nil, "BORDER")
    skin.border.left:SetWidth(1)
    skin.border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    skin.border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    skin.border.left:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.left:SetVertexColor(border[1], border[2], border[3], border[4])

    skin.border.right = frame:CreateTexture(nil, "BORDER")
    skin.border.right:SetWidth(1)
    skin.border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    skin.border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    skin.border.right:SetTexture("Interface\\Buttons\\WHITE8X8")
    skin.border.right:SetVertexColor(border[1], border[2], border[3], border[4])
  end

  if not options.noTopLine then
    if not skin.topLine then
      skin.topLine = frame:CreateTexture(nil, "ARTWORK")
      skin.topLine:SetTexture("Interface\\Buttons\\WHITE8X8")
      skin.topLine:SetVertexColor(0.12, 0.12, 0.12, 0.8)
      skin.topLine:SetHeight(1)
      skin.topLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -28)
      skin.topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -28)
    end
    skin.topLine:Show()
  elseif skin.topLine then
    skin.topLine:Hide()
  end
end

local function CreateMetricRow(parent, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(parent:GetWidth(), 20)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * 22 - 18)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", 0, 0)

  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.label:SetText("")

  row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.value:SetPoint("RIGHT", -8, 0)
  row.value:SetText("")

  row.bar = CreateFrame("StatusBar", nil, row)
  row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  row.bar:SetMinMaxValues(0, 1)
  row.bar:SetValue(0)
  row.bar:SetSize(140, 8)
  row.bar:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
  row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
  row.bar.bg:SetAllPoints()
  row.bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  row.bar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

  return row
end

local function CreateReportFrame()
  local frame = CreateFrame("Frame", "AnalyzerDPSFrame", UIParent)
  frame:SetSize(760, 600)
  frame:SetPoint("CENTER")
  frame:Hide()
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetFrameStrata("HIGH")

  Analyzer:ApplyUISkin(frame)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("TOP", 0, -10)
  frame.title:SetText("xAnalyzerDPS")
  frame.title:SetTextColor(227 / 255, 186 / 255, 4 / 255)

  frame.closeButton = CreateFrame("Button", nil, frame)
  frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  frame.closeButton:SetSize(16, 16)
  frame.closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)
  ApplyUIButtonSkin(frame.closeButton)

  local function CreateTab(parent, index, text, onClick)
    local tab = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    tab:SetSize(100, 22)
    tab:SetPoint("TOPLEFT", 16 + (index - 1) * 105, -30)
    tab:SetText(text)
    tab:SetScript("OnClick", onClick)
    ApplyTabButtonSkin(tab)
    return tab
  end

  frame.tabs = {}
  frame.tabs[1] = CreateTab(frame, 1, "Report", function()
    Analyzer:SwitchTab(1)
  end)
  frame.tabs[2] = CreateTab(frame, 2, "Settings", function()
    Analyzer:SwitchTab(2)
  end)
  frame.tabs[3] = CreateTab(frame, 3, "Info", function()
    Analyzer:SwitchTab(3)
  end)

  frame.activeTab = 1

  local reportContent = CreateFrame("Frame", nil, frame)
  reportContent:SetAllPoints()
  reportContent:Show()
  frame.reportContent = reportContent

  local function CreateReportTab(parent, index, text, onClick)
    local tab = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    tab:SetSize(120, 20)
    tab:SetPoint("TOPLEFT", 16 + (index - 1) * 125, -60)
    tab:SetText(text)
    tab:SetScript("OnClick", onClick)
    ApplyTabButtonSkin(tab)
    return tab
  end

  frame.reportTabs = {}
  frame.reportTabs[1] = CreateReportTab(reportContent, 1, Analyzer:L("REPORT_SUMMARY"), function()
    Analyzer:SwitchReportTab(1)
  end)
  frame.reportTabs[2] = CreateReportTab(reportContent, 2, Analyzer:L("REPORT_LOG"), function()
    Analyzer:SwitchReportTab(2)
  end)
  frame.reportTabs[3] = CreateReportTab(reportContent, 3, Analyzer:L("REPORT_HISTORY"), function()
    Analyzer:SwitchReportTab(3)
  end)
  frame.reportActiveTab = 1

  local reportOverviewContent = CreateFrame("Frame", nil, reportContent)
  reportOverviewContent:SetAllPoints()
  reportOverviewContent:Show()
  frame.reportOverviewContent = reportOverviewContent

  local reportLogContent = CreateFrame("Frame", nil, reportContent)
  reportLogContent:SetAllPoints()
  reportLogContent:Hide()
  frame.reportLogContent = reportLogContent

  local reportHistoryContent = CreateFrame("Frame", nil, reportContent)
  reportHistoryContent:SetAllPoints()
  reportHistoryContent:Hide()
  frame.reportHistoryContent = reportHistoryContent

  frame.summary = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.summary:SetPoint("TOPLEFT", 16, -96)
  frame.summary:SetWidth(720)
  frame.summary:SetJustifyH("LEFT")

  frame.subsummary = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subsummary:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -4)
  frame.subsummary:SetWidth(720)
  frame.subsummary:SetJustifyH("LEFT")

  frame.score = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.score:SetPoint("TOPLEFT", frame.subsummary, "BOTTOMLEFT", 0, -8)
  frame.score:SetText("Ocena: 0 / 100")

  frame.dps = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.dps:SetPoint("TOPLEFT", frame.score, "BOTTOMLEFT", 0, -4)
  frame.dps:SetText("DPS: n/a")

  frame.duration = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.duration:SetPoint("TOPLEFT", frame.dps, "BOTTOMLEFT", 0, -2)
  frame.duration:SetText("Czas walki: 0.0s")

  local metricsFrame = CreateFrame("Frame", nil, reportOverviewContent)
  metricsFrame:SetSize(350, 220)
  metricsFrame:SetPoint("TOPLEFT", 16, -202)

  metricsFrame.title = metricsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  metricsFrame.title:SetPoint("TOPLEFT", 0, 0)
  metricsFrame.title:SetText("Metryki")
  metricsFrame.title:SetTextColor(1.00, 0.85, 0.10)

  metricsFrame.rows = {}
  for i = 1, 9 do
    metricsFrame.rows[i] = CreateMetricRow(metricsFrame, i)
  end

  local issuesFrame = CreateFrame("Frame", nil, reportOverviewContent)
  issuesFrame:SetSize(350, 220)
  issuesFrame:SetPoint("TOPRIGHT", -16, -202)

  issuesFrame.title = issuesFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  issuesFrame.title:SetPoint("TOPLEFT", 0, 0)
  issuesFrame.title:SetText("Problemy i sugestie")
  issuesFrame.title:SetTextColor(1.00, 0.85, 0.10)

  local scrollFrame = CreateFrame("ScrollFrame", "AnalyzerDPSIssuesScroll", issuesFrame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 0, -18)
  scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(1, 1)
  scrollFrame:SetScrollChild(content)

  local issuesText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  issuesText:SetPoint("TOPLEFT", 0, 0)
  issuesText:SetWidth(issuesFrame:GetWidth() - 28)
  issuesText:SetJustifyH("LEFT")
  issuesText:SetJustifyV("TOP")
  issuesText:SetText(Analyzer:L("NO_REPORT"))

  local logFrame = CreateFrame("Frame", nil, reportLogContent)
  logFrame:SetSize(720, 440)
  logFrame:SetPoint("TOPLEFT", 16, -96)

  logFrame.title = logFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  logFrame.title:SetPoint("TOPLEFT", 0, 0)
  logFrame.title:SetText(Analyzer:L("REPORT_LOG"))
  logFrame.title:SetTextColor(1.00, 0.85, 0.10)

  local logScroll = CreateFrame("ScrollFrame", "AnalyzerDPSLogScroll", logFrame, "UIPanelScrollFrameTemplate")
  logScroll:SetPoint("TOPLEFT", 0, -18)
  logScroll:SetPoint("BOTTOMRIGHT", -26, 0)

  local logContent = CreateFrame("Frame", nil, logScroll)
  logContent:SetSize(1, 1)
  logScroll:SetScrollChild(logContent)

  local logText = logContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  logText:SetPoint("TOPLEFT", 0, 0)
  logText:SetWidth(logFrame:GetWidth() - 28)
  logText:SetJustifyH("LEFT")
  logText:SetJustifyV("TOP")
  logText:SetText(Analyzer:L("NO_LOG"))

  local historyFrame = CreateFrame("Frame", nil, reportHistoryContent)
  historyFrame:SetSize(720, 440)
  historyFrame:SetPoint("TOPLEFT", 16, -96)

  historyFrame.title = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  historyFrame.title:SetPoint("TOPLEFT", 0, 0)
  historyFrame.title:SetText(Analyzer:L("REPORT_HISTORY"))
  historyFrame.title:SetTextColor(1.00, 0.85, 0.10)

  local historyScroll = CreateFrame("ScrollFrame", "AnalyzerDPSHistoryScroll", historyFrame, "UIPanelScrollFrameTemplate")
  historyScroll:SetPoint("TOPLEFT", 0, -18)
  historyScroll:SetPoint("BOTTOMRIGHT", -26, 0)

  local historyContent = CreateFrame("Frame", nil, historyScroll)
  historyContent:SetSize(1, 1)
  historyScroll:SetScrollChild(historyContent)

  local historyText = historyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  historyText:SetPoint("TOPLEFT", 0, 0)
  historyText:SetWidth(historyFrame:GetWidth() - 28)
  historyText:SetJustifyH("LEFT")
  historyText:SetJustifyV("TOP")
  historyText:SetText(Analyzer:L("NO_HISTORY"))

  local timelineLabel = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  timelineLabel:SetPoint("BOTTOMLEFT", 16, 78)
  timelineLabel:SetText(Analyzer:L("TIMELINE_LABEL"))

  local timeline = CreateFrame("Frame", nil, reportOverviewContent)
  timeline:SetPoint("BOTTOMLEFT", 16, 22)
  timeline:SetPoint("BOTTOMRIGHT", -16, 22)
  timeline:SetHeight(46)
  timeline:SetWidth(680)

  timeline.bg = timeline:CreateTexture(nil, "BACKGROUND")
  timeline.bg:SetAllPoints()
  timeline.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  timeline.bg:SetVertexColor(0.08, 0.08, 0.08, 0.85)

  timeline.line = timeline:CreateTexture(nil, "ARTWORK")
  timeline.line:SetPoint("LEFT", 0, 0)
  timeline.line:SetPoint("RIGHT", 0, 0)
  timeline.line:SetHeight(2)
  timeline.line:SetTexture("Interface\\Buttons\\WHITE8X8")
  timeline.line:SetVertexColor(0.30, 0.30, 0.30, 1)

  timeline.marks = {}
  for i = 1, MAX_TIMELINE_MARKS do
    local mark = timeline:CreateTexture(nil, "OVERLAY")
    mark:SetSize(12, 12)
    mark:Hide()
    timeline.marks[i] = mark
  end

  local timelineScaleLine = reportOverviewContent:CreateTexture(nil, "ARTWORK")
  timelineScaleLine:SetPoint("BOTTOMLEFT", 16, 16)
  timelineScaleLine:SetPoint("BOTTOMRIGHT", -16, 16)
  timelineScaleLine:SetHeight(1)
  timelineScaleLine:SetTexture("Interface\\Buttons\\WHITE8X8")
  timelineScaleLine:SetVertexColor(0.30, 0.30, 0.30, 0.8)

  local timelineScale = reportOverviewContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  timelineScale:SetPoint("BOTTOM", 0, 10)
  timelineScale:SetText(string.format(Analyzer:L("TIMELINE_SCALE"), 0, 0))

  Analyzer.ui.frame = frame
  Analyzer.ui.summary = frame.summary
  Analyzer.ui.subsummary = frame.subsummary
  Analyzer.ui.score = frame.score
  Analyzer.ui.dps = frame.dps
  Analyzer.ui.duration = frame.duration
  Analyzer.ui.metricRows = metricsFrame.rows
  Analyzer.ui.issuesText = issuesText
  Analyzer.ui.issuesContent = content
  Analyzer.ui.logText = logText
  Analyzer.ui.logContent = logContent
  Analyzer.ui.historyText = historyText
  Analyzer.ui.historyContent = historyContent
  Analyzer.ui.timeline = timeline
  Analyzer.ui.timelineScale = timelineScale

  local settingsContent = CreateFrame("Frame", nil, frame)
  settingsContent:SetAllPoints()
  settingsContent:Hide()
  frame.settingsContent = settingsContent

  local function SetCheckLabel(check, text)
    if check.Text then
      check.Text:SetText(text)
    elseif check.text then
      check.text:SetText(text)
    end
  end

  local languageTitle = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  languageTitle:SetPoint("TOPLEFT", 16, -60)
  languageTitle:SetText(Analyzer:L("LANGUAGE"))

  frame.languageDropdown = CreateFrame("Button", "AnalyzerDPSLanguageDropdown", settingsContent, "UIDropDownMenuTemplate")
  frame.languageDropdown:SetPoint("TOPLEFT", languageTitle, "BOTTOMLEFT", -16, -4)

  local function CreateLanguageFlag(parent, anchor)
    local flag = CreateFrame("Frame", nil, parent)
    flag:SetSize(20, 12)
    flag:SetPoint("LEFT", anchor, "RIGHT", -6, 2)

    flag.border = flag:CreateTexture(nil, "BORDER")
    flag.border:SetAllPoints()
    flag.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    flag.border:SetVertexColor(0, 0, 0, 0.6)

    flag.pl = {}
    flag.pl[1] = flag:CreateTexture(nil, "ARTWORK")
    flag.pl[1]:SetPoint("TOPLEFT", 1, -1)
    flag.pl[1]:SetPoint("TOPRIGHT", -1, -1)
    flag.pl[1]:SetHeight(5)
    flag.pl[1]:SetTexture("Interface\\Buttons\\WHITE8X8")
    flag.pl[1]:SetVertexColor(1, 1, 1, 1)

    flag.pl[2] = flag:CreateTexture(nil, "ARTWORK")
    flag.pl[2]:SetPoint("BOTTOMLEFT", 1, 1)
    flag.pl[2]:SetPoint("BOTTOMRIGHT", -1, 1)
    flag.pl[2]:SetHeight(5)
    flag.pl[2]:SetTexture("Interface\\Buttons\\WHITE8X8")
    flag.pl[2]:SetVertexColor(0.85, 0.1, 0.1, 1)

    flag.us = {}
    for i = 1, 6 do
      local stripe = flag:CreateTexture(nil, "ARTWORK")
      stripe:SetPoint("TOPLEFT", 1, -(i - 1) * 2 - 1)
      stripe:SetPoint("TOPRIGHT", -1, -(i - 1) * 2 - 1)
      stripe:SetHeight(2)
      stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
      if i % 2 == 1 then
        stripe:SetVertexColor(0.75, 0.1, 0.1, 1)
      else
        stripe:SetVertexColor(1, 1, 1, 1)
      end
      flag.us[i] = stripe
    end

    flag.usCanton = flag:CreateTexture(nil, "ARTWORK")
    flag.usCanton:SetPoint("TOPLEFT", 1, -1)
    flag.usCanton:SetSize(8, 6)
    flag.usCanton:SetTexture("Interface\\Buttons\\WHITE8X8")
    flag.usCanton:SetVertexColor(0.05, 0.2, 0.6, 1)

    return flag
  end

  frame.languageFlag = CreateLanguageFlag(settingsContent, frame.languageDropdown)

  local soundTitle = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  soundTitle:SetPoint("TOPLEFT", 16, -120)
  soundTitle:SetText(Analyzer:L("SOUND_TITLE"))

  local soundNote = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  soundNote:SetPoint("TOPLEFT", soundTitle, "BOTTOMLEFT", 0, -4)
  soundNote:SetText(Analyzer:L("SOUND_NOTE"))

  local function CreateSoundRow(parent, yOffset, label, key)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(500, 44)
    row:SetPoint("TOPLEFT", 16, yOffset)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("TOPLEFT", 0, 0)
    row.label:SetText(label)

    row.enable = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    row.enable:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", -4, -6)
    SetCheckLabel(row.enable, Analyzer:L("ENABLE_SOUND"))
    row.enable:SetScript("OnClick", function(self)
      local entry = Analyzer:EnsureSoundEntry(key)
      entry.enabled = self:GetChecked() == true
    end)

    row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.input:SetSize(240, 20)
    row.input:SetPoint("LEFT", row, "LEFT", 180, -18)
    row.input:SetAutoFocus(false)
    row.input:SetScript("OnEditFocusLost", function(self)
      local entry = Analyzer:EnsureSoundEntry(key)
      entry.sound = self:GetText() or ""
    end)
    row.input:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
    end)

    row.test = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
    row.test:SetSize(50, 20)
    row.test:SetPoint("LEFT", row.input, "RIGHT", 6, 0)
    row.test:SetText(Analyzer:L("TEST"))
    row.test:SetScript("OnClick", function()
      Analyzer:PlaySoundPreview(row.input:GetText())
    end)

    return row
  end

  frame.soundRows = {}
  frame.CreateSoundRow = CreateSoundRow

  frame.soundEmptyText = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.soundEmptyText:SetPoint("TOPLEFT", soundNote, "BOTTOMLEFT", 0, -12)
  frame.soundEmptyText:SetText(Analyzer:L("NO_SOUND_SETTINGS"))
  frame.soundEmptyText:Hide()

  local hintTitle = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hintTitle:SetPoint("TOPLEFT", 16, -340)
  hintTitle:SetText(Analyzer:L("HINT_POSITION"))

  local function CreatePositionSlider(parent, yOffset, label, axis)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 16, yOffset)
    slider:SetWidth(260)
    slider:SetMinMaxValues(-800, 800)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    if slider.Text then
      slider.Text:SetText(label)
    end
    if slider.Low then
      slider.Low:SetText("-800")
    end
    if slider.High then
      slider.High:SetText("800")
    end
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    slider:SetScript("OnValueChanged", function(self, value)
      if frame.isRefreshing then
        return
      end
      local rounded = math.floor(value + 0.5)
      if self.valueText then
        self.valueText:SetText(string.format("%d", rounded))
      end
      local settings = Analyzer.settings
      if not settings or not settings.hintPosition then
        return
      end
      if axis == "x" then
        settings.hintPosition.x = rounded
      else
        settings.hintPosition.y = rounded
      end
      Analyzer:ApplyHintPosition()
    end)

    return slider
  end

  frame.hintXSlider = CreatePositionSlider(settingsContent, -360, Analyzer:L("POSITION_X"), "x")
  frame.hintYSlider = CreatePositionSlider(settingsContent, -400, Analyzer:L("POSITION_Y"), "y")

  frame.hintUnlockCheck = CreateFrame("CheckButton", nil, settingsContent, "ChatConfigCheckButtonTemplate")
  frame.hintUnlockCheck:SetPoint("TOPLEFT", 16, -440)
  SetCheckLabel(frame.hintUnlockCheck, Analyzer:L("UNLOCK_HINT"))
  frame.hintUnlockCheck:SetScript("OnClick", function(self)
    local settings = Analyzer.settings
    if not settings then
      return
    end
    settings.hintUnlocked = self:GetChecked() == true
  end)

  frame.hintPreviewCheck = CreateFrame("CheckButton", nil, settingsContent, "ChatConfigCheckButtonTemplate")
  frame.hintPreviewCheck:SetPoint("TOPLEFT", frame.hintUnlockCheck, "BOTTOMLEFT", 0, -6)
  SetCheckLabel(frame.hintPreviewCheck, Analyzer:L("PREVIEW_HINT"))
  frame.hintPreviewCheck:SetScript("OnClick", function(self)
    Analyzer:SetHintPreview(self:GetChecked() == true)
  end)

  frame.resetButton = CreateFrame("Button", nil, settingsContent, "GameMenuButtonTemplate")
  frame.resetButton:SetSize(120, 22)
  frame.resetButton:SetPoint("TOPRIGHT", -16, -440)
  frame.resetButton:SetText(Analyzer:L("RESET_POSITION"))
  frame.resetButton:SetScript("OnClick", function()
    local settings = Analyzer.settings
    if not settings then
      return
    end
    settings.hintPosition = settings.hintPosition or {}
    settings.hintPosition.point = DEFAULT_SETTINGS.hintPosition.point
    settings.hintPosition.relativePoint = DEFAULT_SETTINGS.hintPosition.relativePoint
    settings.hintPosition.x = DEFAULT_SETTINGS.hintPosition.x
    settings.hintPosition.y = DEFAULT_SETTINGS.hintPosition.y
    Analyzer:ApplyHintPosition()
    Analyzer:RefreshSettingsUI()
  end)

  local infoContent = CreateFrame("Frame", nil, frame)
  infoContent:SetAllPoints()
  infoContent:Hide()
  frame.infoContent = infoContent

  local infoTitle = infoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  infoTitle:SetPoint("TOP", 0, -80)
  infoTitle:SetText("xAnalyzerDPS")
  infoTitle:SetTextColor(227 / 255, 186 / 255, 4 / 255)

  local versionText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  versionText:SetPoint("TOP", infoTitle, "BOTTOM", 0, -10)
  versionText:SetText("Version 0.70")

  local authorLabel = infoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  authorLabel:SetPoint("TOP", versionText, "BOTTOM", 0, -30)
  authorLabel:SetText("Author:")
  authorLabel:SetTextColor(0.8, 0.8, 0.8)

  local authorText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  authorText:SetPoint("TOP", authorLabel, "BOTTOM", 0, -5)
  authorText:SetText("xCzarownik69")
  authorText:SetTextColor(1.0, 0.82, 0.0)

  local guildLabel = infoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  guildLabel:SetPoint("TOP", authorText, "BOTTOM", 0, -30)
  guildLabel:SetText("Created for:")
  guildLabel:SetTextColor(0.8, 0.8, 0.8)

  local guildText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  guildText:SetPoint("TOP", guildLabel, "BOTTOM", 0, -5)
  guildText:SetText("REGRESS Guild")
  guildText:SetTextColor(0.8, 0.2, 0.8)

  local dedicationText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dedicationText:SetPoint("TOP", guildText, "BOTTOM", 0, -40)
  dedicationText:SetWidth(500)
  dedicationText:SetJustifyH("CENTER")
  dedicationText:SetText("Wtyczka stworzona dla poglebienia REGRESSu\npozdro dla wariatow z fartem")
  dedicationText:SetTextColor(0.9, 0.9, 0.9)

  local politicsText = infoContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  politicsText:SetPoint("BOTTOM", 0, 60)
  politicsText:SetText("jebac pis")
  politicsText:SetTextColor(1.0, 0.3, 0.3)

  local hint = CreateFrame("Frame", "AnalyzerDPSHintFrame", UIParent)
  hint:SetSize(260, 60)
  hint:SetPoint("CENTER", 0, 140)
  hint:Hide()
  hint:SetFrameStrata("HIGH")
  hint:SetMovable(true)
  hint:EnableMouse(true)
  hint:RegisterForDrag("LeftButton")
  hint:SetScript("OnDragStart", function(self)
    local settings = Analyzer.settings
    if settings and settings.hintUnlocked == true then
      self.dragging = true
      self:StartMoving()
    end
  end)
  hint:SetScript("OnDragStop", function(self)
    if not self.dragging then
      return
    end
    self.dragging = false
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    Analyzer:SaveHintPosition(point, relativePoint, x, y)
  end)

  Analyzer:ApplyUISkin(hint, { noTopLine = true, alpha = 0.9 })

  hint.icon = hint:CreateTexture(nil, "ARTWORK")
  hint.icon:SetSize(36, 36)
  hint.icon:SetPoint("LEFT", 12, 0)

  hint.text = hint:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  hint.text:SetPoint("LEFT", hint.icon, "RIGHT", 10, 0)
  hint.text:SetText(Analyzer:GetHintText())

  Analyzer.ui.hintFrame = hint
  Analyzer:UpdateHintIcon()

  for i, tab in ipairs(frame.tabs) do
    SetTabSelected(tab, i == 1)
  end
  for i, tab in ipairs(frame.reportTabs) do
    SetTabSelected(tab, i == 1)
  end

  return frame
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= ADDON_NAME then
      return
    end
    Analyzer:InitSettings()
    CreateReportFrame()
    Analyzer:InitLanguageDropdown()
    Analyzer:ApplyHintPosition()
    Analyzer:QueueAnnounce()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    Analyzer:QueueAnnounce()
    return
  end

  if event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    Analyzer:QueueAnnounce()
    return
  end

  if event == "PLAYER_REGEN_DISABLED" then
    Analyzer:StartFight()
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    Analyzer:EndFight()
    return
  end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local timestamp, subevent, _, srcGUID, srcName, _, _, destGUID, destName, destFlags, _, spellId, _, _, auraType, amount =
      CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player") or Analyzer.player.guid
    local playerName = UnitName("player")
    local isPlayerSource = srcGUID == playerGUID or (srcName and playerName and srcName == playerName)
    local isPlayerDest = destGUID == playerGUID or (destName and playerName and destName == playerName)
    local isAuraEvent = subevent == "SPELL_AURA_APPLIED"
      or subevent == "SPELL_AURA_APPLIED_DOSE"
      or subevent == "SPELL_AURA_REFRESH"
      or subevent == "SPELL_AURA_REMOVED"

    if not Analyzer.fight then
      if isAuraEvent
        and isPlayerDest
        and (auraType == "BUFF" or not auraType)
        and Analyzer:IsPrecombatBuffSpell(spellId) then
        local spellName = GetSpellInfo(spellId)
        local label = "Prepot: " .. (spellName or "Unknown")
        Analyzer:RecordPrecombatEvent(timestamp, label, spellId)
      end
      if ShouldAutoStartFight(subevent, spellId, isPlayerSource, isPlayerDest, isAuraEvent, destFlags) then
        Analyzer:StartFight(timestamp)
      end
      if not Analyzer.fight then
        return
      end
    end

    if isAuraEvent
      and isPlayerSource
      and IsTrackedDebuffSpell(spellId) then
      Analyzer:TrackDebuff(subevent, spellId, destGUID, destName, timestamp)
      return
    end

    if isAuraEvent
      and (isPlayerDest or isPlayerSource)
      and (auraType == "BUFF" or IsTrackedBuffSpell(spellId)) then
      Analyzer:TrackAura(subevent, spellId, amount, timestamp)
      return
    end

    if not isPlayerSource then
      return
    end

    if subevent == "SPELL_CAST_SUCCESS" and spellId then
      Analyzer:TrackSpellCast(spellId, timestamp)
    elseif subevent == "SPELL_SUMMON" and spellId then
      local module = Analyzer.activeModule
      if module and module.ShouldTrackSummonSpell and module.ShouldTrackSummonSpell(spellId) then
        Analyzer:TrackSpellCast(spellId, timestamp)
      end
    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
      Analyzer:TrackTarget(destGUID, destName, destFlags)
      Analyzer:TrackDamage(amount)
    elseif subevent == "UNIT_DIED" or subevent == "PARTY_KILL" then
      local fight = Analyzer.fight
      if fight and destGUID then
        if not fight.primaryTargetGUID then
          fight.primaryTargetGUID = destGUID
        end
        if destName and fight.primaryTargetGUID == destGUID then
          fight.primaryTargetName = destName
        end
        if fight.targets[destGUID] or fight.primaryTargetGUID == destGUID then
          if fight.flags.isBoss or (destFlags and band(destFlags, COMBATLOG_OBJECT_TYPE_BOSS or 0) > 0) then
            fight.kill = true
          end
        end
      end
    end
  end
end)

Analyzer.locales["enUS"] = {
  REPORT_SUMMARY = "Summary",
  REPORT_LOG = "Event Log",
  REPORT_HISTORY = "Fight History",
  NO_REPORT = "No report available.",
  NO_LOG = "No event log available.",
  NO_HISTORY = "No fight history available.",
  TIMELINE_LABEL = "Timeline",
  TIMELINE_SCALE = "Prepull: %.1fs | Fight: %.1fs",
  SCORE = "Score:",
  KILL = "KILL",
  ATTEMPT = "Attempt",
  DUMMY = "Dummy",
}

Analyzer.locales["plPL"] = {
  REPORT_SUMMARY = "Podsumowanie",
  REPORT_LOG = "Log Walki",
  REPORT_HISTORY = "Historia Walk",
  NO_REPORT = "Brak raportu.",
  NO_LOG = "Brak logu wydarzen.",
  NO_HISTORY = "Brak historii walk.",
  TIMELINE_LABEL = "Oś czasu",
  TIMELINE_SCALE = "Prepull: %.1fs | Walka: %.1fs",
  SCORE = "Ocena:",
  KILL = "KILL",
  ATTEMPT = "Proba",
  DUMMY = "Dummy",
}

SLASH_ANALYZERDPS1 = "/adps"
SlashCmdList["ANALYZERDPS"] = function(msg)
  msg = SafeLower(msg)
  if msg == "hide" then
    AnalyzerDPSFrame:Hide()
    return
  end
  if msg == "config" or msg == "settings" or msg == "ustawienia" then
    Analyzer:ToggleSettings()
    return
  end
  if msg == "debug" then
    print("AnalyzerDPS Debug:")
    print("  Klasa: " .. (Analyzer.player and Analyzer.player.class or "nil"))
    print("  Spec: " .. (Analyzer.player and Analyzer.player.specName or "nil"))
    print("  Active Module: " .. (Analyzer.activeModule and Analyzer.activeModule.name or "nil"))
    print("  Fight aktywny: " .. (Analyzer.fight and "tak" or "nie"))
    print("  Ostatni raport: " .. (Analyzer.lastReport and "tak" or "nie"))
    return
  end
  if AnalyzerDPSFrame:IsShown() then
    AnalyzerDPSFrame:Hide()
  else
    if Analyzer.lastReport then
      Analyzer:RenderReport(Analyzer.lastReport)
    else
      print("AnalyzerDPS: Brak raportu do wyswietlenia. Wejdz w walke i zakoncz ja, by zobaczyc analize.")
      AnalyzerDPSFrame:Show()
    end
  end
end
