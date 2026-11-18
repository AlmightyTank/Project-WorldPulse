import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { HealthStatusSchema, WorldStatusSchema, type WorldStatus } from '@worldpulse/shared';
import { buildApp } from '../../src/app.js';

const worldStatus = {
  worldId: 'test-world',
  worldName: 'Persisted World',
  simulationStatus: 'not_started',
  citizens: 0,
  worldTime: null,
} satisfies WorldStatus;

const checkDatabase = vi.fn<() => Promise<unknown>>();
const pingRedis = vi.fn<() => Promise<string>>();
const readWorldStatus = vi.fn<() => Promise<WorldStatus | null>>();
let app: ReturnType<typeof buildApp>;

beforeEach(() => {
  checkDatabase.mockReset().mockResolvedValue(undefined);
  pingRedis.mockReset().mockResolvedValue('PONG');
  readWorldStatus.mockReset().mockResolvedValue(worldStatus);
  app = buildApp({ checkDatabase, pingRedis, readWorldStatus });
});

afterEach(() => app.close());

describe('GET /health', () => {
  it('reports liveness without touching either dependency', async () => {
    const response = await app.inject('/health');
    expect(response.statusCode).toBe(200);
    expect(HealthStatusSchema.parse(response.json())).toEqual({
      status: 'ok', service: 'worldpulse-server',
    });
    expect(checkDatabase).not.toHaveBeenCalled();
    expect(pingRedis).not.toHaveBeenCalled();
    expect(readWorldStatus).not.toHaveBeenCalled();
  });
});

describe('GET /ready', () => {
  it('requires both dependencies', async () => {
    const response = await app.inject('/ready');
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ready', checks: { database: true, redis: true } });
  });

  it.each([[true, false], [false, true], [false, false]])(
    'reports 503 with database=%j and redis=%j', async (database, redis) => {
      if (!database) checkDatabase.mockRejectedValue(new Error('database password'));
      if (!redis) pingRedis.mockRejectedValue(new Error('redis password'));
      const response = await app.inject('/ready');
      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({ status: 'not_ready', checks: { database, redis } });
    },
  );

  it('returns 503 when a dependency never responds', async () => {
    pingRedis.mockImplementation(() => new Promise(() => {}));
    const response = await app.inject('/ready');
    expect(response.statusCode).toBe(503);
    expect(response.json()).toMatchObject({ checks: { database: true, redis: false } });
  });
});

describe('GET /api/world/status', () => {
  it('uses the shared status contract', async () => {
    const response = await app.inject('/api/world/status');
    expect(response.statusCode).toBe(200);
    expect(WorldStatusSchema.parse(response.json())).toEqual(worldStatus);
    expect(pingRedis).not.toHaveBeenCalled();
  });

  it('returns 404 instead of inventing a world when the seed is missing', async () => {
    readWorldStatus.mockResolvedValue(null);
    const response = await app.inject('/api/world/status');
    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual({ error: 'World not initialized' });
  });

  it('hides database errors from clients', async () => {
    readWorldStatus.mockRejectedValue(new Error('postgresql://user:password@localhost/world'));
    const response = await app.inject('/api/world/status');
    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({ error: 'Internal server error' });
  });
});
