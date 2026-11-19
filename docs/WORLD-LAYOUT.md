# Founder's District layout

Run `game/godot/scenes/world/World.tscn` directly with F6, or `godot --path game/godot res://scenes/world/World.tscn`. `Main.tscn` remains the startup scene; World runs offline.

## Buildings-first plan

`game/godot/data/founders_district.json` describes a 256 × 256 m terrain, from (-128, -128) to (128, 128), with 32 × 32 cells at the verified 8 m road pitch. North is -Z. Rectangles are `[x, z, width, depth]`, minimum inclusive and maximum exclusive. Terrain and its collision top remain at Y = -0.02 m.

The isolated district loops were replaced by shared streets enclosing nine adjoining blocks. Four east-west streets occupy rows 8, 13, 17 and 21 from column 6 to 25. Four north-south streets occupy columns 6, 13, 17 and 25 from row 8 to 21. Blocks follow measured building depths, rather than forcing rear buildings into narrow leftover strips.

| District | Cell rectangle | World bounds X; Z (m) | Role |
| --- | --- | --- | --- |
| Town Square | `[14,14,4,8]` | -16 to 16; -16 to 48 | Plaza and southern shops |
| Residential Quarter | `[6,8,8,14]` | -80 to -16; -64 to 48 | Three quiet residential blocks |
| Market Street | `[18,14,8,8]` | 16 to 80; -16 to 48 | Two compact commercial blocks |
| Civic Quarter | `[14,8,12,6]` | -16 to 80; -64 to -16 | Square-facing hall and records tower |
| Greenbelt | `[6,22,20,5]` | -80 to 80; 48 to 88 | Uninterrupted 160 × 40 m open land |

The plaza is 24 × 24 m, still centered at (-4, -4). The beacon stays at cell (15,15). The southern 24 × 8 m gathering reservation `[14,16,3,1]` stays clear of its base. Four marked crossings connect the square's approaches. There are 11 plots: three residential, two civic, two market, one southern square block and three contiguous Greenbelt reserves. F8 reveals their bounds.

## Road assembly and validation

Author nonzero axis-aligned segments between cell centers. Shared endpoints and intersections merge into one tile per occupied cell; repeating an edge is an error. Placement is `origin_m + (cell + 0.5) * 8` at Y = 0. Each compiled cell stores its asset, quarter-turn and N/E/S/W connection mask. Crossings replace straight pieces only.

| Kenney asset ID | Ports at 0° | Tiles |
| --- | --- | ---: |
| `road_straight` | E/W | 100 |
| `road_bend` | S/W | 4 |
| `road_intersection` | E/S/W | 8 |
| `road_crossroad` | N/E/S/W | 4 |
| `road_crossing` | E/W | 4 |

The 120 tiles form one connected component with 128 links and no dead ends. The existing road compiler and seam validation were retained. Wrappers measure (-4,0,-4) to (4,0.16,4), with centered base pivots, roadway at 0.08 m and sidewalks at 0.16 m. Positive Y rotation takes east to north. The road atlas overrides are unchanged. Other road assets are not interchangeable: `road_curve` spans 16 × 16 m, and the manifest has no compatible dead end.

Validation checks dimensions, IDs, bounds, overlaps, frontage, plaza reservations, references, rotations, reciprocal ports and graph reachability. Building validation additionally proves a clear 2 m entrance corridor to the actual adjacent street for every placement. These corridors now receive simple paving through the building-site finish. This is geometric access, not navigation, traffic routing or gameplay. The current 48-building layout retains every road; two removed market units make room for paved courts. Greenbelt is unchanged.

See [building catalog](BUILDING-CATALOG.md), [camera controls](WORLD-CAMERA.md) and [GPU results](ASSET-QA.md).
