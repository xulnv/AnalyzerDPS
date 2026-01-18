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

-- Popular sounds used in addons as alerts
Analyzer.RecommendedSounds = {
  {
    name = "Raid Warning",
    path = "Sound\\Interface\\RaidWarning.ogg",
    description = "Standard raid warning sound",
  },
  {
    name = "Map Ping",
    path = "Sound\\Interface\\MapPing.ogg",
    description = "Map ping sound",
  },
  {
    name = "Ready Check",
    path = "Sound\\Interface\\ReadyCheck.ogg",
    description = "Ready check sound",
  },
  {
    name = "Alarm Clock 1",
    path = "Sound\\Interface\\AlarmClockWarning1.ogg",
    description = "Quiet alarm",
  },
  {
    name = "Alarm Clock 2",
    path = "Sound\\Interface\\AlarmClockWarning2.ogg",
    description = "Medium alarm",
  },
  {
    name = "Alarm Clock 3",
    path = "Sound\\Interface\\AlarmClockWarning3.ogg",
    description = "Loud alarm",
  },
  {
    name = "Level Up",
    path = "Sound\\Interface\\LevelUp.ogg",
    description = "Level up sound",
  },
  {
    name = "Quest Complete",
    path = "Sound\\Interface\\iquestcomplete.ogg",
    description = "Quest complete sound",
  },
  {
    name = "Quest Activate",
    path = "Sound\\Interface\\iQuestActivate.ogg",
    description = "Quest accepted sound",
  },
  {
    name = "Bell (Alliance)",
    path = "Sound\\Doodad\\BellTollAlliance.ogg",
    description = "Alliance bell",
  },
  {
    name = "Bell (Horde)",
    path = "Sound\\Doodad\\BellTollHorde.ogg",
    description = "Horde bell",
  },
  {
    name = "Bell (Night Elf)",
    path = "Sound\\Doodad\\BellTollNightElf.ogg",
    description = "Night Elf bell",
  },
  {
    name = "Bell (Tribal)",
    path = "Sound\\Doodad\\BellTollTribal.ogg",
    description = "Tribal bell",
  },
  {
    name = "PVP Flag Taken",
    path = "Sound\\Interface\\PVPFlagTaken.ogg",
    description = "Flag taken sound",
  },
  {
    name = "PVP Flag Captured",
    path = "Sound\\Interface\\PVPFlagCaptured.ogg",
    description = "Flag captured sound",
  },
  {
    name = "Boss Warning",
    path = "Sound\\Interface\\RaidBossEmoteWarning.ogg",
    description = "Boss warning",
  },
  {
    name = "Boss Whisper",
    path = "Sound\\Interface\\RaidBossWhisperWarning.ogg",
    description = "Boss whisper",
  },
  {
    name = "Spell Activation",
    path = "Sound\\Interface\\SpellActivationOverlay.ogg",
    description = "Spell activation",
  },
  {
    name = "Auction Open",
    path = "Sound\\Interface\\AuctionWindowOpen.ogg",
    description = "Auction open",
  },
  {
    name = "UI Error",
    path = "Sound\\Interface\\Error.ogg",
    description = "UI error",
  },
  {
    name = "None",
    path = "",
    description = "No sound",
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
