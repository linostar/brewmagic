# BrewMagic

A cosy, witty, occasionally absurd pixel-art potion shop for your phone. Read each customer's oddly specific
request, work out the potion, mix the ingredients and brew it with your thumb.

Entry for [Jamference: AI Game Jam Hack 2](https://itch.io/jam/jamference-ai-game-jam-hack-2)
(theme "Crafting", restriction "Playable on Mobile"). Made with Godot 4.7.1. Every asset (code, pixel art,
sound, music and writing) is made by Claude.

Play it in the browser on itch.io: (link added once the page is published).

## How to play

Portrait, one thumb:

- Read the request: hint words point to the essences the potion needs (warmth and courage: ember; calm and cold:
  frost; growth and healing: bloom; sleep and spooky things: gloom).
- Tap or drag 2 or 3 ingredients into the cauldron, then Brew.
- Brew by hand: stir in circles with the ghost ladle, hold to pour and release on the line, scrub the pestle from
  mark to mark, tap the bellows to keep the heat in the band.
- Story mode: a 20-day story with three endings whose days adapt to how well you brew, an evening market for stock
  and upgrades, and a Codex of what you've learned. Rush Hour, endless, is open from the start. Gentle and Assist
  modes are in Settings; Credits is next to them.

## Build and check

Needs Godot 4.7.1 (`GODOT` overrides the default `/Applications/Godot.app/Contents/MacOS/Godot`), Python 3,
Node 22 and Google Chrome.

- One-time setup: `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm --prefix tools ci`
- Validate everything (art, sound and music reproducibility, project rules, gameplay and content tests):
  `tools/validate.sh`
- Release build for itch.io (validate, web export, browser smoke test): `tools/build_web.sh` -> `build/brewmagic.zip`
- Android debug APK (validate, export, package check): `tools/build_android.sh` -> `build/android/brewmagic.apk`,
  then `adb install build/android/brewmagic.apk`. Needs the Godot 4.7.1 Android export templates, JDK 17 and the
  Android SDK set in Editor Settings > Export > Android.
- Google Play App Bundle: `tools/build_android.sh --play` -> `build/android/brewmagic.aab` (Gradle build; needs a
  release keystore in the "Android (Play Store)" preset). Store icon, feature graphic and listing notes: `store/play/`.
- Re-render the itch cover and screenshots into `submission/` (needs a window):
  `"$GODOT" --path brewmagic --audio-driver Dummy --resolution 1080x1920 --fixed-fps 60 --script "$PWD/tools/capture.gd"`

The itch page text and upload settings are in `SUBMISSION.md`.

## Credits

- Made by linostar with Claude (Anthropic).
- Fonts: [Silkscreen](https://fonts.google.com/specimen/Silkscreen) (Copyright 2001 The Silkscreen Project Authors) and
  [VT323](https://fonts.google.com/specimen/VT323) (Copyright 2011 The VT323 Project Authors), both under the SIL Open Font License 1.1
  (licence files in `brewmagic/fonts/`, shipped in the web build zip).
- Engine: [Godot Engine](https://godotengine.org) 4.7.1 (MIT license).
