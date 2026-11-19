# Building catalog and district composition

`game/godot/data/building_catalog.json` contains explicit placements, built and validated by `game/godot/scripts/world_buildings.gd`. The site-finish revision has 48 buildings: 18 residential, 18 market, 4 square shops and 8 civic. The developer overlay combines market and square shops as 22 commercial. Greenbelt remains empty.

## Measured assets

One Godot unit is one metre. Positions are footprint centers; rotations are Y quarter turns. Bounds come from actual mesh AABBs at the original scale-8 wrappers, not guessed plot dimensions. No per-placement scaling, source asset or animation changes are used. Town houses receive roof-only material overrides; see [derivative provenance](ASSET-LICENSES.md).

| Asset | Footprint (m) | Height (m) | Local entrance | Placed |
| --- | ---: | ---: | --- | ---: |
| `res_building_type_a` | 10.400 × 8.225 | 6.668 | south | 6 |
| `res_building_type_c` | 10.291 × 8.225 | 8.268 | south | 5 |
| `res_building_type_f` | 11.424 × 11.247 | 9.100 | south | 1 |
| `res_building_type_j` | 10.960 × 7.328 | 8.300 | south | 4 |
| `res_building_type_n` | 14.274 × 11.023 | 9.100 | south | 1 |
| `res_building_type_t` | 10.509 × 11.251 | 9.251 | south | 1 |
| `com_building_a` | 7.069 × 7.520 | 10.344 | north | 10 |
| `com_building_c` | 7.069 × 8.720 | 7.144 | north | 8 |
| `com_building_e` | 13.120 × 8.063 | 7.144 | north | 7 |
| `com_building_k` | 16.669 × 7.536 | 11.760 | north | 4 |
| `com_skyscraper_a` | 10.880 × 10.880 | 23.040 | north | 1 |
| `com_low_detail_building_a` | 4.000 × 4.000 | 16.000 | unknown | 0 |

The low-detail wrapper remains catalog-only because it lacks an identifiable entrance. Civic roles reuse commercial shells; they are visual roles, not implemented services.

## Blocks and frontage

| Plot | Interior size (m) | Buildings | Arrangement |
| --- | --- | ---: | --- |
| `res_north` | 48 × 32 | 6 | Three homes per opposing street, deeper rear gardens |
| `res_square` | 48 × 24 | 6 | Two west-facing, two square-facing, one north-facing and one south-facing home |
| `res_south` | 48 × 24 | 6 | Opposing residential rows facing the high street and greenbelt edge |
| `civic_west` | 24 × 32 | 2 | Hall faces plaza; library faces the northern street |
| `civic_east` | 56 × 32 | 6 | Records tower and halls with entrances on opposite streets |
| `market_north` | 56 × 24 | 9 | Removed n4 and moved n5 2 m east, opening a 7 m paved court |
| `market_south` | 56 × 24 | 9 | Removed n2, opening a 7.2 m paved court beside the retained K-shell anchor |
| `square_south` | 24 × 24 | 4 | Two square-facing shops and two southern shops |
| Three Greenbelt reserves | 160 × 40 combined | 0 | Contiguous open land without an internal road loop |

The first connected-grid pass had an oversized empty residential center and identical market rows. Two homes now occupy the north and south edges of the central residential block, breaking the lawn into smaller rear spaces without adding blocked rear entrances. The market's western pair turns toward the plaza, and the southern high street has a different width/height sequence. The site-finish pass adds four restrained roof colors, 18 bounded lawn patches, paved entrance corridors, wider commercial/civic forecourts where clear, and two market service courts. No fences, people, trees or props were added. Original shrubs embedded in the Kenney meshes remain unchanged.

Site slabs reuse measured bounds, plot rectangles and entrance corridors. Lawn patches shrink where neighbors leave insufficient space; they cannot overlap adjacent footprints or each other. Paving is outside footprints and coplanar paving pieces cannot overlap. All sites stay within built plots, outside roads/plaza/Greenbelt. Lawn tops are Y=0.004 m and paving tops Y=0.06 m, above terrain at -0.02 m and below sidewalks at 0.16 m. They add no blocking colliders; existing terrain collision remains. The surfaces are visual finishes, not a new traversable elevation system.

## Entrance and clearance contract

Every placement must have an identifiable entrance. `entrance_corridor()` starts at the midpoint of the catalogued entrance facade and extends straight to that plot's street edge with a 2 m transverse width. It probes the road at the center and both sides, requires the corridor to remain in the plot and rejects intersection with any other building footprint. Opposing rows therefore face separate streets, rather than requiring access through a front row.

Other checks retain schema/units, unique IDs, known plot/district/asset references, supported rotations, measured wrapper dimensions and ground alignment within 0.02 m, collision sizes, rotated footprint containment, pairwise overlap, 1 m road clearance, protected Greenbelt land and beacon/plaza bounds. The whole World build is rejected on catalog errors; the separate debug builder can display rejected placements in red for diagnosis.

This is a conservative geometric corridor from an inferred facade midpoint. It does not locate individual mesh door polygons, certify accessibility standards, or implement pedestrian navigation. Paving follows the designated street-facing corridor; secondary courtyard-facing doors are not individually connected. Ground contact uses measured wrapper bounds and simple box collision proxies, not detailed per-wall collision.

Regression tests check every placement against every road and other footprint, all corridor transverse widths, blocked rear access, unknown entrances, missing road at an actual entrance and corridor containment at plot edges. They also verify the scene instances, fixed scales, metadata, collisions and camera framing.

## Beacon and debug

The original primitive WorldPulse Beacon remains centered at (-4,-4), cell (15,15): a 3.4 m base radius, ground height 0.165 m, 14 m configured overall height, 11.2 m tapered shaft and wider cyan crown. Its five primitive meshes and two collision shapes are deliberately modest; there is no animation or gameplay. The reduced 24 × 24 m plaza preserves a clear ring and southern gathering space.

F10 reveals footprint outlines, yellow entrance corridors and labels (`id`, `plot · facing · rotation`). Invalid placements are red. F8 reveals plot reservations. District labels and the readout show building counts; all planning overlays start hidden. See [layout](WORLD-LAYOUT.md), [camera](WORLD-CAMERA.md) and [QA evidence](ASSET-QA.md).
