# iOS Style Picker English Translation

## Overview

Translated all Chinese text in the iOS Style Picker interface to professional English, maintaining consistency with international navigation app standards.

## Translation Reference

### Navigation Bar
| Chinese | English |
|---------|---------|
| 地图样式设置 | Map Style Settings |
| 取消 | Cancel |

### Info Card
| Chinese | English |
|---------|---------|
| 自定义地图外观 | Customize Map Appearance |
| 调整地图样式和光照效果，打造个性化导航体验 | Adjust map style and lighting effects to create a personalized navigation experience |

### Map Styles
| Chinese | English | Description |
|---------|---------|-------------|
| 标准 | Standard | Default map style |
| 卫星 | Satellite | Satellite imagery view |
| 褪色 | Faded | Soft color tones |
| 单色 | Monochrome | Black and white style |
| 浅色 | Light | Bright background |
| 深色 | Dark | Dark background |
| 户外 | Outdoors | Terrain display |

### Style Card
| Chinese | English |
|---------|---------|
| 地图样式 | Map Style |

### Light Preset Card
| Chinese | English |
|---------|---------|
| Light Preset（光照效果） | Light Preset |
| 选择不同时段的光照效果 | Select lighting effects for different times of day |

### Light Presets
| Chinese | English | Time Range |
|---------|---------|------------|
| 黎明 | Dawn | 5:00-7:00 AM |
| 白天 | Day | 7:00 AM-5:00 PM |
| 黄昏 | Dusk | 5:00-7:00 PM |
| 夜晚 | Night | 7:00 PM-5:00 AM |

### Auto-Adjust Card
| Chinese | English |
|---------|---------|
| 根据日出日落自动调整 | Auto-Adjust Based on Sunrise/Sunset |
| 自动根据时间切换光照效果 | Automatically switch lighting effects based on time |

### Bottom Buttons
| Chinese | English |
|---------|---------|
| 取消 | Cancel |
| 应用 | Apply |

## Picker Display Format

### Style Picker
```
Format: "{Title} - {Description}"

Examples:
- "Standard - Default map style"
- "Satellite - Satellite imagery view"
- "Faded - Soft color tones"
```

### Light Preset Picker
```
Format: "{Title} ({Time Range})"

Examples:
- "Dawn (5:00-7:00 AM)"
- "Day (7:00 AM-5:00 PM)"
- "Dusk (5:00-7:00 PM)"
- "Night (7:00 PM-5:00 AM)"
```

## Professional Terminology

### Navigation & Mapping
- **Map Style** - Standard term used in Mapbox and Google Maps
- **Light Preset** - Mapbox's official terminology for lighting effects
- **Satellite Imagery** - Professional term for satellite view
- **Terrain Display** - Standard term for topographic/outdoor maps

### Time Periods
- **Dawn** - Early morning twilight (5:00-7:00 AM)
- **Day** - Daytime hours (7:00 AM-5:00 PM)
- **Dusk** - Evening twilight (5:00-7:00 PM)
- **Night** - Nighttime hours (7:00 PM-5:00 AM)

### UI Elements
- **Auto-Adjust** - Common term for automatic adjustment features
- **Sunrise/Sunset** - Standard astronomical terms
- **Apply** - Standard action button for confirming changes
- **Cancel** - Standard action button for discarding changes

## Consistency with Industry Standards

### Mapbox Terminology
All map-related terms follow Mapbox's official documentation:
- Standard, Satellite, Light, Dark, Outdoors (style names)
- Light Preset (lighting configuration)
- Dawn, Day, Dusk, Night (preset values)

### iOS Human Interface Guidelines
Button and action terms follow Apple's HIG:
- "Cancel" for dismissing without changes
- "Apply" for confirming and applying changes
- Clear, concise labels for all UI elements

### Navigation App Standards
Terminology consistent with major navigation apps:
- Google Maps: "Map type", "Satellite", "Terrain"
- Apple Maps: "Map", "Satellite", "Transit"
- Waze: "Map display", "Day mode", "Night mode"

## Implementation Date

2026-01-31

## Related Documents

- [iOS Style Picker Modern Redesign](./IOS_STYLE_PICKER_MODERN_REDESIGN.md)
- [iOS Style Picker Final Redesign](./IOS_STYLE_PICKER_FINAL_REDESIGN.md)
- [iOS Theme Update](./IOS_THEME_UPDATE.md)
