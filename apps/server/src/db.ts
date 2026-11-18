import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';

export function createPrisma(connectionString: string): PrismaClient {
  const adapter = new PrismaPg({
    connectionString,
    connectionTimeoutMillis: 1000,
    statement_timeout: 1000,
    query_timeout: 1500,
  });
  return new PrismaClient({ adapter });
}
