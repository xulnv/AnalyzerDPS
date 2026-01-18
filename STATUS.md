# xAnalyzerDPS - Status Rozwoju

**Wersja:** 0.76  
**Data aktualizacji:** Styczeń 2026  
**Platforma:** WoW MoP Classic (Interface 50503)  
**Faza dodatku:** Throne of Thunder (5.5.3)

---

## Stan Modułów Klas

### ✅ W Pełni Zaimplementowane (6/34 specjalizacji)

| Klasa | Specjalizacja | Status | Funkcje |
|-------|---------------|--------|---------|
| **Mage** | Frost | ✅ Kompletny | DoT uptime, proc tracking (FoF, BF), cooldown usage, cast efficiency, live advice z ikonami |
| **Warlock** | Affliction | ✅ Kompletny | DoT uptime (Agony, Corruption, UA), Haunt, Dark Soul, Nightfall proc, cast efficiency |
| **Shaman** | Elemental | ✅ Kompletny | Flame Shock uptime, Lava Burst usage, cooldowns, proc tracking |
| **Warrior** | Arms | ✅ Kompletny | Colossus Smash, Mortal Strike, debuff uptime, rage management |
| **Priest** | Shadow | ✅ Kompletny | DoT uptime (VT, SW:P, DP), Mind Blast, Shadowfiend, proc tracking |
| **Rogue** | Combat | ✅ Kompletny | SnD uptime, Revealing Strike, Killing Spree, cooldown usage |

### ⏳ Stub (Tylko framework - 28 specjalizacji)

#### DPS Specs - Priorytet Wysoki
| Klasa | Specjalizacja | Priorytet |
|-------|---------------|-----------|
| Warlock | Demonology | 🔴 Wysoki |
| Warlock | Destruction | 🔴 Wysoki |
| Hunter | Beast Mastery | 🔴 Wysoki |
| Hunter | Marksmanship | 🔴 Wysoki |
| Hunter | Survival | 🔴 Wysoki |
| Mage | Arcane | 🟡 Średni |
| Mage | Fire | 🟡 Średni |
| Death Knight | Frost | 🟡 Średni |
| Death Knight | Unholy | 🟡 Średni |

#### DPS Specs - Priorytet Średni
| Klasa | Specjalizacja | Priorytet |
|-------|---------------|-----------|
| Druid | Balance | 🟡 Średni |
| Druid | Feral | 🟡 Średni |
| Monk | Windwalker | 🟡 Średni |
| Paladin | Retribution | 🟡 Średni |
| Rogue | Assassination | 🟡 Średni |
| Rogue | Subtlety | 🟡 Średni |
| Warrior | Fury | 🟡 Średni |

#### Tank/Healer Specs - Priorytet Niski
| Klasa | Specjalizacja | Priorytet |
|-------|---------------|-----------|
| Death Knight | Blood | 🟢 Niski |
| Druid | Guardian | 🟢 Niski |
| Druid | Restoration | 🟢 Niski |
| Monk | Brewmaster | 🟢 Niski |
| Monk | Mistweaver | 🟢 Niski |
| Paladin | Holy | 🟢 Niski |
| Paladin | Protection | 🟢 Niski |
| Priest | Discipline | 🟢 Niski |
| Priest | Holy | 🟢 Niski |
| Shaman | Enhancement | 🟡 Średni |
| Shaman | Restoration | 🟢 Niski |
| Warrior | Protection | 🟢 Niski |

---

## Funkcje Core

### ✅ Zaimplementowane

| Funkcja | Status | Opis |
|---------|--------|------|
| **Śledzenie walki** | ✅ | Automatyczne wykrywanie startu/końca walki |
| **Analiza raportów** | ✅ | Generowanie szczegółowych raportów po walce |
| **Live Advice** | ✅ | Podpowiedzi w czasie rzeczywistym z ikonami spelli |
| **Mini okienko** | ✅ | Małe okno z DPS, score i poradami podczas walki |
| **Historia walk** | ✅ | Persystentna historia z klikalnymi szczegółami |
| **Czyszczenie historii** | ✅ | Możliwość wyczyszczenia całej historii |
| **Lokalizacja** | ✅ | Polski i angielski |
| **Ikona minimapy** | ✅ | Szybki dostęp do addona |
| **System dźwięków** | ✅ | Alerty na proci i cooldowny |
| **Cast Efficiency** | ✅ | Metryka efektywności castowania |

### ⏳ Planowane

| Funkcja | Status | Opis |
|---------|--------|------|
| **Boss-specific advice** | 📋 Zaprojektowane | Porady dla bossów z Throne of Thunder |
| **Web error reporting** | 📋 Zaprojektowane | Zgłaszanie błędów przez web |
| **Report sharing** | 📋 Zaprojektowane | Udostępnianie analiz online |
| **Prepull analysis** | 🔧 Częściowe | Analiza prepota i precastu |

---

## Metryki Analizy

### Wspólne dla wszystkich modułów
- **DoT/Buff uptime** - % czasu aktywności kluczowych efektów
- **Cooldown usage** - Wykorzystanie major cooldowns
- **Proc utilization** - Wykorzystanie proców (nie marnowanie)
- **Cast efficiency** - Ilość castów vs. oczekiwana ilość

### Progi oceny
- **≥90%** - Zielony (dobry)
- **70-89%** - Żółty (średni)
- **<70%** - Czerwony (słaby)

---

## Pliki Projektu

```
AnalyzerDPS/
├── AnalyzerDPS.lua          # Core addon (3700+ linii)
├── AnalyzerDPS.toc          # Manifest
├── lang/
│   ├── enUS.lua             # Angielski
│   └── plPL.lua             # Polski
├── classes/
│   ├── mage_frost.lua       # ✅ Kompletny
│   ├── warlock_affliction.lua # ✅ Kompletny
│   ├── shaman_elemental.lua # ✅ Kompletny
│   ├── warrior_arms.lua     # ✅ Kompletny
│   ├── priest_shadow.lua    # ✅ Kompletny
│   ├── rogue_combat.lua     # ✅ Kompletny
│   └── [pozostałe]          # ⏳ Stub
├── CHANGELOG.md             # Historia zmian
├── ARCHITECTURE.md          # Architektura web
├── ROTATIONS_TODO.md        # Rotacje do implementacji
├── BOSS_ADVICE.md           # Porady dla bossów ToT
└── STATUS.md                # Ten plik
```

---

## Roadmap

### v0.77 (Następna wersja)
- [ ] Warlock Demonology - pełna implementacja
- [ ] Warlock Destruction - pełna implementacja
- [ ] Hunter Beast Mastery - pełna implementacja

### v0.8
- [ ] Wszystkie Hunter specs
- [ ] Mage Arcane i Fire
- [ ] Death Knight Frost i Unholy

### v0.9
- [ ] Wszystkie pozostałe DPS specs
- [ ] Boss-specific advice dla ToT

### v1.0
- [ ] Wszystkie DPS specs kompletne
- [ ] Web integration (error reporting)
- [ ] Report sharing

---

## Znane Problemy

1. **Starsze zapisy historii** - Zapisy sprzed v0.75 nie mają pełnych danych raportów
2. **Tank/Healer specs** - Brak planów implementacji w najbliższym czasie
3. **Multi-target tracking** - Ograniczone śledzenie debuffów na wielu celach

---

## Wymagania

- **WoW Version:** MoP Classic 5.5.3
- **Interface:** 50503
- **SavedVariables:** AnalyzerDPSDB

---

## Kontakt

Autor: xCzarownik2137

---

*Ostatnia aktualizacja statusu: Styczeń 2026*
