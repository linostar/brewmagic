# BrewMagic: itch.io submission

The page text for the itch.io page and the jam entry for
**Jamference: AI Game Jam Hack 2** (https://itch.io/jam/jamference-ai-game-jam-hack-2).
Everything between the two rules below is the public page; paste it as is.

## Upload settings

- **Title:** BrewMagic
- **Short description (tagline):** A cosy potion shop for one thumb: read the oddly specific request, mix the potion, brew it by hand.
- **Kind of project:** HTML
- **Upload:** `build/brewmagic.zip` (rebuild with `tools/build_web.sh` first), tick "This file will be played in the browser".
- **Embed options:** viewport 405 x 720, fullscreen button on, "SharedArrayBuffer support" off. Tick "Mobile friendly" and choose portrait orientation.
- **Classification:** Game. Genre: Simulation. Tags: potions, crafting, cozy, pixel-art, mobile, touch, singleplayer, godot.
- **Cover image:** `submission/cover.png` (630 x 500).
- **Screenshots:** `submission/1-title.png` to `submission/8-ending.png`, in that order (1080 x 1920, portrait).
- **Jam:** submit the page to the jam and pick the optional theme "Crafting".

---

# BrewMagic

**Read the request. Work out the potion. Brew it with your thumb.**

You run a small potion shop. Customers walk in with oddly specific problems ("Hay's gone limp. Want it fresh and growing. Duchess is judging.") and never say which potion they want. The words they use are your clues: warmth and courage mean ember, calm and cold mean frost, growth and healing mean bloom, sleep and spooky things mean gloom. Mix 2 or 3 ingredients whose essences add up to the right potion, then brew it by hand.

How you play, all with one thumb:

- **Tap or drag** ingredients from the shelf into the cauldron (tap a pot slot to take one back out).
- **Stir** in circles, following the ghost ladle's tempo.
- **Pour:** hold to fill the bottle and let go on the line.
- **Grind:** scrub the pestle from mark to mark.
- **Pump the bellows:** tap to keep the heat needle in the band.

A good match and a steady hand earn a **Perfect**: full pay, a tip and reputation. Get it wrong and it's a **Misbrew**: hiccups that come out as tiny, polite fireballs, a small personal blizzard, a daisy sprouting on top (it looks very smug) or a personal rain cloud that's moody. Customers queue up and run out of patience, so keep the line moving, or refuse the impossible ones.

- **A 7-day story:** each day adds something new (an ingredient, a station, a rival, a rush). Inspector Quill audits your licence, Madame Vexley opens a rival shop across the street, and a shy Hooded Stranger keeps sneezing. How you treat them changes later days and decides which of three endings you reach at the Guild Fair.
- **Evening market:** buy stock and upgrades (a steadier ladle, a wider funnel) with what you earned.
- **The Codex** records every hint word and recipe you work out.
- **Rush Hour** unlocks after the story: an endless shift that speeds up wave by wave until your reputation runs out. Beat your best score.
- **Accessibility:** Gentle mode makes every brewing gesture 1.5x more forgiving; Assist mode turns each one into a single tap (scoring Good, never Perfect). With Assist on, the whole game also works with a keyboard.

Your progress is saved in your browser.

## The restriction: Playable on Mobile

BrewMagic is built portrait-first for one thumb: every action is a tap, drag, hold or circular swipe inside the bottom 60% of the screen, with no multi-touch, keyboard, hover or right click needed anywhere, and an automated checker fails the build if any game code reads the mouse or keys.

## Team

- **linostar** (solo developer): game direction and every design decision (concept, scope, mechanics, story, look and feel), playtesting on real phones, reviewing all the writing, and publishing.
- **Claude** (Anthropic's AI, through Claude Code): built the game to that direction, writing all the code, art, sound, music and text listed below.

This is linostar's only entry in the jam.

## How AI was used

BrewMagic was made with one AI tool: Claude (Anthropic), used through Claude Code. There are no asset packs and no other AI tools. Apart from the two fonts and the engine, everything was made for this jam:

- **Code:** about 8,500 lines of GDScript in Godot 4.7.1, plus two shaders (the customers' palette swap and the potion-swirl screen transition). Game rules (brewing, grading, economy, story, Rush Hour) are pure functions, separate from the scenes, so every rule can be tested.
- **Pixel art written as text:** all 127 sprites are typed as character grids (about 6,000 lines, one character per palette colour) and compiled into sprite sheets by a small compiler Claude wrote. One locked 32-colour palette is enforced on every pixel. The customers are assembled at runtime from part sheets plus colour swaps, giving over 13,000 distinct visitors.
- **Sound:** all 31 sound effects and a voice for each of the 11 characters (the little blips they "talk" in) are synthesised by a Python synthesiser Claude wrote. Nothing is sampled.
- **Music:** four loops (title, shop waltz, Rush Hour jig, ending) composed as notes around one shared motif and rendered by a Python music-box synthesiser Claude wrote, with plucked lute, bass and frame drum.
- **Writing:** every word in the game, about 5,000 words in total: 150 customer requests written in each character's voice, their reactions, 24 absurd misbrew outcomes, the 7-day story, morning notes and three endings. A content checker proves every request has a fair solution on its day and every line fits its speech bubble.
- **Customer AI (no language model):** each customer is a small state machine (enter, order, wait, react, storm off) with patience, mood, tip habits and a voice. It's classic game AI and runs offline; no language model runs inside the game.
- **Quality:** about 2,700 automated gameplay checks, about 100 content checks, a checker that enforces the one-thumb rules on every script and scene, and browser tests of the web build on desktop, an emulated phone and keyboard only. The cover and screenshots on this page were rendered by a script that stages each moment in the real game.

## Content

No intense content: no horror, gore, flashing imagery or heavy themes. Misbrews are comic (smouldering hair, a personal blizzard, a smug daisy), and a misbrew or storm-off gives the screen a short, mild shake.

## Credits

- Made by linostar with Claude (Anthropic).
- Fonts: Silkscreen (Copyright 2001 The Silkscreen Project Authors) and VT323 (Copyright 2011 The VT323 Project Authors), both under the SIL Open Font License 1.1.
- Engine: Godot Engine 4.7.1 (MIT license), https://godotengine.org.

---

## Before you press publish

- Upload `build/brewmagic.zip` from a fresh `tools/build_web.sh` run on the final commit.
- Play the uploaded page in a private window on desktop: the game is framed with no odd letterbox bars, fullscreen works, and the title music starts on the first click or tap.
- On a real **iPhone (Safari)** and a real **Android phone (Chrome)**, play the itch page through day 1:
  - The first tap unlocks the sound.
  - Stirring, pouring and dragging ingredients all follow your thumb.
  - Pull-to-refresh, double-tap zoom, text selection and long-press menus never trigger.
- On the Android phone, play Rush Hour to wave four and watch the frames: with Chrome remote debugging (chrome://inspect, Rendering > Frame Rendering Stats) it should hold about 60 fps.
- Submit to the jam before **2026-10-23 07:00** (the jam page gives no timezone; the last Jamference used UTC+3). After the deadline only fixes for bugs that block play are allowed.
