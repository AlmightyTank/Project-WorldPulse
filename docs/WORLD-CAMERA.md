# World camera and planning tools

`game/godot/scripts/world_camera.gd` provides an orthographic three-quarter view for 16:9 output. The default aims at Town Square, 60° down and 19° around Y, with a 160 m vertical view span. Smaller spans zoom in. Default limits are 30 to 398 m. Orthographic framing keeps road widths consistent throughout the view.

| Control | Action |
| --- | --- |
| WASD or arrow keys | Pan relative to the view |
| Middle mouse drag | Pan directly |
| Mouse wheel or `+` / `=` / `-` | Zoom |
| Q / E or right mouse drag | Rotate if enabled |
| R or Home | Ease back to home view |
| F5 | Toggle the 8 m grid |
| F6 | Toggle district boundaries and labels |
| F7 | Toggle reciprocal road links |
| F8 | Toggle reserved plot footprints |
| F9 | Toggle the world readout |
| F10 | Toggle building footprints, ids and frontage debug |

The world supplies its bounds and home focus using `configure()`. Inspector exports control pan speed, keyboard and mouse rotation, keyboard and wheel zoom, smoothing, home framing and span limits. The camera clamps its focus to the map; the viewport can still show beyond the terrain, especially when zoomed out. No tracking or broadcast switching is implemented.

The debug-only tools are hidden initially. The grid verifies tile placement, plot tints show reserved land, and road links show connections without covering the default streets. The upper-left readout uses light text on an opaque dark panel for contrast against both paving and grass. It does not take mouse focus. It shows layout ID, district at the ground focus, camera position and span, road count and validation, building counts per district, FPS, visible draws and triangles. It updates four times per second only while open. Use the Godot log for detailed validation errors.

F10 adds a building overlay: one footprint outline and a two-line `id` / `plot · facing · rotation°` label per placement, plus red highlighting for placements whose validation failed. District labels gain `N buildings` counts. Yellow rectangles show the unobstructed 2 m entrance corridors. None of this is visible by default. The home span was tightened from 280 to 160 m for the connected town; full-map review uses 310 m at (0,0), and manual zoom-out remains available.
