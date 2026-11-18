import { Redis } from 'ioredis';

export function createRedis(url: string): Redis {
  return new Redis(url, {
    connectTimeout: 1000,
    commandTimeout: 1000,
    enableOfflineQueue: false,
    maxRetriesPerRequest: 0,
  });
}
