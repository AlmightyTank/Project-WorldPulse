import { z } from 'zod';

export const SimulationStatusSchema = z.enum(['not_started']);
export type SimulationStatus = z.infer<typeof SimulationStatusSchema>;

export const SystemEventTypeSchema = z.enum(['world_initialized']);
export type SystemEventType = z.infer<typeof SystemEventTypeSchema>;

export const HealthStatusSchema = z.object({
  status: z.literal('ok'),
  service: z.literal('worldpulse-server'),
});
export type HealthStatus = z.infer<typeof HealthStatusSchema>;

export const WorldStatusSchema = z.object({
  worldId: z.string().min(1),
  worldName: z.string().min(1),
  simulationStatus: SimulationStatusSchema,
  citizens: z.number().int().nonnegative(),
  worldTime: z.iso.datetime().nullable(),
});
export type WorldStatus = z.infer<typeof WorldStatusSchema>;
