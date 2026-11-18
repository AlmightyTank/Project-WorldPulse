import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { WorldStatusSchema } from '@worldpulse/shared';
import { buildApp } from '../../src/app.js';
import { loadConfig } from '../../src/config.js';
import { createPrisma } from '../../src/db.js';
import { seed, DEFAULT_WORLD_NAME } from '../../src/modules/seed.js';
import { createWorldStatusReader, DEFAULT_WORLD_ID } from '../../src/modules/world.js';
import { createRedis } from '../../src/redis.js';

if (process.env.DATABASE_URL === undefined) {
  process.loadEnvFile(new URL('../../../../.env', import.meta.url));
}

const config = loadConfig();
const prisma = createPrisma(config.DATABASE_URL);
const redis = createRedis(config.REDIS_URL);
const app = buildApp({
  checkDatabase: () => prisma.$queryRaw`SELECT 1`,
  pingRedis: () => redis.ping(),
  readWorldStatus: createWorldStatusReader(prisma),
});

beforeAll(async () => {
  if (redis.status === 'ready') return;
  await new Promise<void>((resolve, reject) => {
    redis.once('ready', resolve);
    redis.once('error', reject);
  });
});

afterAll(async () => {
  await app.close();
  redis.disconnect();
  await prisma.$disconnect();
});

describe('PostgreSQL and Redis', () => {
  it('reports ready against both services', async () => {
    const response = await app.inject('/ready');
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ready', checks: { database: true, redis: true } });
  });

  it('seeds one world, one settings row, and one initialization event across reruns', async () => {
    await seed(prisma);
    await seed(prisma);
    const world = await prisma.world.findUniqueOrThrow({
      where: { id: DEFAULT_WORLD_ID },
      include: { settings: true, events: { where: { eventType: 'world_initialized' } } },
    });
    expect(world).toMatchObject({
      id: DEFAULT_WORLD_ID,
      name: DEFAULT_WORLD_NAME,
      status: 'not_started',
      settings: { worldId: DEFAULT_WORLD_ID, settings: {} },
    });
    expect(world.events).toMatchObject([{ worldId: DEFAULT_WORLD_ID, eventType: 'world_initialized' }]);
  });

  it('reads the seeded world through the HTTP status API', async () => {
    await seed(prisma);
    const response = await app.inject('/api/world/status');
    expect(response.statusCode).toBe(200);
    expect(WorldStatusSchema.parse(response.json())).toEqual({
      worldId: DEFAULT_WORLD_ID,
      worldName: DEFAULT_WORLD_NAME,
      simulationStatus: 'not_started',
      citizens: 0,
      worldTime: null,
    });
  });
});
