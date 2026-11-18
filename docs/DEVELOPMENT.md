# Development on Windows

Use Node.js 22 LTS (22.12 or newer), Docker Desktop in Linux container mode, and the standard Godot 4.7 build. Open PowerShell at the repo root. Check `node --version`, `npm --version`, and `docker compose version`. Start Docker Desktop and wait until `docker info` reports a server. Copy `.env.example` to `.env` before starting Compose. The example passwords are for local development only.

| Command | Purpose |
| --- | --- |
| `npm install` | Install all workspaces, generate Prisma Client, and build shared contracts. Use `npm ci` to reproduce the lockfile. |
| `npm run infra:up` | Start PostgreSQL and Redis and wait for both health checks. |
| `npm run db:migrate` | Apply committed migrations. Does not seed. |
| `npm run db:seed` | Ensure the default world exists. Safe to rerun. |
| `npm run dev:server` | Start only the API in watch mode. |
| `npm run dev:web` | Start only Vite and its development API proxy. |
| `npm run dev` | Start both apps; stop both with Ctrl+C. |
| `npm run test` | Unit and contract tests, no services needed. |
| `npm run test:integration` | Real dependency tests; use a migrated, seeded development database, never production. |
| `npm run lint` | Check TypeScript and TSX sources. |
| `npm run typecheck` | Check each workspace in strict TypeScript mode. |
| `npm run build` | Build shared, backend, and web in order. |
| `npm run infra:down` | Stop and remove the containers, keeping data volumes. |

After starting all components, check the endpoints independently:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health
Invoke-RestMethod http://127.0.0.1:3000/ready
Invoke-RestMethod http://127.0.0.1:3000/api/world/status
Invoke-RestMethod http://127.0.0.1:5173/api/world/status
```

## Godot

In the Godot Project Manager, select **Import**, open `game/godot/project.godot`, and press F5 in the editor. The Compatibility renderer uses a 1920×1080 base resolution and scales to the game window. No assets or plugins are required. The placeholder scene remains usable if the status check fails. Restart the scene to repeat the status check.

For a headless check without opening the editor (Godot 4.7.2 on `PATH`, or the `_console.exe` on Windows):

```powershell
godot --headless --path game/godot --import
godot --headless --path game/godot --script res://tests/offline_smoke.gd
```

## Troubleshooting

- **Port 5432 or 6379 in use:** Change `POSTGRES_PORT` or `REDIS_PORT` in `.env` and update the matching port in `DATABASE_URL` or `REDIS_URL`. The container ports stay unchanged. Apply the changes with `npm run infra:up`.
- **Port 3000 in use:** Change `PORT` in `.env`, restart both apps, and point Godot at the updated backend URL. The web proxy uses `PORT` by default or `WEB_API_TARGET` when set. If 5173 is in use, free it or change the Vite `server.port` setting in `apps/web/vite.config.ts`.
- **`/health` is OK, `/ready` is 503:** Check `docker compose ps`, the two URLs, and `docker compose logs postgres redis`. Healthy containers do not prove your application credentials work.
- **World status is unavailable but `/ready` is OK:** Run `npm run db:migrate` and `npm run db:seed`. Readiness checks connectivity, not schema or seed state.
- **Changed the example database password after first boot:** PostgreSQL does not change existing credentials when the container restarts. Use the existing local credentials or change the role password. `docker compose down -v` deletes WorldPulse's local PostgreSQL and Redis data; only use it for a deliberate reset.
- **Dependency install or Prisma Client fails:** Verify the Node major version. Rerun `npm ci` from the repository root and ensure the registry is reachable. Do not disable validation or CI checks.

For a production web build, serve `apps/web/dist` with a same-origin `/api` proxy to Fastify. Vite's preview is for local verification, not production hosting.
