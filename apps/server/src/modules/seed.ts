import type { PrismaClient } from '@prisma/client';
import { DEFAULT_WORLD_ID } from './world.js';

export const DEFAULT_WORLD_NAME = 'WorldPulse';

export async function seed(prisma: PrismaClient): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const { count } = await tx.world.createMany({
      data: { id: DEFAULT_WORLD_ID, name: DEFAULT_WORLD_NAME, status: 'not_started' },
      skipDuplicates: true,
    });
    if (count === 0) return;

    await tx.worldSettings.create({ data: { worldId: DEFAULT_WORLD_ID, settings: {} } });
    await tx.systemEvent.create({
      data: {
        worldId: DEFAULT_WORLD_ID,
        eventType: 'world_initialized',
        payload: { worldId: DEFAULT_WORLD_ID, worldName: DEFAULT_WORLD_NAME },
      },
    });
  });
}
