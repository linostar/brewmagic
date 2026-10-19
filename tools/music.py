#!/usr/bin/env python3
"""Synthesises BrewMagic's four music-box folk loops and encodes them to MP3.

Ported from Silly Kitty's chiptune tools/music.py (../jamference-20261002) and re-voiced:
a music box carries the melody (sine partials with a short metallic tine), a plucked lute
(additive string partials, the high ones dying first) plays the chords, a plucked bass
string the roots, and a soft frame drum and shaker keep time where a track needs them.
All four loops are built on one motif (MOTIF: G-C-E rising, a step down, a lift to A,
home): the title states it alone, the shop day turns it into a waltz with a middle
section, Rush Hour runs it as a fast jig and the ending slows it down to a full close.

Each loop is rendered into a buffer exactly one loop long. Note tails that run past the
end wrap around to the start, so the last sample flows into the first and the loop is
seamless. MP3 encoding adds silence before and after the audio; lame records how much in
its LAME/Xing tag, and Godot's decoder (like ffmpeg) trims it, so the decoded file is
exactly one loop and Godot's plain whole-file loop is seamless. Never pass lame -t: it
drops that tag. After encoding, each file is decoded (gapless) with ffmpeg to check it is
exactly one loop long, and the loop is switched on in its .import file.

The rendered PCM of every loop is deterministic (stdlib only, fixed seeds); its sha256 and
length are recorded in tools/music.lock.json, which --check compares against a fresh render
(no lame or ffmpeg needed, so validate.sh runs it locally and in CI).

Usage (from repo root):
    python3 tools/music.py           render, encode brewmagic/audio/music/<track>.mp3, write the lock
    python3 tools/music.py --check   render in memory and verify the lock, the MP3s and their
                                     .import loop flags; prints "music: OK"
Generating needs lame and ffmpeg on PATH (Homebrew: brew install lame ffmpeg). The MP3s are
constant bitrate (96 kbps mono) without ID3 tags.
"""
import hashlib
import json
import math
import operator
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "brewmagic" / "audio" / "music"
LOCK = ROOT / "tools" / "music.lock.json"
RATE = 44100
# Music sits under the sound effects (tools/sfx.py PEAK 0.9).
PEAK = 0.6
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
# The four MP3s together must stay under this (plan step 9, AC4).
MAX_TOTAL_BYTES = 3 * 1024 * 1024


class MusicError(Exception):
    pass


def freq(note):
    """'C5', 'F#4', 'Bb3' -> Hz (A4 = 440)."""
    name, octave = note[:-1], int(note[-1])
    semitone = NOTE_NAMES[name[0]] + name.count("#") - name.count("b")
    return 440.0 * 2 ** ((semitone + 12 * (octave + 1) - 69) / 12)


def parse(bars):
    """Bars of space-separated steps: a note (or notes joined by '+') starts, '-' holds,
    '.' rests. Returns ([(notes, start_step, length_steps)], total_steps)."""
    steps = " ".join(bars).split()
    events = []
    for i, token in enumerate(steps):
        if token in ("-", "."):
            continue
        length = 1
        while i + length < len(steps) and steps[i + length] == "-":
            length += 1
        events.append((token.split("+"), i, length))
    return events, len(steps)


_CACHE = {}


def partials_tone(hz, n, partials, attack, damp_from=None, damp_len=0):
    """Sum of sine partials (frequency multiple, amplitude, decay per second), n samples,
    with a linear attack and, from sample damp_from on, a damp_len-sample fade out."""
    key = (round(hz, 6), n, partials, attack, damp_from, damp_len)
    if key in _CACHE:
        return _CACHE[key]
    out = [0.0] * n
    for mult, amp, decay in partials:
        w = 2 * math.pi * hz * mult / RATE
        if w >= math.pi:
            continue
        r = math.exp(-decay / RATE)
        out = list(map(operator.add, out, [amp * math.sin(w * i) * r ** i for i in range(n)]))
    a = max(1, int(attack * RATE))
    for i in range(min(a, n)):
        out[i] *= i / a
    if damp_from is not None:
        for i in range(damp_from, n):
            out[i] *= max(0.0, 1.0 - (i - damp_from) / max(1, damp_len))
    _CACHE[key] = out
    return out


# Instruments: (partials, attack seconds, ring seconds, damped). A ringing instrument
# (the music box) lets every note sound for `ring` seconds whatever its written length;
# a damped one (lute, bass) stops at the written length with a short fade.
MUSIC_BOX = (((1.0, 1.0, 2.6), (2.0, 0.28, 4.0), (3.0, 0.08, 6.0), (5.98, 0.22, 38.0)), 0.001, 1.6, False)
LUTE = (tuple((h, 0.9 / h ** 1.1 * abs(math.sin(math.pi * h * 0.18)), 2.2 + 1.6 * h) for h in range(1, 9)), 0.003, 0.0, True)
BASS = (tuple((h, 1.0 / h ** 1.4, 1.6 + 1.2 * h) for h in range(1, 6)), 0.004, 0.0, True)
DAMP_SECONDS = 0.05


def render_note(instrument, hz, seconds):
    partials, attack, ring, damped = instrument
    if damped:
        n = int((seconds + DAMP_SECONDS) * RATE)
        return partials_tone(hz, n, partials, attack, int(seconds * RATE), int(DAMP_SECONDS * RATE))
    # A ringing note still fades over its last DAMP_SECONDS, so its cut never clicks.
    n = int(max(seconds, ring) * RATE)
    return partials_tone(hz, n, partials, attack, n - int(DAMP_SECONDS * RATE), int(DAMP_SECONDS * RATE))


def add_into(buf, samples, start, gain):
    """Adds samples * gain into buf from `start`, wrapping past the end to the start."""
    size = len(buf)
    start %= size
    pos = 0
    while pos < len(samples):
        at = (start + pos) % size
        count = min(len(samples) - pos, size - at)
        buf[at:at + count] = map(operator.add, buf[at:at + count], [s * gain for s in samples[pos:pos + count]])
        pos += count


def drum(rng):
    """A soft frame drum: a falling low sine with a little skin noise."""
    n, phase, out = int(0.22 * RATE), 0.0, []
    for i in range(n):
        phase += (95.0 * (1.0 + 0.8 * math.exp(-28.0 * i / RATE))) / RATE
        out.append(math.sin(2 * math.pi * phase) * math.exp(-14.0 * i / RATE) + rng.uniform(-0.12, 0.12) * math.exp(-60.0 * i / RATE))
    return out


def shaker(rng):
    """A seed shaker: a short burst of bright noise."""
    n, last, out = int(0.06 * RATE), 0.0, []
    for i in range(n):
        x = rng.uniform(-1.0, 1.0)
        out.append((x - last) * math.sin(math.pi * i / n))
        last = x
    return out


# Chords: bass root, bass fifth, lute triad (low to high).
CHORDS = {
    "C": ("C3", "G2", ("C4", "E4", "G4")),
    "G": ("G2", "D3", ("B3", "D4", "G4")),
    "Am": ("A2", "E3", ("A3", "C4", "E4")),
    "F": ("F2", "C3", ("A3", "C4", "F4")),
    "Dm": ("D3", "A2", ("A3", "D4", "F4")),
    "Em": ("E3", "B2", ("G3", "B3", "E4")),
}

# The shared motif (8 bars of six 8th-note steps, 3/4) and its chords.
MOTIF = [
    "G4 - C5 - E5 -", "D5 - - - C5 B4", "E5 - G5 - A5 -", "G5 - - - - -",
    "A5 - G5 - E5 -", "F5 - - - E5 D5", "C5 - D5 - B4 -", "C5 - - - - -",
]
MOTIF_CHORDS = ["C", "G", "C", "C", "F", "Dm", "G", "C"]
# The motif answered with ornaments (title and shop return).
MOTIF_ORNATE = [
    "G4 - C5 E5 G5 E5", "D5 - - C5 B4 D5", "E5 - G5 - A5 C6", "G5 - - - E5 -",
    "A5 - G5 - E5 C5", "F5 - - E5 D5 -", "C5 - D5 - B4 G4", "C5 - - - - -",
]


def accompaniment(chords, style):
    """Per-bar lute and bass lines for `chords` (one per bar, six steps a bar) in `style`."""
    lute, bass = [], []
    for name in chords:
        root, fifth, (t0, t1, t2) = CHORDS[name]
        if style == "rolled":  # title: a chord rolled up and left to ring
            lute.append(f"{t0} {t1} {t2} - - -")
            bass.append(f"{root} - - - - -")
        elif style == "waltz":  # shop: oom-pah-pah
            lute.append(f". . {t0}+{t1}+{t2} . {t0}+{t1}+{t2} .")
            bass.append(f"{root} - . . . .")
        elif style == "jig":  # rush: two strong beats of a 6/8 bar
            lute.append(f"{t0}+{t1}+{t2} . {t1} {t0}+{t1}+{t2} . {t2}")
            bass.append(f"{root} - . {fifth} - .")
        elif style == "flowing":  # ending: a rolling arpeggio under a long bass note
            lute.append(f"{t0} {t2} {t1} {t2} {t1} {t2}")
            bass.append(f"{root} - - - - -")
        else:
            raise MusicError(f"unknown accompaniment style '{style}'")
    return lute, bass


def track(name, step, melody, chords, style, drums, lute_melody_gain=0.0):
    """A loop: `step` seconds per step (an 8th note), the melody bars, one chord per bar,
    the accompaniment style, the drum bars ('k' drum, 'K' soft drum, 's' shaker, '.' none)
    and how loud the lute doubles the melody an octave down (0: not at all)."""
    lute, bass = accompaniment(chords, style)
    return {"name": name, "step": step, "melody": melody, "lute": lute, "bass": bass, "drums": drums,
            "lute_melody_gain": lute_melody_gain}


def eighth(quarter_bpm):
    return 60.0 / quarter_bpm / 2


# Title: the motif alone, then answered with ornaments, over rolled chords (84 BPM, 3/4).
TITLE = track("title", eighth(84), MOTIF + MOTIF_ORNATE, MOTIF_CHORDS * 2, "rolled", ["......"] * 16)

# Shop: a waltz (108 BPM): the motif, a middle section in A minor, the ornate return.
SHOP_MIDDLE = [
    "A5 - - - G5 E5", "F5 - E5 - D5 -", "E5 - - - D5 C5", "D5 - - - - -",
    "A5 - - - G5 E5", "F5 - A5 - C6 -", "B5 - - - A5 B5", "G5 - - - - -",
]
SHOP = track("shop", eighth(108), MOTIF + SHOP_MIDDLE + MOTIF_ORNATE, MOTIF_CHORDS + ["Am", "F", "C", "G", "Am", "F", "G", "G"] + MOTIF_CHORDS,
             "waltz", ["k....."] * 24)

# Rush Hour: the motif as a running jig in 6/8 (dotted quarter 125 BPM), busier and faster,
# the lute doubling the tune an octave down.
RUSH_A = [
    "G4 C5 E5 G5 E5 C5", "D5 - C5 B4 - G4", "E5 - G5 A5 - G5", "G5 E5 C5 G4 C5 E5",
    "A5 - G5 E5 - C5", "F5 - E5 D5 - A4", "C5 - D5 B4 - G4", "C5 E5 G5 C6 - -",
]
RUSH_A2 = RUSH_A[:7] + ["C5 - - C5 - -"]
RUSH_B = [
    "A5 G5 E5 C5 E5 A5", "F5 E5 C5 A4 C5 F5", "G5 E5 C5 G4 C5 E5", "D5 B4 G4 B4 D5 G5",
    "A5 G5 E5 A5 - C6", "A5 - F5 C5 - A4", "B4 D5 G5 B5 A5 G5", "D5 - - G4 - -",
]
RUSH = track("rush", 0.16, RUSH_A + RUSH_A2 + RUSH_B + RUSH_A,
             MOTIF_CHORDS * 2 + ["Am", "F", "C", "G", "Am", "F", "G", "G"] + MOTIF_CHORDS,
             "jig", ["kssKss"] * 32, lute_melody_gain=0.35)

# Ending: the motif slowed down to a warm, full close (66 BPM, 3/4).
ENDING = track("ending", eighth(66), [
    "G4 - C5 - E5 -", "D5 - - - C5 B4", "C5 - E5 - A5 -", "G5 - - - - -",
    "A5 - G5 - F5 -", "E5 - - - C5 -", "D5 - F5 - A5 -", "G5 - - - F5 -",
    "E5 - G5 - C6 -", "A5 - - - G5 F5", "D5 - - - B4 -", "C5 - - - - -",
], ["C", "G", "Am", "Em", "F", "C", "Dm", "G", "C", "F", "G", "C"], "flowing", ["......"] * 12)

TRACKS = (TITLE, SHOP, RUSH, ENDING)


def render(spec):
    """One loop of `spec` as float samples."""
    step = spec["step"]
    total = None
    voices = []
    for key, instrument, gain, octave in (("melody", MUSIC_BOX, 0.32, 0), ("lute", LUTE, 0.16, 0), ("bass", BASS, 0.34, 0),
                                          ("melody", LUTE, spec["lute_melody_gain"] * 0.32, -1)):
        if gain <= 0.0:
            continue
        events, steps = parse(spec[key])
        if total is None:
            total = steps
        elif steps != total:
            raise MusicError(f"{spec['name']}: '{key}' is {steps} steps, expected {total}")
        voices.append((events, instrument, gain, octave))
    size = int(round(total * step * RATE))
    buf = [0.0] * size
    for events, instrument, gain, octave in voices:
        for notes, start, length in events:
            for note in notes:
                hz = freq(note) * 2.0 ** octave
                add_into(buf, render_note(instrument, hz, length * step * 0.95), int(round(start * step * RATE)), gain)
    hits = "".join(spec["drums"])
    if len(hits) != total:
        raise MusicError(f"{spec['name']}: 'drums' is {len(hits)} steps, expected {total}")
    rng = random.Random(f"music/{spec['name']}")
    kit = {"k": (drum(rng), 0.3), "K": (drum(rng), 0.18), "s": (shaker(rng), 0.05)}
    for i, hit in enumerate(hits):
        if hit in kit:
            add_into(buf, kit[hit][0], int(round(i * step * RATE)), kit[hit][1])
        elif hit != ".":
            raise MusicError(f"{spec['name']}: unknown drum '{hit}'")
    return buf


def to_pcm(samples):
    top = max(abs(s) for s in samples) or 1.0
    return b"".join(struct.pack("<h", int(s / top * PEAK * 32767)) for s in samples)


def render_all():
    """{track name: (16-bit mono PCM bytes, sample count)} for every track."""
    rendered = {}
    for spec in TRACKS:
        pcm = to_pcm(render(spec))
        rendered[spec["name"]] = (pcm, len(pcm) // 2)
    return rendered


def lock_entry(pcm, samples):
    return {"samples": samples, "seconds": round(samples / RATE, 3), "sha256": hashlib.sha256(pcm).hexdigest()}


def import_has_loop(mp3):
    path = Path(str(mp3) + ".import")
    return path.exists() and "loop=true" in path.read_text().splitlines()


def check():
    try:
        lock = json.loads(LOCK.read_text())
    except (OSError, ValueError) as e:
        raise MusicError(f"cannot read {LOCK.relative_to(ROOT)}: {e}; run python3 tools/music.py")
    problems = []
    rendered = render_all()
    if sorted(lock) != sorted(rendered):
        problems.append(f"{LOCK.relative_to(ROOT)} lists {sorted(lock)}, the tracks are {sorted(rendered)}")
    total_bytes = 0
    for name, (pcm, samples) in rendered.items():
        want = lock.get(name, {})
        if want.get("samples") != samples:
            problems.append(f"{name}: the loop is {samples} samples, the lock says {want.get('samples')}")
        if want.get("sha256") != hashlib.sha256(pcm).hexdigest():
            problems.append(f"{name}: the rendered audio differs from the lock, run python3 tools/music.py")
        mp3 = OUT_DIR / f"{name}.mp3"
        if not mp3.exists():
            problems.append(f"{mp3.relative_to(ROOT)} missing, run python3 tools/music.py")
            continue
        total_bytes += mp3.stat().st_size
        if not import_has_loop(mp3):
            problems.append(f"{mp3.relative_to(ROOT)}.import does not switch the loop on (loop=true)")
    for path in sorted(OUT_DIR.glob("*.mp3")):
        if path.stem not in rendered:
            problems.append(f"{path.relative_to(ROOT)} is stale: no track makes it any more")
    if total_bytes > MAX_TOTAL_BYTES:
        problems.append(f"the MP3s total {total_bytes} bytes, over {MAX_TOTAL_BYTES}")
    if problems:
        raise MusicError("\n".join(problems))
    print(f"music: OK ({len(rendered)} loops, {total_bytes} bytes of MP3)")


def check_decode(ffmpeg, mp3, samples):
    """Decodes `mp3` the gapless way (as Godot does) and confirms it is exactly `samples` long."""
    raw = subprocess.run([ffmpeg, "-v", "error", "-i", str(mp3), "-f", "s16le", "-ac", "1", "-"],
                         capture_output=True, check=True).stdout
    if len(raw) // 2 != samples:
        raise MusicError(f"{mp3} decodes to {len(raw) // 2} samples, expected {samples}; is lame still writing its LAME tag?")


def write_import(mp3):
    """Switches Godot's plain loop on in <mp3>.import, keeping whatever else Godot wrote there."""
    path = Path(str(mp3) + ".import")
    params = {"loop": "true", "loop_offset": "0", "bpm": "0", "beat_count": "0", "bar_beats": "4"}
    if path.exists():
        lines, seen = [], set()
        for line in path.read_text().splitlines():
            key = line.split("=", 1)[0]
            if key in params:
                line = f"{key}={params[key]}"
                seen.add(key)
            lines.append(line)
        lines += [f"{k}={v}" for k, v in params.items() if k not in seen]
        text = "\n".join(lines) + "\n"
    else:
        res = "res://" + mp3.resolve().relative_to(ROOT / "brewmagic").as_posix()
        text = (f'[remap]\n\nimporter="mp3"\ntype="AudioStreamMP3"\n\n[deps]\n\nsource_file="{res}"\n\n[params]\n\n'
                + "".join(f"{k}={v}\n" for k, v in params.items()))
    path.write_text(text)


def generate():
    lame, ffmpeg = shutil.which("lame"), shutil.which("ffmpeg")
    if lame is None or ffmpeg is None:
        raise MusicError("lame and ffmpeg are needed on PATH to encode (Homebrew: brew install lame ffmpeg)")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lock = {}
    with tempfile.TemporaryDirectory() as tmp:
        for name, (pcm, samples) in render_all().items():
            wav = Path(tmp) / f"{name}.wav"
            with wave.open(str(wav), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm)
            mp3 = OUT_DIR / f"{name}.mp3"
            # CBR, no ID3 tags. Keep the LAME tag (no -t): it makes the decoded file one loop long.
            result = subprocess.run([lame, "--quiet", "-m", "m", "-b", "96", "--noreplaygain", str(wav), str(mp3)],
                                    capture_output=True, text=True)
            if result.returncode != 0:
                raise MusicError(f"lame failed for {mp3}: {result.stderr.strip()}")
            check_decode(ffmpeg, mp3, samples)
            write_import(mp3)
            lock[name] = lock_entry(pcm, samples)
            print(f"music: wrote {mp3.relative_to(ROOT)} ({samples / RATE:.3f}s loop, {samples} samples, {mp3.stat().st_size} bytes)")
    LOCK.write_text(json.dumps(lock, indent=2) + "\n")
    print(f"music: wrote {LOCK.relative_to(ROOT)}")


def main():
    try:
        if sys.argv[1:] == ["--check"]:
            check()
        elif not sys.argv[1:]:
            generate()
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except MusicError as e:
        print(f"music: error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
