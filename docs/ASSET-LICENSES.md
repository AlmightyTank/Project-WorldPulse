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

## Rules

- Source only `https://kenney.nl/assets/<slug>`. No third-party re-hosts or asset sites.
- Never edit a licence file, and never delete a `LICENSE.txt` or `source.json`.
- Do not commit the downloaded archives. Download them from Kenney and keep them
  outside the repository; the importer reads those local files.
- Do not claim a pack that was not verified. If a download cannot be verified against
  its SHA-256, report it as blocked instead of importing it.
