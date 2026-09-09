"""Rebuild Chicken Pit's original, offline-authored PCM sound bank (stdlib only).

The game plays these WAV files, never a runtime synthesizer. No recordings,
samples, melodies, or models from external asset libraries are used.
"""

from array import array
from math import exp, pi, sin
from pathlib import Path
from random import Random
import sys
import wave

RATE = 22050
TAU = 2 * pi
DESTINATION = Path(__file__).resolve().parents[1].joinpath("assets", "audio")


def track(seconds):
    return [0.0] * round(seconds * RATE)


def add(buffer, start, seconds, sound, gain=1.0):
    first = round(start * RATE)
    for i in range(round(seconds * RATE)):
        offset = first + i
        if offset >= len(buffer):
            break
        buffer[offset] += sound(i / RATE) * gain


def note(midi, decay=9.0):
    frequency = 440.0 * 2 ** ((midi - 69) / 12)

    def pluck(t):
        phase = TAU * frequency * t
        attack = min(t * 800, 1.0)
        return attack * exp(-t * decay) * (
            sin(phase) + 0.34 * sin(phase * 2.003) + 0.12 * sin(phase * 3)
        )

    return pluck


def write(name, samples, peak=0.6, fade=True):
    maximum = max(abs(sample) for sample in samples) or 1.0
    output = array("h")
    for i, sample in enumerate(samples):
        envelope = min(i / 160, (len(samples) - 1 - i) / 240, 1.0) if fade else 1.0
        output.append(round(sample / maximum * peak * max(envelope, 0.0) * 32767))
    if sys.byteorder != "little":
        output.byteswap()
    with wave.open(str(DESTINATION.joinpath(name + ".wav")), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(output.tobytes())


def cluck(t):
    return min(t * 950, 1.0) * exp(-t * 24) * (
        sin(TAU * (620 * t - 1200 * t * t))
        + 0.25 * sin(TAU * (1120 * t - 1900 * t * t))
    )


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    random = Random(8247)
    pull = track(0.16)
    add(pull, 0, 0.16, cluck)
    write("pull", pull, 0.48)

    capture = track(0.32)
    add(capture, 0, 0.30, note(84, 18), 0.7)
    add(capture, 0.09, 0.23, note(91, 19), 0.5)
    write("notch", capture, 0.56)

    pin = track(0.95)
    for i, pitch in enumerate([72, 76, 79, 84]):
        add(pin, i * 0.085, 0.55, note(pitch, 5), 0.7)
    add(pin, 0.48, 0.3, cluck, 0.45)
    write("pin", pin, 0.65)

    # The periodic pitch bends close at the loop boundary.
    creak = track(2.0)
    for i in range(len(creak)):
        t = i / RATE
        phase = TAU * 62.5 * t + sin(TAU * t) * 3.5
        creak[i] = sin(phase) * sin(phase * 2) * (0.30 + 0.20 * sin(TAU * t * 2))
    write("rope-creak", creak, 0.25)

    # Menu "back": the pit gate dropping onto its latch. Two descending knocks,
    # short enough to fire on every keypress without ringing over the next one.
    latch = track(0.26)
    add(latch, 0, 0.20, note(45, 42), 0.9)
    add(latch, 0.055, 0.17, note(38, 34), 0.7)
    write("latch", latch, 0.42)

    crowd = track(4.0)
    low = 0.0
    for i in range(len(crowd)):
        low = low * 0.94 + random.uniform(-1, 1) * 0.06
        crowd[i] = low * 0.36
    for bird in range(19):
        at = random.uniform(0.05, 3.6)
        pitch = random.uniform(0.6, 1.6)
        add(crowd, at, 0.28, lambda t, pitch=pitch: cluck(t * pitch), 0.045)
    write("crowd", crowd, 0.30)

    # "The Great Pull-Off": an original 8-bar plucked county-fair jig, 110 BPM.
    beat = 60 / 110
    music = track(32 * beat)
    melody = [
        76, 79, 81, 79, 76, 74, 72, 67,
        69, 72, 77, 76, 74, 72, 69, None,
        74, 79, 83, 81, 79, 74, 71, 67,
        72, 76, 79, 76, 74, 72, 67, None,
        79, 81, 84, 81, 79, 76, 74, 72,
        77, 81, 79, 77, 76, 74, 72, 69,
        74, 79, 83, 86, 83, 79, 74, 71,
        72, 79, 76, 74, 72, None, 67, None,
    ]
    for i, midi in enumerate(melody):
        if midi is not None:
            add(music, i * beat / 2, beat * 0.9, note(midi, 10), 0.105)
    roots = [48, 53, 55, 48, 48, 53, 55, 48]
    for pulse in range(32):
        root = roots[pulse // 4]
        add(music, pulse * beat, beat * 0.85,
            note(root if pulse % 2 == 0 else root + 7, 5), 0.11)
        if pulse % 2:
            for interval in [12, 16, 19]:
                add(music, pulse * beat, 0.18, note(root + interval, 22), 0.023)
        else:
            add(music, pulse * beat, 0.12,
                lambda t: sin(TAU * (68 * t - 130 * t * t)) * exp(-t * 30), 0.08)
        for half in range(2):
            noise = [random.uniform(-1, 1) for _ in range(round(0.065 * RATE))]
            add(music, (pulse + half * 0.5) * beat, 0.065,
                lambda t, noise=noise: noise[min(int(t * RATE), len(noise) - 1)]
                * exp(-t * 70), 0.012)
    write("pit-jig", music, 0.38)

    # A beat-locked danger stem, not a faster/louder copy of the main tune.
    # Author it last so the existing sound bank keeps exactly the same RNG draws.
    danger = track(32 * beat)
    for pulse in range(32):
        root = roots[pulse // 4]
        add(danger, pulse * beat, 0.22,
            lambda t: min(t * 900, 1.0) * exp(-t * 22)
            * sin(TAU * (74 * t - 110 * t * t)), 0.42)
        for half in range(2):
            add(danger, (pulse + half * 0.5) * beat, beat * 0.45,
                note(root + (12 if half else 0), 14), 0.15)
        for subdivision in range(4):
            at = (pulse + subdivision * 0.25) * beat
            noise = [random.uniform(-1, 1) for _ in range(round(0.09 * RATE))]
            accent = pulse % 2 == 1 and subdivision == 0
            roll = pulse % 4 == 3 and subdivision >= 2
            add(danger, at, 0.09,
                lambda t, noise=noise: noise[min(int(t * RATE), len(noise) - 1)]
                * min(t * 1200, 1.0) * exp(-t * 48),
                0.20 if accent else (0.12 if roll else 0.035))
            if subdivision % 2 == 1:
                interval = [12, 19, 16, 19][(pulse + subdivision) % 4]
                add(danger, at, beat * 0.35, note(root + interval, 19), 0.07)
    # Even simultaneous peaks leave 0.28 full-scale headroom with the base stem.
    write("pit-jig-danger", danger, 0.34)
    print("Rendered eight original Chicken Pit WAV assets.")


if __name__ == "__main__":
    main()
