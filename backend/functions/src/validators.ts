import { z } from "zod";

const scenarioModeSchema = z.enum(["interview", "workplace", "customer"]);
const sessionTypeSchema = z.enum(["full", "quick"]);

export const startSessionSchema = z.object({
  uid: z.string().min(1),
  mode: scenarioModeSchema,
  scenarioId: z.string().min(1),
  scenarioPrompt: z.string().min(4).optional(),
  sessionType: sessionTypeSchema,
  timezone: z.string().optional(),
});

export const analyzeRepSchema = z.object({
  uid: z.string().min(1),
  sessionId: z.string().min(1),
  repIndex: z.number().int().min(1).max(3),
  mode: scenarioModeSchema,
  prompt: z.string().min(4),
  audioStoragePath: z.string().min(4),
  durationSec: z.number().min(1).max(180),
});

export const completeSessionSchema = z.object({
  uid: z.string().min(1),
  sessionId: z.string().min(1),
  timezone: z.string().optional(),
});

export const feedbackSchema = z.object({
  breakdown: z.object({
    structure: z.number(),
    clarity: z.number(),
    conciseness: z.number(),
    delivery: z.number(),
  }),
  primaryImprovement: z.string().min(4),
  suggestedStructure: z.string().min(4),
  rewrittenExample: z.string().min(4),
  retryInstruction: z.string().min(4),
  strength: z.string().min(4),
  firstSentenceFeedback: z.string().min(4),
  ramblingFeedback: z.string().min(4),
  structureFeedback: z.string().min(4),
  deliveryFeedback: z.string().min(4),
  safetyFlags: z.array(z.string()).default([]),
});

export const syncEntitlementSchema = z.object({
  uid: z.string().min(1),
  status: z.enum(["active", "inactive"]),
  tier: z.enum(["free", "pro"]),
  productId: z.string().optional(),
  transactionId: z.string().optional(),
  originalTransactionId: z.string().optional(),
  purchasedAt: z.string().nullable().optional(),
  expiresAt: z.string().nullable().optional(),
});
