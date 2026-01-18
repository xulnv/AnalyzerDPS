# AnalyzerDPS - Advanced DPS Analysis for MoP Classic

**Version:** 0.83  
**Author:** xCzarownik2137  
**Game Version:** Mists of Pandaria Classic (5.0.5)

## 📋 Overview

AnalyzerDPS is a comprehensive DPS analysis addon for World of Warcraft: Mists of Pandaria Classic. It provides real-time feedback, detailed post-fight reports, and actionable suggestions to help players optimize their damage output and rotation execution.

### Key Features

- **Real-time Live Window**: Displays current DPS and up to 3 prioritized rotation tips during combat
- **Detailed Post-Fight Reports**: Comprehensive analysis with scoring (0-100), metrics, and suggestions
- **Smart Fight Detection**: Automatically starts/stops tracking based on combat activity
- **Rotation Analysis**: Detects common mistakes and provides specific improvement suggestions
- **Buff/Debuff Tracking**: Monitors important buffs, debuffs, and proc usage
- **Cooldown Analysis**: Tracks major cooldown usage and timing
- **Pre-pull Detection**: Recognizes pre-combat actions (prepotions, precasts)
- **Fight History**: Saves reports for boss fights and training dummies
- **Multi-language Support**: English and Polish localization
- **Minimap Icon**: Quick access to settings and reports

## 🎯 Current Development Status

### ✅ Fully Implemented & Tested

#### **Mage - Frost** (100% Complete)
- ✅ Full rotation analysis with mistake detection
- ✅ Proc tracking (Fingers of Frost, Brain Freeze)
- ✅ Buff monitoring (Invoker's Energy, Icy Veins)
- ✅ Debuff tracking (Living Bomb, Nether Tempest, Frost Bomb)
- ✅ Cooldown analysis (Icy Veins, Frozen Orb, Alter Time)
- ✅ Pet detection (Water Elemental)
- ✅ Pre-pull optimization (Evocation, prepotions)
- ✅ Real-time advice system with spell icons
- ✅ Comprehensive scoring algorithm
- ✅ Detailed metrics and suggestions

**Status:** Production-ready, extensively tested

---

### 🚧 Implemented but Untested

The following classes/specs have basic analysis modules implemented but have **not been tested in-game**. They may require adjustments based on actual gameplay.

#### **Death Knight**
- **Blood** (Untested)
  - Basic tanking metrics
  - Cooldown tracking
  - Needs validation
  
- **Frost** (Untested)
  - Rune management tracking
  - Proc monitoring
  - Needs validation
  
- **Unholy** (Untested)
  - Disease tracking
  - Pet management
  - Needs validation

#### **Druid**
- **Balance** (Untested)
  - Eclipse tracking
  - DoT management
  - Needs validation
  
- **Feral** (Untested)
  - Bleed tracking
  - Energy management
  - Needs validation
  
- **Guardian** (Untested)
  - Tanking metrics
  - Rage tracking
  - Needs validation

#### **Hunter**
- **Beast Mastery** (Untested)
  - Focus tracking
  - Pet management
  - Needs validation
  
- **Marksmanship** (Untested)
  - Aimed Shot tracking
  - Proc monitoring
  - Needs validation
  
- **Survival** (Untested)
  - Trap management
  - DoT tracking
  - Needs validation

#### **Monk**
- **Brewmaster** (Untested)
  - Tanking metrics
  - Stagger tracking
  - Needs validation
  
- **Windwalker** (Untested)
  - Energy/Chi tracking
  - Combo management
  - Needs validation

#### **Paladin**
- **Holy** (Untested)
  - Healing metrics
  - Mana management
  - Needs validation
  
- **Protection** (Untested)
  - Tanking metrics
  - Holy Power tracking
  - Needs validation
  
- **Retribution** (Untested)
  - Holy Power management
  - Cooldown tracking
  - Needs validation

#### **Priest**
- **Discipline** (Untested)
  - Healing/DPS hybrid
  - Atonement tracking
  - Needs validation
  
- **Shadow** (Untested)
  - DoT management
  - Shadow Orb tracking
  - Needs validation

#### **Rogue**
- **Assassination** (Untested)
  - Poison tracking
  - Energy/CP management
  - Needs validation
  
- **Combat** (Untested)
  - Revealing Strike tracking
  - Bandit's Guile
  - Needs validation
  
- **Subtlety** (Untested)
  - Shadow Dance tracking
  - Stealth mechanics
  - Needs validation

#### **Shaman**
- **Elemental** (Untested)
  - Lightning Shield tracking
  - Lava Burst/Flame Shock
  - Needs validation
  
- **Enhancement** (Untested)
  - Maelstrom Weapon
  - Weapon imbues
  - Needs validation

#### **Warlock**
- **Affliction** (Untested)
  - DoT tracking
  - Soul Shard management
  - Needs validation
  
- **Demonology** (Untested)
  - Metamorphosis tracking
  - Pet management
  - Needs validation
  
- **Destruction** (Untested)
  - Burning Ember tracking
  - Backdraft management
  - Needs validation

#### **Warrior**
- **Arms** (Untested)
  - Colossus Smash tracking
  - Rage management
  - Needs validation
  
- **Fury** (Untested)
  - Enrage tracking
  - Bloodthirst management
  - Needs validation
  
- **Protection** (Untested)
  - Tanking metrics
  - Shield Block tracking
  - Needs validation

---

## 🔧 Installation

1. Download the addon
2. Extract to `World of Warcraft\_classic_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)
4. Access settings via minimap icon or `/analyzerdps`

## 📖 Usage

### Basic Usage
1. Enter combat - the addon automatically starts tracking
2. Live window appears showing DPS and rotation tips
3. After combat ends, a detailed report opens automatically
4. Review metrics, issues, and suggestions in the report window

### Commands
- `/analyzerdps` - Open main window
- `/analyzerdps config` - Open settings
- `/analyzerdps reset` - Clear current fight data

### Report Tabs
- **Summary**: Overview with score, DPS, metrics, and issues
- **Suggestions**: Detailed improvement tips with icons
- **Event Log**: Chronological list of all combat events
- **History**: Saved reports from previous fights

## 🎮 Features in Detail

### Live Window
- Real-time DPS counter
- Up to 3 prioritized rotation tips
- Spell icons for visual clarity
- Draggable and customizable position

### Scoring System (0-100)
- **90-100**: Excellent execution
- **70-89**: Good with minor issues
- **60-69**: Average with notable mistakes
- **0-59**: Needs significant improvement

### Metrics Tracked
- Buff/debuff uptimes
- Proc usage efficiency
- Cooldown timing
- Resource management
- Rotation mistakes
- Pre-pull optimization

### Smart Detection
- Automatic fight start/stop
- Boss vs trash differentiation
- Training dummy recognition
- Pre-combat action tracking
- Prevents false triggers from DoTs

## ⚙️ Settings

- **Language**: English / Polish
- **Mini Window**: Enable/disable live DPS window
- **Minimap Icon**: Show/hide minimap button
- **Sound Alerts**: Customizable audio notifications
- **Hint Position**: Adjust on-screen tip location

## 🐛 Known Issues & Limitations

- Only **Mage (Frost)** has been thoroughly tested
- Other classes may have inaccurate analysis
- Some spell IDs may need adjustment for different talents
- Details! addon integration recommended for accurate DPS

## 🔮 Future Plans

1. **Testing & Validation**: Test all untested specs with actual gameplay
2. **Talent Detection**: Automatic adjustment based on selected talents
3. **Advanced Metrics**: Add more detailed analysis per spec
4. **Comparison Tools**: Compare fights and track progress over time
5. **Export Features**: Share reports with others
6. **WeakAuras Integration**: Export suggestions to WeakAuras

## 🤝 Contributing

This addon is in active development. Feedback and testing reports are highly appreciated, especially for untested classes/specs.

### How to Help
1. Test your class/spec in actual combat
2. Report any incorrect analysis or suggestions
3. Provide spell IDs for missing abilities
4. Share rotation priorities for your spec

## 📝 Changelog

### Version 0.83 (Current)
- Fixed: Live score removed from mini window (simplified UI)
- Fixed: Icon overlapping in mini window
- Fixed: Report not showing after second fight
- Fixed: Living Bomb detection (now checks current target only)
- Fixed: Mini window background texture (clean, borderless)
- Improved: Event log readability (larger font, better spacing)
- Added: Issues/suggestions back to Summary tab (alongside Suggestions tab)
- Removed: "Review Suggestions" button (redundant)

### Version 0.82
- Fixed: Live score display in mini window
- Improved: Invoker's Energy detection (multiple spell IDs)

### Version 0.81
- Added: Persistent tips in mini window (up to 3 prioritized)
- Fixed: Combat log reset prevention after fight end
- Fixed: Potion usage detection (prepot vs in-combat)
- Improved: Mini window sizing and layout

### Version 0.80
- Initial public release
- Full Mage (Frost) analysis
- Basic modules for all classes (untested)

## 📄 License

This addon is provided as-is for World of Warcraft: Mists of Pandaria Classic.

## 💬 Contact

For bug reports, suggestions, or testing feedback, please contact the author.

---

**Note:** This addon is designed for MoP Classic (5.0.5) and may not work correctly on other versions of World of Warcraft.
