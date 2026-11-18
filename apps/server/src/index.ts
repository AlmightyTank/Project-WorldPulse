import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createPrisma } from './db.js';
import { createWorldStatusReader } from './modules/world.js';
import { createRedis } from './redis.js';

async function main(): Promise<void> {
  const config = loadConfig();
  const prisma = createPrisma(config.DATABASE_URL);
  const redis = createRedis(config.REDIS_URL);
  redis.on('error', () => console.error('Redis connection unavailable.'));
  const app = buildApp({
    checkDatabase: () => prisma.$queryRaw`SELECT 1`,
    pingRedis: () => redis.ping(),
    readWorldStatus: createWorldStatusReader(prisma),
  }, true);
  app.addHook('onClose', async () => {
    redis.disconnect();
    await prisma.$disconnect();
  });
  for (const signal of ['SIGINT', 'SIGTERM'] as const) {
    process.once(signal, () => {
      app.close().catch(() => { process.exitCode = 1; });
    });
  }
  try {
    await app.listen({ host: config.HOST, port: config.PORT });
  } catch (error) {
    await app.close();
    throw error;
  }
}

main().catch(() => {
  console.error('Server startup failed. Check configuration and port availability.');
  process.exitCode = 1;
});
