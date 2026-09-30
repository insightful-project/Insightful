import { z } from 'zod';

export const zodSchema = z.object({
    token: z.string().optional(),
    objective: z.string().min(1, 'Objective required'),
    state: z.record(z.unknown()).optional(),
    questions: z.record(z.union([
        z.object({ type: z.literal('noul'), instructions: z.string(), true: z.string(), false: z.string() }),
        z.object({ type: z.literal('choice'), instructions: z.string(), criteria: z.record(z.string()) }),
        z.object({ type: z.literal('score'), instructions: z.string(), criteria: z.array(z.string()) }),
    ])).optional(),
    thresholds: z.object({
        act: z.number().min(0).max(1).optional(),
        reroute: z.number().min(0).max(1).optional(),
    }).optional(),
    model: z.string().optional(),
    timestamp: z.number().optional(),
});