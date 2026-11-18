# Roadmap

| Slice | Scope | Status |
| --- | --- | --- |
| v0.1A | Project Foundation | Implemented; hosted CI run pending |
| v0.1A.1 | Kenney Asset Foundation | Implemented with known gaps; hosted CI pending |
| v0.1B | World Scene & Visual Foundation | Not started; follows v0.1A.1 |
| v0.1C | City layout and environment | Pending |
| v0.1D | Authoritative simulation engine and world clock | Pending |
| v0.2 | Citizens and basic participation | Pending |
| v0.3 | Jobs and economy | Pending |
| v0.4 | Inventory and property | Pending |
| v0.5 | World events and citizen website | Pending |
| v0.6 | Twitch adapter | Pending |
| v0.7 | Kick adapter and platform-specific interactions | Pending |
| v0.8 | B.O.B. virtual host | Pending |
| v0.9 | Operational resilience, moderation, and continuous broadcast tests | Pending |
| v1.0 | Persistent city and public livestream launch | Pending |

Later slices are planning placeholders, not current capabilities.

v0.1A is code-complete and locally verified. It is not marked complete yet: the hosted GitHub Actions run could not be executed because this checkout has no Git remote. Push the repository, confirm the `CI` workflow passes, then mark v0.1A complete. v0.1A.1 sits between v0.1A and v0.1B.

## v0.1A.1 asset foundation

The Kenney library, import pipeline, development scenes and local checks are in place. See [Asset Import](ASSET-IMPORT.md), [Asset Catalog](ASSET-CATALOG.md), [Asset Licenses](ASSET-LICENSES.md), [Art Direction](ART-DIRECTION.md), and [QA results](ASSET-QA.md).

Open items: the protagonist pack has no Walk clip (Run is the available locomotion clip), Foliage Pack is 2D-only and excluded from the 3D import, and road asphalt needs visual tuning. Hosted CI remains unverified because this checkout has no remote. No city, AI, traffic simulation or broadcast work was started.

## v0.1A verification record

Verified locally on Windows with Node 22.23.5, Docker Desktop, PostgreSQL 17 in Compose, and Godot 4.7.2:

| Check | Result |
| --- | --- |
| `npm ci` from the committed lockfile | Pass |
| `npm run lint` | Pass, no warnings |
| `npm run typecheck` | Pass for shared, server, and web |
| `npm run test` | Pass, server unit and web tests |
| `npm run test:integration` | Pass against migrated, seeded services |
| `npm run build` | Pass for all three workspaces |
| `npm run db:migrate` on a clean database | Pass |
| `npm run db:seed` twice | Pass, one world, one settings row, one event |
| `prisma migrate diff --exit-code` | Pass, no drift |
| `/health`, `/ready`, `/api/world/status` | Expected bodies and status codes |
| `/ready` with PostgreSQL stopped | 503, `database: false` |
| Web page with PostgreSQL stopped | Error state, then Refresh recovers |
| Godot import and offline smoke test | Pass |
| Hosted GitHub Actions | Not run, no remote |
