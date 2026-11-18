import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../src/config.js';

const env = {
  DATABASE_URL: 'postgresql://worldpulse:password@localhost/worldpulse',
  REDIS_URL: 'redis://localhost:6379',
};

describe('loadConfig', () => {
  it('provides default bind options and accepts overrides', () => {
    expect(loadConfig(env)).toEqual({ ...env, HOST: '127.0.0.1', PORT: 3000 });
    expect(loadConfig({ ...env, HOST: '0.0.0.0', PORT: '4321' })).toEqual({
      ...env,
      HOST: '0.0.0.0',
      PORT: 4321,
    });
  });

  it('requires both dependency URLs', () => {
    expect(() => loadConfig({})).toThrow(/DATABASE_URL, REDIS_URL/);
  });

  it.each(['', 'oops', '2.5', '65536'])('rejects invalid port %j', (PORT) => {
    expect(() => loadConfig({ ...env, PORT })).toThrow(/PORT/);
  });

  it('rejects the wrong protocols without disclosing credentials', () => {
    expect(() => loadConfig({
      DATABASE_URL: 'http://user:secret@localhost/database',
      REDIS_URL: 'https://user:secret@localhost',
    })).toThrow('Invalid server configuration: DATABASE_URL, REDIS_URL');
  });
});
