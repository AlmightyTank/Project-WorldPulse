import { z } from 'zod';

const ConfigSchema = z.object({
  DATABASE_URL: z.url({ protocol: /^postgres(?:ql)?$/ }),
  REDIS_URL: z.url({ protocol: /^rediss?$/ }),
  HOST: z.string().trim().min(1).default('127.0.0.1'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
});

export type Config = z.infer<typeof ConfigSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const result = ConfigSchema.safeParse(env);
  if (!result.success) {
    const keys = result.error.issues.map(({ path }) => path.join('.'));
    throw new Error(`Invalid server configuration: ${keys.join(', ')}`);
  }
  return result.data;
}
