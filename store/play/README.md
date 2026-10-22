# Google Play listing assets

Upload these in Play Console > Grow users > Store presence > Main store listing.

| Play Console field | File | Spec |
|---|---|---|
| App icon | `store/play/icon_512.png` | 512 x 512 PNG, opaque (Play rounds the corners) |
| Feature graphic | `store/play/feature_graphic.png` | 1024 x 500 PNG, no alpha |
| Phone screenshots | `submission/1-title.png` to `submission/8-ending.png` | 8 x 1080 x 1920 PNG, portrait 9:16 |

The app's own launcher icons (legacy 192 px and the adaptive foreground, background and
monochrome layers) are in `brewmagic/icons/` and set in both Android export presets.

Regenerate:
- Icons and feature graphic: `python3 tools/store_art.py` (needs Pillow; `--check` compares).
- Screenshots: `"$GODOT" --path brewmagic --audio-driver Dummy --resolution 1080x1920 --fixed-fps 60 --script "$PWD/tools/capture.gd"` (needs a window).

## Listing text

- **App name:** BrewMagic
- **Short description (80 max):** A cosy potion shop for one thumb: read the request, mix it, brew it by hand.
- **Category:** Game > Simulation. Tags: casual, cozy, crafting, pixel art, offline.
- **Full description:** reuse the public page text in `SUBMISSION.md`.

## Still to do in Play Console (not files)

- Release keystore: create it, set it in the "Android (Play Store)" preset, then
  `tools/build_android.sh --play` -> `build/android/brewmagic.aab`. Enrol in Play App Signing.
- Privacy policy URL, Data safety form (the game collects no data; it saves only on the
  device and asks for no permissions), content rating questionnaire, target audience.
