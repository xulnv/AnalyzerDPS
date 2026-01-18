# AnalyzerDPS - Changelog

## Version 0.89 (2026-01-18)

### Fixed
- **Rogue - Vanish Combat Drop**: Fixed issue where Vanish would end combat log prematurely
  - Added 2.5 second delay before ending fight when leaving combat
  - If player re-enters combat during delay (e.g., after Vanish), fight continues normally
  - Prevents combat log from ending when using Vanish as opener or mid-fight
  - Works for all abilities that drop combat (Feign Death, Shadowmeld, etc.)

### Technical
- Added `pendingFightEnd` flag to track delayed fight end
- `PLAYER_REGEN_DISABLED` now cancels pending fight end
- `EndFight()` checks if player is still in combat after delay before finalizing

---

## Version 0.88 (2026-01-18)

### Fixed
- **Shadow Priest - Mind Blast Tracking**: Fixed Mind Blast not being counted properly
  - Added support for all Mind Blast ranks (Rank 1-9)
  - All ranks now normalized to base spell ID for accurate tracking
  - Mind Blast casts now appear in event log
- **Shadow Priest - Shadowform Detection**: Improved Shadowform buff tracking
  - Added event log entry when Shadowform is activated
  - Better uptime calculation for Shadowform metric

### Technical
- Added Mind Blast rank spell IDs: 8205, 8206, 10945, 10946, 10947, 25372, 25375, 48126, 48127
- All Mind Blast ranks tracked in TRACKED_CASTS
- Spell ID normalization in TrackSpellCast for consistent counting
- Enhanced event logging for Shadow Priest abilities

---

## Version 0.87 (2026-01-18)

### Fixed
- **Browse Button**: Fixed sound selection dropdown menu - now works correctly with proper event handling
- **Suggestions Tab**: Fixed hardcoded Polish text "Sugestie" - now uses translation key
- **UI Localization**: All UI texts now properly translated (Score, DPS, Duration, etc.)
- **No Critical Issues Message**: Fixed hardcoded Polish text in suggestions view
- **Event Log**: Fixed "No log" message translation

### Added
- **Full English Localization**: Complete translation of all Mage (Frost) texts
  - 66 translation keys for issues and suggestions
  - 10 translation keys for metric labels
  - 8 translation keys for live advice messages
  - 10 translation keys for event log entries
- **Sound Library Improvements**:
  - All sound descriptions now in English (were in Polish)
  - Dropdown menu shows sound name + description
  - Tooltip on Browse button explaining functionality
  - 22 pre-configured sound options available

### Improved
- **Sound Selection UX**: Browse button renamed from "Preset" to "Browse..." with helpful tooltip
- **Dropdown Menu**: Shows full descriptions: "Sound Name - Description"
- **Translation System**: All hardcoded Polish strings replaced with L() function calls

### Technical
- Added `REPORT_SUGGESTIONS` translation key
- Updated all metric labels to use translation keys
- Updated all issue messages to use translation keys
- Updated all event log entries to use translation keys
- Updated all live advice messages to use translation keys
- Fixed Browse button with `notCheckable` and named dropdown frame

---

## Version 0.76 (2026-01-17)

### Fixed
- **Living Bomb Detection**: Naprawiono wykrywanie Living Bomb - teraz sprawdza czy JAKIKOLWIEK cel ma bombę, nie tylko aktualny target
  - Nie krzyczy już o bombę gdy jest nałożona na innym celu
  - Ostrzega tylko gdy bomba wygasa na aktualnym celu (<4s)
- **Scoring Algorithm**: Dodano metrykę efektywności castowania do oceny
  - Porównuje ilość wykonanych castów do oczekiwanej ilości
  - Za mało castów = niższa ocena (penalty do 15 punktów)
  - Uzyskanie 100 punktów wymaga teraz aktywnego grania

### Added
- **Clear All History Button**:
  - Przycisk "Wyczyść Całą Historię" w zakładce History
  - Dialog potwierdzenia przed usunięciem
  - Zlokalizowany (PL/EN)
- **Cast Efficiency Metric**:
  - Nowa metryka w raportach: "Efektywność castowania"
  - Pokazuje X/Y castów (Z%)
  - Penalizuje downtime i przerwy w DPS
- **Warlock Affliction Module** (NOWY - KOMPLETNY):
  - Śledzenie DoT uptime (Agony, Corruption, UA, Haunt)
  - Nightfall proc detection z dźwiękiem
  - Dark Soul cooldown tracking
  - Live advice z ikonami spelli
  - Cast efficiency metric
- **STATUS.md**: Nowy dokument ze statusem rozwoju addona

### Improved
- **Mini Live Window**: Całkowicie przeprojektowane
  - Większe okno (320x140)
  - Osobny kontener dla porad z własnym tłem
  - Większa ikona (40x40) po lewej stronie
  - Większy tekst (font 14 z outline)
  - Biały tekst zamiast czerwonego - lepiej widoczny
  - Automatyczne ukrywanie gdy brak porad

### Technical
- Dodano funkcję `ClearAllHistory()` do czyszczenia historii
- Dodano `StaticPopupDialogs["ANALYZER_CLEAR_ALL_HISTORY"]`
- Zaktualizowano `CheckTargetDebuff` aby zwracał czas pozostały
- Rozszerzono lokalizację o nowe klucze

---

## Version 0.75 (2026-01-17)

### Fixed
- **Rogue Combat Module**: Naprawiono problem z brakiem danych w podsumowaniu - poprawiono sygnaturę funkcji `Analyze`
- **Summary Window Bug**: Dodano lepszą obsługę błędów i 0.1s opóźnienie przy otwieraniu okna po walce
- **Live Tips Refresh**: Wszystkie moduły klas używają teraz real-time sprawdzania aur zamiast cache'owanych danych
  - Mage Frost, Shaman Elemental, Warrior Arms, Priest Shadow, Rogue Combat
- **Module Signatures**: Ujednolicono sygnatury funkcji `Analyze` we wszystkich modułach

### Added
- **Enhanced Mini Window**: 
  - Większe okno (280x120) z lepszą czytelnością
  - Wsparcie dla ikon spelli w podpowiedziach
  - Większy, bardziej widoczny tekst (czerwony z cieniem)
  - Funkcja `GetAdviceSpellIcon` w modułach klas
- **Persistent History System**:
  - Historia walk zapisywana w SavedVariables (przetrwa reload/relog)
  - Zwiększony limit historii do 20 walk
  - Klikalne przyciski historii z pełnymi szczegółami
  - Ładowanie pełnych raportów z historii
  - Lepsze formatowanie z kolorami według wyniku
- **Clear Report Button**: 
  - Przycisk do czyszczenia obecnego raportu
  - Dialog potwierdzenia przed usunięciem
  - Lokalizacja PL/EN
- **Minimap Icon Improvements**:
  - Zmieniona nazwa na "Rotation Analyzer"
  - Wyświetlanie wersji addona
  - Zlokalizowane opisy kliknięć

### Improved
- **History Display**: Całkowicie przeprojektowane UI historii z przyciskami zamiast tekstu
- **Data Storage**: Pełne raporty zapisywane w historii (metryki, issues, timeline, event log)
- **Localization**: Dodano nowe klucze tłumaczeń dla nowych funkcji

### Technical
- Zaktualizowano wszystkie moduły klas do nowej sygnatury API
- Dodano obsługę błędów w `BuildReport` z `pcall`
- Rozszerzono strukturę danych historii o pełne raporty

## Version 0.74 (2026-01-17)

### Fixed
- Summary window race condition
- Minimap tooltip text
- Tips refresh in mini window

### Added
- Clear report functionality
- Better error handling

## Version 0.73 (Previous)

### Features
- Basic rotation analysis for Frost Mage, Elemental Shaman, Arms Warrior
- Live DPS window
- Fight history tracking
- Minimap icon
- Sound alerts for procs
- Multi-language support (EN/PL)

---

## Planned Features (Future Versions)

### Version 0.76+ (In Development)
- [ ] Podstawowe rotacje dla wszystkich DPS specs (ToT 5.5.3)
- [ ] System porad specyficznych dla bossów z Throne of Thunder
- [ ] Rozszerzone porady dla każdego bossa/klasy
- [ ] Więcej modułów klas z pełną analizą

### Future Considerations
- Web integration dla dzielenia się raportami
- System zgłaszania błędów
- Porównywanie raportów
- Guild analytics
- Mobile-responsive web viewer

---

## Known Issues
- Niektóre specjalizacje nie mają jeszcze pełnej implementacji
- Boss-specific advice system w planach
- Web features wymagają zewnętrznej infrastruktury
