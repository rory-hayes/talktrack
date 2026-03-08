import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const firestoreState = vi.hoisted(() => {
  const collections = {
    users: new Map<string, Record<string, unknown>>(),
    entitlements: new Map<string, Record<string, unknown>>(),
    usage_weekly: new Map<string, Record<string, unknown>>(),
    progress_daily: new Map<string, Record<string, unknown>>(),
    sessions: new Map<string, Record<string, unknown>>(),
    reps: new Map<string, Map<string, Record<string, unknown>>>(),
  };
  let sessionCounter = 0;

  function reset() {
    Object.values(collections).forEach((collection) => collection.clear());
    sessionCounter = 0;
  }

  function clone<T>(value: T): T {
    return JSON.parse(JSON.stringify(value));
  }

  function docSnapshot<T extends Record<string, unknown>>(collection: Map<string, T>, id: string) {
    return {
      exists: collection.has(id),
      data: () => {
        const value = collection.get(id);
        return value ? clone(value) : undefined;
      },
    };
  }

  function applySet(
    collection: Map<string, Record<string, unknown>>,
    id: string,
    data: Record<string, unknown>,
    options?: { merge?: boolean },
  ) {
    if (options?.merge) {
      collection.set(id, { ...(collection.get(id) ?? {}), ...clone(data) });
      return;
    }
    collection.set(id, clone(data));
  }

  function repCollection(sessionId: string) {
    return {
      doc(repId: string) {
        return {
          id: repId,
          async set(data: Record<string, unknown>, options?: { merge?: boolean }) {
            const reps = collections.reps.get(sessionId) ?? new Map<string, Record<string, unknown>>();
            applySet(reps, repId, data, options);
            collections.reps.set(sessionId, reps);
          },
        };
      },
      orderBy(field: string, direction: "asc" | "desc") {
        return {
          async get() {
            const reps = Array.from(collections.reps.get(sessionId)?.values() ?? []);
            const docs = reps
              .sort((lhs, rhs) => {
                const left = Number(lhs[field] ?? 0);
                const right = Number(rhs[field] ?? 0);
                return direction === "asc" ? left - right : right - left;
              })
              .map((rep) => ({
                data: () => clone(rep),
              }));

            return {
              empty: docs.length === 0,
              docs,
            };
          },
        };
      },
    };
  }

  type RootCollectionName = "users" | "entitlements" | "usage_weekly" | "progress_daily" | "sessions";

  function collection(name: RootCollectionName) {
    const records = collections[name];

    return {
      doc(id?: string) {
        const resolvedID = id ?? `session-${++sessionCounter}`;
        return {
          id: resolvedID,
          async get() {
            return docSnapshot(records, resolvedID);
          },
          async set(data: Record<string, unknown>, options?: { merge?: boolean }) {
            applySet(records, resolvedID, data, options);
          },
          collection(subcollection: string) {
            if (name !== "sessions" || subcollection !== "reps") {
              throw new Error(`Unexpected subcollection: ${name}/${subcollection}`);
            }
            return repCollection(resolvedID);
          },
        };
      },
      where(field: string, operator: string, value: unknown) {
        if (operator !== "==") {
          throw new Error(`Unexpected operator: ${operator}`);
        }

        let filtered = Array.from(records.values()).filter((record) => record[field] === value);
        return {
          orderBy(orderField: string, direction: "asc" | "desc") {
            filtered = filtered.sort((lhs, rhs) => {
              const left = String(lhs[orderField] ?? "");
              const right = String(rhs[orderField] ?? "");
              return direction === "asc" ? left.localeCompare(right) : right.localeCompare(left);
            });
            return {
              limit(limitCount: number) {
                return {
                  async get() {
                    const docs = filtered.slice(0, limitCount).map((record) => ({
                      data: () => clone(record),
                    }));
                    return {
                      empty: docs.length === 0,
                      docs,
                    };
                  },
                };
              },
            };
          },
        };
      },
    };
  }

  function seedRep(sessionId: string, repId: string, data: Record<string, unknown>) {
    const reps = collections.reps.get(sessionId) ?? new Map<string, Record<string, unknown>>();
    reps.set(repId, clone(data));
    collections.reps.set(sessionId, reps);
  }

  return {
    collections,
    reset,
    collection,
    seedRep,
  };
});

vi.mock("firebase-admin/firestore", () => ({
  FieldValue: {
    serverTimestamp: vi.fn(() => "SERVER_TIMESTAMP"),
  },
  Timestamp: {
    now: vi.fn(),
  },
}));

vi.mock("../src/db", () => ({
  db: {
    collection: firestoreState.collection,
    runTransaction: async (
      callback: (tx: {
        get: (ref: { get: () => Promise<unknown> }) => Promise<unknown>;
        set: (ref: { set: (data: Record<string, unknown>, options?: { merge?: boolean }) => Promise<void> }, data: Record<string, unknown>, options?: { merge?: boolean }) => Promise<void>;
      }) => Promise<void>,
    ) => callback({
      get: (ref) => ref.get(),
      set: (ref, data, options) => ref.set(data, options),
    }),
  },
}));

import { completeSession, startSession } from "../src/sessionService";

describe("sessionService quota accounting", () => {
  beforeEach(() => {
    firestoreState.reset();
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-03-07T12:00:00Z"));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("does not charge a free full session at start", async () => {
    const response = await startSession({
      uid: "user-123",
      mode: "workplace",
      scenarioId: "scenario-1",
      sessionType: "full",
      timezone: "UTC",
    });

    expect(response.allowed).toBe(true);
    expect(response.sessionId).toBeTruthy();
    expect(firestoreState.collections.usage_weekly.size).toBe(0);
  });

  it("charges a free full session once on completion and keeps completion idempotent", async () => {
    const start = await startSession({
      uid: "user-123",
      mode: "workplace",
      scenarioId: "scenario-1",
      sessionType: "full",
      timezone: "UTC",
    });

    const sessionId = start.sessionId!;
    firestoreState.seedRep(sessionId, "rep-1", {
      repIndex: 1,
      score: 68,
      speechMetrics: { fillerRate: 2.2 },
      breakdown: { conciseness: 17, structure: 18 },
    });
    firestoreState.seedRep(sessionId, "rep-2", {
      repIndex: 2,
      score: 75,
      speechMetrics: { fillerRate: 1.4 },
      breakdown: { conciseness: 19, structure: 20 },
    });

    const firstCompletion = await completeSession({
      uid: "user-123",
      sessionId,
      timezone: "UTC",
    });

    const weeklyUsage = firestoreState.collections.usage_weekly.get("user-123_2026-W10");
    const dailyProgress = firestoreState.collections.progress_daily.get("user-123_2026-03-07");

    expect(firstCompletion.sessionScore).toBe(75);
    expect(firstCompletion.improvementDelta).toBe(7);
    expect(weeklyUsage?.fullSessions).toBe(1);
    expect(dailyProgress?.fullSessionCount).toBe(1);
    expect(dailyProgress?.sessionsCompleted).toBe(1);

    const secondCompletion = await completeSession({
      uid: "user-123",
      sessionId,
      timezone: "UTC",
    });

    expect(secondCompletion.sessionScore).toBe(75);
    expect(secondCompletion.improvementDelta).toBe(7);
    expect(firestoreState.collections.usage_weekly.get("user-123_2026-W10")?.fullSessions).toBe(1);
    expect(firestoreState.collections.progress_daily.get("user-123_2026-03-07")?.sessionsCompleted).toBe(1);
  });
});
