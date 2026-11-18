import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readWorldStatus, statusPath } from '../src/world-status.ts';

const world = {
  worldId: 'test-world',
  worldName: 'Test World',
  simulationStatus: 'not_started',
  citizens: 0,
  worldTime: null,
};

test('reads the v0.1A contract and distinguishes failed responses', async (t) => {
  const signal = new AbortController().signal;
  const fetchMock = t.mock.method(globalThis, 'fetch');

  fetchMock.mock.mockImplementationOnce(async () => Response.json(world));
  assert.deepEqual(await readWorldStatus(signal), { kind: 'ready', world });
  assert.equal(fetchMock.mock.calls[0]?.arguments[0], statusPath);

  fetchMock.mock.mockImplementationOnce(async () => new Response(null, { status: 503 }));
  assert.deepEqual(await readWorldStatus(signal), { kind: 'http-error', status: 503 });

  fetchMock.mock.mockImplementationOnce(async () => new Response(null, {
    status: 502,
    headers: { 'X-WorldPulse-Proxy-Error': 'upstream-unreachable' },
  }));
  assert.deepEqual(await readWorldStatus(signal), { kind: 'unreachable' });

  fetchMock.mock.mockImplementationOnce(async () => Response.json({ citizens: 0 }));
  assert.deepEqual(await readWorldStatus(signal), { kind: 'invalid-response' });

  fetchMock.mock.mockImplementationOnce(async () => new Response('<html>'));
  assert.deepEqual(await readWorldStatus(signal), { kind: 'invalid-response' });

  fetchMock.mock.mockImplementationOnce(async () => { throw new TypeError('Network failure'); });
  assert.deepEqual(await readWorldStatus(signal), { kind: 'unreachable' });
});
