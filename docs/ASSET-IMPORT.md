# Asset Import

How the Kenney library gets into `game/godot/assets/third_party/kenney/`, and how to
refresh it. The importer checks the pinned archives for the imported packs, copies files,
converts the protagonists, and regenerates `manifest.json`. Use Blender 5.1.1 to match
the tested toolchain; byte-identical exports across Blender versions are not guaranteed.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7
- Node 22 LTS (for `npm run assets:validate`)
- Blender 5.x, only needed for the animated protagonists (`BLENDER_EXE`)
- Godot 4.7 (for the import and the asset test)

## One-time archive download

Download the eight archives listed in `tools/assets/kenney-packs.json` directly from
Kenney and keep them outside the repository, all in one folder:

```
https://kenney.nl/assets/city-kit-suburban
https://kenney.nl/assets/city-kit-commercial
https://kenney.nl/assets/city-kit-roads
https://kenney.nl/assets/animated-characters-protagonists
https://kenney.nl/assets/car-kit
https://kenney.nl/assets/nature-kit
https://kenney.nl/assets/foliage-pack
https://kenney.nl/assets/mini-characters
```

Archives are never committed. The importer reads them read-only and extracts to
`%TEMP%\worldpulse-kenney-import`, which it wipes on every run.

## Import

```powershell
$env:KENNEY_ARCHIVE_DIR = "D:\assets\kenney"
$env:BLENDER_EXE = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
npm run assets:import
```

Or call the script directly with parameters:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/assets/import-kenney.ps1 `
  -ArchiveDir "D:\assets\kenney" `
  -Blender "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
```

Expected result: `Imported 50 assets into ...\game\godot\assets\third_party\kenney`.

What the importer does:

1. Checks each imported pack's archive against its SHA-256 in `kenney-packs.json`.
   A missing or mismatched archive stops the run. The importer skips the 2D-only
   Foliage Pack; its archive hash is recorded separately as provenance.
2. Copies the models listed in `kenney-selection.json` to `<pack>/models/<id>.glb`,
   renaming to snake_case ids, plus the shared `Textures/colormap.png`.
3. Copies the original `License.txt` as `<pack>/LICENSE.txt` and writes `<pack>/source.json`.
4. Converts the protagonist FBX set with Blender (`tools/assets/convert-characters.py`),
   applying the skin texture, fixing alpha, and exporting Idle/Run/Jump via NLA tracks.
5. Verifies every converted GLB: expected clip names exist and at least one sampler has
   more than one key. A bind-pose-only export fails the run.
6. Writes `manifest.json` with the pack list, and per asset: id, category, pack, source
   file, imported path, byte size, SHA-256, scale, collision flag, clip list.

## Godot import

After the files change, let Godot regenerate its import cache:

```powershell
godot --headless --path game/godot --import
```

Then verify the assets and clips headlessly:

```powershell
godot --headless --path game/godot --script res://tests/validate_assets.gd
```

Expected: `PASS: 50 Kenney assets load; protagonist states and road overrides validated.` and exit code 0.

### Road palette derivative

The road correction lives outside the third-party import tree. Regenerate it with
Python and Pillow installed:

```powershell
python tools/assets/build-road-atlas.py
godot --headless --path game/godot --import
```

The script asserts the inspected Roads 2.2 palette and changed-pixel counts.
`KenneyAssets.instance()` applies a cached material copy only to the `roads`
category. It preserves the original material settings and swaps only the atlas;
traffic props and other categories keep their original materials. Reimporting
Kenney assets does not overwrite this WorldPulse derivative.

### Project-authored protagonist Walk

The Kenney importer still exports only Idle, Run and Jump. After a Godot import,
regenerate the separate Walk resource and check it from the repository root:

```powershell
godot --headless --path game/godot --script res://tools/generate_protagonist_walk.gd
godot --headless --path game/godot --script res://tools/check_protagonist_walk.gd
```

The generator bakes an in-place 1.04 s loop to `res://assets/animations/protagonist_walk.tres`
using 104 intervals. Each foot is in stance for 60% of its cycle; the feet are half
a cycle apart, retaining double support. Heel/toe roll and a two-bone leg solve use
the rig's rest geometry. Unreachable ankle targets abort the bake before overwriting
the resource. At the manifest scale of 0.478128, the reference travel speed is
1.256618 m/s (115.385 steps/min). The clip does not move the character node: future
world movement must match this speed, or retune and repeat contact review.
Slopes, turns and variable-speed gameplay are not validated. See
[provenance](ASSET-LICENSES.md#worldpulse-walk-v01a2).

To use Walk, create one `CharacterVisualState` per visual, call `bind(player)` on
its `AnimationPlayer`, and request states with `play(&"Walk")` or the corresponding
Idle, Run or Jump name. `bind()` validates and installs Walk in an instance-local
animation library and starts Idle. `get_state()` and `state_changed` expose the
current state. Idle, Walk and Run loop; state changes blend over 0.12 s. Jump plays
once and returns to the last requested locomotion state, including requests made
mid-jump. Repeating the active state does not restart its clip.

The local CI definition runs the headless Walk checker and the character scene with
`CHARACTER_SELF_TEST=1` in addition to the existing asset and startup checks.
See [QA results](ASSET-QA.md) for renderer and visual evidence.

## Machine validation

```powershell
npm run assets:validate
```

`tools/assets/validate-kenney.mjs` checks the manifest against the pack and selection
files: 8 packs and 50 assets, snake_case unique ids, known packs and categories, CC0
licence and Kenney source URLs, canonical import paths, file existence, byte size and
SHA-256, GLB magic, animation names with multi-key samplers, skin presence, positive
scale, and a `LICENSE.txt` naming Kenney and CC0 for every imported pack. Exit code 1 on
any mismatch.

## Changing the selection

Edit `tools/assets/kenney-selection.json` (ids, categories, collision flags, the
normalization map), then rerun the import and both checks. Do not rename imported files
by hand and do not edit `manifest.json`: the importer overwrites it.

## Troubleshooting

- `Missing archive` / `archive SHA-256 mismatch`: re-download that pack from Kenney. Do
  not lower the check.
- `Blender character conversion raised a Python error`: the importer prints Blender's
  traceback. Blender exits 0 even on Python errors, so the importer greps for
  `Traceback (most recent call last)` and throws.
- `has one key per track (bind pose only)`: the clip was exported without NLA tracks.
  Keep `export_animation_mode="NLA_TRACKS"` in `convert-characters.py`.
- Characters render invisible: the FBX material arrives with alpha 0. Keep the
  `Alpha = 1.0` fix in the converter.
- Assets missing in Godot after a manual copy: rerun `godot --headless --path game/godot --import`.
