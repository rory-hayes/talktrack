import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  verifyIdToken: vi.fn(),
  startSession: vi.fn(),
  completeSession: vi.fn(),
  analyzeAudioResponse: vi.fn(),
  dbCollection: vi.fn(),
  bucket: vi.fn(),
  file: vi.fn(),
  deleteFile: vi.fn(),
  loggerInfo: vi.fn(),
  loggerWarn: vi.fn(),
  loggerError: vi.fn(),
}));

vi.mock("firebase-functions/v2/https", () => ({
  onRequest: (_options: unknown, handler: unknown) => handler,
}));

vi.mock("firebase-functions", () => ({
  logger: {
    info: mocks.loggerInfo,
    warn: mocks.loggerWarn,
    error: mocks.loggerError,
  },
}));

vi.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    verifyIdToken: mocks.verifyIdToken,
  }),
}));

vi.mock("firebase-admin/firestore", () => ({
  FieldValue: {
    serverTimestamp: vi.fn(() => "SERVER_TIMESTAMP"),
  },
}));

vi.mock("../src/sessionService", () => ({
  startSession: mocks.startSession,
  completeSession: mocks.completeSession,
}));

vi.mock("../src/openaiClient", () => ({
  analyzeAudioResponse: mocks.analyzeAudioResponse,
}));

vi.mock("../src/db", () => ({
  db: {
    collection: mocks.dbCollection,
  },
  storage: {
    bucket: mocks.bucket,
  },
}));

import { app } from "../src/api";

function configureCollections(collections: Record<string, unknown>) {
  mocks.dbCollection.mockImplementation((name: string) => {
    const collection = collections[name];
    if (!collection) {
      throw new Error(`Unexpected collection: ${name}`);
    }
    return collection;
  });
}

function createSessionRef(sessionData: {
  uid: string;
  expectedRepCount: number;
  repCount?: number;
  status?: string;
} | null) {
  const repSet = vi.fn().mockResolvedValue(undefined);
  const repDoc = { set: repSet };
  const repCollection = {
    doc: vi.fn().mockReturnValue(repDoc),
  };
  const sessionSet = vi.fn().mockResolvedValue(undefined);
  const snapshot = sessionData === null ? {
    exists: false,
    data: () => undefined,
  } : {
    exists: true,
    data: () => sessionData,
  };

  const sessionRef = {
    get: vi.fn().mockResolvedValue(snapshot),
    collection: vi.fn().mockReturnValue(repCollection),
    set: sessionSet,
  };

  return { sessionRef, repSet, sessionSet, repCollection };
}

function createSettableDoc() {
  return {
    set: vi.fn().mockResolvedValue(undefined),
  };
}

function makeAnalyzeRepFeedback() {
  return {
    transcript: "I gave a focused update and ended with the blocker.",
    feedback: {
      workClarityScore: 82,
      breakdown: {
        structure: 21,
        clarity: 22,
        conciseness: 19,
        delivery: 20,
      },
      speechMetrics: {
        wpm: 132,
        fillerCount: 3,
        fillerRate: 2.1,
        pauseCount: 5,
      },
      primaryImprovement: "State the blocker one sentence earlier.",
      suggestedStructure: "Progress -> Blocker -> Next step",
      rewrittenExample: "Yesterday I finished the API wiring. Today I am validating the payloads. The current blocker is auth configuration.",
      retryInstruction: "Try again in 30 to 45 seconds and lead with the current status.",
      strength: "You stayed concrete.",
      firstSentenceFeedback: "The opening was clear.",
      ramblingFeedback: "The middle stayed concise.",
      structureFeedback: "Your answer followed a logical order.",
      deliveryFeedback: "The pace was steady.",
      fillerHotspot: "Two fillers appeared before the blocker.",
      pacingBand: "steady" as const,
      openingOverlong: false,
      weakConclusion: false,
      safetyFlags: [],
    },
  };
}

function authedPost(path: string, body: Record<string, unknown>, uid = "user-123") {
  mocks.verifyIdToken.mockResolvedValue({ uid });
  return request(app)
    .post(path)
    .set("Authorization", "Bearer token-123")
    .send(body);
}

beforeEach(() => {
  vi.clearAllMocks();

  mocks.bucket.mockReturnValue({
    file: mocks.file,
  });
  mocks.file.mockReturnValue({
    delete: mocks.deleteFile,
  });
  mocks.deleteFile.mockResolvedValue(undefined);

  mocks.dbCollection.mockImplementation((name: string) => {
    throw new Error(`Unexpected collection: ${name}`);
  });
});

describe("api routes", () => {
  describe("POST /startSession", () => {
    const validBody = {
      uid: "user-123",
      mode: "workplace",
      scenarioId: "scenario-1",
      sessionType: "full",
    };

    it("returns 401 when auth token is missing", async () => {
      const response = await request(app).post("/startSession").send(validBody);

      expect(response.status).toBe(401);
      expect(response.body).toEqual({ error: "missing_auth_token" });
    });

    it("returns 400 for malformed requests", async () => {
      const response = await authedPost("/startSession", {
        uid: "user-123",
      });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe("invalid_request");
      expect(mocks.startSession).not.toHaveBeenCalled();
    });

    it("returns 403 when the request uid does not match the token uid", async () => {
      const response = await authedPost("/startSession", validBody, "other-user");

      expect(response.status).toBe(403);
      expect(response.body).toEqual({ error: "uid_mismatch" });
      expect(mocks.startSession).not.toHaveBeenCalled();
    });

    it("returns a delegated allowed response", async () => {
      const result = {
        allowed: true,
        reason: null,
        sessionId: "session-123",
        remainingFullSessionsThisWeek: 2,
        streakState: {
          current: 4,
          best: 8,
          lastPracticeDate: "2026-03-06",
        },
      };
      mocks.startSession.mockResolvedValue(result);

      const response = await authedPost("/startSession", validBody);

      expect(response.status).toBe(200);
      expect(response.body).toEqual(result);
      expect(mocks.startSession).toHaveBeenCalledWith(validBody);
    });

    it("surfaces gated responses without rewriting the backend reason", async () => {
      const result = {
        allowed: false,
        reason: "free_full_session_limit_reached",
        sessionId: null,
        remainingFullSessionsThisWeek: 0,
        streakState: {
          current: 2,
          best: 5,
          lastPracticeDate: "2026-03-06",
        },
      };
      mocks.startSession.mockResolvedValue(result);

      const response = await authedPost("/startSession", validBody);

      expect(response.status).toBe(200);
      expect(response.body).toEqual(result);
    });

    it("returns 500 when session creation throws", async () => {
      mocks.startSession.mockRejectedValue(new Error("boom"));

      const response = await authedPost("/startSession", validBody);

      expect(response.status).toBe(500);
      expect(response.body).toEqual({ error: "start_session_failed" });
    });
  });

  describe("POST /analyzeRep", () => {
    const validBody = {
      uid: "user-123",
      sessionId: "session-123",
      repIndex: 1,
      mode: "workplace",
      prompt: "Give a quick project update",
      audioStoragePath: "tmp/user-123/audio.m4a",
      durationSec: 42,
    };

    it("returns 400 for malformed requests", async () => {
      const response = await authedPost("/analyzeRep", {
        uid: "user-123",
      });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe("invalid_request");
      expect(mocks.analyzeAudioResponse).not.toHaveBeenCalled();
    });

    it("returns 404 when the session does not exist", async () => {
      const { sessionRef } = createSessionRef(null);
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });

      const response = await authedPost("/analyzeRep", validBody);

      expect(response.status).toBe(404);
      expect(response.body).toEqual({ error: "session_not_found" });
    });

    it("returns 403 when the session belongs to another user", async () => {
      const { sessionRef } = createSessionRef({
        uid: "other-user",
        expectedRepCount: 3,
      });
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });

      const response = await authedPost("/analyzeRep", validBody);

      expect(response.status).toBe(403);
      expect(response.body).toEqual({ error: "session_not_owned_by_user" });
    });

    it("returns 409 when the session is already completed", async () => {
      const { sessionRef } = createSessionRef({
        uid: "user-123",
        expectedRepCount: 3,
        status: "completed",
      });
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });

      const response = await authedPost("/analyzeRep", validBody);

      expect(response.status).toBe(409);
      expect(response.body).toEqual({ error: "session_already_completed" });
    });

    it("returns 400 when repIndex exceeds the expected rep count", async () => {
      const { sessionRef } = createSessionRef({
        uid: "user-123",
        expectedRepCount: 1,
      });
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });

      const response = await authedPost("/analyzeRep", {
        ...validBody,
        repIndex: 2,
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({ error: "rep_index_exceeds_expected_reps" });
    });

    it("writes the rep, updates the session, and returns transcript plus feedback", async () => {
      const { sessionRef, repSet, sessionSet } = createSessionRef({
        uid: "user-123",
        expectedRepCount: 3,
        repCount: 0,
      });
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });
      const result = makeAnalyzeRepFeedback();
      mocks.analyzeAudioResponse.mockResolvedValue(result);

      const response = await authedPost("/analyzeRep", validBody);

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        transcript: result.transcript,
        ...result.feedback,
      });
      expect(mocks.analyzeAudioResponse).toHaveBeenCalledWith({
        mode: validBody.mode,
        prompt: validBody.prompt,
        audioStoragePath: validBody.audioStoragePath,
        durationSec: validBody.durationSec,
      });
      expect(repSet).toHaveBeenCalledWith(expect.objectContaining({
        repId: "rep-1",
        repIndex: 1,
        transcript: result.transcript,
        score: 82,
        createdAt: "SERVER_TIMESTAMP",
      }));
      expect(sessionSet).toHaveBeenCalledWith(expect.objectContaining({
        repCount: 1,
        updatedAt: "SERVER_TIMESTAMP",
      }), { merge: true });
      expect(mocks.bucket).toHaveBeenCalled();
      expect(mocks.file).toHaveBeenCalledWith(validBody.audioStoragePath);
      expect(mocks.deleteFile).toHaveBeenCalledWith({ ignoreNotFound: true });
    });

    it("still returns 200 when uploaded-audio cleanup fails", async () => {
      const { sessionRef } = createSessionRef({
        uid: "user-123",
        expectedRepCount: 3,
        repCount: 0,
      });
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });
      mocks.analyzeAudioResponse.mockResolvedValue(makeAnalyzeRepFeedback());
      mocks.deleteFile.mockRejectedValue(new Error("cleanup failed"));

      const response = await authedPost("/analyzeRep", validBody);

      expect(response.status).toBe(200);
      expect(mocks.loggerWarn).toHaveBeenCalled();
    });

    it("returns 500 when analysis fails", async () => {
      const { sessionRef } = createSessionRef({
        uid: "user-123",
        expectedRepCount: 3,
      });
      configureCollections({
        sessions: {
          doc: vi.fn().mockReturnValue(sessionRef),
        },
      });
      mocks.analyzeAudioResponse.mockRejectedValue(new Error("ai down"));

      const response = await authedPost("/analyzeRep", validBody);

      expect(response.status).toBe(500);
      expect(response.body).toEqual({ error: "analyze_rep_failed" });
    });
  });

  describe("POST /completeSession", () => {
    const validBody = {
      uid: "user-123",
      sessionId: "session-123",
    };

    it("returns 400 for malformed requests", async () => {
      const response = await authedPost("/completeSession", {
        uid: "user-123",
      });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe("invalid_request");
    });

    it("returns 403 when the request uid does not match the token uid", async () => {
      const response = await authedPost("/completeSession", validBody, "other-user");

      expect(response.status).toBe(403);
      expect(response.body).toEqual({ error: "uid_mismatch" });
      expect(mocks.completeSession).not.toHaveBeenCalled();
    });

    it("returns the delegated completion response", async () => {
      const result = {
        sessionScore: 84,
        improvementDelta: 11,
        streakUpdated: {
          current: 5,
          best: 9,
        },
        trendSnapshot: {
          avgScore7d: 78,
          fillerRate7d: 2.1,
          concisenessAvg7d: 18,
          structureAvg7d: 19,
        },
      };
      mocks.completeSession.mockResolvedValue(result);

      const response = await authedPost("/completeSession", validBody);

      expect(response.status).toBe(200);
      expect(response.body).toEqual(result);
      expect(mocks.completeSession).toHaveBeenCalledWith(validBody);
    });

    it("returns 500 when completion fails", async () => {
      mocks.completeSession.mockRejectedValue(new Error("boom"));

      const response = await authedPost("/completeSession", validBody);

      expect(response.status).toBe(500);
      expect(response.body).toEqual({ error: "complete_session_failed" });
    });
  });

  describe("POST /syncEntitlement", () => {
    const validBody = {
      uid: "user-123",
      status: "active",
      tier: "pro",
      productId: "clearify.pro.monthly",
      transactionId: "txn-123",
    };

    it("returns 400 for malformed requests", async () => {
      const response = await authedPost("/syncEntitlement", {
        uid: "user-123",
        status: "active",
      });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe("invalid_request");
    });

    it("returns 403 when the request uid does not match the token uid", async () => {
      const response = await authedPost("/syncEntitlement", validBody, "other-user");

      expect(response.status).toBe(403);
      expect(response.body).toEqual({ error: "uid_mismatch" });
    });

    it("writes active entitlements and mirrors the tier to the user record", async () => {
      const entitlementDoc = createSettableDoc();
      const userDoc = createSettableDoc();
      configureCollections({
        entitlements: {
          doc: vi.fn().mockReturnValue(entitlementDoc),
        },
        users: {
          doc: vi.fn().mockReturnValue(userDoc),
        },
      });

      const response = await authedPost("/syncEntitlement", validBody);

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        tier: "pro",
        status: "active",
      });
      expect(entitlementDoc.set).toHaveBeenCalledWith(expect.objectContaining({
        uid: "user-123",
        tier: "pro",
        status: "active",
        productId: "clearify.pro.monthly",
        transactionId: "txn-123",
        updatedAt: "SERVER_TIMESTAMP",
      }), { merge: true });
      expect(userDoc.set).toHaveBeenCalledWith(expect.objectContaining({
        planTier: "pro",
        updatedAt: "SERVER_TIMESTAMP",
      }), { merge: true });
    });

    it("returns free when an inactive entitlement is synced", async () => {
      const entitlementDoc = createSettableDoc();
      const userDoc = createSettableDoc();
      configureCollections({
        entitlements: {
          doc: vi.fn().mockReturnValue(entitlementDoc),
        },
        users: {
          doc: vi.fn().mockReturnValue(userDoc),
        },
      });

      const response = await authedPost("/syncEntitlement", {
        ...validBody,
        status: "inactive",
      });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        tier: "free",
        status: "inactive",
      });
      expect(userDoc.set).toHaveBeenCalledWith(expect.objectContaining({
        planTier: "free",
        updatedAt: "SERVER_TIMESTAMP",
      }), { merge: true });
    });

    it("returns 500 when entitlement writes fail", async () => {
      const entitlementDoc = {
        set: vi.fn().mockRejectedValue(new Error("db down")),
      };
      const userDoc = createSettableDoc();
      configureCollections({
        entitlements: {
          doc: vi.fn().mockReturnValue(entitlementDoc),
        },
        users: {
          doc: vi.fn().mockReturnValue(userDoc),
        },
      });

      const response = await authedPost("/syncEntitlement", validBody);

      expect(response.status).toBe(500);
      expect(response.body).toEqual({ error: "sync_entitlement_failed" });
      expect(userDoc.set).not.toHaveBeenCalled();
    });
  });
});
