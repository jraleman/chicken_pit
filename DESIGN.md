# Chicken Pit — Game Design Document

> **Status:** implemented. The pulling model, three CPU birds, Timer and Lives
> rounds, original 3D toy farm, rope, HUD, effects and audio are built. The
> implementation notes below record corrections found while exercising the design.
> **Target engine:** Godot 4.7, `gl_compatibility` renderer, as a game folder
> inside the existing `dcs_games` base project.
> **Location:** `dcs_games/godot-base/games/chicken_pit/`, discovered by
> `GameCatalog` at startup beside `triangle_rush`, `desk_can_saw` and
> `dead_metal_jam`.
> **Prior art:** a React/Three.js prototype, since removed from the repository.
> It informed *subject* — birds, rope, barn, posts — and explicitly **not**
> mechanics. Its pulling model was a placeholder (§3.1) and is replaced here.
> **This document covers gameplay and presentation only.** Menus, settings,
> boot flow, pause, results, share cards, achievements and accessibility
> already exist in the base and are consumed, not rebuilt.
> **Headline decision:** Chicken Pit is the first game in this project to run a
> **real `Node3D` world** (§5), hosted in a `SubViewport` so the shared 2D shell
> never has to learn about 3D.
> **Framework cost:** the host now provides **`CONTROL_STYLE_CUSTOM_KEYS`** —
> custom action keys and a CPU opponent, with live rebound instructions.
> `GameShell` itself remains unchanged.

### Implementation notes

- The models are original, vertex-painted geometry in `pit/toy_mesh.gd`,
  `scenery.gd` and `chicken_rig.gd`. Tagged rigid parts animate in a vertex
  shader, keeping each bird to one draw surface. No external models were needed.
- Original WAV assets and the county-fair jig replace the absent prototype
  audio. `tools/render_audio.py` is offline authoring, not runtime synthesis.
  The supplied opening narration is unchanged and retains its original ownership.
- The matte presentation uses a changing sunset key, cool ambient fill and
  directional shadows, without SSAO or glow. Automatic camera shots favour
  the coop losing ground and follow the actual falling birds. Scenery,
  spectators and notches are batched; `pit_view_test.gd`
  enforces the below-60 draw-call budget with a real Compatibility renderer.
- Strength **and** rope travel/held-ground area are integrated analytically,
  including velocity saturation, the deadzone, zero crossings and the actual
  pin instant. Exponential decay alone would not make frame-end Euler motion
  independent of frame rate. Equivalent elapsed times agree within floating
  precision (`1e-8` in the regression), not necessarily bit for bit.
- Three true 30 Hz frames equal `0.1 s`; the small gate epsilon permits 10 Hz
  there too. Six times `0.0167 s` equals `0.1002 s`, so equivalence tests use
  `0.1 / 6`, not a rounded substitute.
- Scaling gain and decay preserves the **continuous approximation** to
  equilibrium, not the exact discrete sawtooth: clean 10 Hz mean strength is
  `43.96507` at speed 1.0 and `43.52055` at speed 0.6. The assist still slows
  travel without materially increasing the strength demand.
- `extreme[i]` stores each coop's greatest **favourable magnitude**, including
  fractions of a notch. Clean Coop requires the opponent's value to be zero;
  Fowl Play requires it to reach `L - 1`. Recaptures count in stats and notch
  runs, but only a new match-wide deepest notch earns the 100-point bonus.
- The actual shell script is `res://scripts/game_shell.gd`. Its default lives
  rule ends when **all** players are out, not either player. Chicken Pit
  specializes its active seats, elimination predicate and remaining-life gauge
  so a duel ends on the first exhausted coop, without changing the framework.
- A scene-owned, pausable `PinHold` timer replaces an always-processing
  `SceneTreeTimer`. A pin stops the round clock immediately, survives a buzzer,
  freezes input/model updates and completes outside the shell's process stack.
  A nonterminal lives pin re-centres the state and resets the CPU's schedule.
  A frame hitch at timeout only integrates the time still left on the clock.
- The safety matrix covers all rope lengths and the Cartesian product of
  power/decay corners plus defaults and speeds 0.6/0.8/1.0: 351 configurations.
  Dominance pins take 3.588–25.982 seconds; a scripted perfect player beats all
  three birds, and clean 3 Hz beats Chick. This is a representative safety
  grid, not an assertion about every point of a continuous option space.

---

## 1. Concept

*Chicken Pit* is a **barnyard tug-of-war for two coops**, played on one
keyboard, in a bright toy-farm 3D world.

Two flocks of chickens hold opposite ends of one rope. Hammering your three
pull keys builds *strength*; strength drains the moment you stop; the rope
moves toward whichever coop currently has more of it. Drag the knot past your
coop's goal line and you have pinned the other flock. If the clock runs out first,
whoever held the most ground wins.

The whole game is one number — the position of the knot — fought over by two
players who can both see exactly how they are doing. There is no hidden state,
no inventory, no map. That is the point.

### Locked pillars

| Pillar | Decision |
| --- | --- |
| Genre | Local-versus rhythm-of-mashing contest. One rope, two ends, forty-five seconds. |
| Presentation | **A real 3D world.** `Node3D`, `Camera3D`, lit meshes, shadows and 3D particles, hosted in a `SubViewport` inside the shell's 2D `%Playfield` (§5). |
| Look | **Colourful toy farm at sunset.** A golden-to-mauve sky and slowly changing warm key, balanced by cool fill so the birds and rope remain clear. The menus retain their darker, legible exposure (§6.1). |
| Skill expressed | **Rhythm, not raw frequency.** A hard rate ceiling plus an alternation penalty means the fastest input device wins nothing (§3.3). |
| Input | Two three-key clusters on one keyboard, both rebindable. Already declared in `chicken_pit_options.gd`. |
| Round shape | **Timer** — judged on ground held. **Lives** is a real second mode, not a fallback: each pin costs a life (§3.8). |
| Modes | Two humans on one keyboard, or one human against a named bird. A single-seat host entry also seats a CPU in the blue coop (§4.1). |
| Framework cost | **One change** — a new control style (§14.5). Everything else is already declared or already generic. |

### Look and tone

The earlier prototype rendered a grey post, a brown cylinder and two untextured
birds on a black background. The Godot build is the opposite of that: **a
sunset-lit, candy-coloured farm** — grass in two greens, a fire-engine-red barn
with white trim, warm yellow dirt in the pit itself, a peach-and-mauve sky with
fat warm clouds, and two coops of chickens in **scarlet** and **cyan** that
remain readable as the lighting changes.

The tone is slapstick, not gritty. Chickens brace, skid, flap and tumble into
the straw-lined hole at the centre of the arena.
Feathers burst on every hard pull. Dust kicks up at their feet. The crowd in
the stands jumps when the rope moves. Nothing bleeds and nobody dies: the
fallen birds join a cosy flock in the hole. The opening story (`intro.gd`)
still introduces the sunniest thing in the collection.

**The menus are the same fairground, one stop below.** `game.gd` declares a
`GameTheme` drawn entirely from the game's own colours — the tug meter's cream
and gold, the barn's red, the pit `Sun`'s warm key — over a turf-shadow
backdrop (`#16241f` → `#070d0a`), and `ui/menu_background.gdshader` reprises
the bunting, mown stripes and lamps of the approach. It dresses the menus, the
plaque and the share card, and it hands off to the pit as an exposure change
rather than a change of world. See §6.1 for the legibility floor that fixes how
bright the approach is allowed to get.

---

## 2. Core gameplay loop

```
        ┌───────────────────────────────────────────────────────────┐
        │  GameShell countdown  ·  "GO!"                            │
        │  camera pushes in on the knot; birds take the strain      │
        └────────────────────────────┬──────────────────────────────┘
                                     ▼
        ┌───────────────────────────────────────────────────────────┐
        │  THE PULL — every frame, while the round is active        │
        │                                                           │
        │   player taps a pull key                                  │
        │     → discarded if it is an OS key-repeat echo            │
        │     → discarded if that coop already pulled this window   │
        │     → alternation checked against that coop's last key    │
        │     → cadence checked against that coop's last pull time  │
        │     → strength += gain · (1 - strength / MAX)             │
        │     → bird lurches back, feathers burst, rope goes taut   │
        │                                                           │
        │   every frame                                             │
        │     → strength decays in proportion to itself             │
        │     → diff = strength[red] - strength[blue]               │
        │     → knot moves toward whichever coop has more           │
        │     → the leading coop banks ground-held points           │
        └────────────────────────────┬──────────────────────────────┘
                                     ▼
             knot past a goal line? ──yes──►  PIN
                                     │        Timer mode: round ends
                                     │        Lives mode: −1 life, re-centre
                                     no
                                     ▼
             clock still running?  ──yes──►  back to THE PULL
                                     │
                                     no
                                     ▼
        ┌───────────────────────────────────────────────────────────┐
        │  Round over — GameShell results, stats and share card     │
        │  the coop with the higher score wins, and the score IS    │
        │  ground held, so headline and scoreboard cannot disagree  │
        └───────────────────────────────────────────────────────────┘
```

A **round is one match**, `round_length` seconds long (default 45).

---

## 3. The pulling model

This is the heart of the game and the part the prototype did not have.

### 3.1 What the prototype did, and why it is being replaced

Its `MainGameScene` moved the rope **directly** on every keydown:

```ts
if (LEFT_TEAM_CONTROLS.includes(e.key)) {
  setRopePos(p => Math.min(p + 0.15, limit));
}
```

No strength, no decay, no state between presses. Three consequences, all fatal:

1. **Holding a key won.** OS key-repeat fires `keydown` continuously.
2. **An autofire pad won harder.** The fastest input device won outright.
3. **The CPU could not lose.** Its puller applied `0.5 * delta` unconditionally,
   every frame, forever. A constant headwind rather than an opponent.

The README, the manifest copy and `chicken_pit_options.gd` all already describe
the intended model instead — *"strength drains between pulls, so a steady
rhythm beats one wild burst"* — and the options for pull power and strength
decay exist precisely to tune it. This section specifies it.

### 3.2 State

Per coop `i ∈ {red = 0, blue = 1}`:

| Field | Type | Meaning |
| --- | --- | --- |
| `strength[i]` | `float` 0 – 100 | Current pulling power. Decays in proportion to itself. |
| `last_action[i]` | `StringName` | The pull key that coop used last, for the alternation check. |
| `last_pull_time[i]` | `float` | Round-clock time of that coop's last **accepted** pull. `-INF` before the first. |
| `extreme[i]` | `float` | Deepest signed position this coop ever reached. Drives achievements and stats. |

Shared:

| Field | Type | Meaning |
| --- | --- | --- |
| `rope` | `float` | **Signed notches, positive means red is ahead.** Range `[-L, +L]`. |
| `clock` | `float` | Seconds since the round activated. The only time source the model has. |
| `L` | `int` | `_round_rope_length`, the rope-length option (6 – 18, default 10). |

`rope` is a pure model quantity with no units in metres and no knowledge of the
camera. The 3D view maps it to world space (§8.3); nothing in the model ever
reads back from a node. This split is what makes the whole thing testable
headless (§14.8).

### 3.3 Accepting a pull

A key press becomes a pull only after four gates.

**Gate 1 — echoes are discarded.** `event.is_echo()` is rejected outright. A
held key produces exactly one pull, ever.

**Gate 2 — the rate ceiling.** If `clock - last_pull_time[i] < MIN_PULL_INTERVAL`,
the press is **rejected entirely** — not scaled down, rejected.
`MIN_PULL_INTERVAL = 0.10 s`, so **no coop can ever exceed 10 pulls per
second**, whatever is generating the events.

This gate is doing the load-bearing work, and it replaces an earlier design
that merely multiplied fast presses by 0.5. That version was broken: pressing
`Q`, `W` and `E` on the *same frame* produced three separate, non-echo,
perfectly-alternating events, and even at a reduced multiplier that chord beat
any honest rhythm. A multiplier cannot close a throughput exploit; only a hard
gate can. Same-frame chords now yield exactly one pull.

**The ceiling is frame-quantised, and that is accepted.** All inputs arriving
in one frame share one `clock`, which is what closes the chord exploit.
Six true 60 Hz frames and three true 30 Hz frames both span 0.1 seconds; a
small epsilon tolerates floating-point summation error. Other rates still
quantise input opportunities to whole frames. Both coops and the CPU share
that clock and ceiling. Settled-strength tests therefore simulate real frame
cadence rather than pretending every requested frequency divides it evenly.

**Gate 3 — alternation.** If the pressed action equals `last_action[i]`,
`alternation_factor = 0.35`; otherwise `1.0`. Three keys per coop is not
decoration — it is why `ChickenPitOptions.pull_actions()` returns three actions.
With Gate 2 capping everyone at 10 Hz, alternation is what separates a player
tapping one key at the ceiling from a player rolling three fingers at it.

**Gate 4 — cadence.** Measured against `last_pull_time[i]`, with half-open
intervals so every boundary belongs to exactly one band:

| Interval `dt` since that coop's last accepted pull | Factor |
| --- | --- |
| `dt < 0.10` | **rejected by Gate 2** |
| `0.10 ≤ dt < 0.12` | ramps linearly `1.00 → 1.15` |
| `0.12 ≤ dt < 0.45` | **1.15** — the groove |
| `0.45 ≤ dt` | **1.00** |
| first pull of the round (`last_pull_time = -INF`) | **1.15**, treated as in-groove |

The first-pull rule matters: a zero-initialised timestamp would otherwise
classify the opening press of the round against `clock = 0` and mis-band it.
`-INF` makes `dt` infinite, which lands in the honest `1.00` band — so it is
special-cased to `1.15` explicitly, because nobody should be punished for the
first press of the match.

There is no penalty band below the groove any more; Gate 2 makes one
unnecessary and unnecessary bands are places for bugs to hide.

```
gain = BASE_PULL_GAIN            (9.0)
     · pull_power_option         (0.5 – 2.0, player setting)
     · gameplay_speed_assist     (shared accessibility assist, §3.6)
     · alternation_factor        (1.0 or 0.35)
     · cadence_factor            (1.00 – 1.15)
```

### 3.4 Applying a pull — diminishing returns

```
strength[i] += gain · (1.0 - strength[i] / MAX_STRENGTH)
```

`MAX_STRENGTH = 100.0`.

The taper is what creates an **attracting equilibrium**. Without it, any
sustained rate above the break-even point drifts to the cap and stays there,
both coops sit pinned at 100, and every skill difference above the threshold
compresses to nothing. With it, each pull rate settles at its own strength, and
being faster is worth something all the way to the ceiling.

### 3.5 Decay is proportional, not absolute

```
strength[i] *= exp(-λ_eff · delta)
λ_eff = DECAY_LAMBDA · decay_option · gameplay_speed
```

`DECAY_LAMBDA = 1.2` per second.

**The exponential form is deliberate, and is not the same as `s -= s·λ·delta`.**
The subtractive form is a forward-Euler step of this equation, and it has two
defects that matter. At the legal corner *decay 2.0* the coefficient reaches
2.4, so any single frame longer than `1/2.4 ≈ 0.417 s` — an alt-tab, a shader
compile, a load hitch — drives strength **negative**, which inverts `diff`,
sends the rope the wrong way and pushes the `(1 - s/MAX)` taper above 1.0.
`exp()` cannot produce a negative strength for any `delta`, however large.
Second, the Euler step's result depends on frame rate; `exp()` composes exactly
(`e^{-λt₁}·e^{-λt₂} = e^{-λ(t₁+t₂)}`), so 30, 60 and 144 Hz produce *identical*
strength curves rather than merely similar ones, and §14.8 can assert that as
an equality.

**Proportional decay is a correctness requirement, not a flavour choice.** A
flat drain (an earlier draft used 26 strength/second) has a hard break-even
rate below which strength can never leave zero — and at the legal corner
*pull power 0.5 / decay 2.0* that break-even sits above the 10 Hz ceiling, so
the game becomes literally inert: no strength, no rope movement, no score, for
the whole round. Proportional decay approaches zero as strength does, so
strength can always accumulate from rest, and no legal option combination can
produce a dead match.

### 3.6 The equilibrium table

**Strength does not settle on a value — it settles into a sawtooth.** Each pull
jumps it up; decay drags it down until the next one. Quoting one number per
rate hides that, and an earlier draft's table did exactly that and was wrong
because of it. Three numbers describe the settled cycle, for a coop pulling
cleanly at a steady `f` pulls per second:

```
a       = exp(-λ_eff / f)                  decay across one pull interval
s_peak  = g / (1 - a + g · a / MAX)        just after a pull
s_trough= s_peak · a                       just before the next
s_mean  = s_peak · (1 - a) / (λ_eff / f)   the time-average
```

`s_mean` is the one that matters: the rope integrates the strength difference
over time (§3.7), so mean strength is what actually moves it. `s_peak` and
`s_trough` describe how much the tug meter visibly breathes.

**`g` is not constant across the table.** Gate 4's cadence factor depends on
the interval, and `1/f` leaves the groove at both ends: at 2 Hz `dt = 0.50 ≥
0.45` and at 10 Hz `dt = 0.10` sits at the bottom of the ramp, so both get
factor **1.00**, not 1.15. At default settings (`BASE_PULL_GAIN = 9.0`,
`λ_eff = 1.2`):

| Clean alternating rate | cadence | `g` | peak | **mean** | trough |
| --- | --- | --- | --- | --- | --- |
| 2 Hz | 1.00 | 9.00 | 17.98 | **13.52** | 9.87 |
| 3 Hz | 1.15 | 10.35 | 25.94 | **21.38** | 17.39 |
| 4 Hz | 1.15 | 10.35 | 30.82 | **26.62** | 22.83 |
| 6 Hz | 1.15 | 10.35 | 38.91 | **35.26** | 31.86 |
| 8 Hz | 1.15 | 10.35 | 45.32 | **42.08** | 39.01 |
| 10 Hz (the ceiling) | 1.00 | 9.00 | 46.66 | **43.97** | 41.38 |

Mean strength is **monotonically increasing** across the whole 2–10 Hz range —
verified by evaluating the closed form at 0.05 Hz steps. This matters: because
cadence *drops* from 1.15 to 1.00 as a player accelerates past 8.33 Hz, a
carelessly tuned ramp could have made pulling faster actively worse. It does
not. Speeding up is never punished; it just stops paying as well near the top.

Single-key mashing at the ceiling (`×0.35`) settles at a mean of **21.05** —
less than half what three-finger alternation earns at the same 10 Hz (43.97),
and *below* what alternation earns at a leisurely **3 Hz** (21.38). That is the
design pillar, stated as a number: *rolling three fingers at a comfortable
speed beats destroying one key as fast as you physically can.*

**The gameplay-speed assist scales `gain`, `λ_eff` and rope speed together.**
This approximately preserves settled strength while slowing travel. The
continuous approximation is invariant, but the discrete sawtooth shifts
slightly; the measured values are recorded in the implementation notes.
Scaling only gain would make the assist harder by increasing the pull rate
needed to sustain a given strength. `_pull_strength()` retains its existing
signature; the model applies the same factor to decay and rope speed.

### 3.7 Moving the rope

```
diff = strength[red] - strength[blue]
if abs(diff) < CREEP_DEADZONE:  velocity = 0
else: velocity = clamp(diff / REFERENCE_DIFF, -1, 1) · rope_speed
rope = clamp(rope + velocity · delta, -L, +L)
```

This states the instantaneous velocity law. The implementation integrates that
velocity over the exponential decay interval rather than sampling only its
end; otherwise frame partitioning would change travel and held-ground scores.

- `REFERENCE_DIFF = 40.0` — the strength lead that produces full rope speed.
- `CREEP_DEADZONE = 1.5`.
- `rope_speed = ROPE_SPEED_BASE · sqrt(L / DEFAULT_ROPE_LENGTH) · gameplay_speed`,
  with `ROPE_SPEED_BASE = 2.2` notches/second.

**Rope speed is coupled to rope length on purpose.** Uncoupled, the
rope-length option is secretly a match-length option: at `L = 6` a dominant
coop pins in 2.7 s and at `L = 18` it takes 8.2 s, a 3× swing the player never
asked for. The square-root coupling bounds full-dominance traverse time to
**3.5 s – 6.1 s** across the whole 6–18 range, so rope length does what its
description says — changes how many notches there are — without quietly
becoming a difficulty dial.

The deadzone exists because without it two near-matched coops produce a knot
that drifts imperceptibly for forty-five seconds and then declares a winner by
a margin nobody saw. With it, a genuine stalemate *looks* like a stalemate.

**Strength is not consumed by pulling.** The rope reads the *difference*
continuously, so strength is a position you hold rather than a resource you
spend. A coop that stops pulling keeps sliding for a moment as its strength
decays — which is the correct feel for a tug-of-war, and is bounded by the
deadzone.

### 3.8 Notches, scoring and the pin

The rope is divided into whole **notches**, visible in the world (§6.3), so the
model's units and the player's units are the same units.

**Score is ground held, integrated over time.** Every frame, the leading coop
earns

```
_scores[leader] += HOLD_RATE · abs(rope) · delta
```

`HOLD_RATE = 20` points per notch-second. Holding three notches for thirty
seconds is 1 800 points; a coop that never crosses the centre line scores
nothing.

**This is the fix for a contradiction worth recording.** An earlier draft
scored high-water notch captures but awarded the *win* on final rope position,
so a coop that led for forty seconds and lost the last exchange would see a
headline saying it lost above a scoreboard saying it won — and the results
panel, the stats panel, the share card and the progression payload all read
`_scores`, so the disagreement would propagate everywhere. Making score *be*
ground-held resolves it: `_describe_round_outcome()` is handed
`player_one_total` and `player_two_total` by the shell and simply reports whoever
has more. Headline, scoreboard and share card cannot disagree, because there is
only one number.

It is also the better judgement. "Who held the most ground over forty-five
seconds" is a truer answer to *who won the tug-of-war* than a snapshot at the
buzzer.

**Notch captures** remain, as a bonus and a stat: reaching a new deepest whole
notch awards `NOTCH_POINTS = 100` and increments `_streaks[i]`; losing that
ground back resets the streak. Because captures only ever add to the leader's
score, they cannot invert the ordering. Capture processing iterates *every*
integer boundary crossed in a frame, so a large `delta` cannot skip a notch.

**A pin** is `abs(rope) >= L`:

- **Timer mode.** `_scores[winner] = max(_scores[winner], _scores[loser]) + PIN_BONUS`
  with `PIN_BONUS = 2000`, then the round ends (§14.2 describes the safe path).
  The `max` is what *guarantees* the pinning coop also wins on score — a
  guarantee rather than a hope, since a pin could in principle arrive after the
  other coop banked a long lead.
- **Lives mode.** `_lose_life(pinned_coop)`, the rope re-centres, both strengths
  reset to zero and play resumes. The round ends when a coop is out of lives —
  which is the shell's own rule, via `_player_is_out()`.

Lives mode is therefore a **first-to-N-pins match with no clock**, which is
exactly the prototype's "first to 5" ladder, restored in the place the
framework already has for it. It is not a fallback and not a degenerate case;
it is the second way to play.

### 3.9 Why Lives mode has to be real

`default_lives_mode = false` on the manifest is only a *default*.
`Settings.round_mode()` returns the **saved global choice** in preference to it,
so a player who selected Lives while playing Dead Metal Jam carries it into
Chicken Pit. In Lives mode `GameShell` starts no countdown and waits for
gameplay to call `_lose_life()`.

A version of this game with no life-loss rule would therefore **hang forever**
in a legal, reachable configuration — no timer, no way to lose, no way out but
the pause menu. §3.8's pin rule is what closes that, and it costs one branch.

---

## 4. Modes and the CPU birds

### 4.1 Both modes are two-seat sessions

This needed correcting against the framework, and the correction changes the
manifest.

`GameSession.is_single_player()` means *there is no Player 2 at all*: the shell
hides the second score card, omits its stats and drops it from the share
payload. A CPU opponent is not a single-player concept in this framework — it
is `configure_multiplayer(controller, difficulty)` with `player_two_is_cpu()`
true.

So Chicken Pit has exactly two configurations, and both seat two coops:

- **Versus.** Two humans, one keyboard, `Q W E` against `I O P`.
- **Solo.** One human on red; a bird on blue, as a CPU Player 2 with its own
  score card and its own stats row.

There is no score-attack mode. **The pit always has two ends**, so the blue
coop is always driven: by a human when `GameSession.player_two_enabled()` is
true, and by a bird otherwise. `_prepare_session()` implements exactly that
rule and never asserts.

**It must not assert**, and an earlier draft that did was wrong. A player
never reaches solo through mode selection any more — §14.5 row 2 is
implemented, `game.gd` clears `supports_single_player`, and the screen skips
the player-count step entirely — but two entry points still hand this game a
one-seat session. On mobile it is not even a choice: `multiplayer_available()`
is `not OS.has_feature("mobile")`, so `player_two_enabled()` is permanently
false and `configure_multiplayer()` silently falls back to
`configure_single_player()` (`game_session.gd:112-114, 124-132`). And
`tests/game_shell_test.gd:26-28` drives **every catalogued game** through
`configure_single_player()` before instantiating its scene, so an assert there
fails a suite §14.8 requires to keep passing — while in a release build, where
asserts are stripped, it would instead ship a one-ended tug-of-war.

Degrading gracefully costs one line and covers both cases. The only residual
is cosmetic, and now confined to them: in a single-player session the shell
hides the second score card, so the bird pulls without a visible score.

**The scaffold manifest forbade the solo mode it advertised.** It set
both `supports_cpu_opponent = true` and
`control_style = CONTROL_STYLE_DIRECT_MOVEMENT`, and the mode-select screen
treats direct-movement games as *"two humans sharing one screen, so they have
no CPU rival to offer"*:

```gdscript
# scenes/menus/mode_select.gd
func _select_default_opponent() -> void:
    var cpu_default := not _uses_direct_movement()
    ...
func _cpu_selected() -> bool:
    return _cpu_option_button.button_pressed and not _uses_direct_movement()
```

`_update_confirmation()` also hides the opponent selector and the CPU
difficulty panel for these games. The old effect was that **the CPU opponent could
never be chosen**, the *CPU opponent* Settings row does nothing, and the
mode-select copy advertises a mouse and arrow keys this game does not use.

That was a genuine bug, not a preference. The implemented custom-key trait
fixes it while retaining the direct-movement behaviour for existing games.

The old `supports_cpu_opponent` flag was inert: its reader was not called by
mode selection. The new `_cpu_opponent_offered()` consults that capability
as well as the control style and platform. Custom-key opponents use
game-owned settings rather than the target game's generic difficulty picker.

### 4.2 The CPU presses buttons

The CPU **feeds the same `_register_pull()` path a human key press does.** It
gets no private force term, it does not bypass the rate ceiling or the
alternation and cadence gates, and it cannot exceed the strength cap.

This is the most important decision in this section: tuning the model tunes
both sides at once, and a bug in the pull model shows up symmetrically instead
of silently favouring one side.

Each bird is a **target-strength controller with hysteresis**, not a fixed
cadence. It holds a strength band by pulling when it is under and resting when
it is over, capped by its own maximum rate:

```
if strength[cpu] < target · (1 - HYSTERESIS):   pull as soon as the rate cap allows
elif strength[cpu] > target · (1 + HYSTERESIS): rest
else:                                            hold the current cadence
```

`HYSTERESIS = 0.08`. The targets are read straight off §3.6's equilibrium
table, so each bird's number is a strength a human hits at a known pull rate —
which is what makes the roster legible to design and tunable against playtests.

| Bird | Target mean strength | Human equivalent | Max rate | Behaviour |
| --- | --- | --- | --- | --- |
| **Chick** — *takes it easy* | 18 | ~2.4 Hz | 5 Hz | **Gives up when losing**: once more than 40% of `L` behind, target drops to 11. It should lose gracefully rather than limply — it keeps pulling, it just stops fighting. |
| **Hen** — *pulls its weight* | 26 | ~3.9 Hz | 8 Hz | **Rubber-bands**: target `+6` while behind, `−6` while comfortably ahead. **Takes a breather** — target 0 for 0.6 – 1.1 s every 4 – 7 s, the window a human learns to attack. The default, and the one that should feel like a person. |
| **Rooster** — *never lets go* | 38 | ~6.8 Hz | 10 Hz | **Reads the player.** When the player's strength falls below 15 it raises target to 46 for 1.5 s — it punishes you for resting. Within 2 notches of being pinned it holds 46 permanently. No breather. |

Targets are jittered ±4% per pull so no bird is a metronome a player can
phase-lock against.

**Every bird's primary target is reachable; only the Rooster's panic value is
not.** The mean ceiling for clean 10 Hz alternation is 43.97 (§3.6), so 18, 26
and 38 are all strengths a bird can actually hold, and each corresponds to a
human pull rate a designer can feel. The Rooster's 46 sits deliberately above
the ceiling: it is a sentinel meaning *pull flat out and never rest*. Writing
it as a strength rather than a special case keeps all three birds on one
controller with one parameter.

An earlier draft set these to 20/34/44 against a mis-tabulated ceiling of 46.3.
With the corrected ceiling of 43.97 the Rooster's *primary* target would have
been unreachable too, so it could never have entered its rest branch and the
44-versus-52 distinction would have collapsed into "always flat out".

An earlier draft specified fixed pull intervals and separate "ceilings"; those
were incoherent, because a fixed interval *determines* the settled strength via
§3.6 and cannot also be given an independent ceiling. Chick's stated 0.42 s
interval in particular settled near zero rather than its advertised 45.

**The Rooster is beatable, and this is checked rather than asserted.** Its
target of 38 sits a clear 6 points under the 43.97 a human reaches by
alternating cleanly at the 10 Hz ceiling, so a player who keeps a clean roll
going simply out-pulls it. Its edge is that it never rests: it wins the
exchanges where a human takes a breath, and it is beaten by a human who does
not. §14.8's matrix test asserts a scripted perfect human beats every bird at
default settings — and, just as importantly, that the Chick loses to a scripted
mediocre one.

**`GameSession` also carries its own CPU difficulty** from the mode-select
screen. Where the two disagree, **this game's option wins** and the bird is the
named bird, because the Settings row is the more specific statement of intent.
`_prepare_session()` resolves that, and it needs a comment in the code because
it looks like a bug otherwise.

---

## 5. Architecture — a 3D world inside a 2D shell

### 5.1 The problem

`GameShell` is a **2D** scene. `res://scenes/game/game_shell.tscn`:

```
GameShell            Node2D
├── BackgroundLayer  CanvasLayer   layer = -1
├── Playfield        Node2D        ← games mount content here
├── WorldFX          Node2D        z_index = 10
├── RoundTimer       Timer
└── HUD              CanvasLayer   layer = 1 (default)
```

`%Playfield` is a `Node2D`. Nothing in the shell hosts a `Camera3D`, and
`_playfield_bounds()` returns a `Rect2` in screen pixels. Dead Metal Jam hit
this same wall and chose **2.5D fake depth with no `Node3D` at all**, recording
the reason in its own pillars table: *"Keeps `gl_compatibility` and the
`%Playfield` contract intact."*

Chicken Pit deviates from that precedent deliberately, because "the rope you
are fighting over is a physical object in a real space" is the entire appeal of
the game, and faking it in 2D throws away the one thing the reference build
already got right.

### 5.2 The solution, and the precedent for it

**A `SubViewportContainer` hosting a `SubViewport` that contains a full
`Node3D` world, mounted under `%Playfield`.**

This is not novel in this project — `scenes/menus/main_menu.tscn` already does
exactly it for the spinning studio logo:

```
LogoShowcase   SubViewportContainer   stretch = true, mouse_filter = 2
└── LogoViewport   SubViewport        transparent_bg = true
                                      gui_disable_input = true
                                      render_target_update_mode = 4
    ├── Camera3D                      current = true
    ├── KeyLight   DirectionalLight3D shadow_enabled = true
    ├── OmniLight3D
    └── LogoRig    Node3D
```

Chicken Pit's scene:

```
ChickenPit                      GameShell (Node2D)   ← gameplay.tscn
├── BackgroundLayer             framework, untouched — themed gradient
├── Playfield                   framework mount point
│   └── PitView                 SubViewportContainer   stretch, mouse_filter = IGNORE
│       └── PitViewport         SubViewport            transparent_bg, own_world_3d
│           └── Pit             Node3D                 ← pit.tscn, the whole world
│               ├── WorldEnvironment
│               ├── SkyDome     MeshInstance3D         painted sunset
│               ├── Sun         DirectionalLight3D     shadows on
│               ├── Bounce      OmniLight3D            warm fill
│               ├── Lighting    Node                   match-clock sunset
│               ├── PitCamera   Camera3D               current = true
│               ├── Scenery     Node3D                 ground, barn, fence, stands
│               ├── Notches     MultiMeshInstance3D + Label3D
│               ├── RedCoop     ChickenRig ×6
│               ├── BlueCoop    ChickenRig ×6
│               ├── Rope        RopeView
│               └── Fx          GPUParticles3D pool
├── WorldFX                     framework, untouched — 2D confetti lands on top
└── HUD                         framework, untouched — timer, scores, captions
```

**Settings, and what each actually does:**

| Setting | Reason |
| --- | --- |
| `transparent_bg = true` | The shell's themed `Background` (layer −1) shows through wherever the 3D world does not draw. In practice the sky dome covers most of the frame, so this mostly matters at the container's edges and during fades — but it is also what keeps the pit *inside* the theme rather than punching an opaque hole in it. |
| `own_world_3d = true` | Gives the pit its own `World3D`, so its environment, lights and physics cannot leak into or be disturbed by any other 3D content the framework may add later (the main menu already has some). Default is `false`, which shares the parent world — not what is wanted here. |
| `gui_disable_input = true` | The `SubViewport` does not receive GUI input. **The parent viewport still dispatches `_unhandled_input()` to the shell as normal** — that dispatch was never the `SubViewport`'s to intercept. The setting is here so the 3D world cannot swallow or duplicate events, not because the shell's input path depends on it. |
| `mouse_filter = IGNORE` on the container | The render surface is non-interactive; the shell's `%PauseButton` sits above it on HUD layer 1 and must stay clickable. |
| `render_target_update_mode = ALWAYS` | The world animates continuously. |
| `stretch = true` | The container drives the viewport's size and scales the result to fit. See §13.3 — this is *why* render scale uses `scaling_3d_scale` rather than resizing the viewport. |
| `Camera3D.current = true` | Set explicitly. A lone camera is normally made current automatically, but the menu precedent sets it and relying on implicit behaviour in a scene that gets instantiated headless is not worth the ambiguity. |
| `audio_listener_enable_3d` | Only if `AudioStreamPlayer3D` is used. §11 uses non-positional players, so it stays off. |

**Render order falls out for free.** `BackgroundLayer` is `layer = -1`,
`%Playfield` is plain canvas layer 0, `WorldFX` is `z_index = 10` on the same
layer, and `HUD` is `layer = 1`. The pit draws above the themed background,
below the shell's confetti, and below every HUD element — no `z_index` fiddling.

### 5.3 Sizing

The container is set to `_playfield_bounds()` — the shell's own rectangle,
already inset by `SIDE_CLEARANCE = 38`, `TOP_CLEARANCE = 190` and
`BOTTOM_CLEARANCE = 105` — so the 3D world never renders under the score cards
or the caption strip. It is refreshed on `get_viewport().size_changed`, the
same signal `intro.gd` already uses.

With `stretch = true` the `SubViewport`'s own `size` follows the container and
is **not** set by hand. Render resolution is controlled by
`SubViewport.scaling_3d_scale` instead (§13.3).

### 5.4 Model / view split

```
        pit_state.gd            (RefCounted, no nodes, no autoloads)
          strength, rope, scoring, capture, pin and lives rules
                    │
                    │  read-only, once per frame
                    ▼
        pit_view.gd             (Node3D)
          camera, birds, rope sag, particles, crowd
```

`gameplay.gd` owns a `PitState`, drives it from `_update_round()`, and hands it
to the view to read. **The view never writes to the model.**

Three things this buys:

1. **Headless tests are trivial.** `pit_state.gd` can be `load()`ed and stepped
   in a `SceneTree` script with no rendering at all.
2. **`--headless` cannot crash the round.** `tests/game_shell_test.gd`
   instantiates *every* catalogued gameplay scene headless, so the 3D half must
   be inert-safe, not merely fast.
3. **The look can be rebuilt without touching the rules.**

`pit_state.gd` follows the same no-dependency rule `chicken_pit_options.gd`
already documents: **no `Settings`, no autoloads, no singletons**, because
headless `--script` runs compile `class_name` dependencies before autoloads
exist. Tunables are passed *in*, never read from inside. It also takes **no
`InputEvent`** — echo rejection (Gate 1) happens in `gameplay.gd`, and the model
receives only `(coop, action, clock)`.

---

## 6. Art direction

### 6.1 One fairground, a stop below the round

The standalone menus and the pit are now the same place at the same fair. The
menu theme in `game.gd` draws its whole palette out of the game itself — cream
`#fff8e7` and gold `#ffd45c` from `ui/tug_meter.gd`, barn red `#e8453c` from
`pit/scenery.gd`, and the original `#fff1d1` warm-key accent — and
`ui/menu_background.gdshader` builds the approach to the pit out of the same
motifs: the coop-coloured bunting, the mown stripes converging on a far fence,
the lamps, the drifting dust.

The menus are still darker than the round, but as an **exposure** difference
rather than a different world:

**The approach is the same fairground held one stop below the pit. Walking in
is the joke, and it lands because you can already see where you are going.**

This is not purely an aesthetic choice. The shared menu scenes bake fixed
light-on-dark colours into roughly eighty labels that a `GameTheme` cannot
reach, so the backdrop is bound by a hard legibility floor: measured against
the shipped baselines, the tagline holds 5.22:1 and the footer 5.17:1 over the
backdrop's median luminance, versus 5.9–6.6:1 and 4.9–5.2:1 for the other
games. A brighter noon backdrop would drop those labels below 4.5:1. Any change
to the shader must be re-measured on a rendered frame, not eyeballed.

The same ceiling applies to the plaque. `main_menu.tscn` lights it with a 1.5
key and a 4.0 omni fill, so `assets/ui/plaque.svg` is authored in the midtones
(0.16–0.55): a bright texture drives the red channel past 1.0 and the face
clips to a flat orange that no `plaque_color` can pull back.

### 6.2 Palette

The standalone menu's square cover (`assets/menu-cover.png`) is an offline
portrait of the same toy farm: enlarged rival birds and the rope in the
foreground, with the barn, crowd and bunting behind them. Cream-and-gold title
lettering and a fine gold frame tie it to the widgets. `tools/render_cover.gd`
stages the original models with fixed poses and a separate camera; none of its
posing or lighting changes affect gameplay. The full-colour image uses a white
logo tint, while the barn-board plaque remains its backing. Keep the supplied
silhouette and the instructional gameplay poster as separate assets.

| Element | Colour | Notes |
| --- | --- | --- |
| Sky (top) | `#667da6` to `#765b87` | Muted blue into mauve; warm, batched clouds. |
| Sky (horizon) | `#ffd29f` to `#ee9d83` | Apricot into salmon, with a broad painted sun glow. |
| Grass (light) | `#7cd44a` | |
| Grass (dark) | `#5cb238` | Two-tone mown stripes; doubles as a distance cue. |
| Pit dirt | `#e8b84b` | Warm yellow, not brown, so birds and rope both pop. |
| Barn | `#e8453c` | Fire-engine red, `#fff8e7` trim. |
| Rope | `#c98a3e` | Light enough to stay visible against the dirt. |
| **Red coop** | `#ff6b57` | `player_one_color`, already set in `gameplay.tscn`. |
| **Blue coop** | `#4da3ff` | `player_two_color`, already set in `gameplay.tscn`. |
| Goal line, red | `#ff6b57` at 70% | Painted stripe on the dirt. |
| Goal line, blue | `#4da3ff` at 70% | |
| Centre line | `#fff8e7` | |

The two coop colours are **read from the scene, not re-declared.**
`gameplay.tscn` already sets `player_one_color = Color(1, 0.419608, 0.341176)`
and `player_two_color = Color(0.301961, 0.639216, 1)` — exactly `#ff6b57` and
`#4da3ff`. The birds read them through `_player_color()`, so a bird and the
score card above it can never disagree.

### 6.3 The pit

A rectangular sandy arena in a green field surrounds a real central chicken
pit, viewed from a low three-quarter angle so the rope crosses the screen
roughly horizontally and both coops are visible at once. The octagonal opening
has a 2 m half-width and a straw-lined floor 1.35 m below the field. Every
terrain layer, including the wooden diorama base, is triangulated around the
opening; a dark decal over solid ground would hide the resident chickens.
The rim, sloped earth walls and floor remain in the single scenery surface.

- **Notch markers.** `L × 2` short white posts along the near edge, drawn with
  one `MultiMeshInstance3D`. Goal-line posts are taller, painted in the coop
  colours, and carry a `Label3D` reading `RED GOAL` / `BLUE GOAL`.
- **The centre line** is a painted stripe on either side of the opening; the
  knot carries a bright ribbon so its position against the markers is legible
  at a glance. There is no floating ground-marker disc over the hole.
- **The barn** sits behind the pit, angled, as the visual anchor. It is
  authored in `scenery.gd`: red walls, white cross-braced doors, a dark roof,
  a weathervane and the Cluck County sign.
- **Stands** on the far side hold spectator chickens (§9.4).
- **Fence, water trough, feed sacks, a tractor tyre** — static set dressing.

### 6.4 Working inside `gl_compatibility`

The project is `renderer/rendering_method="gl_compatibility"` on desktop *and*
mobile. Per the Godot 4.7 renderer comparison, Compatibility **does** support
more than is often assumed, and the design should spend what is actually there:

| Available in Compatibility | Not available |
| --- | --- |
| SSAO | SDFGI, VoxelGI, SSIL, SSR |
| Glow | Volumetric fog |
| ReflectionProbe (2 per mesh) | Decals |
| Depth and height fog | Particle trails, particle SDF collision |
| Tonemapping, Adjustments | Sub-surface scattering |
| **MSAA 3D** | **MSAA 2D**, TAA, FXAA, SMAA, FSR2 |
| SSAA | Debanding, depth-of-field blur |
| LightmapGI *rendering* (baking needs RenderingDevice) | PCSS shadows, light projectors |
| Screen texture, depth texture, fullscreen-quad post | Compute shaders, CompositorEffects |

An earlier draft of this section claimed SSAO, glow and reflection probes were
unavailable and designed elaborate workarounds for them. That was wrong for
4.7 and the workarounds are withdrawn.

**Even so, the art direction barely uses the recovered features, and that is
the point.** A flat, saturated, high-key toy world does not want heavy ambient
occlusion or bloom; it wants strong local colour, one clean shadow, and shapes
that read as silhouettes. The renderer and the look point the same way.

Concretely:

- **One `DirectionalLight3D`** with `shadow_enabled`, single split, plus the
  existing warm `OmniLight3D` over the sand. `pit_lighting.gd` eases the sun
  from 34 to 24 degrees above the horizon, golden into orange, and balances it
  with cool ambient fill. PCSS is unavailable, so shadows are hard-edged.
- **SSAO off.** Directional shadows provide contact without the extra pass.
- **Glow off.** Goal caps pulse through their batched instance colours, and
  the shell's accessibility-gated `_flash_screen()` provides the pin punch.
- **Depth fog**, matching the warm horizon and distant-only.
- **Sky** uses an opaque inward dome with `sunset_sky.gdshader`, an unshaded
  gradient and broad sun glow. The dome follows the camera so wide/portrait
  framing cannot leave it. A solid environment background avoids per-frame
  sky radiance/cubemap rebuilds. Clouds remain one batch of original ellipsoids.
- **No reflection probes.** Available, but nothing in a matte farm needs one.

The scene owns a slow 96-second sunset cycle, independent of exchange resets.
New matches reset it; Lives exchanges continue it; pause and results freeze
it. Reduced motion selects one fixed, readable sunset. The intense-effects setting adds
only a small, eased tension accent to the existing fill, never a flashing
light or additional shadow pass. Sky and environment resources are local to
each pit instance, and the shader receives explicit uniforms instead of
unpausable `TIME`.

**Materials** are `StandardMaterial3D`, with `shading_mode = UNSHADED` for
anything that must hold an exact colour — goal lines, the knot ribbon, notch
posts — and `PER_PIXEL` for birds, barn and ground so the sun still models
their form. Mixing the two deliberately is what gives the flat-but-lit look.

**MSAA 2× is set on the `SubViewport`.** Note that Compatibility supports MSAA
for 3D but **not** for 2D, so confining antialiasing to the 3D subviewport is
not merely an optimisation — it is the only place it can work at all.

---

## 7. Camera

A plain `Camera3D` driven automatically. No add-on, manual camera keys or
framework camera. Front-quarter rotations preserve red-left/blue-right
orientation, while perspective, pitch and zoom make the action less static.

| Behaviour | Rule |
| --- | --- |
| **Automatic shots** | Four smoothly blended front-quarter shots, eight seconds apart: yaw -24 to +27 degrees, elevation 30 to 39 degrees, FOV 46 to 53 degrees. Dolly distance varies with composition and framing. |
| **Losing-coop close-up** | Between 30% and 78% ground loss, blend from full-arena coverage into an action frame. Aim toward that coop's lead bird, lower toward a 22-degree elevation and narrow FOV by up to 17 degrees (30-degree minimum). Ease lens magnification and dolly separately. Positive rope focuses blue, negative rope red; this follows current ground, not banked Timer score. |
| **Safe framing** | Establishing shots fit all birds and goals. Close-ups may crop rear chickens and distant scenery, but protect both lead birds, grips, the visible knot, sagging rope spans and pit bounds. During a pin, include every falling bird. Lift the aim for HUD headroom rather than cancelling the zoom with an unnecessary pull-back. Any pose/resize that threatens essential action still forces immediate safe framing. |
| **Tension push-in** | After 0.8 seconds of near-equal pulling with total strength above 15, narrow FOV by another 2 degrees; ease out when the stalemate breaks. |
| **Pull kick** | Each accepted pull adds about 0.06 units of impulse toward that coop, capped at 0.12 and decaying over 0.15 seconds. Disabled with intense effects or reduced motion. |
| **Pin cam** | Arc from the current shot toward a 12-degree falling-side angle, 42-degree elevation and 28-degree FOV, facing into the hole. A more side-on angle made the far grip force a pull-back during the fall. Track the actual tumbling/landed flock and reeled-in knot during the existing 1.1-second pin hold, using the view's authoritative fall time. A duplicate pin or accessibility toggle cannot restart the move. |

Close-ups are automatic and intentionally allow peripheral cropping. Requiring
every rear chicken and goal to stay visible largely undid the lens zoom.
Ground recovery eases back into the complete arena instead of cutting to a
wide shot. The native-resolution tug meter still shows both teams and goals
throughout, independent of the camera.

**Under reduced motion**, follow lag, FOV changes, pull kick and pin swing are
all disabled; a fixed 54-degree shot uses a conservative whole-round envelope,
not changing bird poses, so pulls and falls cannot cause a dolly. The knot
still moves. The pin phase keeps identical timing and settles the fallen birds
immediately. Zero-time redraws do not advance the director, and pause/results
hold the last camera pose.

---

## 8. The rope

### 8.1 Two ropes, and only one of them is real

**The gameplay rope is the number `rope` in `PitState`.** That is the rope that
decides matches, and it is a float.

**The visual rope is a cosmetic Verlet chain** with 25 points, distance
constraints and gravity. Its main anchors are the two animated beak grips and
the ribbon; extra supports at the inner and outer pit rim keep a descending
span out of the earth. These guides follow the sagged curve while airborne,
then rest on the rim; slack can reach the lip before the beak drops below it.
The rope sags, ripples on an accepted pull and slackens into
the hole on a pin. **It has no effect on gameplay whatsoever.**

This split is a requirement, not laziness. Tests must be deterministic and
headless; a physics-driven rope is neither. `SoftBody3D` is rejected for the
same reason — not because Compatibility forbids it (it is a physics node, not a
rendering feature), but because it is non-deterministic and heavier than a
25-point chain.

Reduced motion draws straight spans between the grips, knot and necessary
rim supports, without a Verlet simulation. The rope still fits the landed
birds rather than cutting through solid ground. It is skipped entirely when
the view is headless.

### 8.2 Drawing it

An `ImmediateMesh` rebuilt each frame from the verlet points, extruded to a
camera-facing ribbon with a tiling rope texture. One mesh, one material.

Rejected alternatives: `CSGPolygon3D` on a `Path3D` re-tessellates constantly;
a chain of individual `MeshInstance3D` segments would add a node and draw call
for every segment.

The strip faces the current camera, including during the pin swing. Its yarn
tiles by actual arc length, and its width tapers with the falling bird's scale.
The rope endpoint includes the head rotation performed in `chicken.gdshader`;
after landing, it blends to the visible resident's beak rather than staying
attached to the hidden falling rig.

Before solving constraints, the existing curve is moved with its new anchor
guides. This refits the length as the coop approaches the hole instead of
leaving the old arena-wide chain trailing behind. Ground clearance follows
`Scenery.pit_surface_height()` through the rim, sloping walls and recessed
floor, not a constant above-ground Y limit. Zero elapsed time never integrates
residual velocity, so paused or settled rope does not creep between redraws.

**Tautness is driven by total strength, not by the difference:**

```
tension = clamp((strength[0] + strength[1]) / (2 · REFERENCE_DIFF), 0, 1)
sag     = MAX_SAG · (1 - tension)
whip    = lateral offset proportional to diff, applied to the mid-points
```

An earlier draft used `1 - abs(diff) / 100`, which is wrong: it gives maximum
sag both when nobody is pulling *and* when both coops are at full strength, so
the one state it most needed to distinguish — two exhausted birds versus a
straining deadlock — looked identical. Total strength sets how straight the
rope is; imbalance sets which way it whips.

### 8.3 World-space mapping

The one piece of geometry everything else depends on:

- `NOTCH_METRES = 0.55`. At `L = 10` each goal line is 5.5 m from centre.
- The **goal posts are fixed** at `±L · NOTCH_METRES`, and so are the coops'
  standing positions.
- The **knot** is the thing that travels: `knot.x = -rope · NOTCH_METRES`
  during the pull (negated because red, the positive direction in the model,
  stands on −X).
- **Birds shuffle**, they do not travel: each coop's root slides within
  `±1.2 m` of its post, mapped from `rope`, so a losing coop is visibly dragged
  toward the pit without ever leaving its own ground.
- **On a pin**, and only then, all six losing birds skid to the central lip,
  teeter, somersault around their body centres, and squash/bounce onto the
  bedding. Wings flap independently, feet kick and heads look down. Each
  0.84-second sequence is staggered by 0.045 s, so the last bird still settles
  before the existing 1.1-second `PIN_CAMERA_SECONDS` expires.
- **The pinned visual knot** reels toward the falling lead bird and drops
  into the hole as tension releases. The rope shrinks with the moving beaks
  and drapes over the rim. The model's knot and score remain frozen at the pin;
  no visual transform feeds back into gameplay.

At `L = 18` the pit is 19.8 m across, which is why the camera pulls back with
rope length (§7) rather than using one fixed framing.

---

## 9. The chickens

### 9.1 Rig — and the OBJ problem

The original chicken is authored in `chicken_rig.gd`, with separate rigid
body, head, wing, leg and headwear geometry. These are batched into one mesh
whose UV2 tags let `chicken.gdshader` rotate each part about its own hinge.
An imported replacement would need equivalent tags or an actual rig:
**an OBJ carries no bone weights**, so merely adding `Skeleton3D` is not skinning.

Two options, and the design takes the second:

1. Re-rig and weight-paint in Blender, export glTF. Correct, smooth, and needs
   a rigging pass nobody on this project has scheduled.
2. **Author rigid parts** — body, neck, head, two legs, two wings — and apply
   rigid hinge transforms. This implementation tags them in one mesh and
   transforms vertices in the shader, avoiding a draw call per part.

Option 2 suits a chunky toy look, survives the import pipeline unchanged, and
is how the crowd and rear birds work anyway. If a later art pass wants smooth
deformation, option 1 drops in behind the same `ChickenRig` interface.

**Animation is procedural, not authored clips.** There is no animator on this
project, and the poses are driven by continuous state — strain, cadence,
whether the coop is winning — which is exactly the case where blending
hand-made clips is more work and looks worse.

### 9.2 Poses

| State | Body | Wings | Head |
| --- | --- | --- | --- |
| **Idle** | Breathing bob, 0.8 Hz | Folded, occasional flap | Pecks at the sand |
| **Strain** | Leaned back by `strength[i] / MAX_STRENGTH`; heels dug in | Half-out for balance | Thrust forward, beak on the rope |
| **Pull** | Sharp lurch back over 0.12 s, then ease forward | Full flap | Snaps back with the body |
| **Losing ground** | Skidding: feet slide, body low, dust at the toes | Windmilling | Wide-eyed, down at the rope |
| **Pinned** | Skids, teeters, somersaults and bounces into the bedding | Asymmetric flapping | Looks down, then rights itself |
| **Won** | Jumping, flapping; one bird struts | Full spread | Up |

The **lurch is the key frame of the whole game.** It fires within one frame of
the key, and its magnitude scales with the `gain` that press actually earned —
so the alternation penalty is *visible*: mash one key and the birds barely
twitch. A press rejected by the rate ceiling produces no lurch at all, which is
the feedback that teaches Gate 2 without a tutorial.

### 9.3 Six birds per coop

A line of six staggered along the rope, each with its animation phase offset,
so a pull ripples down the line instead of six identical puppets snapping
together. Rear birds are smaller and simpler.

Six `MeshInstance3D` per coop with a shared mesh — or, if profiling demands it
(§13.2), the rear four collapse to a `MultiMeshInstance3D` with baked bob and
no rig at all. That fallback is designed in rather than discovered later.

### 9.4 Spectators

One `MultiMeshInstance3D` of ~40 simple chickens in the stands, bobbing on a
sine wave offset by instance index. On a notch capture, the instances on the
capturing side jump. One draw call, no rigs, no per-instance logic.

### 9.5 The remembered flock

A first-time player sees an empty hole. Each **completed match** contributes
six resident chickens, with an absolute **24-chicken cap**. Starts, abandoned
replays and exits during an unfinished pin do not count. Timer finishes,
including draws, CPU games and terminal Lives pins all use the same completion
hook, guarded by the shell's round ID against duplicate counting.

`pit/pit_history.gd` stores only the completed-match counter in
`user://chicken_pit_history.cfg`. The host has no numeric play history, so an
existing `pit_first_match` achievement supplies a one-match minimum for older
players. A fresh scene reloads the saved count; a replay uses the just-saved
count immediately. Failed reads disable writes rather than replacing unknown
history, and failed saves are reported without claiming a persistent increment.

Residents share the low-detail spectator mesh in a single 24-slot `MultiMesh`,
with fixed landing slots and no per-bird nodes or physics. One bounded loop
adds gentle bobbing and pecking while motion is enabled; it adds no draw calls.
A pin uses six landing slots for the current match, replacing the last six if the
pit is full. Repeated Lives exchanges reuse those same slots and leave landed
birds visible when the pulling coops reset; they never bank extra plays.
At an unpinned buzzer, the next six residents appear without delaying results.
The flock is purely decorative: no score, achievement or win rule depends on it.

Reduced motion shows the landed state immediately, retaining the normal
1.1-second pin hold. Re-enabling motion cannot rewind a completed fall. The
headless view keeps only counts and allocates no resident instances.

---

## 10. Effects and juice

Gated on `Settings.visual_effects_enabled()`; all motion additionally gated on
`Settings.reduced_motion_enabled()`.

| Event | Effect |
| --- | --- |
| **Accepted pull** | 3–6 feather particles from that coop (`GPUParticles3D`, one-shot from a pool), in the coop colour. Dust puff at the feet. |
| **Rejected pull** (rate ceiling) | A 2-pixel recoil on that coop's rope anchor and nothing else — no feather, no dust, no sound, no strength. Distinct from an accepted pull, so mashing above the cap reads as *capped* rather than as dropped input, without rewarding the overage. |
| **Single-key pull** | A weak twitch and no feathers, scaled by the 0.35 factor. |
| **Notch captured** | The notch post lights in the capturing colour and stays lit; spectators on that side jump; short cheer. |
| **Notch lost** | The post goes dark. |
| **Stalemate** | Rope hums and vibrates; dust drifts from both sets of feet. |
| **Near a goal line** | The threatened coop's goal posts pulse. The shell's `%DangerOverlay` is left to the framework's clock and not co-opted. |
| **Pin** | Camera swing (§7), skid dust followed by a pooled feather burst as the lead bird tips into the hole, staggered flapping tumbles and a slackening rope, `_flash_screen()` in the winner's colour, `_add_screen_shake()`, and the framework's confetti on `WorldFX`. |

Feathers come from **one pooled set of `GPUParticles3D` emitters** created at
build time and re-fired — never `new`ed per event. Particle *trails* and SDF
collision are unavailable in Compatibility; neither is used. The pool is not
created at all when the view is headless.

---

## 11. Audio

The framework's `AudioManager` is consumed as-is. **No new methods are added to
the autoload** — Dead Metal Jam's §9.5 records why adding game-specific
synthesis there was the wrong call, and that lesson is taken rather than
relearned.

`AudioManager` owns eight internal non-positional one-shot players. That pool is
reached through `AudioManager.play_sfx(stream, volume_db, pitch_scale)` and is
correct for **one-shots**. It is *not* a pool that game-owned nodes can join, so
the two **loops** — rope creak and crowd bed — are game-owned
`AudioStreamPlayer`s on the SFX bus, living in this game's own scene so they
die with it.

The adaptive score is likewise scene-owned, but on the **Music** bus:
`pit_music.gd` uses one `AudioStreamSynchronized` player for the original jig
and a matching-length, 110 BPM danger stem. Both clips start together; only
the second stem's gain changes, so extra stomps, bass, subdivisions and plucks
remain on the beat without pitching up or restarting the tune. Danger rises
symmetrically from 60% to 95% rope travel, with a 0.35-second attack and
1.25-second release. Their combined authored peaks retain mix headroom.

The inherited shell's persistent `music` slot stays empty. Activation starts
one owned playback, pause holds its playhead and envelope, replay resets it,
and nonterminal Lives pins only release intensity. Results and all exit paths
stop it. Startup, Router-fade, pin and buzzer races abandon the round without
recording a completed match; `_finish_round()` is cleanup, while only guarded
`_end_round()` authorizes history. Exit cleanup must not redraw an already
unmounted SubViewport. The host's existing `stop_music()` now cancels pending
crossfade swaps and stops both menu voices, including an incoming fade-in.
Old game teardown never stops music owned by an incoming scene.

| Sound | Route | Caption |
| --- | --- | --- |
| Music | Scene-owned synchronized base/danger stems, shared Music volume and mute | Near-pin caption below |
| Pull grunt | `play_sfx()`, pitch-scaled by `gain` | — (too frequent) |
| Rope creak | Game-owned loop, volume from total strength | `"rope creaking"` |
| Notch captured | `play_sfx()` | `"red coop gains ground"` / `"blue coop gains ground"` |
| Notch lost | `play_sfx()` | — |
| Near pin | Crowd and beat-locked danger stem swell | `"crowd roars, music intensifies - close to a pin"` |
| Pin | `play_sfx()` | `"RED COOP PINS BLUE"` etc. |
| Ambient | *Chicken picking grass* — nickcase, CC0, already credited. Sparse, stalemates only. | — |

Captions go through `AudioManager.request_caption()`, already a no-op unless
`Settings.audio_captions_enabled()`. The shell's `AudioCaption` widget already
has reserved space, so captions never push the playfield around.

**Pull grunts are throttled** to one per 0.08 s per coop. Two players at the
10 Hz ceiling generate 20 presses per second between them; un-throttled that is
not a farmyard, it is a buzzsaw.

---

## 12. HUD and readability

The shell provides the score cards, round timer, danger overlay, results panel
and share card. Chicken Pit adds **one** element, because the one thing the
shell cannot know is where the rope is.

**The tug meter**, a horizontal bar under the timer:

```
   RED  ████████████▏            │            ▕     BLUE
        ◄── 3 notches                            goal
```

- A centre tick, both goal lines, and a marker at the knot.
- Fill drawn from the centre toward the leading coop.
- **Numeric readout: `"RED +3"`.** Never colour alone — the coop is named in
  text, which is what makes the meter work for a colourblind player.
- Each coop's **strength** is a thin sub-bar under its own score card.

A 2D `Control` in the shell's HUD, not a world-space element, so it stays
legible at any render scale and does not move when the camera does. Under
reduced motion the marker moves without easing or trailing.

---

## 13. Performance

### 13.1 Budget

The base targets `gl_compatibility` specifically to reach low-end desktop,
mobile and web. A 3D game folder must not be the reason that stops being true.

Target: **60 fps at 1280×720 on integrated graphics.** Draw-call budget for the
pit: **under 60**.

Rough accounting: ground + pit + barn + fence + dressing ≈ 12; notch posts 1;
spectators 1; birds 12; rope 1; particles ≤ 6 active; sky 1; `Label3D`s ≈ 4.

**Platform scope is desktop.** The pull model is keyboard-only, gamepad support
is a stretch item (§16), and there is no touch input path — so while the
renderer would export to web and mobile unchanged, this game does not claim
those platforms. Saying so plainly is better than implying reach the input
design does not have.

### 13.2 Levers, in the order they get pulled

1. **SSAO off**, falling back to painted contact-shadow quads (§6.4).
2. **Rear birds → `MultiMeshInstance3D`** (§9.3).
3. **Shadow map to 1024**, directional only, single split.
4. **Spectators → flat billboard `MultiMesh`.**
5. **`scaling_3d_scale` to 0.75** (§13.3).
6. **Verlet rope → straight segment.** Already the reduced-motion path, so it
   is tested.

### 13.3 Render scale

Because the 3D world lives in a `SubViewport`, its 3D resolution is independent
of the window. With `stretch = true` the container owns `SubViewport.size` and
it must not be assigned by hand, so the lever is **`SubViewport.scaling_3d_scale`**
— default 1.0, dropping to 0.75 on low-end. That scales 3D rendering only.

This is a genuine advantage of the `SubViewport` approach over a hypothetical
3D shell, and worth stating plainly: **the HUD, the tug meter and every piece
of text stay crisp at native resolution when the graphics get cheaper.**

Whether this becomes a player-facing option is deferred (§16); it ships as an
internal constant.

---

## 14. Integration with the base project

### 14.1 File layout

```
games/chicken_pit/
├── DESIGN.md                    this document
├── README.md / AGENTS.md         running, provenance and maintenance guidance
├── game.gd                      manifest, custom-key trait, theme, credits, poster
├── chicken_pit_options.gd       constants-only tunables and actions
├── gameplay.gd / gameplay.tscn  inherited shell, model and viewport integration
├── intro.gd / intro.tscn        supplied narrated opening
├── pit/
│   ├── pit_state.gd             RefCounted model, no autoloads
│   ├── pit_history.gd           completed matches and capped flock persistence
│   ├── pit_view.gd / pit.tscn   isolated world, lights, crowd and pooled effects
│   ├── toy_mesh.gd / scenery.gd original vertex-painted model sources
│   ├── chicken_rig.gd          rigid-part chicken geometry
│   ├── chicken.gdshader        single-surface procedural rig animation
│   ├── rope_view.gd            cosmetic Verlet chain + ImmediateMesh
│   ├── pit_camera.gd           framing, tension and guarded pin camera
│   └── cpu_bird.gd             seeded target-strength controllers
├── ui/
│   └── tug_meter.gd            native-resolution HUD addition
├── assets/
│   ├── game-icon.svg            exists
│   ├── intro-narration.mp3      exists
│   ├── pit-poster.png           rendered README hero still
│   ├── textures/                original rope, feather and dust SVGs
│   └── audio/                   original jig, clucks, creak, crowd and cues
├── tools/render_audio.py        reproducible offline WAV authoring
└── tests/
    ├── chicken_pit_options_test.gd   options through to the actual model
    ├── chicken_pit_intro_test.gd     narration/cue regression
    ├── pit_state_test.gd        pure model tests
    ├── pit_matrix_test.gd       option-grid and CPU safety tests
    ├── pit_geometry_test.gd     original mesh batching and paint
    ├── pit_round_test.gd        input, lives, timer, accessibility and scores
    ├── pit_round_fixture.gd     persistence-free wrapper around the real game
    └── pit_view_test.gd         graphics, framing, draw budget and captures
```

### 14.2 `GameShell` hook map

| Hook | What Chicken Pit does |
| --- | --- |
| `game_id()` | Returns `"chicken_pit"`. **Already implemented.** |
| `_load_round_settings()` | `super()`, then read the five tunables into `_round_*`. **Already implemented**, and already tested for not restretching a running round. |
| `_prepare_session()` | `super()`, then seat the blue coop — human when `GameSession.player_two_enabled()`, a bird otherwise (§4.1) — and resolve which bird from this game's option in preference to `GameSession`'s. **Never asserts**: `tests/game_shell_test.gd:26-28` drives every catalogued game through `configure_single_player()`. |
| `_build_playfield()` | Instantiate `pit.tscn` under a `SubViewportContainer` added to `%Playfield`; create the particle pool; add the tug meter to the HUD. Called **once per scene instance**, not per round — confirmed at `game_shell.gd:162-187`. |
| `_reset_round_state()` | New `PitState` for this round's `L`, pull power and decay; re-centre the knot; relight notch posts; reset the camera. **Not scores, streaks or lives** — the shell resets `_scores`, `_streaks`, `_best_streaks`, `_round_elapsed` and the lives pool itself *before* calling this (`game_shell.gd:260-292`). |
| `_activate_round()` | `super()` (the "GO!" flash), then unlock input and start the crowd bed. |
| `_update_round(delta, time_left)` | Return immediately if `_pin_pending`. Otherwise: step the CPU bird, step `PitState`, push state to the view, update the tug meter, and call `_update_scores()` / `_update_streaks()` when either changed. On a pin, enter the pin phase below. |
| `_handle_gameplay_input(event)` | Reject echoes; match against `ChickenPitOptions.pull_actions(0)` and `(1)`; ignore everything while `_pin_pending`; call `PitState.register_pull(coop, action, clock)`. In solo, coop 1's actions are ignored — the bird owns that seat. |
| `_finish_round()` | Stop the crowd bed, settle the birds, freeze the model. Synchronous and short — the pin animation has already finished by the time this runs. |
| `_describe_round_outcome(p1, p2)` | Reports whoever has the higher total (§3.8). `"RED COOP PINS BLUE!"` when the round ended on a pin, `"RED COOP HOLDS THE PIT"` on a timeout, `"DEAD EVEN"` when the totals tie. |
| `_round_totals()` | `hits` = notches captured by both, `attempts` = total accepted pulls. |
| `_player_stats(i)` | `score`, `hits` = captures, `misses` = notches lost back, `accuracy` = capture ratio, `streak` = `_best_streaks[i]`. |
| `_round_highlight_summary()` | `"Pinned at 0:31 · 7 notches · best run ×4"`. |
| `_award_round_achievements(p1, p2)` | §14.7. |
| `_set_reduced_motion_enabled(value)` | `super()` **first**, then park the camera and straighten the rope. |
| `_set_intense_effects_enabled(value)` | `super()` first, then enable/disable the particle pool. |
| `_on_controls_changed()` | `super()`, then refresh the on-screen key hints. |
| `_on_player_labels_changed()` | `super()`, then refresh the tug meter's coop names. |
| `_on_game_setting_changed(key, _v)` | The five gameplay tunables are next-round settings and are deliberately ignored. |
| `_playfield_bounds()` | **Not overridden.** The shell's rect is exactly what the container wants (§5.3). |

**Two corrections against the framework are folded into that table.**

*First, live accessibility changes do not arrive via `_on_game_setting_changed()`.*
`_on_setting_changed()` intercepts and early-returns for visual effects,
reduced motion, player labels and `controls/` keys, dispatching each to its own
hook (`game_shell.gd:1136-1149`). A game that watched `_on_game_setting_changed`
for reduced motion would simply never react.

*Second, ending the round on a pin must not be synchronous.* `_process()` reads
`time_left` **before** calling `_update_round()` and then keeps using it
afterwards — writing `_time_progress.value` and calling `_update_urgency()` and
`_update_time()` with the stale value (`game_shell.gd:193-216`). Calling
`_end_round()` from inside `_update_round()` therefore lets the shell restore
timer and danger state it has just torn down. The pin path is guarded instead:

```gdscript
func _begin_pin(winner: int) -> void:
    if _pin_pending:
        return
    _pin_pending = true
    _pin_round_id = _round_id
    _last_pin_winner = winner
    # PitState has already awarded the pin exactly once.
    _round_timer.stop()
    _view.play_pin(winner)
    _pin_timer.start(PIN_CAMERA_SECONDS)

func _complete_pin() -> void:
    if not _round_active or not _pin_pending or _pin_round_id != _round_id:
        return
    _pin_pending = false
    if _lives_mode:
        _lose_life(1 - _last_pin_winner)
        if _round_active:
            _state.recentre()
            _cpu_bird.reset(_state.clock)
            _view.reset_round(_state, [player_one_color, player_two_color])
        return
    _end_round()
```

**The Lives branch is the whole point of §3.9.** Ending the round on the first
pin would reduce "first to N pins" to "first pin wins" and make the lives pool
decorative. `_lose_life()` calls `_end_round()` when its elimination predicate
becomes true. Chicken Pit overrides that predicate to **either** coop being
out; the shell's default is **all** players, which is unsuitable for a duel.
The pin timer pauses and frees with the scene. Replay stops it before resetting
the round, and the generation guard rejects stale completion.

The round is never ended inside the `_update_round()` call stack; the model is
frozen and input ignored for the whole hold; and the `_round_active` recheck
covers a pause or an exit landing during the animation.

### 14.3 Tunables

**No new tunables.** The five in `chicken_pit_options.gd` — round length, rope
length, pull power, strength decay, CPU opponent — were declared for this
design and cover it completely.

The constants in §3 (`BASE_PULL_GAIN`, `MIN_PULL_INTERVAL`, `DECAY_LAMBDA`,
`ROPE_SPEED_BASE`, `REFERENCE_DIFF`, `CREEP_DEADZONE`, the cadence bands,
`HOLD_RATE`, `NOTCH_POINTS`, `PIN_BONUS`) are **design constants, not
settings.** They live in `pit_state.gd` and are not exposed. A player who could
set `ROPE_SPEED_BASE` could trivially break the game, and every one of them is
reachable indirectly through the four sliders that exist.

**The option envelope is a tested safety property, not an assumption.** The
corners are extreme: *pull power 0.5 / decay 2.0* is the slowest legal match and
*2.0 / 0.5* the fastest. Because both coops share one global setting, an extreme
corner changes the *pace* of a match rather than its fairness — but it must
still produce a match. §14.8's matrix test asserts across the full grid that a
maximum-rate player can capture at least one notch inside the shortest round,
and that full-dominance pin time stays inside 3–40 s.

### 14.4 Manifest integration

The manifest keeps its original host contract. Its credits and poster now
describe the authored assets rather than the absent prototype downloads.
Keep these decisions intact:

- `default_lives_mode = false` — correct. Timer is the default shape; Lives is
  real and specified (§3.8).
- `instructions_player_one_controls` explains the action, not literal keys;
  the framework appends each enabled human coop's current bindings.
- The `CONTROL_BINDINGS` are marked `movement: true`, so
  `Settings.movement_summary_for_game()` describes a rebound coop in one line.

**`control_style` is now `CONTROL_STYLE_CUSTOM_KEYS`**, for the reasons in §4.1.
The shared settings screen also hides unrelated controller steering/target
rows for this style; it still generates the game's options and bindings.

### 14.5 Framework touchpoints — the honest list

| # | Touchpoint | Status |
| --- | --- | --- |
| 1 | `game_manifest.gd` + `mode_select.gd` + `instructions.gd` + controller-row gating in `settings_menu.gd` | **Implemented.** `CONTROL_STYLE_CUSTOM_KEYS` keeps a declared CPU opponent, presents live action bindings instead of mouse/target prompts, and hides unrelated controller rows. It remains a game-agnostic control category, with synthetic-manifest regression coverage. |
| 2 | `game_manifest.gd` + `game_session.gd` + `mode_select.gd` — a `supports_single_player` capability that drops the player-count step for games that are inherently two-seat | **Implemented.** Chicken Pit clears the flag, so mode selection opens on its confirmation step with the *Who plays as Player 2?* choice and no stepper or *Change Mode* button. The rule is game-agnostic: the step collapses whenever the player count has one answer, which also covers a mode-gated game with only Local Multiplayer unlocked. This cannot become a two-seat assertion: the shared shell regression drives every game single-player, and mobile forces it unconditionally, so `_prepare_session()` still seats a bird rather than asserting (§4.1). |
| 3 | `settings_menu.gd` — rows for this game's tunables | **Not required.** `_build_option_rows()` iterates `Settings.options_for_game(manifest.id)` and `control_bindings_for_game()` generically. Dead Metal Jam's §9.4 describes hand-authored rows; that is no longer true of the current code, and `chicken_pit_options_test.gd` already asserts a row per declared tunable. |
| 4 | `project.godot` — `share/stats_urls/chicken_pit` | **Done.** Present, and already asserted to fit a scannable QR code. |
| 5 | `project.godot` — `config/name.cp`, `custom_user_dir_name.cp`, `build/single_game_id.cp` | **Done.** The standalone `cp` build is already wired. |
| 6 | `project.godot` — renderer | **Untouched.** The design targets `gl_compatibility` as it stands (§6.4). Switching the shared project to Forward+ for one game would regress every other game and every low-end target, and is rejected. |
| 7 | `game_shell.gd` / `game_shell.tscn` | **Untouched.** The `SubViewport` approach exists precisely so the 2D shell does not have to learn about 3D (§5.2). |
| 8 | `audio_manager.gd` | **Untouched.** One-shots go through `play_sfx()`; the two loops are game-owned nodes on the SFX bus (§11). |
| 9 | `share_card.gd` / `share_art_scene_path` | **Implemented.** The game supplies its original cover portrait and opts into `GameTheme.style_share_card`. The shared card uses that manifest's branding even in collection builds, freezes a scene-local copy of the menu backdrop, and accepts game-native stat captions and rematch copy. Other games retain the default presentation unless they opt in. |
| 10 | Export presets | **Simplified.** The `games/chicken_pit/web/*` exclusion in both presets is removed along with the folder it filtered. |
| 11 | `game_manifest.gd` + a `Store` autoload + `scenes/menus/store.tscn` + a `_round_points_earned()` shell hook — a cosmetics shop | **Implemented, and game-agnostic.** Four manifest fields describe a shop; the framework renders and banks it. Chicken Pit declares seven hats, two coop slots and a Feather currency in `chicken_pit_options.gd`, plus `ui/hat_preview.tscn` for the card art. No shared file names this game, and a game declaring no `store_items` sees no Store button anywhere (§14.9). |
| 12 | `game_manifest.gd` + `scenes/menus/gallery.tscn` — a model gallery | **Implemented, and game-agnostic.** Two manifest fields describe a museum; the framework owns the room, the list, the orbit and the label, and **no autoload was added** because a gallery saves nothing. Chicken Pit declares nine exhibits in `chicken_pit_options.gd` and supplies `ui/gallery_stage.tscn`, which builds each one from the same `ChickenRig`/`Scenery` calls the match makes. `scenery.gd` gained four public mesh accessors to make that possible. A game declaring no `gallery_exhibits` sees no Gallery button anywhere (§14.10). |

**One required change, one optional polish, and eight rows that say "nothing to
do".** An earlier draft claimed zero required and was wrong; row 1 is the price
of the CPU opponent the manifest already advertises. That same draft also
proposed asserting the session is two-seat, which would have broken the
framework test suite — row 2 is what that assert should have been, demoted to
optional because §4.1 no longer needs it. Rows 11 and 12 were added later and
are a different kind of entry: not concessions for this game, but framework
capabilities this game happens to be the first to use (§14.9, §14.10).

### 14.6 Accessibility

| Feature | Implementation |
| --- | --- |
| **Rebindable pull keys** | Already shipped. Both coops, six keys, conflict-swapping inside the game, already tested. |
| **Reduced motion** | Camera holds still (§7); rope becomes a straight segment; no feathers, dust, shake or crowd jumping; the knot and tug meter still move, because those are gameplay. Applied live by overriding `_set_reduced_motion_enabled()`, **not** `_on_game_setting_changed()` (§14.2). |
| **Audio captions** | §11. Every sound-only event that carries information is captioned. |
| **Never colour alone** | The tug meter names the leading coop in text (§12). Red birds wear tall combs, blue birds wear bonnets, so the coops differ in silhouette. Goal lines carry `Label3D` text, not just paint. |
| **Visual effects off** | Particles and lighting flourishes suppressed via `_set_intense_effects_enabled()`; the game stays fully playable. |
| **Gameplay speed / extra time** | `_load_round_settings()` already adds `Settings.extra_round_time()`. Gameplay speed now scales gain, decay **and** rope speed together, so it slows the match without raising the motor demand (§3.6). This is a fix, not a restatement. |
| **Intro is never sound-only** | Already shipped — `intro.gd` puts the full transcript on screen. |

**One gap this design owns:** rapid alternating key presses are a motor-skill
demand, and no existing assist removes it. Gameplay speed now genuinely helps
(above), and *Strength decay* at 50% raises settled strength at every rate. A
true one-button mode is a stretch item (§16) rather than quietly skipped.

### 14.7 Achievements

The three in `game.gd` are already declared, registered and persisted. Unlock
via `_unlock_round_achievement(id)` inside `_award_round_achievements()`.

| ID | Title | Condition |
| --- | --- | --- |
| `pit_first_match` | Chicken Run | Finish any match. Unconditional. |
| `pit_clean_sweep` | Clean Coop | Win with the opponent's favourable `extreme` exactly zero, including fractional notches. |
| `pit_comeback` | Fowl Play | Win after the opponent's favourable extreme reached at least `L - 1` notches. |

Both conditions read `extreme[]`, tracked as each coop's **nonnegative
favourable magnitude**, including fractional notches. An earlier draft tested
`deepest[opponent] == 0`, which a lead of 0.99 notches would satisfy despite
the opponent having held ground beyond the centre line.

### 14.8 Testing

Headless `SceneTree` scripts that exit 0, matching the existing files.

**`pit_state_test.gd`** — pure model, no scene, no autoloads:

- Presses inside `MIN_PULL_INTERVAL` are **rejected**, not scaled.
- Three actions submitted at the same `clock` yield exactly **one** pull. *The
  chord exploit, as a regression test.*
- Same key twice yields 35% of alternating.
- Cadence boundaries at exactly `0.10`, `0.12` and `0.45` land in the intended
  band (half-open intervals).
- The first pull of a round is treated as in-groove.
- Strength never exceeds `MAX_STRENGTH` nor falls below 0 — including a single
  1-second `delta` at `decay = 2.0`, the frame hitch that made the earlier
  subtractive decay go negative (§3.5).
- Settled **mean** strength matches §3.6's table at 2, 3, 4, 6, 8 and 10 Hz,
  simulated at a real 60 Hz frame cadence rather than an idealised `dt`.
  Peak and trough are asserted too — the sawtooth is the model, not noise.
- Mean strength is monotonically non-decreasing in pull rate across 2…10 Hz,
  so accelerating past the 8.33 Hz cadence-band edge is never a downgrade.
- Single-key mashing at 10 Hz settles **below** three-finger alternation at 3 Hz.
- Equal strength does not move the rope; the deadzone holds a near-tie.
- The rope clamps at `±L` for every `L` in 6…18.
- Capture awards `NOTCH_POINTS` once, never twice, and a single large `delta`
  spanning three notches awards all three.
- Ground lost breaks the streak but never removes banked score.
- The pin winner's total always exceeds the loser's.
- A pin reports once and is idempotent if stepped again.
- Stepping with `delta = 0` changes nothing.
- Stepping the same elapsed time as 1×`0.1` or 6×`(0.1 / 6)` gives equal rope
  position within floating precision. Include 30/60/144 Hz partitions,
  saturation, deadzone crossings and held-ground totals.

**`pit_matrix_test.gd`** — the option envelope as a safety property:

- Across the full grid of pull power × decay × rope length × gameplay speed:
  a maximum-rate player captures ≥ 1 notch inside the shortest round, and
  full-dominance pin time is within 3–40 s.
- No configuration leaves strength permanently at 0 (the inert corner §3.5
  exists to prevent).
- A scripted perfect human beats Chick, Hen and Rooster at default settings.

**`pit_camera_test.gd`** — deterministic projection and camera behavior:

- Distinct yaw, elevation, lens and dolly states, with continuous cycle wraps.
- Safe framing across short/default/long ropes and landscape/portrait aspects.
- Measured on-screen enlargement of either losing lead bird by at least 50%,
  not FOV alone, with smooth entry and recovery from action framing.
- Zero-time redraws, immediate resize, fixed reduced motion, gated pull shake,
  caller-owned subject arrays and idempotent, synchronized pin coverage.

**`pit_view_test.gd`** — graphics-only coverage of the actual animated world:
the same framing/zoom promises with real bird poses, every fall phase, shared
window resizing, changing sunset uniforms/lights, scene-local resources and
pause/results/accessibility. Remembered-flock visibility compares rendered
frames with and without the flock at an identical pose, rather than relying on
noon-specific RGB thresholds. Every store hat is rendered on both pulling coops
and in its actual store portrait; the entire hat must fit the card. All measured
pit draws, including shadows, must remain below 60.

**`pit_audio_test.gd`** — actual mixed PCM capture plus the real shell/Router:
live danger-stem gain for either coop, Music volume/mute, pause/resume, release,
silence on results, one-player replay, nonterminal/terminal Lives and initial
crossfade cancellation. Real menu/startup/pin/buzzer exits must stop playback
without recording abandoned matches or stopping an incoming scene's music.
Run with an isolated profile; the Dummy driver still mixes capturable audio.

**`pit_round_test.gd`** — scene level, instantiating `gameplay.tscn`:

- The scene builds and frees cleanly **headless** — the specific regression the
  3D subtree could introduce.
- `PitView` reports itself inert headless: no particle pool, no verlet rope.
- **A synthesised pull action dispatched through the parent viewport reaches
  `_handle_gameplay_input()` and moves the model.** The end-to-end routing
  assertion — asserting `gui_disable_input == true` alone proves nothing, since
  that flag is not what makes the shell's dispatch work (§5.2).
- The container tracks `_playfield_bounds()` after a viewport resize.
- Reduced motion parks the camera and straightens the rope, applied **live**
  through `_set_reduced_motion_enabled()`.
- A pin ends the round after `PIN_CAMERA_SECONDS`, not synchronously, and the
  timer/urgency HUD is not left in a stale state.
- **In Lives mode the first pin does *not* end the round** — it costs one life,
  re-centres the knot and resumes. Only the pin that empties a coop's pool ends
  it. This is the §14.2 branch, and without it "first to N pins" silently
  becomes "first pin wins".
- **A single-player session still has two ends.** With
  `configure_single_player()`, the blue coop is seated by a bird and the rope
  still moves both ways — the §4.1 degradation, asserted rather than assumed,
  because this is the configuration `game_shell_test.gd` and every mobile build
  actually run.
- A timeout awards the round to the coop with the higher score, and the results
  headline agrees with the scoreboard.

**`chicken_pit_options_test.gd`** — existing, extended. Its header already says
*"Once the rope and the coops exist, their assertions go here too."* Add that
`_round_rope_length` reaches `PitState.L`, and that pull power and decay reach
the model rather than merely being stored.

**Framework-wide tests** cover this game automatically and must keep passing —
`game_shell_test.gd`, `game_options_test.gd`, `game_select_test.gd`,
`store_test.gd`, `gallery_test.gd`, `single_game_test.gd`, `lives_mode_test.gd`
and `accessibility_test.gd` all iterate the catalog. `game_shell_test.gd`
instantiating every gameplay scene headless is why §5.4 is a hard requirement
rather than a preference.

```bash
godot --headless --path . --script res://games/chicken_pit/tests/pit_state_test.gd -- --game=all
godot --headless --path . --script res://games/chicken_pit/tests/pit_matrix_test.gd -- --game=all
godot --headless --path . --script res://games/chicken_pit/tests/pit_camera_test.gd -- --game=all
godot --headless --audio-driver Dummy --path . --script res://games/chicken_pit/tests/pit_audio_test.gd -- --game=all
godot --headless --path . --script res://games/chicken_pit/tests/pit_round_test.gd -- --game=all
```

---

### 14.9 The hat store

A tug-of-war is a spectacle, and a spectacle wants a costume. The store is the
first place this game spends the score on something other than a leaderboard.

**It is framework data, not a Chicken Pit screen.** `GameManifest` grew
`store_items`, `store_slots`, `store_currency` and `store_preview_scene_path`;
the `Store` autoload owns wallets, ownership and equipped slots; and
`scenes/menus/store.tscn` renders whatever a manifest declares. Chicken Pit
contributes three constants in `chicken_pit_options.gd` and one preview scene.
Nothing under `autoload/`, `scenes/` or `ui/` names this game — the same rule
§14.5 applies to everything else.

**Wallets are per game.** Chicken Pit banks in the thousands (100 a notch, 20 a
unit-second of ground held, 2000 a pin) while a target game counts hits. A
shared purse would let this game buy out every other shop by simply being
loud, so each game converts its own round with its own rule:
`round(best × 0.02) + 5`, `+10` for beating the CPU, capped at 150. The cap is
what stops the §14.3 option envelope from becoming an exploit: an 18-notch rope
on `decay = 0.5` is a legitimately long match, not a licence to clear the shelf
in one sitting.

**Two slots, one shelf.** A hat is bought once and can be worn on either end of
the rope, because a tug-of-war has two coops and both of them are somebody's
birds. That falls out of the generic `kind`/slot match — an item declaring
`"kind": "hat"` fits any slot accepting hats — so the framework never learns
that there are exactly two.

**A hat-ready model prevents comb clipping.** The original Comb & Bonnet look
is unchanged. Only a recognized, non-default store hat selects a comb-free red
head; empty, unknown and bare item ids retain the natural comb. The comb is
omitted from that variant's mesh, not hidden by a shader or left intersecting
the hat. `ChickenRig.hat_ready_mesh()` exposes the same shared body builder
used by equipped hats, with the body, face and rigid-part tags unchanged.
Blue retains its complete bonnet, whose brim and ties remain a non-colour
distinction alongside §14.6's player labels, goals and meter.

Both coops' hats are now centred at `HAT_CENTRE_X = 0.35` with their bases
against the cream head at `HAT_BASE = 1.58`. There is no rearward offset to
expose a comb, and no tall crest acting as a spacer. Every hat keeps its
wearer's team colour in a band, edging or jewels.

The shelf has sixteen paid styles plus the free Comb & Bonnet. The beret,
propeller cap, explorer helmet, pirate tricorn, toadstool cap and sprout pot
join the existing styles without changing their ids, prices or the crown's
Clean Sweep requirement. The propeller is fixed decorative geometry, not an
extra animation that would need a reduced-motion exception.

`pit_geometry_test.gd` checks the variants separately: only the red comb may
differ from the natural bird, blue's bonnet stays intact, every item uses the
proper body, and bare/unknown ids restore the full original model. It requires
0.005–0.10 units of overlap between each hat's underside and the cream head at
three contact points, excluding the bonnet from that contact surface. It also
checks exposed eyes and bonnet trim, each hat's own team colour and head tags
on every added vertex, including the tricorn's authored triangles.

**It costs nothing to render.** Hats are emitted into the bird's existing
single surface with head part id `3.0`, so they inherit the head-dip vertex
animation from `chicken.gdshader` for free and add **zero** draw calls against
the §13.1 budget of 60.

**It applies at the countdown, not mid-pull.** `gameplay.gd` reads the equipped
hats in `_load_round_settings()`, which the shell calls before
`_reset_round_state()`. A hat changed from the pause menu therefore lands on
the next round, the same way §14.2's live settings do. `pit_view.gd` receives
them as an argument to `reset_round()` and never touches the `Store` autoload —
it is loaded directly by `pit_view_test.gd`, which runs before autoloads exist.

### 14.10 The gallery

The farm is modelled to a standard a match never shows. The barn stands behind
the north fence and the camera never approaches it; the pit's sloped walls are
seen from forty feet up with two coops of birds on top of them; the bunting is
a strip of colour at the edge of frame. The gallery is where all of it stands
still and the player can walk round it.

**It is framework data too.** `GameManifest` grew `gallery_exhibits` and
`gallery_stage_scene_path`; `scenes/menus/gallery.tscn` owns the room, the list,
the orbit and the label. Chicken Pit contributes one constant in
`chicken_pit_options.gd` and one stage scene. There is deliberately **no Gallery
autoload** — a store has a wallet to protect, a museum has an opening time and a
door, so the manifest is the whole state and nothing is written to `user://`.

**The exhibits are the game, not a render of it.** Every plinth calls the same
`ChickenRig.build_mesh` / `Scenery.*` builder the match calls, and the two coop
birds come out wearing whatever hats §14.9's store has equipped. A gallery
showing a nicer version of the game would be an advert; this one cannot drift
from what is actually played, because there is only one copy of the geometry.
Making that possible is why `scenery.gd` gained public `pit_mesh()`,
`stand_mesh()`, `tree_mesh()` and `bunting_mesh()` beside the existing
`barn_mesh()` — accessors onto the private builders, not copies of them.

**Framing is derived, not authored.** Each exhibit is treated as the cylinder it
sweeps out as it turns, and the camera is placed where that cylinder is tangent
to the narrower of the two field-of-view angles. A 1.9-unit bird and a 23-unit
showground therefore both fit, on a phone held upright and on an ultrawide,
without a single hand-measured distance. A new exhibit needs a `FRAMING` entry
only to say which side is worth opening on.

**Rendering is request-driven.** The `SubViewport` draws one frame whenever the
view actually changes, so a gallery left open on a still model costs nothing.
That matters because this screen can be opened from the pause overlay with a
whole 3D match still resident behind it — see §13.1.

**The label is not decoration.** Every exhibit carries a description and two or
three specification lines, because §6.2's rule that meaning never rests on one
channel applies to a screen whose subject *is* a picture. Reduced motion parks
the turntable and disables the auto-spin toggle with a tooltip saying why,
rather than leaving a switch that silently does nothing, and the player can
still turn the model by hand. Every orbit action has an on-screen button as well
as a drag and a wheel notch; the arrow keys are deliberately left to menu focus,
because a focusable viewer that swallowed `ui_left`/`ui_right` would trap a
keyboard or d-pad player inside the picture with no way out.

**One exhibit is earned.** *Cluck County Showground* — the whole fairground in
one mesh — sits behind `pit_first_match`. It is listed, named and explained from
the first visit, and disabled with the reason why, so the collection reads as
something to finish rather than something the game is hiding. Earning it while
the screen is open rebuilds the list immediately, because the pause overlay sits
on a round that is still scoring.

---

## 15. Build order

| # | Step | Done when |
| --- | --- | --- |
| 0 | `CONTROL_STYLE_CUSTOM_KEYS` in the framework (§14.5 row 1) | Mode select offers the CPU opponent and stops advertising a mouse. Blocks the solo mode, so it goes first. |
| 1 | `pit_state.gd` + `pit_state_test.gd` + `pit_matrix_test.gd` | The model is correct with no renderer at all. Tests green. |
| 2 | Wire the model into the hooks; tug meter only, no 3D | The game is **fully playable** as a bar on a themed background. Two people can have a real match. **The checkpoint that proves the design.** |
| 3 | `SubViewportContainer` + a grey-box world: ground, two cubes, a line | Proves §5.2 end to end — input still reaches the game, render order is right, headless still passes. Ship `pit_round_test.gd` here, not later. |
| 4 | Camera (§7) and the guarded pin phase (§14.2) | Grey boxes already feel like a fight; pins end cleanly. |
| 5 | Rope: verlet chain + `ImmediateMesh` (§8) | Sag and tautness read correctly. |
| 6 | Chickens: rigid-part rig, procedural poses, six per coop (§9) | The lurch lands within a frame of the key. |
| 7 | Scenery, palette, lighting (§6) | The bright farm exists. |
| 8 | CPU birds (§4.2) | Solo is a real game against three distinct opponents. |
| 9 | Particles, crowd, audio, captions (§10, §11) | Juice. |
| 10 | Accessibility pass (§14.6), performance pass (§13) | All framework tests green; 60 fps at 720p on integrated graphics. |
| 11 | Update `README.md`, asset provenance and agent guidance | Completed alongside the implementation and rendered poster. |

**Step 2 is the gate.** If the game is not fun as a bar on a background, no
amount of 3D in steps 3–9 will save it, and the cost of finding that out is two
files instead of twenty.

---

## 16. Cut, simplified and stretch

### Cut

- **A game-owned best-of-five ladder.** Superseded: Lives mode *is* the
  first-to-N-pins match, and it is the framework's own round mode rather than a
  second scoreboard competing with the shell's (§3.8).
- **Camera orbit on the arrow keys.** A third player nobody agreed to (§7).
- **Physics-driven gameplay rope.** Non-deterministic, untestable headless
  (§8.1).
- **Procedural Web-Audio-style synthesis.** A browser workaround; this project
  ships audio files and has an `AudioManager`.
- **Team selection.** Solo is always the red coop, the bird always blue. One
  less screen, and the HUD cards, goal-line colours and results copy stop
  needing to be conditional.
- **A true single-player score attack.** Not a mode this framework has a shape
  for, and not one this game wants (§4.1).

### Simplified

- Rigid-part chicken rig instead of weight-painted skinning (§9.1).
- Six birds per coop, rear four collapsible to a `MultiMesh` (§9.3).
- Spectators are one `MultiMesh` with no individual logic (§9.4).
- Render scale ships as an internal constant (§13.3).
- Desktop only; no touch path (§13.1).

### Stretch, in priority order

1. **One-button accessibility mode** — a single key with the alternation gate
   disabled and gain rebalanced. Precedent exists:
   `Settings.one_button_triangle_rush_enabled()` establishes the shape of a
   per-game one-button toggle.
2. **Completed: a pit-themed share card** via `share_art_scene_path` (§14.5 row 9).
3. **Render scale as a player option**, if the performance pass finds real
   variance across machines.
4. **Gamepad support.** Two pads, three face buttons each. The bindings system
   already models controller buttons; the pull model needs no changes, and it
   is the prerequisite for any console or handheld target.
5. **Weather** — a rain match where the sand turns to mud and decay doubles.

---

## 17. Open risks

| # | Risk | Mitigation |
| --- | --- | --- |
| 1 | **Input never reaches the game**, silently. The 3D subtree makes this a real possibility and it fails *quietly* — the game looks perfect and does nothing. | §14.8's end-to-end routing test dispatches a real action through the parent viewport and asserts the model moved. Landing it at build step 3 is deliberate. |
| 2 | **Headless instantiation of the 3D subtree breaks the framework-wide tests**, blocking every other game's CI, not just this one. | §5.4's model/view split; the view is inert headless; `pit_round_test.gd` lands before there is much 3D to go wrong. |
| 3 | **The cadence and equilibrium numbers are wrong for real hands.** They are reasoned, not measured. | Step 2 makes the model playable before any art exists — the cheapest possible place to retune. All numbers are constants in one file, and §3.6's table is the thing to re-measure against. |
| 4 | **`CONTROL_STYLE_CUSTOM_KEYS` grows.** A framework change made for one game tends to acquire that game's special cases. | It is specified as a *category* — "controls are the manifest's own action keys" — and reviewed against that. If it cannot be written without naming Chicken Pit, it is wrong. |
| 5 | **Performance on integrated graphics**, with a shadow-casting light, SSAO and 12 rigged birds. | §13.2's six levers, in order, all designed in rather than retrofitted. SSAO is lever one precisely because it is the newest and least essential. |
| 6 | **Resolved: the dusk menu / noon pit split read as a bug** rather than a joke. | The menus now draw their whole palette from the game and reprise its bunting, stripes and lamps, so the approach and the pit are one place at two exposures (§6.1). `transparent_bg` still keeps the theme framing the pit. |
| 7 | **Two players on one keyboard hit USB rollover limits.** | The clusters are already spread (`Q W E` / `I O P`). Because presses are discrete and echoes discarded, the game never needs two keys held at once — which is the case rollover actually breaks. |
| 8 | **Lives mode is under-playtested** relative to Timer, because it is reachable only through a shared global setting most players never touch. | `lives_mode_test.gd` already iterates the catalog, and §14.8 adds an explicit termination test. Playtest it deliberately rather than waiting to encounter it. |
| 9 | **Resolved: model provenance and availability.** The removed prototype meshes were not reused. | Original geometry is authored in `pit/`, with reproducible source and accurate credits. `pit_geometry_test.gd` guards batching, paint and rigid-part tags. |

---

## 18. Document revisions

| # | Change |
| --- | --- |
| 1 | Initial design. Strength/decay/alternation pull model replacing the prototype's direct rope movement; `SubViewport` 3D architecture deviating from Dead Metal Jam's 2.5D precedent; bright noon palette against the dusk menu theme. Claimed zero framework edits. |
| 2 | **Correctness pass against the framework and the engine.** Closed the same-frame chord exploit with a hard rate ceiling (§3.3) and replaced the flailing multiplier. Switched to proportional decay plus diminishing returns to remove the inert option corner and give an attracting equilibrium (§3.4–3.6). Coupled rope speed to rope length (§3.7). Replaced high-water-mark scoring with time-integrated ground held so the headline, scoreboard and share card cannot disagree (§3.8). Specified Lives mode as first-to-N-pins, closing a non-terminating round reachable from a saved global setting (§3.9). Corrected solo mode to a two-seat CPU session and recorded that `CONTROL_STYLE_DIRECT_MOVEMENT` suppresses the CPU opponent the manifest advertises — the one required framework change (§4.1, §14.4, §14.5). Rebuilt the CPU roster as target-strength controllers (§4.2). Corrected the `gl_compatibility` feature list against the 4.7 renderer table: SSAO, glow and reflection probes *are* supported (§6.4). Fixed the rope tautness formula (§8.2) and added world-space mapping (§8.3). Noted that an OBJ carries no bone weights (§9.1). Corrected the live-settings hooks, the `_end_round()` timing hazard and the `stretch`/`scaling_3d_scale` conflict (§13.3, §14.2). Added the option-matrix test (§14.8). |
| 3 | **Second correctness pass; the pull maths re-derived and the session model corrected.** Revision 2's equilibrium table was wrong at both endpoints: it baked the 1.15 cadence bonus into every row, but §3.3's own bands give **1.00** at 2 Hz (`dt = 0.50 ≥ 0.45`) and at 10 Hz (`dt = 0.10`, the foot of the ramp). It also quoted a single settled value when strength is really a **sawtooth**; §3.6 now gives peak, mean and trough from a closed form, tabulates the mean — the quantity that actually moves the rope — and asserts monotonicity across the band edge. The true ceiling is 43.97, not 46.3. That invalidated the CPU roster, whose 44 target was unreachable, so the birds were retuned to 18 / 26 / 38 with a 46 flat-out sentinel (§4.2). Decay became exponential rather than a forward-Euler subtraction, which cannot go negative on a frame hitch at `decay = 2.0` and makes frame-rate equivalence exact instead of approximate (§3.5, §14.8). Removed the two-seat assertion: single player is not suppressible (`mode_select.gd:415`), is the *default* selection (`:457-459`), is unconditional on mobile (`game_session.gd:124-132`), and is what `game_shell_test.gd:26-28` drives every game through — so `_prepare_session()` now seats a bird instead of asserting, and the card suppression is demoted to optional framework row 2 (§4.1, §14.5). Fixed the pin path to decrement a life and resume in Lives mode instead of ending the round on the first pin (§14.2). Documented that the 10 Hz ceiling is frame-quantised and therefore ~7.5 Hz at 30 Hz, symmetric for both coops (§3.3). Noted that `supports_cpu_opponent` is inert — its only reader is dead code (§4.1). Gave the rejected pull a distinct tell so the cap does not read as dropped input (§10). |
| 4 | **Reference build removed.** The React/Three.js prototype under `web/` was deleted from the repository along with its assets, including the chicken and barn `.obj` models. §3.1 keeps the analysis of its pulling model — that reasoning is why §3 exists — but now describes it in the past tense instead of citing files. §6.3 and §9.1 no longer name a source mesh; both models must be sourced before §15 step 4, recorded as risk 9. Removed the intro test's transcript-versus-source check and its `_words_of()` helper, which could only ever skip once the sources were gone, plus the Vite entries in `.gitignore` and the `games/chicken_pit/web/*` exclusions in both export presets. |
| 5 | **The standalone menus restyled to the game's own look, retiring the dusk/noon split** (§1, §6.1, risk 6). The straw-and-dirt theme shared nothing with the pit but a hinge colour; the menus now take cream `#fff8e7` and gold `#ffd45c` from `ui/tug_meter.gd`, barn red `#e8453c` from `pit/scenery.gd` and the `#fff1d1` key light from the pit's `Sun`, over a turf-shadow backdrop. Added four sibling-standard resources the game had been missing — `ui/menu_background.gdshader` and `.tres` (an original approach-to-the-fairground backdrop: coop-coloured bunting, mown stripes converging on a far fence, lamp glows, drifting dust), `ui/menu_plaque.tres` over a new `assets/ui/plaque.svg` barn-board texture, `ui/menu_skin.tres` in the tug meter's widget language, and `ui/menu_sounds.tres` over a new `latch` cue rendered by `tools/render_audio.py`, which now writes seven WAVs. Two constraints were measured rather than assumed and are recorded in §6.1: the shared menus bake ~80 fixed label colours a theme cannot reach, which fixes a legibility floor on backdrop brightness (tagline 5.22:1, footer 5.17:1, both in line with the shipped baselines); and the plaque's 1.5 key plus 4.0 omni fill clip a bright albedo texture's red channel to flat orange, so `plaque.svg` is authored in the midtones. Note that Godot's shading language predefines `PI` — redeclaring it fails compilation, and `single_game_test.gd` still reports a pass when it does. |
| 6 | **The player-count step retired and a walkthrough clip recorded.** §14.5 row 2 is implemented as a game-agnostic `supports_single_player` manifest capability rather than a Chicken Pit branch: `GameSession.single_player_offered()` reads it, and `mode_select.gd` collapses to its confirmation step whenever the player count has exactly one answer, hiding the stepper and *Change Mode* while keeping the *Who plays as Player 2?* selector that already carried the real choice. Chicken Pit clears the flag because Single Player and *Multiplayer vs CPU* were the same two-seat session (`gameplay.gd` seats a bird whenever `player_two_enabled()` is false), so the screen asked a question with one honest answer. `_prepare_session()` still degrades rather than asserts — mobile and `game_shell_test.gd` both enter solo — see §4.1. The now-unreachable `mode_select_intro`, `mode_select_hint`, `single_player_description` and `multiplayer_description` copy keys were dropped, and `solo_confirm_title` retitled for the CPU card it now labels. Separately, the game joined the shared tutorial pipeline: `tools/tutorial_capture.gd` gained a Chicken Pit caption script and a scripted puller that rotates the real `Q`/`W`/`E` bindings through `_register_pull()` at a legal 0.13 s cadence, and `tools/record_tutorials.ps1` gained a per-game encoder quality because a 3D clip costs Theora roughly twice a 2D one. `assets/video/tutorial.ogv` and its poster now back the instructions video card and the game-picker preview; `assets/pit-poster.png` remains the README hero. The clip teaches the rhythm rather than staging a pin: the CPU seed comes from the shell RNG, so no scripted ending is reproducible across takes. |
| 7 | **The hat store** (§14.9, §14.5 row 11). Rounds now pay Feathers and Feathers buy hats. The shop is a framework capability rather than a Chicken Pit screen: `GameManifest` gained `store_items`, `store_slots`, `store_currency` and `store_preview_scene_path`, a `Store` autoload owns per-game wallets, ownership and equipped slots in `user://store.cfg`, `scenes/menus/store.tscn` renders whatever a manifest declares, and `GameShell._end_round()` banks the payout through an overridable `_round_points_earned()`. Wallets are deliberately per game: this game scores in the thousands and a shared purse would let it buy out every other shop, so the rate is `round(best x 0.02) + 5`, `+10` solo over the CPU, capped at 150 — the cap is what keeps §14.3's long-rope/slow-decay corner from becoming an exploit. Chicken Pit contributes seven hats, two coop slots, a Feather currency and `ui/hat_preview.tscn`. Every hat perches **above** the comb or the bonnet (`COMB_HAT_BASE = 1.90`, `BONNET_HAT_BASE = 1.82`) and keeps a team-coloured band, because §14.6 makes those two silhouettes the non-colour way to tell the coops apart; `pit_geometry_test.gd` asserts it for every declared hat. Hats join the bird's existing single surface on head part `3.0`, so they inherit the head-dip animation and cost zero draw calls against §13.1. They are read in `_load_round_settings()`, so a swap from the pause menu lands at the next countdown, and `pit_view.gd` receives them as an argument rather than reading an autoload it cannot see from `pit_view_test.gd`. |
| 8 | **The gallery** (§14.10, §14.5 row 12). The models are built to a standard the match never shows — the barn stands behind the north fence, the pit's walls are seen from forty feet up, the bunting is a strip of colour at the edge of frame — so a museum was added where they stand still. Like the store it is a framework capability rather than a Chicken Pit screen: `GameManifest` gained `gallery_exhibits` and `gallery_stage_scene_path`, and `scenes/menus/gallery.tscn` owns the room, the grouped list, the orbit and the label. **No autoload was added**, deliberately: a store has a wallet to protect, a museum has an opening time and a door, so the manifest is the whole state and nothing reaches `user://`. Chicken Pit contributes nine exhibits in `chicken_pit_options.gd` and `ui/gallery_stage.tscn`, which builds every one of them from the same `ChickenRig`/`Scenery` call the match makes — the two coop birds even wear the hats revision 7's store has equipped — so the display case cannot drift from the game. `pit/scenery.gd` gained public `pit_mesh()`, `stand_mesh()`, `tree_mesh()` and `bunting_mesh()` beside `barn_mesh()`; they are accessors onto the private builders, not copies. Framing is derived rather than authored: each exhibit is treated as the cylinder it sweeps out as it turns and the camera placed where that cylinder is tangent to the narrower field-of-view angle, so a 1.9-unit bird and a 23-unit showground both fit in portrait and in ultrawide with no hand-measured distance. The `SubViewport` draws only when the view changes, because this screen opens from the pause overlay with a whole 3D match still resident (§13.1). Every exhibit carries a description and specification lines, reduced motion parks the turntable and disables the toggle with a reason, and every orbit action has an on-screen button — the arrow keys stay with menu focus so a keyboard or d-pad player is never trapped inside the picture (§6.2). *Cluck County Showground* sits behind `pit_first_match`, listed and explained but disabled, so the collection reads as something to finish. `tests/gallery_test.gd` covers the framework side and `pit_geometry_test.gd` builds all nine exhibits headlessly. |
