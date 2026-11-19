# Asset Licenses

All third-party art in this repository comes from [Kenney](https://kenney.nl) and is
released under **CC0 1.0 Universal (public domain dedication)**. No attribution is
required; it is given here anyway so the provenance of every file is traceable.

| Pack | Version | Archive | SHA-256 | Licence |
| --- | --- | --- | --- | --- |
| City Kit Suburban | 2.0 | `kenney_city-kit-suburban.zip` | `5869c35cf30b1c87bdb2d197b6d325eebadd2ef08ea27f04797e8e08d77a9a39` | CC0-1.0 |
| City Kit Commercial | 2.1 | `kenney_city-kit-commercial.zip` | `f8b09b081c2bb88bcc126e2dec1cb40fd0dad7e7e591b6c26aaefe96fb35276b` | CC0-1.0 |
| City Kit Roads | 2.2 | `kenney_city-kit-roads.zip` | `374a4552115cbd11b4ec5c930ee31a533562dc78a09af249a655d03f7ea3b959` | CC0-1.0 |
| Animated Characters Protagonists | 1.1 | `kenney_animated-characters-protagonists.zip` | `ec3787de70fa2200256848d74201b10f6b6c3126594e9857bf989753312c2b84` | CC0-1.0 |
| Car Kit | 3.1 | `kenney_car-kit.zip` | `fac7dacac5c7874348cf19729af3ef205f3d366493edaf0a827d93f4fdf3d0c4` | CC0-1.0 |
| Nature Kit | 2.1 | `kenney_nature-kit.zip` | `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d` | CC0-1.0 |
| Foliage Pack | 1.0 | `kenney_foliage-pack.zip` | `33bd564f2cebb6a68bee9a798650d669571a389a437b0bd601d257ca2b5e7aed` | CC0-1.0 |
| Mini Characters | 2.0 | `kenney_mini-characters.zip` | `add348e98ab9e23d9973c4740ef2c5cceb229c742106aca2d56b30a8f1241bb7` | CC0-1.0 |

Versions and hashes are authoritative in `tools/assets/kenney-packs.json`; the table
above mirrors that file. The foliage pack is 2D only: it was downloaded and hashed for
provenance but no foliage assets are imported. [Kenney lists version 1.0 (2016)](https://kenney.nl/assets/foliage-pack);
the archive's `License.txt` is undated.

Each imported pack keeps the original licence text next to its models:
`game/godot/assets/third_party/kenney/<pack>/LICENSE.txt`, with a `source.json` recording
the pack slug, author, version, source URL and archive SHA-256.

## WorldPulse road palette derivative (v0.1A.2)

`game/godot/assets/materials/roads/colormap.png` derives from the City Kit Roads 2.2
CC0 atlas. `tools/assets/build-road-atlas.py` reproduces it: asphalt `#666b80`
becomes `#3a3c3f`, and shoulder `#515566` becomes `#2d2f32`. Exactly 24,576 pixels
change; all other pixels, including markings and sidewalks, remain identical.
The upstream atlas and GLBs remain unchanged, so their recorded hashes still apply.
The derivative retains the source's CC0 provenance.

## WorldPulse residential roof derivatives

`WorldBuildings._apply_roof()` creates four in-memory atlas derivatives of the CC0 City Kit Suburban 2.0 `models/Textures/colormap.png`. No upstream file is overwritten. The 512 × 512 atlas changes only rectangle `(32,128,32,128)`: exactly 4,096 pixels per variant. Terracotta `#935e4f`, slate `#586478`, muted olive `#797c5b` and taupe `#77665e` retain the original swatch shading through its green-channel brightness. Stable placement-id hashes select the variant; materials and textures are cached per World build.

The six placed house meshes were inspected: roof triangles sample X=48 in atlas row 128–255; walls/trim use X=48/240 in row 256–383, windows X=368 in row 128–255, and original shrubs X=112 in row 384–511. No triangle crosses those regions. Tests check triangle isolation, unchanged non-roof pixels and untouched commercial materials. Overrides apply only to these audited town houses, not the gallery or global asset loader. Imported mesh geometry, UVs, filtering, walls, windows, shrubs and road corrections remain unchanged. These runtime derivatives retain the source's CC0 provenance.

## WorldPulse Walk (v0.1A.2)

`game/godot/assets/animations/protagonist_walk.tres` is an original, mathematically
baked WorldPulse gait. `game/godot/tools/generate_protagonist_walk.gd` uses the CC0
Kenney Protagonists rig's rest geometry and the Idle clip's track layout, but does
not sample its motion or slow down Run. No external animation was imported.
This records the Walk's origin without changing the Kenney source license or
assigning a license to WorldPulse code or original assets.

Candidates reviewed but not imported for Walk:

| Candidate | Review outcome |
| --- | --- |
| Kenney Animated Characters Protagonists, Retro and Survivors (CC0) | Idle, Run and Jump only; no upstream Walk. The existing Protagonists import remains in use. |
| Kenney Blocky Characters (CC0) | Walk animates rigid nodes, not the Protagonists skeleton. |
| Godot `tps-demo` (visual assets CC BY 3.0) | No compatible rig imported; no demo art or clips used. |

## Rules

- Source only `https://kenney.nl/assets/<slug>`. No third-party re-hosts or asset sites.
- Never edit a licence file, and never delete a `LICENSE.txt` or `source.json`.
- Do not commit the downloaded archives. Download them from Kenney and keep them
  outside the repository; the importer reads those local files.
- Do not claim a pack that was not verified. If a download cannot be verified against
  its SHA-256, report it as blocked instead of importing it.
