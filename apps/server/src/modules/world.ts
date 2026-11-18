import { WorldStatusSchema, type WorldStatus } from '@worldpulse/shared';
import type { PrismaClient } from '@prisma/client';

export const DEFAULT_WORLD_ID = 'world-001';

export function createWorldStatusReader(prisma: PrismaClient): () => Promise<WorldStatus | null> {
  return async () => {
    const world = await prisma.world.findUnique({
      where: { id: DEFAULT_WORLD_ID },
      select: { id: true, name: true, status: true },
    });
    if (!world) return null;

    return WorldStatusSchema.parse({
      worldId: world.id,
      worldName: world.name,
      simulationStatus: world.status,
      citizens: 0,
      worldTime: null,
    });
  };
}
