# Kenney Asset QA

## v0.1B-A world foundation verification

Local Windows verification on 2026-11-18 used Godot 4.7.2 Compatibility, Ryzen 7 3800X and Radeon RX 5500 XT. The final run used fullscreen 1920 × 1080 and disabled VSync; the capture script checks every image's dimensions. Initial windowed captures were only 1886 × 1061 and are excluded. Final evidence: `%TEMP%\opencode\worldpulse-b-a-final\`, with `metrics.json`, ten PNG views and `contact-sheet.png`; adjacent `worldpulse-b-a-final.log` contains the rendering log.

| View / PNG name | Average FPS | Sampled range | Draws | Visible triangles |
| --- | ---: | ---: | ---: | ---: |
| `default` | 3059.7 | 3021-3095 | 182 | 12864 |
| `minimum-plaza` (30 m span) | 2604.0 | 2545-2646 | 19 | 1372 |
| `maximum` (398 m span) | 3005.3 | 2642-3192 | 182 | 12864 |
| `full-map` | 3159.0 | 3150-3170 | 182 | 12864 |
| `plaza-day` | 2508.3 | 2401-2563 | 66 | 4832 |
| `residential-day` | 2706.3 | 2471-2826 | 91 | 6404 |
| `commercial-day` | 2730.7 | 2594-2800 | 79 | 5528 |
| `district-bounds` | 2891.3 | 2858-2935 | 193 | 13148 |
| `road-connections` | 2614.7 | 1939-3082 | 183 | 13232 |
| `planning-overlay` | 1952.0 | 1560-2224 | 196 | 13152 |

Each average/range uses three Godot FPS readings 1.02 seconds apart after a 1.2-second settling interval, not frame-time percentiles. Counters are viewport-visible values at capture. Resource load plus scene ready took 259.084 ms; first draw took 277.037 ms in the already-imported project. Final GPU log has no rendering errors or warnings. This much lighter scene is faster than the earlier A2 neighborhood asset test (778.7 FPS, 403 draws, 154101 triangles), but these differing short workloads cannot predict a populated, simulated or streamed city.

All ten rendered views were reviewed in the contact sheet. Roads meet cleanly, sidewalks and markings align, daylight is consistent, and the warm plaza is distinct in the default view. Close-up plaza, residential and commercial views reveal no obvious gaps. The minimum span intentionally crops the plaza edges; default framing can crop the far terrain corner, while full-map and maximum views fit the map. District boundaries/labels and connection markers match the planned regions/network. The planning frame shows readable diagnostic text, the grid and all plot reserves. There is no decorative population or simulated lighting cycle.

### Automated and interaction evidence

- New world suite: **278 checks, zero failures**. Includes actual road meshes, pivot extents/openings/materials, deterministic coordinates and rotations, malformed inputs, districts/frontage, plaza reservations, plots, graph/seams, camera clamps and startup.
- Input dispatch tests: wheel zoom, middle drag pan, right drag orbit and R reset pass; F5 grid, F6 districts, F7 connections, F8 plots and F9 overlay all toggle on/off and start hidden. The overlay reports Town Square and successful validation.
- Actual GPU scene additionally holds D/E/= through the input pipeline and checks pan/orbit/zoom movement, then verifies smoothed R reset. This is injected engine input, not a claim of manual physical-key testing.
- Headless import, offline Main, asset validation (50 assets), gallery controls, character self-test, **244 Walk checks**, all four existing development-scene startups and independent World startup pass. Logs: `%TEMP%\opencode\worldpulse-b-a-final-headless\`.
- Workspace: 16 server unit tests and one web test pass; lint, typecheck, build and 50-asset/eight-pack license/hash validation pass. Build emits two dependency-only Rollup annotation warnings in Zod, not Godot rendering warnings.
- Database/Redis integration tests were not rerun: Docker Desktop's Linux engine pipe is unavailable. Hosted CI is unverified; its existing regressions remain and the new world test/startup are added. No commits, pushes, branches or remote changes were made.

### Limits and delivery review

Camera bounds constrain ground focus, not the entire visible footprint. No supported dead-end wrapper is imported; the larger curve is excluded rather than forced onto an 8 m cell. Districts and plots are spatial planning only. The landmark reservation is data, not a decoration. The building pass is recorded below.

Delivery review: **PASS** for requested desktop foundation visuals and controls. Direction/purpose: the sand plaza supplies the focal point, matte grass supports it, guides exist only for spatial inspection, and the readout uses an opaque high-contrast panel. Function: all five toggles and mouse/reset paths were exercised in the headless suite, continuous keyboard pan/orbit/zoom/reset in the GPU scene. Evidence: measurements are from captured engine output, with no generated artwork or invented claims. Web/mobile-specific gate items are not applicable to this 1080p Godot development scene. The local implementation is verified; full integration and hosted-CI acceptance remain unverified.

## v0.1B-B targeted site finish (current)

48 buildings remain: 18 residential, 18 market, 4 square shops and 8 civic. All 120 road tiles, the 256 m terrain, plaza, five districts and empty Greenbelt are retained. Removed `market_north_n4` and `market_south_n2`; moved `market_north_n5` 2 m east. Two paved courts interrupt the tight market frontage without enlarging the town.

Four deterministic roof-only variants replace uniform bright green. The six house meshes were audited by triangle UV assignment before implementation; every variant changes exactly 4,096 atlas pixels, with zero changes outside the roof swatch. A shared-image issue found by regression was fixed by explicitly duplicating the image. Original meshes, UVs, source textures, shrubs, walls, windows and road overrides are unchanged. See ASSET-LICENSES.md for provenance.

18 lawn patches, 48 paved entrance approaches/forecourts and two market courts use existing plot bounds and measured corridors. Tests verify plot containment, no road/plaza intrusion, no coplanar paving overlap, paving outside building footprints, and every designated entrance corridor covered. Lawn and paving tops are separated from terrain and each other. No new blocking collision or park/prop/gameplay work was added.

Final evidence folder: `C:\Users\amightytank\AppData\Local\Temp\opencode\worldpulse-town-site-final\` (17 full-resolution 1920 × 1080 PNGs and `metrics.json`). Engine log: the adjacent `worldpulse-town-site-final.log`. Verification: `C:\Users\amightytank\AppData\Local\Temp\opencode\worldpulse-site-verification\`. Earlier iteration retained as `worldpulse-town-site-finish\`.

The final default, residential-day, commercial-day, residential-closeup, market-north-closeup and market-south-closeup captures were opened and inspected. Roof colors read distinctly while windows/walls/embedded shrubs retain their original colors. Defined lawn edges and paved frontage are visible; market courts break the rows. The market remains intentionally denser than residential/civic areas. No z-fighting was apparent in these still views; elevation and overlap tests provide geometric checks. Secondary courtyard doors still open onto grass, since paths follow catalogued street-facing facades rather than individual mesh doors. This is not a complete landscape treatment or user visual approval.

Godot 4.7.2, actual Radeon RX 5500 XT, OpenGL Compatibility, fullscreen 1080p, VSync disabled:

| View | FPS samples | Draws | Triangles |
| --- | --- | ---: | ---: |
| Default | 1483, 1409, 1453 | 244 | 77061 |
| Residential | 1343, 1570, 1532 | 203 | 69615 |
| Commercial | 1562, 1731, 1734 | 137 | 46294 |
| Residential closeup | 1589, 1815, 1812 | 57 | 14674 |
| North market closeup | 1599, 1769, 1779 | 48 | 21424 |
| South market closeup | 1477, 1764, 1751 | 53 | 22017 |

Ready 469.913 ms; first draw 507.809 ms. Compared with the previous 50-building default, site surfaces increase draws from 178 to 244, while visible triangles decrease from 78,692 to 77,061. These are short uncapped debug samples, not sustained production benchmarks. Pan/orbit/zoom/reset passed in the GPU runner, which exited 0 and checked all capture dimensions.

Focused checks: world buildings 33,901 checks/0 failures; foundation 227/0; Walk 244/0; offline smoke, 50-asset load validation, gallery controls, Godot import, Main/World/four development startups and workspace asset validation passed. No errors were found in final verification logs. Backend and hosted CI were not rerun for this visual-only pass; the earlier Redis limitation remains. No Git writes.

## Previous connected-town redesign (superseded visual finish)

Final evidence: `C:\Users\amightytank\AppData\Local\Temp\opencode\worldpulse-town-final\`, containing fourteen 1920 × 1080 PNGs and `metrics.json`. Engine output: `C:\Users\amightytank\AppData\Local\Temp\opencode\worldpulse-town-final.log`. Verification logs: `C:\Users\amightytank\AppData\Local\Temp\opencode\worldpulse-town-verification\`.

Captured with Godot 4.7.2, OpenGL Compatibility on an actual Radeon RX 5500 XT, fullscreen with VSync disabled. The runner waits 1.2 seconds per view and records three FPS samples 1.02 seconds apart. GPU run exited 0, verified every PNG's dimensions and exercised D pan, E orbit, = zoom and R reset.

| View | FPS samples | Draws | Visible triangles |
| --- | --- | ---: | ---: |
| default | 1575, 1629, 1637 | 178 | 78692 |
| minimum-plaza | 1474, 1676, 1728 | 35 | 10248 |
| maximum | 1849, 1930, 1870 | 178 | 78692 |
| full-map | 1730, 1923, 1973 | 178 | 78692 |
| plaza-day | 1556, 1527, 1535 | 112 | 62765 |
| residential-day | 1279, 1629, 1628 | 146 | 72851 |
| commercial-day | 1533, 1615, 1602 | 104 | 48321 |
| civic-day | 1481, 1729, 1705 | 130 | 64050 |
| greenbelt-day | 1584, 1884, 1862 | 95 | 43079 |
| beacon-closeup | 1639, 1754, 1761 | 65 | 32318 |
| building-footprints | 1308, 1461, 1413 | 279 | 87108 |
| district-bounds | 1472, 1808, 1818 | 189 | 79184 |
| road-connections | 1482, 1740, 1722 | 179 | 78948 |
| planning-overlay | 1417, 1577, 1678 | 190 | 78956 |

All fourteen images were opened and inspected. The default shows one connected compact town, rather than district loops separated by empty margins. The first connected pass (`worldpulse-town-redesign-1`) exposed an oversized residential center and repeated market sequences. The final pass adds two street-facing homes, turns two shops toward the square and varies the southern market massing. Residential rear spaces remain quiet; market frontage is substantially tighter than civic spacing. The plaza and beacon stay legible, with crossings and a clear gathering area. The full-map and maximum views retain the whole terrain, while the Greenbelt capture shows uninterrupted empty southern land. Road-link and footprint views show the shared grid and entrance corridors without red invalid highlights. No floating or road-intersecting buildings were apparent in the inspected views; measured bounds and clearance tests provide the stronger geometric proof.

Visual limitations: source green roofs remain repetitive; private yards are implied rather than fenced; the same commercial shells also represent civic buildings. Debug footprint labels overlap at town scale, and district labels can be occluded by buildings. These overlays are hidden during normal viewing. This is my completed blockout review, not the user's visual approval, and no B-C dressing was added.

Verification on the final layout:

- `world_buildings.log`: 10,046 checks, zero failures, including measured wrappers, every entrance corridor, blocked-access rejection, missing-road rejection, unknown entrances, plot-edge corridor width, collisions and camera framing.
- `world_foundation.log`: 227 checks, zero failures, including disconnected-network rejection, road seams, startup and debug controls.
- `godot-import.log`, `offline_smoke.log`, `validate_assets.log`, `gallery_controls.log`, `walk.log`, `character.log`: import and regressions passed. All 50 imported Kenney assets load; protagonist states, Walk and road overrides pass.
- `startup-*.log`: Main, World, AssetGallery, CharacterAnimationTest, ScaleReference and QABenchmark booted. Final World startup is clean.
- `npm-lint.log`, `npm-typecheck.log`, `npm-test.log`, `npm-build.log`, `npm-assets-validate.log`: passed; asset inventory is 50 assets across 8 packs.
- `integration.log`: attempted but setup failed with `ECONNREFUSED 127.0.0.1:6379`; three integration tests skipped. PostgreSQL's port was reachable. No database migrations, infrastructure reconfiguration or backend changes were made.

These are short uncapped debug-build samples, not sustained frame-time percentiles or a production simulation forecast. Earlier FPS results below used different geometry and framing and are not a controlled speed comparison. Hosted CI and user visual acceptance remain unverified. No Git writes were performed.

## Earlier v0.1B-B buildings verification (superseded layout)

The following records the earlier 47-building layout only; it is retained as historical evidence, not the current design or acceptance result.

Same machine, renderer and measurement method as above: fullscreen 1920 × 1080, VSync and the frame cap disabled, three FPS readings 1.02 s apart after a 1.2 s settle. Evidence: `%TEMP%\opencode\worldpulse-b-b-final2\` with `metrics.json` and fourteen PNG views. The 47-building district is 14 residential, 23 commercial and 10 civic.

| View | Average FPS | Sampled range | Draws | Visible triangles |
| --- | ---: | ---: | ---: | ---: |
| `default` | 2095.0 | 2048-2126 | 234 | 82487 |
| `minimum-plaza` (30 m span) | 2001.0 | 1882-2070 | 24 | 1652 |
| `maximum` (398 m span) | 2311.3 | 2294-2325 | 234 | 82487 |
| `full-map` | 2042.0 | 1943-2110 | 234 | 82487 |
| `plaza-day` | 1879.3 | 1846-1899 | 84 | 25257 |
| `residential-day` | 1911.0 | 1713-2010 | 117 | 35420 |
| `commercial-day` | 1943.3 | 1937-1947 | 107 | 39203 |
| `civic-day` | 1928.0 | 1768-2010 | 87 | 32221 |
| `greenbelt-day` | 1935.7 | 1775-2019 | 160 | 54507 |
| `beacon-closeup` | 1958.3 | 1825-2025 | 52 | 7174 |
| `building-footprints` (F10) | 1593.3 | 1577-1623 | 329 | 90761 |
| `district-bounds` | 2016.0 | 1835-2121 | 245 | 82983 |
| `road-connections` | 2069.3 | 1958-2134 | 235 | 82855 |
| `planning-overlay` | 1945.0 | 1900-1988 | 254 | 82847 |

Against the B-A empty world (`default`: 3059.7 FPS, 182 draws, 12864 triangles) the populated default view costs 52 more draws and 69,623 more triangles, about 31 % fewer FPS and roughly 6.4× the triangles. That is the expected price of 47 real wrapper instances at scale 8; every view still holds above 1,590 FPS, so the slice has ample headroom and adds no per-frame simulation.

Reviewed views: the residential quarter reads as two street rows plus a west terrace with rear cottages; the market reads as two full street walls, two rear service ranks and four mid-block infill bays around an open forecourt; the civic quarter reads as two civic quads plus the mid-plot offices. No floating, sunk, overlapping or road-intersecting footprint is visible, the Greenbelt stays empty, and the plaza keeps a clear ring around the beacon. The footprint view shows all 47 outlines and labels with no red invalid highlight.

- Buildings suite: **9,827 checks, zero failures** (catalog, measured wrappers, ids, footprints, rotations, frontage, overlaps, road clearance, terrain contact, collision, determinism, scene build, beacon, camera and debug).
- World foundation suite: **286 checks, zero failures**, including the 19-plot count, the per-district overlay counts and the three scene child counts.
- Real Windows GPU run re-verified the windowed input pipeline (pan, orbit, zoom, reset); F5-F9 behaviour and the hidden-by-default debug overlays are covered headlessly.
- Limits: this is a static 1080p development scene. No LODs, occlusion culling, decoration, vehicles, citizens or simulated lighting were added. Building coverage per plot is listed in [Building Catalog](BUILDING-CATALOG.md).

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
