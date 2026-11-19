# Roadmap

| Slice | Scope | Status |
| --- | --- | --- |
| v0.1A | Project Foundation | Implemented; hosted CI run pending |
| v0.1A.1 | Kenney Asset Foundation | Implemented with known gaps; hosted CI pending |
| v0.1A.2 | Kenney Asset Refinement | Locally complete; hosted CI unverified |
| v0.1B | World Scene & Visual Foundation | Not started; follows v0.1A.2 |
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

v0.1A is code-complete and was verified locally as recorded below. Completion still requires a passing hosted `CI` run.

## Current verification status

- `origin` is `https://github.com/AlmightyTank/Project-WorldPulse.git`. Local `main` is one commit ahead of `origin/main`: `160982b` (`Build WorldPulse foundation and asset pipeline`) follows `c9d4b11` (`Initial commit`).
- Authenticated GitHub CLI reads succeeded. `gh run list` returned no runs and `gh workflow list --all` listed no workflows. Hosted CI remains unverified. No commit or push was made during this review.
- The final local rerun passed lint, typecheck, all 17 tests, build and asset validation. Godot passed headless import, offline smoke, the asset test, all four development scene starts, the control self-test and all 244 headless Walk checks. The GPU Walk review passed 1,656 checks, and native Windows-message character control tests passed 64 checks.
- The local CI definition adds the headless Walk checker and `CHARACTER_SELF_TEST=1`, with `SCRIPT ERROR:`/`ERROR:` log scans. It preserves the prior checks. These changes have not run on GitHub Actions.
- The local Docker daemon was not running, so integration tests could not be rerun. The historical passing result below is unchanged.

## v0.1A.1 asset foundation

The Kenney library, import pipeline, development scenes and local checks are in place. See [Asset Import](ASSET-IMPORT.md), [Asset Catalog](ASSET-CATALOG.md), [Asset Licenses](ASSET-LICENSES.md), [Art Direction](ART-DIRECTION.md), and [QA results](ASSET-QA.md).

The baseline protagonist pack has no Walk clip (Run is its locomotion clip), Foliage Pack is 2D-only and excluded from the 3D import, and the asphalt needed visual tuning. No city, AI, traffic simulation or broadcast work was started.

## v0.1A.2 asset refinement

The gallery comparison places representative buildings, roads, a vehicle, trees and a protagonist together for scale and material review. The seven imported Nature Kit trees cover the initial tree library; bushes, rocks and grass are available in the same source archive but are not imported. A project-owned road override fixes the lavender asphalt without changing the Kenney originals.

The original in-place Walk works on all four protagonists through `CharacterVisualState`. No new asset pack or external animation was imported. Walk contact sheets were reviewed, automated animation and UI checks passed, and the final GPU population run used Walk on all 30 protagonists. See [QA results](ASSET-QA.md).

The closeout gallery comparison hides the catalog and uses a cool ambient fill at night so road markings and the citizen remain visible. Gallery input checks passed for comparison/reset, lighting, grid, orbit, pan, zoom and asset selection. Walk now matches 1.256618 m/s reference travel; moving contact and in-place transition reviews passed on all four rigs. The local asset-refinement scope is complete. Hosted CI remains unverified; slopes, turns, variable-speed physics and transition foot locking are not part of this slice. See [Asset QA](ASSET-QA.md) for evidence and limits.

## v0.1A verification record (historical)

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
