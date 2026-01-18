local _, Analyzer = ...

if not Analyzer then
  return
end

-- Biblioteka dźwięków dostępnych w WoW Classic/MoP
-- Używaj tych ścieżek w ustawieniach sound alertów

Analyzer.SoundLibrary = {
  -- Interface sounds
  RaidWarning = "Sound\\Interface\\RaidWarning.ogg",
  MapPing = "Sound\\Interface\\MapPing.ogg",
  ReadyCheck = "Sound\\Interface\\ReadyCheck.ogg",
  LevelUp = "Sound\\Interface\\LevelUp.ogg",
  QuestComplete = "Sound\\Interface\\iquestcomplete.ogg",
  QuestActivate = "Sound\\Interface\\iQuestActivate.ogg",
  AlarmClockWarning1 = "Sound\\Interface\\AlarmClockWarning1.ogg",
  AlarmClockWarning2 = "Sound\\Interface\\AlarmClockWarning2.ogg",
  AlarmClockWarning3 = "Sound\\Interface\\AlarmClockWarning3.ogg",
  AuctionWindowOpen = "Sound\\Interface\\AuctionWindowOpen.ogg",
  AuctionWindowClose = "Sound\\Interface\\AuctionWindowClose.ogg",
  BellTollAlliance = "Sound\\Doodad\\BellTollAlliance.ogg",
  BellTollHorde = "Sound\\Doodad\\BellTollHorde.ogg",
  BellTollNightElf = "Sound\\Doodad\\BellTollNightElf.ogg",
  BellTollTribal = "Sound\\Doodad\\BellTollTribal.ogg",
  
  -- PvP sounds
  PVPFlagTaken = "Sound\\Interface\\PVPFlagTaken.ogg",
  PVPFlagCaptured = "Sound\\Interface\\PVPFlagCaptured.ogg",
  PVPFlagReset = "Sound\\Interface\\PVPFlagReset.ogg",
  PVPWarning = "Sound\\Interface\\PVPWarningAlliance.ogg",
  
  -- Combat sounds
  RaidBossEmoteWarning = "Sound\\Interface\\RaidBossEmoteWarning.ogg",
  RaidBossWhisperWarning = "Sound\\Interface\\RaidBossWhisperWarning.ogg",
  
  -- Spell sounds
  PowerAuras = {
    Alert1 = "Sound\\Spells\\PVPFlagTaken.ogg",
    Alert2 = "Sound\\Interface\\RaidWarning.ogg",
    Alert3 = "Sound\\Interface\\MapPing.ogg",
    Alert4 = "Sound\\Interface\\AlarmClockWarning3.ogg",
    Alert5 = "Sound\\Interface\\ReadyCheck.ogg",
  },
  
  -- UI sounds
  UITick = "Sound\\Interface\\uChatScrollButton.ogg",
  UIClick = "Sound\\Interface\\uCharacterSheetTab.ogg",
  UIOpen = "Sound\\Interface\\igMainMenuOpen.ogg",
  UIClose = "Sound\\Interface\\igMainMenuClose.ogg",
  UIError = "Sound\\Interface\\Error.ogg",
  
  -- Spell feedback
  SpellActivationOverlay = "Sound\\Interface\\SpellActivationOverlay.ogg",
  
  -- Creature sounds that work well as alerts
  Murloc = "Sound\\Creature\\Murloc\\mMurlocAggroOld.ogg",
  Dragon = "Sound\\Creature\\DragonYsondre\\DragonYsondreAggro.ogg",
}

-- Popularne dźwięki używane w addionach jako alerty
Analyzer.RecommendedSounds = {
  {
    name = "Raid Warning",
    path = "Sound\\Interface\\RaidWarning.ogg",
    description = "Standardowy dźwięk raid warning",
  },
  {
    name = "Map Ping",
    path = "Sound\\Interface\\MapPing.ogg",
    description = "Dźwięk pingu na mapie",
  },
  {
    name = "Ready Check",
    path = "Sound\\Interface\\ReadyCheck.ogg",
    description = "Dźwięk ready check",
  },
  {
    name = "Alarm Clock 1",
    path = "Sound\\Interface\\AlarmClockWarning1.ogg",
    description = "Cichy alarm",
  },
  {
    name = "Alarm Clock 2",
    path = "Sound\\Interface\\AlarmClockWarning2.ogg",
    description = "Średni alarm",
  },
  {
    name = "Alarm Clock 3",
    path = "Sound\\Interface\\AlarmClockWarning3.ogg",
    description = "Głośny alarm",
  },
  {
    name = "Level Up",
    path = "Sound\\Interface\\LevelUp.ogg",
    description = "Dźwięk level up",
  },
  {
    name = "Quest Complete",
    path = "Sound\\Interface\\iquestcomplete.ogg",
    description = "Dźwięk ukończenia questa",
  },
  {
    name = "Bell (Alliance)",
    path = "Sound\\Doodad\\BellTollAlliance.ogg",
    description = "Dzwon Alliance",
  },
  {
    name = "Bell (Horde)",
    path = "Sound\\Doodad\\BellTollHorde.ogg",
    description = "Dzwon Horde",
  },
  {
    name = "PVP Flag Taken",
    path = "Sound\\Interface\\PVPFlagTaken.ogg",
    description = "Dźwięk zabrania flagi",
  },
  {
    name = "Boss Warning",
    path = "Sound\\Interface\\RaidBossEmoteWarning.ogg",
    description = "Ostrzeżenie bossa",
  },
}

-- Helper function to get sound path by name
function Analyzer:GetSoundPath(soundName)
  for _, sound in ipairs(self.RecommendedSounds) do
    if sound.name == soundName then
      return sound.path
    end
  end
  return self.SoundLibrary[soundName] or soundName
end
