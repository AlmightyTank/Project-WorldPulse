# Local infrastructure

The root `docker-compose.yml` is the source of truth for PostgreSQL and Redis. Run the root `infra:up` and `infra:down` scripts. Compose publishes loopback-only ports and retains the named volumes on shutdown. No application containers are needed in v0.1A.
