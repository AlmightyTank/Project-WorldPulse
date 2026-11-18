import { WorldStatusSchema, type WorldStatus } from '@worldpulse/shared';

export const statusPath = '/api/world/status';

export type StatusResult =
  | { kind: 'ready'; world: WorldStatus }
  | { kind: 'offline' }
  | { kind: 'unreachable' }
  | { kind: 'http-error'; status: number }
  | { kind: 'invalid-response' };

export async function readWorldStatus(signal: AbortSignal): Promise<StatusResult> {
  try {
    const response = await fetch(statusPath, {
      cache: 'no-store',
      headers: { Accept: 'application/json' },
      signal,
    });

    if (!response.ok) {
      if (response.headers.get('X-WorldPulse-Proxy-Error') === 'upstream-unreachable') {
        return { kind: 'unreachable' };
      }
      return { kind: 'http-error', status: response.status };
    }

    const payload: unknown = await response.json();
    const result = WorldStatusSchema.safeParse(payload);
    return result.success ? { kind: 'ready', world: result.data } : { kind: 'invalid-response' };
  } catch (error) {
    return { kind: error instanceof SyntaxError ? 'invalid-response' : 'unreachable' };
  }
}
