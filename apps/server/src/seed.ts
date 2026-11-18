import { loadConfig } from './config.js';
import { createPrisma } from './db.js';
import { seed } from './modules/seed.js';

async function main(): Promise<void> {
  const config = loadConfig();
  const prisma = createPrisma(config.DATABASE_URL);
  try {
    await seed(prisma);
    console.info('World seed complete.');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(() => {
  console.error('World seed failed. Check database connectivity and migrations.');
  process.exitCode = 1;
});
