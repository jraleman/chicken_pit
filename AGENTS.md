# AGENTS.md - Chicken Pit

Guidance for AI coding agents working in this repository.

## What this repository is

A self-contained **Godot 4.7 game folder**, consumed at
`godot-base/games/chicken_pit` by the DeskCanSaw base project. It is not a
standalone Godot project: the host owns `project.godot`, autoloads, menus,
settings, pause, results, sharing and achievements.

Read `DESIGN.md` before changing mechanics. The game is a local-versus
barnyard tug-of-war, with a CPU bird filling the second end when needed.
It uses real 3D inside a `SubViewport`, not a replacement for the shared
2D `GameShell`.

## Layout

| Path | Responsibility |
| --- | --- |
| `game.gd` | Manifest, copy, theme, credits and achievement declarations |
| `chicken_pit_options.gd` | Constants-only options and rebindable actions |
| `gameplay.gd` / `.tscn` | Shared-shell integration and inherited UI |
| `pit/pit_state.gd` | Pure pulling, decay, ground-held scoring, captures and pins |
| `pit/pit_history.gd` | Game-local completed-match history and capped resident flock |
| `pit/cpu_bird.gd` | Seeded CPU controllers using the same pull path |
| `pit/pit_view.gd` / `pit.tscn` | Read-only world, crowd and pooled effects |
| `pit/toy_mesh.gd`, `scenery.gd` | Original batched, vertex-painted model sources |
| `pit/chicken_rig.gd`, `chicken.gdshader` | Rigid-part birds, one surface each |
| `pit/rope_view.gd`, `pit_camera.gd` | Cosmetic simulation and camera work |
| `pit/pit_lighting.gd`, `sunset_sky.gdshader` | Scene-clock sunset and painted sky |
| `pit/pit_music.gd` | Owned Music-bus playback and synchronized danger stem |
| `ui/tug_meter.gd` | Native-resolution strength, knot and live key hints |
| `ui/menu_*.tres`, `menu_background.gdshader` | Standalone menu backdrop, plaque, widget skin and sounds |
| `ui/share_art.gd` / `.tscn` | Original farm portrait in the shared scorecard |
| `intro.gd` / `.tscn` | Existing narrated standalone opening |
| `assets` | Original textures/WAVs, supplied icon and opening recording |
| `tools/render_audio.py` | Offline audio authoring; Python standard library only |
| `tools/render_cover.gd` | Offline 3D cover portrait; graphics display required |
| `tests` | Standalone Godot `SceneTree` regression scripts |

## Commands

From this game folder, with the host project two directories above:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=chicken_pit
godot --headless --path ..\.. --script res://games/chicken_pit/tests/pit_state_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/chicken_pit/tests/pit_matrix_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/chicken_pit/tests/pit_geometry_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/chicken_pit/tests/pit_camera_test.gd -- --game=all
godot --headless --audio-driver Dummy --path ..\.. --script res://games/chicken_pit/tests/pit_audio_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/chicken_pit/tests/pit_round_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/chicken_pit/tests/chicken_pit_options_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/chicken_pit/tests/chicken_pit_intro_test.gd -- --game=all
godot --path ..\.. --resolution 1280x720 --script res://games/chicken_pit/tests/pit_view_test.gd -- --game=all
```

Run tests sequentially: framework tests share `user://`. Preserve the
developer's settings and progress, or use an isolated host/user directory.
The round fixture intercepts achievement writes while exercising the real
scene. Do not preload `GameShell` or a gameplay script from a `SceneTree`
test; load it at runtime after autoloads exist.

`pit_view_test.gd` requires a graphics window. Its optional user arguments
`--pit-capture-dir=<absolute directory>` and `--pit-poster=<absolute PNG path>`
save rendered images. Do not claim graphics coverage from a headless run.

The host also provides `game_shell_test.gd`, `lives_mode_test.gd`,
`accessibility_test.gd`, `game_options_test.gd`, `single_game_test.gd` and
custom-key menu coverage. Run affected coverage when changing those seams.
There is no separate linter or package manager.

## Framework boundary

- Extend `GameShell`; do not build parallel menus, pause, results or scorecards.
- The host must provide `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` and
  `GameManifest.supports_single_player`. Shared code branches on these
  capabilities, never on the string `chicken_pit`. Clearing
  `supports_single_player` only collapses mode selection's player-count step;
  the gameplay scene must still seat a bird when a solo session arrives from
  mobile or `game_shell_test.gd`, not assert.
- Mount the 3D world under `%Playfield`. Keep the container non-interactive,
  `own_world_3d`, `gui_disable_input`, transparency and resize wiring intact.
  With `stretch = true`, do not assign the subviewport's size yourself.
- Keep the host on `gl_compatibility`. No renderer switch or add-on dependency.
- One-shot audio uses `AudioManager.play_sfx`; cosmetic loops use the SFX bus.
  Adaptive music owns one `AudioStreamSynchronized` player on the Music bus,
  not the persistent menu music players. All owned loops pause/free with the
  scene. Keep both stems beat-aligned and stop them on results and exits.
  Do not extend the shared sound synthesizer.
- Both coops need a life pool even through a single-seat framework entry.
  Chicken Pit specializes `_active_player_indices`, `_every_player_is_out`
  and `_remaining_lives`: a duel ends when **either** coop is eliminated,
  unlike the shell's default independent-score survival rule.

## Mechanics invariants

- The model has no nodes, input events, settings or autoload instances.
  Pass options in. The CPU also uses only model time and a seeded RNG.
- Positive `rope` means red leads; world X is its negation. Never read a
  visual transform back into scoring.
- Reject echoes in gameplay. Reject sub-0.10-second pulls in the model,
  including simultaneous chords. Repeated actions receive the 0.35 penalty.
- Keep exponential decay and piecewise integration through the velocity cap
  and deadzone. A frame hitch must not invert strength or skip captures.
- Accumulate fractional held-ground score in the model; round only at the
  shell boundary. Headlines, results, stats and shares use the same totals.
- `extreme[i]` is that coop's greatest favourable magnitude, including
  fractional ground. A clean sweep requires the opponent's value to be zero.
- A pin is idempotent. Its score is awarded once; its scene-owned 1.1-second
  timer is pausable and finishes outside `_update_round`'s call stack.
  Replays and exits must cancel pending pin completion.
- A lives reset clears exchange state, not banked score or match history.
- Exits, including Router fades and startup/pin/buzzer races, cancel completion.
  `_finish_round()` is also cleanup, not proof that a match completed; only
  the guarded `_end_round()` marks a match for history. Do not update the 3D
  view from exit cleanup after its SubViewport has left the tree.
- Persist one play per completed match, never per start or lives pin. Seed
  legacy players from `pit_first_match`; keep six resident chickens per
  completed match, capped at 24. The current match reuses six landing slots
  through its lives exchanges. Failed history reads must not overwrite saves.
- Tunables and gameplay assists apply next round. Live controls, labels,
  reduced motion and intense effects use the shell's dedicated hooks.

## Art, accessibility and performance

The look is a colourful, handmade toy farm in a warm, changing sunset.
Standalone menus are the same fairground one stop below: they take their colours
from `ui/tug_meter.gd` and `pit/scenery.gd` and reprise the bunting, mown
stripes and lamps through `ui/menu_background.gdshader`. Two limits are
measured, not eyeballed (DESIGN.md §6.1): the shared menus bake fixed label
colours a theme cannot repaint, so a brighter backdrop breaks contrast; and the
menu's 1.5 key plus 4.0 omni fill clip a bright plaque texture's red channel,
so `assets/ui/plaque.svg` stays in the midtones. Re-measure a rendered frame
before brightening either. Note that Godot predefines `PI` in shaders, and
`single_game_test.gd` reports a pass even when a shader fails to compile.
Use the scene's player colours rather than hardcoding another red/blue pair.
Tall combs, bonnets, labelled goals and the textual tug meter distinguish sides
without relying on colour. Rebound keys must appear immediately.

The model sources are original geometry, not placeholder asset-store links.
Batch scenery; share the chicken mesh within a coop; use `MultiMesh` for
spectators and markers. Preserve the **under 60 pit draw calls including
shadows** budget. Cosmetic particles are pooled, never spawned per key event.
The view must remain inert-safe headless, with no emitters or Verlet buffers.
The central hole must cut every terrain layer, not paint a dark disc over
solid ground. Keep its walls and floor in the scenery batch and its resident
flock in one fixed-size `MultiMesh`; falling rigs are the existing coop birds.

Automatic camera shots stay on the front side so the coops never swap sides.
Focus the coop losing ground (positive rope means blue), and track actual
falling birds rather than stationary coop roots. Establishing/reduced-motion
shots fit the full arena. Action close-ups may crop rear chickens, distant
goals and scenery, but must retain both lead birds, the actual rope curve and
the pit inside HUD-safe bounds. Blend framing sets and focal length smoothly;
changing FOV alone does not prove visible zoom. The pin arc turns toward the
hole's front rather than forcing a pull-back to fit the winning rear birds.
The sunset uses the existing key/fill and an unshaded dome, not extra shadow
lights or per-frame sky cubemap updates. Keep mutable sky/environment resources
scene-local. Its explicit clock freezes on pause/results, survives Lives
exchanges and resets for a new match; do not use shader `TIME`.

Reduced motion fixes the camera and sunset and suppresses decorative motion, dust,
feathers and crowd jumps. Pin falls settle immediately without rewinding if
motion is re-enabled. Keep essential knot/strength movement. Intense
effects can be disabled separately. Caption meaningful audio events without
spamming a caption for every pull.

Rebuild original audio with `python tools\render_audio.py`, which writes eight
WAVs including `latch` and the beat-locked `pit-jig-danger` music stem; commit the
resulting WAV assets as well as source changes. Do not synthesize on the
runtime audio callback. Keep asset provenance and credits accurate.
The existing opening recording is not relicensed by the repository's MIT
code licence.

Rebuild `assets/menu-cover.png` with
`godot --path ..\.. --script res://games/chicken_pit/tools/render_cover.gd -- --game=all`.
Keep the generated cover with its source. It uses the original farm models,
fixed poses and the scene's team colours, without changing gameplay or settings.
The menu cover is full-colour: keep its logo tint white, not silhouette cream.
The shared scorecard reuses that portrait through `share_art_scene_path` and
opts into `GameTheme.style_share_card`. Keep its backdrop material scene-local
and frozen, both coop scores present even for single-seat entries, and its
pull/notch captions consistent with the model. The host's `share_card_test.gd`
covers theme switching and renders with a graphics display; its optional
`--share-capture-dir=<absolute directory>` saves example cards.

The instructions walkthrough clip is host-owned and lives outside this folder,
at `res://assets/video/tutorial_chicken_pit.ogv` with its poster. Re-record it
from `godot-base` with
`.\tools\record_tutorials.ps1 -Games chicken_pit -Godot (Get-Command godot).Source`
after changing gameplay visuals, the pull gates or the capture captions. The
scripted puller must keep rotating this game's real bindings above the model's
0.10-second floor; do not script the clip around a pin, whose CPU seed is not
reproducible across takes.

## Conventions

Tabs, static typing, snake_case and `_private_members`, matching the host.
Use preload constants as types for game-local scripts; avoid unnecessary
global `class_name` registrations. Explain non-obvious integration decisions,
not ordinary assignments. Godot resource URIs use `res://`; filesystem
commands on Windows use backslashes.

Keep changes within this game unless a generic framework capability is
genuinely necessary. Preserve existing work in both nested repositories.
Update `README.md` and any affected design decisions with behaviour changes.
