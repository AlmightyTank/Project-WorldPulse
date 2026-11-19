# Asset Catalog

Fifty assets from seven Kenney packs, normalized to metres. `id` is the stable name used
in `manifest.json`, in code (`KenneyAssets.instance("res_building_type_a")`) and in scene
files. `scale` is the metres-per-source-unit factor applied by the Godot wrapper, not a
baked transform. Collision is a runtime box from the scaled bounds.

Day-one layout intent is listed per category; none of it commits the city plan.

## Residential - City Kit Suburban 2.0

| id | Source file | Scale | Collision | Intended use |
| --- | --- | --- | --- | --- |
| `res_building_type_a` | `building-type-a.glb` | 8 | yes | Small detached house, low-density block filler |
| `res_building_type_c` | `building-type-c.glb` | 8 | yes | Mid-size house with pitched roof |
| `res_building_type_f` | `building-type-f.glb` | 8 | yes | Two-storey home, reference building in the scale scene |
| `res_building_type_j` | `building-type-j.glb` | 8 | yes | Apartment block variant |
| `res_building_type_n` | `building-type-n.glb` | 8 | yes | Compact terraced house |
| `res_building_type_t` | `building-type-t.glb` | 8 | yes | Corner house, wider footprint |
| `res_fence` | `fence.glb` | 8 | no | Garden/plot boundary dressing |
| `res_planter` | `planter.glb` | 8 | no | Sidewalk greenery |

## Commercial - City Kit Commercial 2.1

| id | Source file | Scale | Collision | Intended use |
| --- | --- | --- | --- | --- |
| `com_building_a` | `building-a.glb` | 8 | yes | Small storefront |
| `com_building_c` | `building-c.glb` | 8 | yes | Mid-rise shop block |
| `com_building_e` | `building-e.glb` | 8 | yes | Office block |
| `com_building_k` | `building-k.glb` | 8 | yes | Large retail/commercial anchor, 16.7 m wide |
| `com_skyscraper_a` | `building-skyscraper-a.glb` | 8 | yes | Downtown high-rise landmark |
| `com_low_detail_building_a` | `low-detail-building-a.glb` | 8 | yes | Background block, cheap silhouette |

## Roads and traffic - City Kit Roads 2.2

| id | Source file | Scale | Collision | Intended use |
| --- | --- | --- | --- | --- |
| `road_straight` | `road-straight.glb` | 8 | no | Two-lane straight, 8 m module |
| `road_straight_half` | `road-straight-half.glb` | 8 | no | Half-width lane segment |
| `road_crossroad` | `road-crossroad.glb` | 8 | no | Four-way crossing |
| `road_intersection` | `road-intersection.glb` | 8 | no | T-junction |
| `road_curve` | `road-curve.glb` | 8 | no | Wide curve |
| `road_bend` | `road-bend.glb` | 8 | no | Tight bend |
| `road_side` | `road-side.glb` | 8 | no | Side/kerb strip |
| `road_crossing` | `road-crossing.glb` | 8 | no | Pedestrian crossing |
| `road_tile_low` | `tile-low.glb` | 8 | no | Low ground tile |
| `road_tile_high` | `tile-high.glb` | 8 | no | Raised ground tile |
| `road_traffic_light` | `traffic-light.glb` | 4 | yes | Intersection control |
| `road_light_square` | `light-square.glb` | 4 | yes | Street lamp |
| `road_sign_stop` | `road-sign-stop.glb` | 4 | yes | Stop sign |

All road tiles are ground geometry with no collision; the ground plane handles walking.

## Vehicles - Car Kit 3.1

| id | Source file | Scale | Collision | Intended use |
| --- | --- | --- | --- | --- |
| `veh_sedan` | `sedan.glb` | 1.75 | yes | Default traffic car, 4.5 m long |
| `veh_hatchback_sports` | `hatchback-sports.glb` | 1.75 | yes | Sporty civilian car |
| `veh_van` | `van.glb` | 1.75 | yes | Delivery/utility van |
| `veh_taxi` | `taxi.glb` | 1.75 | yes | Taxi service |
| `veh_police` | `police.glb` | 1.75 | yes | Emergency/police traffic |
| `veh_suv` | `suv.glb` | 1.75 | yes | Large civilian car |
| `veh_truck` | `truck.glb` | 1.75 | yes | Heavy goods |
| `veh_delivery` | `delivery.glb` | 1.75 | yes | Delivery van variant |

## Nature - Nature Kit 2.1

| id | Source file | Scale | Collision | Intended use |
| --- | --- | --- | --- | --- |
| `tree_default` | `tree_default.glb` | 3 | yes | Standard street/park tree |
| `tree_detailed` | `tree_detailed.glb` | 3 | yes | Foreground tree with more geometry |
| `tree_fat` | `tree_fat.glb` | 3 | yes | Broad canopy |
| `tree_pine_tall_a` | `tree_pineTallA.glb` | 3 | yes | Tall conifer |
| `tree_simple` | `tree_simple.glb` | 3 | yes | Background tree, cheap |
| `tree_small` | `tree_small.glb` | 3 | yes | Young tree/park detail |
| `tree_palm` | `tree_palm.glb` | 3 | yes | Palm for warmer districts |

These seven imported Nature Kit trees are sufficient for the initial tree library. Bushes, rocks and grass are not part of the Godot import. The existing extracted official Nature Kit archive at `%TEMP%/worldpulse-kenney-import/nature-kit/Models/GLTF format` contains candidates such as `plant_bush.glb`, `rock_smallA.glb` and `grass.glb` if a later scene needs ground-level dressing. No extra pack or import is needed for v0.1A.2. The separate 2D Foliage Pack remains outside the 3D import.

## Citizens - Animated Characters Protagonists 1.1 / Mini Characters 2.0

| id | Source | Scale | Collision | Imported GLB clips |
| --- | --- | --- | --- | --- |
| `char_protagonist_criminal_male_a` | `characterMedium.fbx` | 0.478128 | no | Idle, Run, Jump |
| `char_protagonist_cyborg_female_a` | `characterMedium.fbx` | 0.478128 | no | Idle, Run, Jump |
| `char_protagonist_skater_female_a` | `characterMedium.fbx` | 0.478128 | no | Idle, Run, Jump |
| `char_protagonist_skater_male_a` | `characterMedium.fbx` | 0.478128 | no | Idle, Run, Jump |
| `char_mini_female_a` | `female-a.glb` | 2.2 | no | none (static) |
| `char_mini_male_a` | `male-a.glb` | 2.2 | no | none (static) |
| `char_mini_worker` | `worker.glb` | 2.2 | no | none (static) |
| `char_mini_robot` | `robot.glb` | 2.2 | no | none (static) |

The four protagonists are regenerated from the FBX source by
`tools/assets/convert-characters.py` (see [ASSET-IMPORT.md](ASSET-IMPORT.md)); their source
file is the same skinned model with different skins. All four can also play the
project-authored Walk when bound to `CharacterVisualState`. Walk lives outside the
imported GLBs and manifest; it does not add a catalog entry or change the source clips.
The mini characters are a separate, deliberately static art style kept for scale and
style comparison.

## Normalization

Metres per source unit, from `tools/assets/kenney-selection.json`:

| Category | Factor | Result |
| --- | --- | --- |
| residential, commercial, roads | 8 | 1x1 road tile becomes an 8 m two-lane tile |
| traffic | 4 | Signal head at human height |
| vehicles | 1.75 | Sedan 4.5 m long |
| nature | 3 | Street tree 5.1 m tall |
| citizens | 1 (overridden per asset) | Protagonist 3.7647 source units to 1.8 m |

Every asset's origin sits at the bottom of its bounds, so a node placed at `y = 0` stands
on the ground.
