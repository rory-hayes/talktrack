export type ScenarioMode = "interview" | "workplace" | "customer";
export type SessionType = "full" | "quick";

export interface ScoreBreakdown {
  structure: number;
  clarity: number;
  conciseness: number;
  delivery: number;
}

export interface SpeechMetrics {
  wpm: number;
  fillerCount: number;
  fillerRate: number;
  pauseCount: number;
}

export type PacingBand = "slow" | "steady" | "fast";

export interface CoachingSignals {
  strength: string;
  firstSentenceFeedback: string;
  ramblingFeedback: string;
  structureFeedback: string;
  deliveryFeedback: string;
  fillerHotspot: string;
  pacingBand: PacingBand;
  openingOverlong: boolean;
  weakConclusion: boolean;
}

export interface FeedbackPayload {
  workClarityScore: number;
  breakdown: ScoreBreakdown;
  speechMetrics: SpeechMetrics;
  primaryImprovement: string;
  suggestedStructure: string;
  rewrittenExample: string;
  retryInstruction: string;
  safetyFlags: string[];
}

export interface AnalyzeRepResponse extends FeedbackPayload, CoachingSignals {
  transcript: string;
}

export interface StartSessionRequest {
  uid: string;
  mode: ScenarioMode;
  scenarioId: string;
  scenarioPrompt?: string;
  sessionType: SessionType;
  timezone?: string;
}

export interface StartSessionResponse {
  allowed: boolean;
  reason: string | null;
  sessionId: string | null;
  remainingFullSessionsThisWeek: number;
  streakState: {
    current: number;
    best: number;
    lastPracticeDate: string | null;
  };
}

export interface AnalyzeRepRequest {
  uid: string;
  sessionId: string;
  repIndex: number;
  mode: ScenarioMode;
  prompt: string;
  audioStoragePath: string;
  durationSec: number;
}

export interface CompleteSessionRequest {
  uid: string;
  sessionId: string;
  timezone?: string;
}

export interface CompleteSessionResponse {
  sessionScore: number;
  improvementDelta: number;
  streakUpdated: {
    current: number;
    best: number;
  };
  trendSnapshot: {
    avgScore7d: number;
    fillerRate7d: number;
    concisenessAvg7d: number;
    structureAvg7d: number;
  };
}

export interface SyncEntitlementRequest {
  uid: string;
  status: "active" | "inactive";
  tier: "free" | "pro";
  productId?: string;
  transactionId?: string;
  originalTransactionId?: string;
  purchasedAt?: string | null;
  expiresAt?: string | null;
}

export interface SyncEntitlementResponse {
  tier: "free" | "pro";
  status: "active" | "inactive";
}

export interface UserProfile {
  uid: string;
  locale: string;
  planTier: "free" | "pro";
  onboardingGoalMode: ScenarioMode;
  onboardingCompletedAt?: string | FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp | null;
  selectedRoleTrack?: string | null;
  email?: string | null;
  displayName?: string | null;
  streakCurrent: number;
  streakBest: number;
  lastPracticeDate: string | null;
  createdAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
}
