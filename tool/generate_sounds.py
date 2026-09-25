#!/usr/bin/env python3
"""Generates the game's sound effects into assets/audio as 16-bit mono WAVs.

    python3 tool/generate_sounds.py

The clips are synthesised rather than sourced, which keeps them original, free
of licensing questions and small enough to sit in the repository — the whole set
is a couple of hundred kilobytes. Regenerating is deterministic, so editing a
number here and re-running is the way to retune a sound.

Everything is built from three ingredients:

* bells   - a fundamental plus deliberately inharmonic partials, each decaying
            faster than the one below it. That uneven decay is what reads as
            metal rather than as a plain sine tone.
* noise    - seeded, so a rebuild produces byte-identical files.
* sweeps   - phase accumulated per sample, because the frequency moves.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets",
    "audio",
)

# Note frequencies, equal temperament.
C6, D6, E6, F6, G6, A6 = 1046.50, 1174.66, 1318.51, 1396.91, 1567.98, 1760.00
C7, E7, G7 = 2093.00, 2637.02, 3135.96

# ratio, amplitude, decay multiplier. Ratios sit just off the harmonic series
# so the partials beat against each other slightly.
BELL_PARTIALS = (
    (1.00, 1.00, 1.0),
    (2.01, 0.50, 1.9),
    (3.02, 0.26, 2.7),
    (4.21, 0.13, 3.6),
    (5.43, 0.07, 4.5),
)


def buffer(duration):
    """A silent buffer long enough to hold `duration` seconds."""
    return [0.0] * int(duration * SAMPLE_RATE)


def mix(into, samples, at=0.0):
    """Adds `samples` into `into`, starting at `at` seconds."""
    start = int(at * SAMPLE_RATE)
    for offset, value in enumerate(samples):
        index = start + offset
        if 0 <= index < len(into):
            into[index] += value


def bell(freq, duration, amp=1.0, decay=7.0, partials=BELL_PARTIALS):
    """A struck metallic tone."""
    count = int(duration * SAMPLE_RATE)
    out = [0.0] * count
    for ratio, partial_amp, partial_decay in partials:
        omega = 2.0 * math.pi * freq * ratio
        for i in range(count):
            t = i / SAMPLE_RATE
            out[i] += partial_amp * math.exp(-decay * partial_decay * t) * math.sin(omega * t)
    return [amp * v for v in out]


def noise(duration, amp=1.0, decay=40.0, seed=0):
    """A decaying burst of noise, for transients."""
    rng = random.Random(seed)
    count = int(duration * SAMPLE_RATE)
    return [
        amp * math.exp(-decay * (i / SAMPLE_RATE)) * (rng.random() * 2.0 - 1.0)
        for i in range(count)
    ]


def sweep(start_freq, end_freq, duration, amp=1.0, curve=1.0):
    """A sine whose frequency travels from `start_freq` to `end_freq`."""
    count = int(duration * SAMPLE_RATE)
    out = [0.0] * count
    phase = 0.0
    for i in range(count):
        progress = (i / count) ** curve
        freq = start_freq + (end_freq - start_freq) * progress
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        out[i] = amp * math.sin(phase)
    return out


def swell(samples, attack=0.25, release=0.45):
    """Shapes a sound so it rises and falls instead of starting flat out."""
    count = len(samples)
    attack_samples = max(1, int(count * attack))
    release_samples = max(1, int(count * release))
    out = list(samples)
    for i in range(attack_samples):
        out[i] *= i / attack_samples
    for i in range(release_samples):
        out[count - 1 - i] *= i / release_samples
    return out


def normalise(samples, peak=0.72):
    """Scales to a fixed peak, leaving headroom below full scale."""
    loudest = max((abs(v) for v in samples), default=0.0)
    if loudest == 0.0:
        return samples
    scale = peak / loudest
    return [v * scale for v in samples]


def deglitch(samples, attack_ms=0.4, release_ms=3.0):
    """Fades the very start and end, so playback cannot click.

    The fade in is deliberately much shorter than the fade out: a percussive
    clip is mostly attack transient, and a few milliseconds of ramp at the front
    audibly blunts it. Half a millisecond is enough to avoid starting on a step.
    """
    out = list(samples)
    limit = len(out) // 2
    attack = min(max(1, int(SAMPLE_RATE * attack_ms / 1000.0)), limit)
    release = min(max(1, int(SAMPLE_RATE * release_ms / 1000.0)), limit)
    for i in range(attack):
        out[i] *= i / attack
    for i in range(release):
        out[len(out) - 1 - i] *= i / release
    return out


def write(name, samples):
    """Writes one clip, de-clicked then normalised, as 16-bit mono."""
    # Normalising last means the fades cannot pull the peak back below target.
    samples = normalise(deglitch(samples))
    frames = bytearray()
    for value in samples:
        clamped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(clamped * 32767))
    path = os.path.join(OUTPUT_DIR, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    duration = len(samples) / SAMPLE_RATE
    print(f"  {name:<20} {duration * 1000:6.0f} ms  {os.path.getsize(path) / 1024:6.1f} KiB")


def ui_tap():
    """A button press. Short enough not to be in the way when tapped fast."""
    out = buffer(0.06)
    mix(out, bell(1180.0, 0.06, amp=0.8, decay=55.0))
    mix(out, noise(0.008, amp=0.35, decay=340.0, seed=1))
    return out


def reel_stop():
    """A reel settling into its detent: a low thunk with a hard transient."""
    out = buffer(0.16)
    mix(out, bell(172.0, 0.16, amp=1.0, decay=26.0))
    mix(out, bell(344.0, 0.09, amp=0.32, decay=44.0))
    mix(out, noise(0.014, amp=0.5, decay=240.0, seed=2))
    return out


def spin_start():
    """The reels being let go: a rising whoosh under a rising tone."""
    out = buffer(0.46)
    mix(out, swell(sweep(150.0, 760.0, 0.46, amp=0.55, curve=1.5)))
    mix(out, swell(noise(0.46, amp=0.4, decay=1.6, seed=3), attack=0.35))
    return out


def win_small():
    """Two rising chimes. The everyday win, so it stays brief."""
    out = buffer(0.42)
    mix(out, bell(C6, 0.26, amp=0.85), at=0.0)
    mix(out, bell(E6, 0.30, amp=0.9), at=0.11)
    return out


def win_big():
    """A four-note arpeggio, clearly bigger than win_small without being long."""
    out = buffer(1.0)
    for index, (note, at) in enumerate(
        ((C6, 0.0), (E6, 0.12), (G6, 0.24), (C7, 0.38))
    ):
        mix(out, bell(note, 0.62, amp=0.75 + 0.06 * index, decay=5.2), at=at)
    return out


def win_jackpot():
    """A six-note climb that lands on a ringing chord."""
    out = buffer(1.8)
    for index, (note, at) in enumerate(
        ((C6, 0.0), (E6, 0.10), (G6, 0.20), (C7, 0.30), (E7, 0.40), (G7, 0.50))
    ):
        mix(out, bell(note, 0.8, amp=0.62 + 0.05 * index, decay=5.0), at=at)
    # The chord underneath rings on after the climb finishes.
    for note in (C6, E6, G6, C7):
        mix(out, bell(note, 1.2, amp=0.42, decay=2.6), at=0.6)
    return out


def bonus():
    """Free spins triggering: a sparkle climbing a pentatonic scale."""
    out = buffer(0.95)
    for index, note in enumerate((C6, D6, F6, G6, A6, C7)):
        mix(out, bell(note, 0.42, amp=0.6, decay=9.0), at=0.075 * index)
    mix(out, bell(C7, 0.7, amp=0.5, decay=3.4), at=0.5)
    return out


def credit_tick():
    """One credit landing, played repeatedly while a win counts up."""
    out = buffer(0.07)
    mix(out, bell(2380.0, 0.07, amp=0.7, decay=70.0))
    mix(out, noise(0.005, amp=0.2, decay=420.0, seed=4))
    return out


CLIPS = {
    "ui_tap.wav": ui_tap,
    "reel_stop.wav": reel_stop,
    "spin_start.wav": spin_start,
    "win_small.wav": win_small,
    "win_big.wav": win_big,
    "win_jackpot.wav": win_jackpot,
    "bonus.wav": bonus,
    "credit_tick.wav": credit_tick,
}


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Writing {len(CLIPS)} clips to {OUTPUT_DIR}")
    for name, build in CLIPS.items():
        write(name, build())


if __name__ == "__main__":
    main()
