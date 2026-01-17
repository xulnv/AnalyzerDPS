local _, Analyzer = ...

if not Analyzer then
  return
end

Analyzer.locales = Analyzer.locales or {}
Analyzer.locales.enUS = {
  ADDON_NAME = "xAnalyzerDPS",
  LOADED = "xAnalyzerDPS v%s loaded. Detected: %s - %s.",
  NO_REPORT = "No report to display. Enter combat and finish it to see analysis.",
  FIGHT_TOO_SHORT = "Fight too short for meaningful analysis. Need at least 15s.",
  NO_MODULE = "No rules for this class/spec. We're adding them in the next step.",

  CLASS = "Class",
  SPEC = "Spec",
  RACE = "Race",
  MODE = "Mode",
  SINGLE_TARGET = "Single target",
  MULTI_TARGET = "Multi target",
  TIME = "Time",
  TARGETS = "Targets",
  BOSS = "Boss",
  DUMMY = "Dummy",
  YES = "yes",
  NO = "no",

  SCORE = "Score",
  DPS = "DPS",
  FIGHT_DURATION = "Fight duration",
  METRICS = "Metrics",
  ISSUES_SUGGESTIONS = "Issues and suggestions",
  NO_CRITICAL_ISSUES = "No critical issues. Further improvements are optimizations.",
  FIGHT_LOG = "Fight log",
  NO_LOG = "No usage log. Enter combat and check again.",
  BOSS_HISTORY = "Boss history",
  NO_HISTORY = "No boss history.",

  REPORT = "Report",
  REPORT_SUMMARY = "Summary",
  REPORT_LOG = "Fight log",
  REPORT_HISTORY = "History",
  SETTINGS = "Settings",
  SOUND_TITLE = "Proc and ability sounds",
  SOUND_NOTE = "Path to .ogg file (e.g. Sound\\\\Interface\\\\RaidWarning.ogg)",
  ENABLE_SOUND = "Enable sound",
  TEST = "Test",
  NO_SOUND_SETTINGS = "No sound settings for this class/spec.",

  HINT_POSITION = "Ability hint position",
  POSITION_X = "Position X",
  POSITION_Y = "Position Y",
  UNLOCK_HINT = "Unlock hint dragging",
  PREVIEW_HINT = "Preview hint",
  RESET_POSITION = "Reset position",

  TIMELINE_LABEL = "Timeline: cooldowns (white), procs (blue), prepull (yellow)",
  TIMELINE_SCALE = "Time scale: -%ds (prepull) | 0.0s | %.1fs",
  FOOTER = "Addon created to deepen REGRESS, greetings to the crazy ones with luck | fuck pis",

  KILL = "Kill",
  ATTEMPT = "Attempt",

  LANGUAGE = "Language",
  LANGUAGE_CHANGED = "Language changed to: %s. Reload UI (/reload) to apply changes.",
}
