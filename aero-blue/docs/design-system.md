# Aero Blue design system

A calm, original interpretation of Aqua and Frutiger Aero. Use the native macOS system font, blue skies, restrained reflections, and transparent surfaces. Preserve familiar macOS controls and readable content.

| Token | Color | Use |
| --- | --- | --- |
| Sky | `#A8D8FF` | Wide gradients and wallpaper sky |
| Crystal | `#65C7F7` | Glass highlights and selected controls |
| Aqua | `#48DCE6` | Secondary accents and water |
| Ice | `#F4FBFF` | Light surfaces and highlights |
| Glass | `#CDEEFF` | Panel fills and borders |
| Leaf | `#9AD96B` | Nature accents |
| Ocean | `#2478B8` | Controls and borders |

Body copy needs darker ink than the accent blue on translucent light surfaces. Avoid fine white type on bright glass; use opaque fallback surfaces when transparency is reduced. SF system typography scales with native controls. Icons carry both a distinct symbol and a text label.

Panels use generous rounded corners, a fine highlight at the top, a quiet blue border, and soft shadows. Wallpapers leave quiet areas for desktop items. Distinct light and dark variants keep the same composition without forcing a global system appearance change.

Use short transitions only for deliberate interactions. Disable optional animations through the global setting, and honor the platform's Reduce Motion setting. No perpetual particle effects or background video. Widget data polling is separate from lightweight local clock updates.

Native controls retain keyboard focus and labels. The cursor pack includes a dark outline for visibility on sky, water, and white windows; hotspot coordinates must stay consistent across scale variants. A preview of a cursor is not evidence of system-wide replacement.
