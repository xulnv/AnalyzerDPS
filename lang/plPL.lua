local _, Analyzer = ...

if not Analyzer then
  return
end

Analyzer.locales = Analyzer.locales or {}
Analyzer.locales.plPL = {
  ADDON_NAME = "xAnalyzerDPS",
  LOADED = "xAnalyzerDPS v%s zaladowany. Wykryto: %s - %s.",
  NO_REPORT = "Brak raportu do wyswietlenia. Wejdz w walke i zakoncz ja, by zobaczyc analize.",
  FIGHT_TOO_SHORT = "Walka zbyt krotka na sensowna analize. Potrzebujesz co najmniej 15s.",
  NO_MODULE = "Brak reguly dla tej klasy/speca. Dodajemy je w kolejnym kroku.",

  CLASS = "Klasa",
  SPEC = "Spec",
  RACE = "Rasa",
  MODE = "Tryb",
  SINGLE_TARGET = "Single target",
  MULTI_TARGET = "Multi target",
  TIME = "Czas",
  TARGETS = "Cele",
  BOSS = "Boss",
  DUMMY = "Dummy",
  YES = "tak",
  NO = "nie",

  SCORE = "Ocena",
  DPS = "DPS",
  FIGHT_DURATION = "Czas walki",
  METRICS = "Metryki",
  ISSUES_SUGGESTIONS = "Problemy i sugestie",
  NO_CRITICAL_ISSUES = "Brak krytycznych problemow. Dalsze poprawki to optymalizacje.",
  FIGHT_LOG = "Log walki",
  NO_LOG = "Brak logu z uzyc. Wejdz w walke i sprawdz ponownie.",
  BOSS_HISTORY = "Historia bossow",
  NO_HISTORY = "Brak historii bossow.",

  REPORT = "Raport",
  REPORT_SUMMARY = "Podsumowanie",
  REPORT_LOG = "Log walki",
  REPORT_HISTORY = "Historia",
  SETTINGS = "Ustawienia",
  SOUND_TITLE = "Dzwieki prockow i umiejetnosci",
  SOUND_NOTE = "Sciezka pliku .ogg (np. Sound\\\\Interface\\\\RaidWarning.ogg)",
  ENABLE_SOUND = "Wlacz dzwiek",
  TEST = "Test",
  NO_SOUND_SETTINGS = "Brak ustawien dzwiekow dla tej klasy/speca.",

  HINT_POSITION = "Pozycja informatora umiejetnosci",
  POSITION_X = "Pozycja X",
  POSITION_Y = "Pozycja Y",
  UNLOCK_HINT = "Odblokuj przesuwanie informatora",
  PREVIEW_HINT = "Podglad informatora",
  RESET_POSITION = "Reset pozycji",

  TIMELINE_LABEL = "Timeline: cooldowny (biale), proci (niebieskie), prepull (zolte)",
  TIMELINE_SCALE = "Skala czasu: -%ds (prepull) | 0.0s | %.1fs",
  FOOTER = "Wtyczka stworzona dla poglebienia REGRESSu pozdro dla wariatow z fartem | jebac pis",

  KILL = "Kill",
  ATTEMPT = "Proba",

  LANGUAGE = "Jezyk",
  LANGUAGE_CHANGED = "Jezyk zmieniony na: %s. Przeladuj UI (/reload) aby zastosowac zmiany.",
}
