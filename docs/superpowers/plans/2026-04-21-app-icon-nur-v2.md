# App Icon "Nur v2" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `assets/icon/app_nur.png` with a more expressive indigo-and-gold version of the "nur" light concept, harmonizing with the app's dark indigo theme.

**Architecture:** Author a hand-crafted SVG source file (layered gradients, bloom filters, scattered star particles), convert it to a 1024×1024 PNG via `npx svgexport`, back up the old icon, then regenerate Android/iOS launcher icons via `flutter_launcher_icons`.

**Tech Stack:** SVG (with `feGaussianBlur` filters), `npx svgexport` (Node/npm-based SVG→PNG converter, pulls on-demand), `flutter_launcher_icons` (already in `pubspec.yaml` dev_dependencies).

**Spec:** See `docs/superpowers/specs/2026-04-21-app-icon-nur-v2-design-ru.md`.

**Note on "tests":** Visual assets don't have traditional unit tests. "Verification" steps replace TDD steps — we confirm file existence, correct dimensions (`identify` via Flutter is not available, so we check via PowerShell's `System.Drawing.Image`), and do visual inspection.

---

### Task 1: Back up the existing icon

**Files:**
- Create: `assets/icon/app_nur_v1_backup.png` (copy of current PNG)

- [ ] **Step 1: Copy existing PNG to backup name**

Run from repo root:

```bash
cp assets/icon/app_nur.png assets/icon/app_nur_v1_backup.png
```

- [ ] **Step 2: Verify both files exist**

Run:

```bash
ls -la assets/icon/app_nur*.png
```

Expected: two lines — `app_nur.png` and `app_nur_v1_backup.png`, both with the same byte size.

- [ ] **Step 3: Commit the backup**

```bash
git add assets/icon/app_nur_v1_backup.png
git commit -m "chore(icon): back up original app_nur.png before redesign"
```

---

### Task 2: Create the SVG source file

**Files:**
- Create: `assets/icon/app_nur.svg`

- [ ] **Step 1: Write the full SVG**

Create `assets/icon/app_nur.svg` with the following exact content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <clipPath id="rounded">
      <rect x="0" y="0" width="1024" height="1024" rx="180" ry="180"/>
    </clipPath>

    <radialGradient id="bg" cx="30%" cy="70%" r="95%">
      <stop offset="0%" stop-color="#1E1B4B"/>
      <stop offset="60%" stop-color="#171340"/>
      <stop offset="100%" stop-color="#0B0720"/>
    </radialGradient>

    <linearGradient id="beamCore" x1="1" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
      <stop offset="12%" stop-color="#FFF3D0" stop-opacity="1"/>
      <stop offset="35%" stop-color="#FFD369" stop-opacity="0.95"/>
      <stop offset="65%" stop-color="#F5B82E" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#F5B82E" stop-opacity="0"/>
    </linearGradient>

    <radialGradient id="cornerGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
      <stop offset="35%" stop-color="#FFEFC2" stop-opacity="0.7"/>
      <stop offset="100%" stop-color="#FFD369" stop-opacity="0"/>
    </radialGradient>

    <radialGradient id="sparkleGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="1"/>
      <stop offset="100%" stop-color="#FFD369" stop-opacity="0"/>
    </radialGradient>

    <filter id="blurLg" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="45"/>
    </filter>
    <filter id="blurMd" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="18"/>
    </filter>
    <filter id="blurSm">
      <feGaussianBlur stdDeviation="4"/>
    </filter>
    <filter id="sparkle">
      <feGaussianBlur stdDeviation="1.2"/>
    </filter>
  </defs>

  <g clip-path="url(#rounded)">
    <!-- Background -->
    <rect x="0" y="0" width="1024" height="1024" fill="url(#bg)"/>

    <!-- Beam: three layered rotated ellipses, rotation -45° around (512,512) so beam goes from upper-right to lower-left -->
    <g transform="rotate(-45 512 512)">
      <!-- Outer bloom halo -->
      <ellipse cx="700" cy="512" rx="650" ry="230" fill="url(#beamCore)" opacity="0.35" filter="url(#blurLg)"/>
      <!-- Middle bright layer -->
      <ellipse cx="700" cy="512" rx="600" ry="110" fill="url(#beamCore)" opacity="0.75" filter="url(#blurMd)"/>
      <!-- Core bright streak -->
      <ellipse cx="700" cy="512" rx="520" ry="40" fill="url(#beamCore)" opacity="1" filter="url(#blurSm)"/>
    </g>

    <!-- Corner light source at top-right -->
    <circle cx="910" cy="130" r="220" fill="url(#cornerGlow)" opacity="0.9" filter="url(#blurMd)"/>
    <circle cx="910" cy="130" r="70" fill="#FFFFFF" opacity="0.95" filter="url(#blurSm)"/>

    <!-- Indigo dots (shadow side) -->
    <g fill="#4F46E5" opacity="0.45">
      <circle cx="120" cy="210" r="3"/>
      <circle cx="210" cy="160" r="2"/>
      <circle cx="300" cy="190" r="3"/>
      <circle cx="160" cy="350" r="2"/>
      <circle cx="250" cy="410" r="3"/>
      <circle cx="90" cy="500" r="2"/>
      <circle cx="180" cy="560" r="3"/>
      <circle cx="900" cy="500" r="2"/>
      <circle cx="860" cy="610" r="3"/>
      <circle cx="940" cy="760" r="2"/>
      <circle cx="820" cy="810" r="3"/>
      <circle cx="700" cy="880" r="2"/>
      <circle cx="560" cy="920" r="3"/>
      <circle cx="410" cy="900" r="2"/>
      <circle cx="320" cy="940" r="3"/>
    </g>

    <!-- White/light-blue dots (along and around beam) -->
    <g fill="#FFFFFF">
      <circle cx="880" cy="150" r="3"/>
      <circle cx="840" cy="220" r="2"/>
      <circle cx="780" cy="180" r="3"/>
      <circle cx="760" cy="280" r="2"/>
      <circle cx="700" cy="240" r="3"/>
      <circle cx="680" cy="360" r="2"/>
      <circle cx="590" cy="450" r="3"/>
      <circle cx="550" cy="400" r="2"/>
      <circle cx="470" cy="570" r="2"/>
      <circle cx="440" cy="520" r="3"/>
      <circle cx="390" cy="560" r="2"/>
      <circle cx="360" cy="700" r="3"/>
      <circle cx="340" cy="650" r="2"/>
      <circle cx="300" cy="750" r="3"/>
      <circle cx="270" cy="720" r="2"/>
      <circle cx="220" cy="820" r="3"/>
      <circle cx="200" cy="780" r="2"/>
      <circle cx="930" cy="80" r="2"/>
      <circle cx="850" cy="105" r="2"/>
      <circle cx="150" cy="890" r="2"/>
    </g>
    <g fill="#C7D2FE">
      <circle cx="640" cy="330" r="4"/>
      <circle cx="520" cy="480" r="3"/>
      <circle cx="420" cy="600" r="4"/>
      <circle cx="80" cy="850" r="2"/>
      <circle cx="920" cy="200" r="2"/>
    </g>

    <!-- Gold 4-point sparkle stars (using path) -->
    <g fill="#FFD369" filter="url(#sparkle)">
      <!-- sparkle at (820, 200), size 12 -->
      <path d="M820,188 L822,198 L832,200 L822,202 L820,212 L818,202 L808,200 L818,198 Z"/>
      <!-- sparkle at (650, 370), size 14 -->
      <path d="M650,356 L653,367 L664,370 L653,373 L650,384 L647,373 L636,370 L647,367 Z"/>
      <!-- sparkle at (380, 640), size 10 -->
      <path d="M380,630 L382,638 L390,640 L382,642 L380,650 L378,642 L370,640 L378,638 Z"/>
      <!-- sparkle at (250, 770), size 8 -->
      <path d="M250,762 L252,768 L258,770 L252,772 L250,778 L248,772 L242,770 L248,768 Z"/>
      <!-- sparkle at (770, 270), size 10 -->
      <path d="M770,260 L772,268 L780,270 L772,272 L770,280 L768,272 L760,270 L768,268 Z"/>
    </g>

    <!-- Accent: 8-point star at (510, 510) ~20px radius -->
    <g transform="translate(510 510)">
      <circle r="35" fill="url(#sparkleGlow)" opacity="0.8"/>
      <!-- 8-point star = two rotated squares, 22px half-diagonal -->
      <g fill="#FFFFFF">
        <rect x="-16" y="-16" width="32" height="32" transform="rotate(0)"/>
        <rect x="-16" y="-16" width="32" height="32" transform="rotate(45)"/>
      </g>
      <!-- Inner golden accent -->
      <g fill="#FFD369">
        <rect x="-8" y="-8" width="16" height="16" transform="rotate(0)"/>
        <rect x="-8" y="-8" width="16" height="16" transform="rotate(45)"/>
      </g>
    </g>
  </g>
</svg>
```

- [ ] **Step 2: Verify the file was written and is valid XML**

Run:

```bash
head -5 assets/icon/app_nur.svg && wc -l assets/icon/app_nur.svg
```

Expected: first line is `<?xml version="1.0" encoding="UTF-8"?>`, total ~100 lines.

- [ ] **Step 3: Visually inspect the SVG in a browser**

Open the file in a browser (drag-and-drop into any browser tab, or `start assets/icon/app_nur.svg` on Windows).

Expected: indigo background, golden diagonal beam from upper-right to lower-left, bright corner glow at top-right, 8-point star accent near center, scattered star dots.

If the result looks off (beam invisible, wrong colors, off-center), stop and discuss adjustments before continuing.

- [ ] **Step 4: Commit the SVG source**

```bash
git add assets/icon/app_nur.svg
git commit -m "feat(icon): add SVG source for Nur v2 app icon"
```

---

### Task 3: Convert SVG to PNG

**Files:**
- Modify (overwrite): `assets/icon/app_nur.png`

- [ ] **Step 1: Convert via `npx svgexport`**

Run from repo root:

```bash
npx --yes svgexport assets/icon/app_nur.svg assets/icon/app_nur.png 1024:1024
```

On first run, npx will download the `svgexport` package (and its Puppeteer/Chromium dependency — can take 30-90 seconds). Subsequent runs are fast.

Expected output: a line like `assets/icon/app_nur.svg png 100% 1024:1024 assets/icon/app_nur.png`.

If `svgexport` fails due to Puppeteer/Chromium not downloading (common on corporate networks), fall back to Step 2.

- [ ] **Step 2 (fallback only): Use an online SVG→PNG converter**

If Step 1 failed: open https://cloudconvert.com/svg-to-png or https://www.svgviewer.dev/, upload `assets/icon/app_nur.svg`, set output size to 1024×1024, and save the result as `assets/icon/app_nur.png` (overwriting the existing file).

- [ ] **Step 3: Verify PNG dimensions**

Run in PowerShell (Bash cannot easily read PNG dimensions on Windows without extra tools):

```powershell
Add-Type -AssemblyName System.Drawing; $img = [System.Drawing.Image]::FromFile((Resolve-Path assets/icon/app_nur.png)); "$($img.Width)x$($img.Height)"; $img.Dispose()
```

Expected: `1024x1024`.

- [ ] **Step 4: Visually inspect the PNG**

Open `assets/icon/app_nur.png` in any image viewer. Confirm:
- Rounded corners (180 px radius)
- Indigo background, golden diagonal beam, bright top-right corner
- Central 8-point star visible
- Star dots scattered

If the result visibly differs from the SVG (missing blur, broken gradients), it means the converter didn't support all SVG features — use the online converter fallback instead.

- [ ] **Step 5: Commit the new PNG**

```bash
git add assets/icon/app_nur.png
git commit -m "feat(icon): replace app_nur.png with Nur v2 redesign"
```

---

### Task 4: Regenerate Flutter launcher icons

**Files:**
- Modify (auto-generated): `android/app/src/main/res/**`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/**`

- [ ] **Step 1: Run flutter_launcher_icons**

Run from repo root:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

Expected: output ending with `✓ Successfully generated launcher icons` (or similar). Ignores warnings about `flutter_icons` key moving to `flutter_launcher_icons` section — those are non-fatal.

- [ ] **Step 2: Inspect generated Android icons**

Check that files were regenerated:

```bash
ls -la android/app/src/main/res/mipmap-xxxhdpi/
ls -la ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

Expected: `ic_launcher.png` (Android) and multiple `Icon-App-*.png` files (iOS), all with recent modification timestamps.

- [ ] **Step 3: Run the app to visually confirm the new icon**

```bash
flutter run -d <device_id>
```

Then minimize the app and look at the home screen icon. (If no device connected, skip this step — the PNG inspection in Task 3 is sufficient.)

- [ ] **Step 4: Commit the regenerated launcher icons**

```bash
git add android/app/src/main/res ios/Runner/Assets.xcassets
git commit -m "chore(icon): regenerate Android/iOS launcher icons"
```

---

## Acceptance checklist

After all tasks complete, verify:

- [ ] `assets/icon/app_nur.svg` exists and opens correctly in a browser
- [ ] `assets/icon/app_nur.png` is 1024×1024 and shows the Nur v2 design
- [ ] `assets/icon/app_nur_v1_backup.png` preserves the original
- [ ] Android `mipmap-*` and iOS `AppIcon.appiconset` have fresh PNGs
- [ ] Four commits made: backup, SVG source, PNG replacement, launcher icon regen
- [ ] Icon is legible and visually effective at 48×48 (smallest `mipmap-mdpi` size)
