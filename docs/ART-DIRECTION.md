# Art Direction: v0.1A.2

WorldPulse uses a low-poly town-diorama look. Rooflines, vehicle profiles, tree canopies, and clothing colors should identify objects from an elevated three-quarter view before fine details are visible. The reference is the Kenney gallery in Godot at 1920 x 1080 with the Compatibility renderer. This is an asset direction, not a final city layout or camera specification.

## v0.1B-A district foundation

The independent World scene is a calm daylight town blockout: muted grass, charcoal Kenney roads and a warm sand-colored plaza as its focal point. ENERGY 1 / RHYTHM 2 / MOTION 1: shared streets connect adjoining blocks, while only camera input causes motion. Open space is intentional reservation for the next slice, not missing decorative population. The Greenbelt keeps a broad grass edge; no trees or buildings have been added.

Plot tints and the grid are hidden planning aids rather than broadcast decoration. The compact developer readout uses the engine's default sans-serif for legible diagnostics, with 14 px padding and white text on opaque #192322. District labels have dark outlines. No theme switch or animated UI is needed for this development-only view. The tighter default view prioritizes the plaza and connected town; use the full-map framing to see every terrain corner.

## v0.1B-B district composition

The connected town keeps the calm daylight palette with 48 measured buildings and targeted building-site surfaces. Terracotta, slate, muted olive and taupe residential roofs contrast with grey commercial shells. Stable placement IDs select roof-only atlas variants. A single 23 m records tower anchors the northern civic district. Building wrappers stay at scale 8; streets and block depths were redesigned around their measured bounds.

Entrances face their own adjacent street. Opposing rows face opposite streets, with a validated unobstructed 2 m entrance corridor for every building and at least 1 m road clearance. The middle residential block has homes on all four street edges and smaller rear spaces. Two western market entrances face the square, while a longer southern high-street shell breaks the repeated narrow-bay sequence. The 24 m square is framed by homes, shops and the civic hall rather than isolated between district loops.

The southern Greenbelt remains uninterrupted open land, not a decorated park. The WorldPulse Beacon retains its octagonal plinth, pale shaft and cyan crown, with a stronger 14 m silhouette. Source files remain unchanged; town instances use roof-only overrides documented in ASSET-LICENSES.md. Bounded lawn patches and warm neutral approach paving distinguish building sites from surrounding grass. One shop per market block was removed for a paved court, retaining 18 market buildings. There are no new fences, props, trees or people. Secondary doors are not individually paved; the surfaces follow designated facade corridors. The home camera uses a 160 m vertical span, with full-map framing retained. See the current image review and limitations in ASSET-QA.md.

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
