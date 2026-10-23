# Lift Log brand

The source of truth for how Lift Log looks. Everything here comes from the app icon:
a white pulse line that turns into a lime arrow going up, on deep navy.

**The idea:** steady effort (white pulse) turns into progress (lime arrow).
Lime always means *progress or done*. Don't use it for decoration, warnings or anything neutral.

## Files

| File | Use |
|---|---|
| `brand/icon.svg` | App icon, square and full bleed. The OS rounds the corners. Source for all PNGs. |
| `brand/logo.svg` | Icon with rounded corners (rx 230 / 1024 ≈ 22%). Docs, web pages, social. |
| `brand/mark.svg` | Glyph without the tile. Pulse uses `currentColor`, arrow stays lime. Only use it on navy or dark backgrounds, because lime on white is too faint. |
| `favicon.svg`, `favicon-32.png` | Browser tab icons (rounded logo). |
| `liftlog-icon-180.png` | iOS home screen (full bleed). |
| `liftlog-icon-512/1024.png` | PWA "any" icons (rounded, transparent corners). |
| `liftlog-maskable-512.png` | Android adaptive icon (full bleed; glyph is inside the 80% safe zone). |

To regenerate the PNGs after changing the geometry, edit `make_icon.py` and run `python make_icon.py .`.
Keep `make_icon.py`, `brand/*.svg`, `favicon.svg` and `ICON.mark` in `liftlog.html` in sync.

### Glyph geometry (1024 grid)
- Stroke 66, round caps and round joins.
- Pulse (white): `M180 619 H362 L431 495 L545 704`
- Arrow (lime): `M545 704 L814 434` + head `M680 434 H814 V570`
- Leave at least 1/8 of the logo's width clear around it. Never recolor, rotate, add effects or outline the glyph.

## Color

| Token | Hex | Role |
|---|---|---|
| Navy | `#0D1B2B` | Brand base. Light mode: text and primary fills. Dark mode: card surface. |
| Volt | `#C7F431` | Progress and done: primary fill in dark mode, done-set toggle, active tab pill, chart highlights. |
| White | `#FFFFFF` | The pulse. Text on navy. |

Pairings that pass contrast: lime on navy 13.6:1. Navy on lime tint `#EEF9CC` 15.8:1.
**Never put lime text or thin lime lines on white or light gray** (1.3:1). On light backgrounds, lime is only for fills with navy content.

### App tokens (`:root` in `liftlog.html`)

| Token | Light | Dark |
|---|---|---|
| `--bg` | `#F1F4F8` | `#08121E` |
| `--surface` | `#FFFFFF` | `#0D1B2B` (navy) |
| `--surface-2` (inputs, wells) | `#F2F5F8` | `#132538` |
| `--ink` | `#0D1B2B` | `#EEF3F8` |
| `--muted` | `#556275` | `#8D9CB0` |
| `--line` | `#D9E0E8` | `#1F3349` |
| `--accent` / `--accent-ink` | navy / lime | lime / navy |
| `--accent-soft` | `#EEF9CC` | `#27392C` |
| `--volt` / `--volt-ink` | lime / navy | lime / navy |
| `--volt-soft` (done rows) | `#EEF9CC` | `#27392C` |
| `--good` / `--good-soft` | `#16794A` / `#DDF2E6` | `#3CCB86` / `#12301F` |
| `--warn` / `--warn-soft` | `#C2410C` / `#FBE5DA` | `#FF8A5C` / `#3A1F17` |

The rule of thumb: **`--accent` flips** (navy in light, lime in dark), and **`--volt` stays lime** in both.
Use `--accent` for the main action and selected state. Use `--volt` for moments of progress: a finished set,
the active tab, the latest point on a chart, the current week. Trophy colors (`--t1..3`) are separate and stay as they are.

## Type

**Archivo** (Google Fonts, variable: width 62–125%, weight 400–800). It's one family for everything.

| Role | Setting |
|---|---|
| Display: view titles, card titles, big numbers | `var(--f-display)`, `font-stretch: var(--wd)` (112%), weight 800, uppercase for titles |
| Big buttons | weight 800, stretch 104%, uppercase, letter-spacing .03em |
| Labels | 11–12px, weight 600, uppercase, letter-spacing .07–.08em, `--muted` |
| Body | `var(--f-body)`, 16px, weight 400–600, normal width |
| Numbers | always `font-variant-numeric: tabular-nums` (class `.num`) |

The wide, heavy display style echoes the icon's thick horizontal strokes. Keep titles short, because expanded caps take room.
Fallbacks: Arial Black (display) and the system UI font (body).

## Shape and icons
- Radii: cards 16px, inputs and buttons 9–11px, chips and pills fully round, app tile 22%.
- UI icons: 24px grid, 2px stroke (2.5–3 for small arrows and checks), round caps and joins, `currentColor`. They match the logo's rounded stroke style.
- Active state in the tab bar: lime pill behind a navy icon.

## Voice
Short, plain, encouraging, and never shouty. "Starter plan added." rather than "Awesome!! 💪".
Talk about progress in numbers people can check ("+2.5 kg on your best set").
