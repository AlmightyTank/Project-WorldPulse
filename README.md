# WorldPulse

WorldPulse is the foundation for a persistent low-poly city that will eventually stream on Twitch and Kick. v0.1A provides a read-only status API, a web status page, and an offline-capable Godot placeholder. The simulation is **not running**: there are no citizens, world clock, livestream connections, or B.O.B. host yet.

The npm workspace contains a Node.js 22 TypeScript/Fastify server, a React/Vite site, and shared runtime contracts. PostgreSQL and Redis run through Docker Compose; Prisma manages migrations. The Godot 4.7 client runs separately and fails soft when the API is unreachable.

v0.1A includes the monorepo, migrations and seed, three HTTP endpoints, a status page with loading and error states, a placeholder Godot scene, tests, CI, and docs. Citizens, economy, property, events, livestream adapters, and B.O.B. belong to later slices.

## Run locally

Install Node.js 22 LTS (22.12 or newer), Docker Desktop with Linux containers, and Godot 4.7.2. In PowerShell, from the repo root:

```powershell
Copy-Item .env.example .env
npm install
npm run infra:up
npm run db:migrate
npm run db:seed
npm run dev
```

Open <http://127.0.0.1:5173>. The server defaults to `127.0.0.1:3000`:

| Endpoint | Meaning |
| --- | --- |
| `/health` | Fastify is alive. Does not probe storage. |
| `/ready` | PostgreSQL and Redis respond. Returns 503 when either probe fails. |
| `/api/world/status` | Reads the seeded world from PostgreSQL and reports `not_started`. |

For Godot, import `game/godot/project.godot` in the project manager and press **F6** with `scenes/Main.tscn` open, or **F5** to launch the main scene. The HUD checks `/api/world/status` and reports the result; with the backend stopped it logs `World status: offline` and keeps rendering.

## Verify and stop

```powershell
npm run lint
npm run typecheck
npm run test
npm run test:integration
npm run build
```

Godot's headless checks use the executable path explicitly:

```powershell
godot --headless --path game/godot --editor --import
godot --headless --path game/godot --script res://tests/offline_smoke.gd
```

Integration tests require migrated and seeded local services. Stop `npm run dev` with Ctrl+C, then run `npm run infra:down`. Named volumes are retained.

GitHub Actions runs the same npm checks against PostgreSQL and Redis service containers, validates that migrations match the schema, and imports and smoke-tests the Godot project. The workflow has not run on GitHub yet: this checkout has no remote. Run it once after pushing.

See [development](docs/DEVELOPMENT.md) for individual commands and port conflicts, [architecture](docs/ARCHITECTURE.md) for ownership boundaries, and the [roadmap](docs/ROADMAP.md) for verification status and future slices.
