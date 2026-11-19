# Art Direction: v0.1A.2

WorldPulse uses a low-poly town-diorama look. Rooflines, vehicle profiles, tree canopies, and clothing colors should identify objects from an elevated three-quarter view before fine details are visible. The reference is the Kenney gallery in Godot at 1920 x 1080 with the Compatibility renderer. This is an asset direction, not a final city layout or camera specification.

## Shapes, color, and lighting

- Keep residential rooflines distinct from the flatter commercial masses. Use tree canopies to break up the built silhouettes rather than adding facade detail everywhere.
- Use muted greens for ground and foliage, neutral road surfaces, and brighter colors on occasional roofs, vehicles, and clothes. The A2 road override fixes the pale lavender asphalt from A1 with charcoal asphalt and a darker shoulder. Markings, curbs and sidewalks still read separately.
- Use the source color maps and simple, mostly matte materials. Keep pack originals intact and make tint or material changes in project-owned overrides.
- Day is the neutral material check. Evening tests warm low-angle light. Night should preserve readable silhouettes without looking like dusk, but the revised preset still loses detail on shadowed roads, trees and the citizen. Night is not approved. These are discrete inspection presets, not a time-of-day system.
- Use the protagonists for animated citizen reference. Keep Idle subtle, use the project-authored Walk for ordinary walking, and keep the source Run distinct. The static minis are a proportion comparison, not a replacement rig. Walk contact sheets were reviewed; transitions still need visual acceptance in motion.

## Scale and placement

Use 1 Godot unit = 1 metre. Compare new assets with the 1.8 m human in `ScaleReference.tscn` before approving placement. Use a ground-level origin and document orientation corrections outside the source model. The measured straight road is 8 m square after scaling; that is a tile measurement, not a block-size decision. Use the manifest scales and simple collision proxies documented in the [asset catalog](ASSET-CATALOG.md).

The `AssetGallery` comparison groups Residential F, Commercial K, four connected 8 m straight road tiles, a sedan and a protagonist with two trees: `tree_default` at a 0.8 instance scale factor and `tree_small` at 0.95. These factors apply only to the comparison, not to the manifest scales. Use the grouping to judge how the canopies break up building silhouettes and how the sedan and protagonist read beside the road. The seven imported Nature Kit trees are enough for the initial library; bushes, rocks and grass are available in the source archive but are not imported.

Before approving additions, inspect them at scene scale under all three gallery presets, check their ground contact and alignment with nearby assets, and run the [QA scenes](ASSET-QA.md). Texture memory budgets and production LODs are not set by this slice.
