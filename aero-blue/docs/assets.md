# Original Aero Blue artwork

All artwork in `assets/` is generated from original geometry, gradients and deterministic procedural compositions in `scripts/generate_assets.py`. It contains no downloaded photographs, stock imagery, proprietary application logos, or copied operating-system icons. The application names identify the intended launcher or gallery association; these are original alternative symbols.

## Wallpapers

Six PNG masters, each 3200 × 2000 pixels, cover Aero Sky, Crystal Ocean and Aero Meadow in light and dark variants. All have restrained detail around the left edge for desktop items, soft sky gradients and glass bubbles. Crystal Ocean refracts the generated landscape inside a glass sphere; Aero Meadow uses layered hills and grass detail. JPEG previews are separate from the PNG masters and are only used for selection and review.

The attached cloud machine cannot report a Mac's display dimensions. These masters are therefore a portable default, **not a claim of detecting the user's screen**. The Mac installation checks displays; wallpaper placement uses macOS's desktop wallpaper API. For an exact display-sized master, run the generator after finding the panel's pixel dimensions with `scripts/check-system.sh` or System Information. Cropping on a differently proportioned display is expected.

```sh
python3 scripts/generate_assets.py --width 3024 --height 1964
```

Regeneration requires Python 3 and Pillow. Normal installation uses the committed exports and does not need Pillow. If you choose to regenerate art, create a development virtual environment and explicitly install Pillow:

```sh
python3 -m venv .asset-venv
.asset-venv/bin/python -m pip install 'Pillow>=10.1,<13'
.asset-venv/bin/python scripts/generate_assets.py
```

The generator never downloads artwork, changes the desktop, or installs software by itself. It overwrites only its named generated assets. Rendering is repeatable for a given Pillow/font version; glyph text falls back from DejaVu Sans on Linux to Arial on macOS.

## Aero Blue Crystal Icons

The 17 icon designs each have transparent PNG exports at 16, 32, 64, 128, 256, 512 and 1024 pixels and a macOS ICNS container with matching PNG representations (`icp4`, `icp5`, `icp6`, `ic07`, `ic08`, `ic09`, `ic10`). The manifest's `file` references the 256-pixel preview. The visual language uses a rounded translucent blue tile, ice-white pictogram, aqua reflections, and a fine white rim.

Included designs: Finder, Safari, Mail, Messages, Music, Photos, Calendar, Notes, Settings, Terminal, VS Code, Downloads, Documents, Projects, Applications, Trash and Desktop folders. App names are labels; symbol designs do not reproduce the vendors' logos.

The exports do not change app bundles. Signed system apps and protected folders must remain unchanged. Use the control center's supported file/folder custom-icon workflow, or use the image as a personal shortcut/launcher icon where supported. The project's bridge refuses icon mutations inside application bundles. ICNS structure and PNG contents are validated on Linux; Finder's rendering and Retina representation selection require the Mac acceptance checks.

## Aero Crystal Cursor

Each cursor has a transparent 64 × 64 PNG and a 128 × 128 PNG. Both represent a **32 × 32 logical-point cursor**: the 64px source is 2× and the 128px source is 4×. The manifest defines:

| Field | Coordinate space |
| --- | --- |
| `hotspot` | Logical points in a 32 × 32 cursor |
| `sourceHotspot` / `sourceHotspot64` | Pixels in the 64 × 64 source; logical values × 2 |
| `retinaHotspot` / `sourceHotspot128` | Pixels in the 128 × 128 source; logical values × 4 |
| `logicalSize` | `[32, 32]` points |
| `frames` | `1`; loading artwork is static to minimize motion |

| Cursor | Logical hotspot | 64px hotspot | 128px hotspot |
| --- | --- | --- | --- |
| Normal pointer | 5, 4 | 10, 8 | 20, 16 |
| Text selection | 16, 16 | 32, 32 | 64, 64 |
| Link hand | 13, 4 | 26, 8 | 52, 16 |
| Busy, resize, move, crosshair, unavailable | 16, 16 | 32, 32 | 64, 64 |

The hotspot is the active tip or center, not the transparent canvas's upper-left corner. Fine dark-blue outer outlines and pale inner edges help visibility on light and dark backgrounds. PNG artwork and coordinate bounds are tested; system-wide replacement, pointer scaling and actual click alignment are **not tested in this Linux environment**.

### Manual import into Mousecape, only after compatibility verification

Mousecape uses private CoreGraphics APIs. Its official latest release is old; its operation on the user's current macOS release is not established here. Consult [Mousecape's official repository](https://github.com/alexzielenski/Mousecape), release notes, and open compatibility issues before deciding to install. Do not disable SIP, bypass Gatekeeper, or remove quarantine to force an incompatible manager to run. See `compatibility.md` for the research record.

1. First record macOS version, processor architecture, scaling and any existing cursor manager with `scripts/check-system.sh`. Save/export your current cursor theme in that manager if it supports doing so.
2. If you independently verify a compatible Mousecape release, install it using its official instructions. Installation is optional and is never automatic in this project.
3. In Mousecape's editor, create a new cape called **Aero Crystal Cursor** and add the required semantic cursor types. Names vary by version; match normal pointer, text, pointing hand, busy, left/right resize, up/down resize, diagonal resize, open/move, crosshair and forbidden to the nearest available types.
4. Import the corresponding PNG from `assets/cursors/<id>/`. Set the **logical size to 32 × 32 points**. For a 64px (2×) representation, use the manifest's logical hotspot when the editor asks for points. Use `sourceHotspot` only when its field explicitly asks for image pixels. Do the same for the optional 128px (4×) representation.
5. Keep one frame. The busy indicator is intentionally a static glass ring. If a manager needs distinct system busy subtypes, map the same still to both rather than inventing an unsupported animation format.
6. Preview before applying. Test selection, links, resizing, diagonal orientation, dragging and click alignment in a disposable window at each display's scale. Restore the previous cape immediately if hotspots or rendering are incorrect.
7. Quit/disable the manager and select its default cape to return to the standard cursor. Do not run competing cursor managers at the same time.

No `.cape` is shipped: although the upstream plist format is documented by examples, compatibility and import behavior have not been verified on the user's Mac. Providing a purported ready-to-apply system theme would imply validation we cannot perform here. All importable image assets and exact coordinate metadata are included.

### Supported macOS fallback

On compatible macOS versions, open **System Settings → Accessibility → Display → Pointer**, choose an aqua/sky-blue fill (for example `#65C7F7`), a dark-blue outline (`#2478B8`), and a comfortable pointer size. These settings use macOS's supported controls and do not replace protected resources. Use the panel's **Reset** action to restore its standard colors. The project's restore tool does not claim to undo manual Accessibility changes; record any previous colors before adjusting them.

## Galleries and validation

- `assets/previews/wallpapers.jpg`: all six wallpaper designs.
- `assets/previews/icons.jpg`: all 17 icon designs.
- `assets/previews/cursors.jpg`: all ten cursor designs at enlarged scale.
- `assets/manifest.json`: authoritative paths, sizes and cursor metadata.

These contact sheets are artwork previews, **not screenshots of a customized Mac**. The control center displays the same originals from the manifest. Real Finder rendering, cursor-manager compatibility, multiple-screen cropping and display scaling are recorded as Mac-only acceptance tasks.
