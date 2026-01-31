# iOS Search UI Theme Update - Cycling App Optimized

## Overview
Updated the iOS Search UI for a cycling application with project theme colors (#01E47C green, #040608 dark background) using the official Mapbox Search UI `Style` API. All text has been localized to English.

## Cycling-Specific Features

### 1. **Distance Display with Bicycle Icon**
- Shows cycling distance with bicycle icon (🚴)
- Distance displayed in miles/feet format
- Positioned next to location name for quick reference

### 2. **Estimated Cycling Time**
- Calculates estimated ride time based on average cycling speed (12 mph)
- Displayed in a highlighted info card with clock icon
- Format: "Est. time: X min" or "Xh Ym" for longer rides
- Assumes recreational cycling pace

### 3. **"Start Ride" Primary Action**
- Renamed from "Go To" to "Start Ride"
- Uses bicycle.circle.fill icon
- Prominent green button to begin navigation

### 4. **Save to Favorites**
- Secondary action to bookmark locations
- Useful for saving frequent cycling destinations
- Uses bookmark icon

## UI/UX Improvements

### Visual Hierarchy
```
┌─────────────────────────────────────┐
│  🎯 Location Name        🚴 2.5 mi  │  ← Primary info
│  📍 Full Address                    │  ← Secondary info
│  ┌───────────────────────────────┐  │
│  │ 🕐 Est. time: 12 min          │  │  ← Cycling-specific
│  └───────────────────────────────┘  │
│  ─────────────────────────────────  │
│  [🚴 Start Ride]  [🔖 Save]        │  ← Actions
└─────────────────────────────────────┘
```

### Design Elements
- **Drag Indicator**: 40x5px, green with 50% opacity
- **Location Icon**: mappin.circle.fill, 28x28px
- **Bicycle Icon**: 16x16px next to distance
- **Clock Icon**: 18x18px in time card
- **Time Card**: Light green background (10% opacity), 8px padding
- **Buttons**: 12px corner radius, 14px vertical padding

### Color Scheme
| Element | Color | Usage |
|---------|-------|-------|
| Primary Text | #01E47C | Location name, distance, time |
| Secondary Text | #A0A0A0 | Address |
| Background | #0A0C0E | Drawer background |
| Time Card BG | #01E47C (10%) | Highlighted info |
| Separator | #01E47C (15%) | Divider line |
| Button Primary | #01E47C | Start Ride button |
| Button Secondary | Transparent + #01E47C border | Save button |

## Cycling Time Calculation

Average speed: **12 mph** (19 km/h) - recreational cycling pace

Formula:
```swift
time (minutes) = distance (miles) / 12 mph * 60
```

Display format:
- < 1 min: "< 1 min"
- 1-59 min: "X min"
- ≥ 60 min: "Xh Ym"

## English Localization

All UI text updated to English:
- Title: "Search Location"
- Button: "Start Ride" (primary)
- Button: "Save" (secondary)
- Time: "Est. time: X min"
- Address fallback: "Address unavailable"
- Location fallback: "Current Location"
- Alert: "Location Saved"

## Files Modified
- `ios/flutter_mapbox_navigation/Sources/flutter_mapbox_navigation/SearchViewController.swift`

## Testing Checklist
- [ ] Search UI displays with green theme
- [ ] Distance shows with bicycle icon
- [ ] Estimated cycling time calculates correctly
- [ ] "Start Ride" button starts navigation
- [ ] "Save" button shows confirmation
- [ ] All text is in English
- [ ] Drawer height accommodates new layout (280px)
- [ ] Icons render correctly on all iOS versions

## Design References
Inspired by:
- Strava route planning
- Komoot destination cards
- Apple Maps cycling directions
- Google Maps cycling mode
