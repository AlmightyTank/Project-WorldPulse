# Art Direction: v0.1A.1

WorldPulse uses a low-poly town-diorama look. Rooflines, vehicle profiles, tree canopies, and clothing colors should identify objects from an elevated three-quarter view before fine details are visible. The reference is the Kenney gallery in Godot at 1920×1080 with the Compatibility renderer. This is an asset direction, not a final city layout or camera specification.

## Shapes, color, and lighting

- Keep residential rooflines distinct from the flatter commercial masses. Use tree canopies to break up the built silhouettes rather than adding facade detail everywhere.
- Use muted greens for ground and foliage, neutral road surfaces, and brighter colors on occasional roofs, vehicles, and clothes. Keep lane markings and sidewalks distinct. The imported asphalt currently renders lighter and more lavender than the Kenney preview; review it in context before treating the palette as final.
- Use the source color maps and simple, mostly matte materials. Keep pack originals intact and make any later tint or material change in a project-owned override.
- Day is the neutral material check. Evening tests warm low-angle light, and night tests whether silhouettes remain readable with less light. The gallery presets are discrete inspection settings, not a time-of-day system.
- Use the protagonists for animated citizen reference. Keep Idle subtle; use the source Run loop for locomotion testing without presenting it as Walk. The static minis are a proportion comparison, not a replacement rig.

## Scale and placement

Use 1 Godot unit = 1 metre. Compare new assets with the 1.8 m human in `ScaleReference.tscn` before approving placement. Use a ground-level origin and document orientation corrections outside the source model. The measured straight road is 8 m square after scaling; that is a tile measurement, not a block-size decision. Use the manifest scales and simple collision proxies documented in the [asset catalog](ASSET-CATALOG.md).

Before approving additions, inspect them at scene scale under all three gallery presets, check their ground contact and alignment with nearby assets, and run the [QA scenes](ASSET-QA.md). Texture memory budgets and production LODs are not set by this slice.
