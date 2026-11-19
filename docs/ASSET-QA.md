# Kenney Asset QA

## Review in Godot

Open `game/godot/project.godot`. Open a scene under `res://scenes/development/` and press **F6** to run that scene without starting the main world.

- **AssetGallery:** 50 assets in six sections. Select an asset to see its details. Drag to orbit, Shift+drag to pan, and scroll to zoom. `R` resets the view, `1`/`2`/`3` switch day/evening/night, `G` toggles the grid, and `C` opens the comparison. The live FPS counter is subject to VSync; use the benchmark for uncapped figures.
- **CharacterAnimationTest:** select one of four 58-bone protagonists or four static Mini Characters. Use `1` for Idle (1.38 s, loop), `2` for Walk (1.04 s, loop), `3` for Run (0.71 s, loop), and `4` for Jump (0.54 s, once). `V` cycles lineup, front, three-quarter, side and back views; `S` cycles full, half, quarter speed and pause; `G` toggles the 1 m grid; `F` toggles foot-bone markers. The markers are bone projections, not sole contacts. Animation controls are disabled for static minis.
- **ScaleReference:** the 1.8 m human reference and 1.8 m protagonist stand alongside a 4.5 m sedan, Residential F (11.4 x 9.1 x 11.2 m), Commercial K (16.7 x 11.8 x 7.5 m), an 8 x 0.2 x 8 m straight road, and a 5.1 m tree. Dimensions are rounded from scene bounds in X/Y/Z order where shown. Road dimensions are a reference, not a commitment to city block dimensions.

The A2 atlas override corrects the pale lavender asphalt from A1 while retaining
lane markings, curbs and sidewalks. Foliage Pack is 2D-only and does not appear
in the 3D scenes.

## v0.1A.2 Walk review

Walk is an original baked gait, not a slowed Run. The closeout bake runs at
1.256618 m/s reference travel, with a 1.04 s cycle and 60% stance. The headless
rerun passed 244 checks; the GPU review passed 1,656 checks on Radeon RX 5500 XT
with OpenGL Compatibility. All four rigs produced identical contact results:
heel/flat/toe horizontal drift of 0.016/0.047/0.256 mm, lowest sole proxy -0.132 mm,
and highest stance proxy +0.267 mm. The checker advances playback at 120 Hz over
three cycles while translating the model at reference speed. These are calibrated
heel/toe proxies, not every skinned shoe vertex.

Rendered evidence includes 94 moving frames and 255 transition frames per rig,
animated WebP files, and `motion-contact-review.png` and `transition-review.png`
in the walk-review folder below. The rendered review covered Idle to Walk to Run
to Walk to Idle, repeated requests, and Jump returns. Main-session inspection of
the review sheets confirmed support/swing poses and the imported clips' arm-out
poses. Transitions were rendered in place: this does not certify transition foot
locking. Slopes, turns and variable-speed physics remain outside this asset slice.
The rebake SHA-256 is `ffcd7afc8fd45a422c91368149942bed981cb00e37debbcadce61a29abde2f24`.

The Walk agent reviewed all four contact sheets (side, front and three-quarter
views at nine sampled poses). On Windows they are under
`%APPDATA%\Godot\app_userdata\WorldPulse\walk-review\`:
`criminal_male_a.png`, `cyborg_female_a.png`, `skater_female_a.png` and
`skater_male_a.png`. Main-session inspection of all four sheets confirmed
alternating foot lift/contact poses and consistent sampled loop endpoints, not
live transition quality. To regenerate the sheets on a
rendering display:

```powershell
godot --path game/godot --script res://tools/check_protagonist_walk.gd -- --render
```

The character review passed 64 checks in a Godot 4.7.2 Windows window using native
Win32 mouse and keyboard messages. All eight selections, animation buttons and
shortcuts, Jump returning to Idle, five views, speed and pause/resume, grid and
foot markers behaved as expected. Disabled Mini Character controls ignored input.
Pause held the animation at 0.137500 s across a 350 ms wait; resuming advanced it.
The engine log contained no warnings or errors. Evidence is in
`%TEMP%\opencode\worldpulse-character-os.jsonl`. These were posted window messages,
not foreground hardware input. The expanded `CHARACTER_SELF_TEST=1` also passed
headlessly. Contact sheets alone do not establish in-motion transition quality.

## v0.1A.2 final GPU captures

Repeated on the same hardware, Compatibility renderer and 1920 x 1080 configuration
as the A1 baseline below. The final runs include the corrected road atlas. The
population case binds `CharacterVisualState` and plays Walk on 30 protagonists;
all 30 Walk setup checks passed.

| Scenario | Average FPS | Sampled FPS range | Draw calls | Rendered triangles | Failed checks |
| --- | ---: | ---: | ---: | ---: | ---: |
| Compatibility | 940.8 | 238-1,088 | 47 | 32,440 | 0 |
| Neighborhood | 778.7 | 91-922 | 403 | 154,101 | 0 |
| Population (retuned Walk) | 700.3 | 52-834 | 95 | 144,370 | 0 |

No warnings or errors appeared in the final benchmark logs. Average FPS was lower
than A1, with unchanged draw and triangle counts. These short runs do not isolate
the cost of the road override or Walk; the A1 population workload used Run.

Closeout benchmark evidence is under `%TEMP%\opencode\worldpulse-closeout\`:
`compatibility`, `neighborhood` and `population` each have a `.json`, `.png` and
`.log` file. Earlier A2 captures remain under `%TEMP%\opencode\worldpulse-asset-qa-a2\`
with `-final` suffixes. That earlier folder also contains `comparison-0.png`,
`comparison-1.png`, `comparison-2.png`, `comparison-night-final.png` and `scale.png`.
Road before/after captures are under `%TEMP%\opencode\worldpulse-phase-c\`
(`road-comparison.png`, `before-neighborhood.png`, `after-neighborhood.png`).
Temporary captures are not committed.

The closeout comparison hides the surrounding catalog until `R` restores it.
The night preset uses a cool ambient fill rather than relying on the dark sky
for ambient light. At 1920 x 1080 the updated capture shows the road markings
in shadow, the citizen's limbs and clothing, and the trees against the buildings.
The preset favors inspection readability over realistic night exposure. The
three closeout captures (`gallery-0.png` through `gallery-2.png`) are under
`%TEMP%\opencode\worldpulse-closeout\`; their logs contained no warnings or errors.
The gallery input test covers comparison/reset, the three presets, grid,
orbit, pan, zoom and selection of the comparison sedan through Godot input events.

## v0.1A.1 GPU benchmark (preserved baseline)

Measured windowed at 1920 x 1080 with VSync and the frame cap disabled. Windows build `10.0.26200`, AMD Ryzen 7 3800X, Radeon RX 5500 XT, Godot `4.7.2-stable` (official), Compatibility (`gl_compatibility`, OpenGL 3.3).

| Scenario | Instances | Average FPS | Sampled FPS range | Draw calls | Rendered triangles | Failed checks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Compatibility, all imported categories | 8 | 1,085.5 | 290–1,246 | 47 | 32,440 | 0 |
| Neighborhood, 20 buildings, 20 trees, 10 vehicles, 18 road tiles | 68 | 894.0 | 178–1,039 | 403 | 154,101 | 0 |
| Population, 30 animated protagonists | 30 | 804.8 | 163–934 | 95 | 144,370 | 0 |

No Godot warnings or errors appeared in the three benchmark logs. FPS is the average and range of six readings from Godot's FPS counter, once per second, starting at about one second. The first reading can include startup; the range is not a frame-time percentile. Draw calls and triangles are end-of-run Godot counters. These are short, single-machine asset tests, not a performance forecast for a live city. Compatibility checks representative meshes, material surfaces, bounds and manifest entries; the two load scenarios exercise rendering and instance loading, not simulation.

From the repository root in PowerShell, run on a GPU rather than headlessly:

```powershell
$out = Join-Path $env:TEMP 'worldpulse-asset-qa'
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($mode in 'compatibility', 'neighborhood', 'population') {
  $env:QA_MODE = $mode
  $env:QA_OUTPUT = Join-Path $out "$mode.json"
  $env:QA_SCREENSHOT = Join-Path $out "$mode.png"
  godot --path game/godot --resolution 1920x1080 res://scenes/development/QABenchmark.tscn
  if ($LASTEXITCODE -ne 0) { throw "Benchmark failed: $mode" }
}
Remove-Item Env:QA_MODE, Env:QA_OUTPUT, Env:QA_SCREENSHOT
```

Review each JSON's `checks_failed` and console output in addition to its process exit code.
The local CI workflow definition adds the headless Walk checker, character
control self-test and `gallery_controls.gd`, with log scans for `SCRIPT ERROR:`
and `ERROR:`. It retains
Godot import, offline smoke, asset validation and development scene startup checks.
Hosted CI has not run. Headless checks do not measure GPU performance or replace
visual review.
