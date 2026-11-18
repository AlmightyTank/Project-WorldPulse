# Kenney Asset QA

## Review in Godot

Open `game/godot/project.godot`. Open a scene under `res://scenes/development/` and press **F6** to run that scene without starting the main world.

- **AssetGallery:** 50 assets in six sections. Select an asset to see its details. Drag to orbit, Shift+drag to pan, and scroll to zoom. `R` resets the view, `1`/`2`/`3` switch day/evening/night, and `G` toggles the grid. The live FPS counter is subject to VSync; use the benchmark for uncapped figures.
- **CharacterAnimationTest:** four textured protagonists, each with 58 bones. Press `1` for Idle (1.38 s, loop), `2` for Run (0.71 s, loop), and `3` for Jump (0.54 s, once). The scene turns the models to face the review camera. Idle playback was verified by observing changing bone rotations. The source has no Walk clip, and the static Mini Characters have no rigged clips. Ground-level placement is a scale and visual check, not a frame-by-frame foot-contact or foot-sliding test.
- **ScaleReference:** the 1.8 m human reference and 1.8 m protagonist stand alongside a 4.5 m sedan, Residential F (11.4 x 9.1 x 11.2 m), Commercial K (16.7 x 11.8 x 7.5 m), an 8 x 0.2 x 8 m straight road, and a 5.1 m tree. Dimensions are rounded from scene bounds in X/Y/Z order where shown. Road dimensions are a reference, not a commitment to city block dimensions.

The road atlas renders with distinct lanes, curbs and sidewalks, but asphalt appears pale lavender compared with Kenney's dark preview. Treat this as open visual tuning, not a missing texture. Foliage Pack is 2D-only and not represented in the 3D scenes.

## GPU benchmark

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

Review each JSON's `checks_failed` and console output in addition to its process exit code. CI checks startup headlessly; it does not measure GPU performance.
