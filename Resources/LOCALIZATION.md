# Localization Guide

## Overview
xInsight uses JSON-based localization with **separate files per language** for easy multi-language support. Each language has its own JSON file in `Resources/Localizations/`.

## Current Languages
- **English** (`en.json`)
- **Vietnamese** (`vi.json`)

## File Structure

```
Resources/
└── Localizations/
    ├── en.json      # English translations
    ├── vi.json      # Vietnamese translations
    └── zh.json      # Add new languages here
```

## How to Add a New Language

### Step 1: Create New JSON File

Create a new file `Resources/Localizations/[code].json` with all translation keys:

**Example: `zh.json` (Chinese)**
```json
{
  "appName": "xInsight",
  "appDescription": "macOS AI 系统洞察",
  "overview": "概览",
  "processes": "进程",
  "insights": "洞察",
  "cpuDetail": "CPU 详情",
  "memoryDetail": "内存详情",
  ...
}
```

💡 **Tip:** Copy `en.json` as a template and translate each value.

### Step 2: Add Language Code to Loader

Open `xInsight/Services/Localization.swift` and add the language code:

```swift
static func loadTranslations() {
    let languages = ["en", "vi", "zh"]  // Add "zh" here
    ...
}
```

### Step 3: Add Language to Enum

Add the language to the `Language` enum:

```swift
enum Language: String, CaseIterable {
    case system = "system"
    case english = "en"
    case vietnamese = "vi"
    case chinese = "zh"      // Add new language
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .chinese: return "中文"  // Add display name
        }
    }
    
    var resolvedLanguage: Language {
        if self == .system {
            let preferredLanguages = Locale.preferredLanguages
            if preferredLanguages.first?.starts(with: "vi") == true {
                return .vietnamese
            }
            if preferredLanguages.first?.starts(with: "zh") == true {
                return .chinese  // Add system detection
            }
            return .english
        }
        return self
    }
}
```

### Step 4: Test

1. Build and run the app
2. Go to Settings → Language
3. Select your new language
4. Verify all UI text is translated

## Translation Keys Reference

See `en.json` for the complete list of keys. Main categories:

### App & Menu (6 keys)
- `appName`, `appDescription`
- `menuBarOpen`, `menuBarQuit`, `menuBarRefresh`

### Dashboard Tabs (15 keys)
- `overview`, `processes`, `insights`, `ports`, `cleanup`, `settings`
- `cpuDetail`, `gpuDetail`, `memoryDetail`, `diskDetail`
- `networkTraffic`, `batteryHealth`, `uninstaller`, `startupManager`, `security`

### Metrics (7 keys)
- `cpu`, `memory`, `gpu`, `diskIO`, `temperature`, `network`, `fanSpeed`

### CPU/GPU/Memory (30+ keys)
- Performance cores, efficiency cores, usage, temperature, etc.

### Status & Actions (20+ keys)
- System status, warnings, actions like refresh, scan, clean

### Hardware (10 keys)
- `chip`, `cores`, `type`, `total`, `details`, `history`, `trend`

**Total: ~85 translation keys**

## Usage in Code

```swift
// Use L10n.string() to get localized text
Text(L10n.string(.overview))

// Or use the String extension
Text(.localized(.cpuDetail))
```

## Fallback Behavior

If a translation is missing:
1. Try to load from selected language
2. Fall back to English (`en.json`)
3. If still missing, return the key name

## Benefits of Separate Files

✅ **Easy to manage** - Each language in its own file  
✅ **Clean git diffs** - Changes only affect one file  
✅ **Parallel work** - Multiple translators can work simultaneously  
✅ **No merge conflicts** - Each translator edits different files  
✅ **Better organization** - Scales well with many languages  

## Example: Adding Japanese

**1. Create `Resources/Localizations/ja.json`:**
```json
{
  "appName": "xInsight",
  "overview": "概要",
  "processes": "プロセス",
  "cpuDetail": "CPU 詳細",
  ...
}
```

**2. Update `Localization.swift`:**
```swift
let languages = ["en", "vi", "ja"]  // Add "ja"

case japanese = "ja"  // Add to enum

var displayName: String {
    case .japanese: return "日本語"
}

var resolvedLanguage: Language {
    if preferredLanguages.first?.starts(with: "ja") == true {
        return .japanese
    }
}
```

**3. Build, test, done!** ✅

## Contributing Translations

Want to contribute a translation? 

1. Fork the repo
2. Create `Resources/Localizations/[code].json`
3. Translate all 85 keys
4. Update `Localization.swift` (2 places)
5. Test thoroughly
6. Submit a PR

We appreciate all translation contributions! 🌍

## Supported Languages (Roadmap)

- [x] English (`en`)
- [x] Vietnamese (`vi`)
- [ ] Chinese Simplified (`zh`)
- [ ] Japanese (`ja`)
- [ ] Korean (`ko`)
- [ ] French (`fr`)
- [ ] German (`de`)
- [ ] Spanish (`es`)
