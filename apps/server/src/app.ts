import Fastify, { type FastifyError } from 'fastify';
import { HealthStatusSchema, type WorldStatus } from '@worldpulse/shared';

interface AppDependencies {
  checkDatabase: () => Promise<unknown>;
  pingRedis: () => Promise<string>;
  readWorldStatus: () => Promise<WorldStatus | null>;
}

async function probe(check: () => Promise<unknown>): Promise<boolean> {
  let timeout: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      Promise.resolve().then(check).then(() => true, () => false),
      new Promise<false>((resolve) => { timeout = setTimeout(() => resolve(false), 2000); }),
    ]);
  } finally {
    clearTimeout(timeout);
  }
}

export function buildApp(deps: AppDependencies, logger = false) {
  const app = Fastify({ logger });

  app.get('/health', async () => HealthStatusSchema.parse({
    status: 'ok',
    service: 'worldpulse-server',
  }));

  app.get('/ready', async (_request, reply) => {
    const [database, redis] = await Promise.all([
      probe(deps.checkDatabase),
      probe(async () => {
        if (await deps.pingRedis() !== 'PONG') throw new Error('Unexpected Redis ping response');
      }),
    ]);
    const checks = { database, redis };
    const ready = database && redis;
    return reply.code(ready ? 200 : 503).send({ status: ready ? 'ready' : 'not_ready', checks });
  });

  app.setErrorHandler((error: FastifyError, request, reply) => {
    const statusCode = error.statusCode && error.statusCode < 500 ? error.statusCode : 500;
    request.log.error({ err: error }, 'Request failed');
    return reply.code(statusCode).send({
      error: statusCode === 500 ? 'Internal server error' : error.message,
    });
  });

  app.get('/api/world/status', async (request, reply) => {
    try {
      const status = await deps.readWorldStatus();
      if (status) return status;
      return reply.code(404).send({ error: 'World not initialized' });
    } catch {
      request.log.error('World status read failed');
      return reply.code(500).send({ error: 'Internal server error' });
    }
  });

  return app;
}
