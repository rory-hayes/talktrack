import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "./db";
import { FREE_FULL_SESSIONS_PER_WEEK, FREE_QUICK_DRILLS_PER_DAY, MAX_FULL_REPS, QUICK_REPS } from "./constants";
import {
  CompleteSessionRequest,
  CompleteSessionResponse,
  SessionType,
  StartSessionRequest,
  StartSessionResponse,
  UserProfile,
} from "./types";
import { dateDiffDays, dayKey, weekKey } from "./time";

async function getOrCreateUser(uid: string): Promise<UserProfile> {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();

  if (snap.exists) {
    return snap.data() as UserProfile;
  }

  const now = FieldValue.serverTimestamp();
  const created: UserProfile = {
    uid,
    locale: "en",
    planTier: "free",
    onboardingGoalMode: "workplace",
    streakCurrent: 0,
    streakBest: 0,
    lastPracticeDate: null,
    createdAt: now,
    updatedAt: now,
  };

  await ref.set(created);
  return created;
}

async function getPlanTier(uid: string): Promise<"free" | "pro"> {
  const snap = await db.collection("entitlements").doc(uid).get();
  if (!snap.exists) {
    return "free";
  }
  const data = snap.data() as { tier?: string; status?: string };
  if (data?.status === "active" && data?.tier === "pro") {
    return "pro";
  }
  return "free";
}

function expectedRepCount(sessionType: SessionType): number {
  return sessionType === "full" ? MAX_FULL_REPS : QUICK_REPS;
}

export async function startSession(request: StartSessionRequest): Promise<StartSessionResponse> {
  const now = new Date();
  const timezone = request.timezone ?? "UTC";
  const currentWeekKey = weekKey(now, timezone);
  const currentDayKey = dayKey(now, timezone);

  const user = await getOrCreateUser(request.uid);
  const planTier = await getPlanTier(request.uid);

  let allowed = true;
  let reason: string | null = null;
  let remainingFullSessionsThisWeek = Number.MAX_SAFE_INTEGER;

  if (planTier === "free") {
    if (request.sessionType === "full") {
      const usageRef = db.collection("usage_weekly").doc(`${request.uid}_${currentWeekKey}`);
      const usage = await usageRef.get();
      const fullSessions = (usage.data()?.fullSessions as number | undefined) ?? 0;
      remainingFullSessionsThisWeek = Math.max(0, FREE_FULL_SESSIONS_PER_WEEK - fullSessions);

      if (fullSessions >= FREE_FULL_SESSIONS_PER_WEEK) {
        allowed = false;
        reason = "free_full_session_limit_reached";
      }
    }

    if (request.sessionType === "quick") {
      const progressRef = db.collection("progress_daily").doc(`${request.uid}_${currentDayKey}`);
      const progress = await progressRef.get();
      const quickDrills = (progress.data()?.quickDrillCount as number | undefined) ?? 0;
      if (quickDrills >= FREE_QUICK_DRILLS_PER_DAY) {
        allowed = false;
        reason = "free_quick_drill_limit_reached";
      }
      const usageRef = db.collection("usage_weekly").doc(`${request.uid}_${currentWeekKey}`);
      const usage = await usageRef.get();
      const fullSessions = (usage.data()?.fullSessions as number | undefined) ?? 0;
      remainingFullSessionsThisWeek = Math.max(0, FREE_FULL_SESSIONS_PER_WEEK - fullSessions);
    }
  } else {
    remainingFullSessionsThisWeek = 999;
  }

  if (!allowed) {
    return {
      allowed,
      reason,
      sessionId: null,
      remainingFullSessionsThisWeek,
      streakState: {
        current: user.streakCurrent,
        best: user.streakBest,
        lastPracticeDate: user.lastPracticeDate,
      },
    };
  }

  const sessionRef = db.collection("sessions").doc();
  await sessionRef.set({
    id: sessionRef.id,
    uid: request.uid,
    mode: request.mode,
    scenarioId: request.scenarioId,
    scenarioPrompt: request.scenarioPrompt ?? null,
    type: request.sessionType,
    expectedRepCount: expectedRepCount(request.sessionType),
    repCount: 0,
    status: "active",
    startedAt: FieldValue.serverTimestamp(),
    completedAt: null,
    finalScore: null,
    improvementDelta: null,
    timezone,
  });

  if (planTier === "free" && request.sessionType === "full") {
    const usageRef = db.collection("usage_weekly").doc(`${request.uid}_${currentWeekKey}`);
    await db.runTransaction(async (tx) => {
      const usageSnap = await tx.get(usageRef);
      const fullSessions = (usageSnap.data()?.fullSessions as number | undefined) ?? 0;
      tx.set(
        usageRef,
        {
          uid: request.uid,
          weekKey: currentWeekKey,
          fullSessions: fullSessions + 1,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    remainingFullSessionsThisWeek = Math.max(0, remainingFullSessionsThisWeek - 1);
  }

  return {
    allowed: true,
    reason: null,
    sessionId: sessionRef.id,
    remainingFullSessionsThisWeek,
    streakState: {
      current: user.streakCurrent,
      best: user.streakBest,
      lastPracticeDate: user.lastPracticeDate,
    },
  };
}

async function computeTrend(uid: string): Promise<CompleteSessionResponse["trendSnapshot"]> {
  const querySnap = await db
    .collection("progress_daily")
    .where("uid", "==", uid)
    .orderBy("date", "desc")
    .limit(7)
    .get();

  if (querySnap.empty) {
    return {
      avgScore7d: 0,
      fillerRate7d: 0,
      concisenessAvg7d: 0,
      structureAvg7d: 0,
    };
  }

  let scoreSum = 0;
  let fillerSum = 0;
  let concisenessSum = 0;
  let structureSum = 0;

  querySnap.docs.forEach((doc) => {
    const data = doc.data();
    scoreSum += Number(data.avgScore ?? 0);
    fillerSum += Number(data.avgFillerRate ?? 0);
    concisenessSum += Number(data.concisenessAvg ?? 0);
    structureSum += Number(data.structureAvg ?? 0);
  });

  const count = querySnap.docs.length;
  return {
    avgScore7d: Number((scoreSum / count).toFixed(1)),
    fillerRate7d: Number((fillerSum / count).toFixed(1)),
    concisenessAvg7d: Number((concisenessSum / count).toFixed(1)),
    structureAvg7d: Number((structureSum / count).toFixed(1)),
  };
}

function updateStreakState(input: { lastPracticeDate: string | null; currentDayKey: string; currentStreak: number; bestStreak: number }) {
  if (!input.lastPracticeDate) {
    return { current: 1, best: Math.max(1, input.bestStreak) };
  }

  if (input.lastPracticeDate === input.currentDayKey) {
    return {
      current: input.currentStreak,
      best: Math.max(input.bestStreak, input.currentStreak),
    };
  }

  const diff = dateDiffDays(input.lastPracticeDate, input.currentDayKey);
  if (diff === 1) {
    const current = input.currentStreak + 1;
    return { current, best: Math.max(input.bestStreak, current) };
  }

  return { current: 1, best: Math.max(input.bestStreak, 1) };
}

export async function completeSession(request: CompleteSessionRequest): Promise<CompleteSessionResponse> {
  const sessionRef = db.collection("sessions").doc(request.sessionId);
  const sessionSnap = await sessionRef.get();

  if (!sessionSnap.exists) {
    throw new Error("session_not_found");
  }

  const session = sessionSnap.data() as {
    uid: string;
    type: SessionType;
    timezone?: string;
  };

  if (session.uid !== request.uid) {
    throw new Error("session_not_owned_by_user");
  }

  const repsSnap = await sessionRef.collection("reps").orderBy("repIndex", "asc").get();
  if (repsSnap.empty) {
    throw new Error("session_has_no_reps");
  }

  const scores = repsSnap.docs.map((doc) => Number(doc.data().score ?? 0));
  const finalScore = scores[scores.length - 1];
  const firstScore = scores[0];
  const improvementDelta = finalScore - firstScore;

  const avgScore = Number((scores.reduce((a, b) => a + b, 0) / scores.length).toFixed(1));
  const fillerAvg = Number(
    (
      repsSnap.docs.reduce((acc, doc) => acc + Number(doc.data().speechMetrics?.fillerRate ?? 0), 0) / repsSnap.docs.length
    ).toFixed(1),
  );

  const concisenessAvg = Number(
    (
      repsSnap.docs.reduce((acc, doc) => acc + Number(doc.data().breakdown?.conciseness ?? 0), 0) / repsSnap.docs.length
    ).toFixed(1),
  );

  const structureAvg = Number(
    (
      repsSnap.docs.reduce((acc, doc) => acc + Number(doc.data().breakdown?.structure ?? 0), 0) / repsSnap.docs.length
    ).toFixed(1),
  );

  const now = new Date();
  const timezone = request.timezone ?? session.timezone ?? "UTC";
  const today = dayKey(now, timezone);

  const userRef = db.collection("users").doc(request.uid);
  const userSnap = await userRef.get();
  const user = (userSnap.data() as UserProfile | undefined) ?? {
    streakCurrent: 0,
    streakBest: 0,
    lastPracticeDate: null,
  };

  const streak = updateStreakState({
    lastPracticeDate: user.lastPracticeDate ?? null,
    currentDayKey: today,
    currentStreak: user.streakCurrent ?? 0,
    bestStreak: user.streakBest ?? 0,
  });

  await sessionRef.set(
    {
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
      finalScore,
      improvementDelta,
      repCount: repsSnap.docs.length,
    },
    { merge: true },
  );

  const progressRef = db.collection("progress_daily").doc(`${request.uid}_${today}`);
  const incrementQuickDrill = session.type === "quick" ? 1 : 0;
  const incrementFullSession = session.type === "full" ? 1 : 0;

  await db.runTransaction(async (tx) => {
    const currentProgressSnap = await tx.get(progressRef);
    const current = currentProgressSnap.data() as Record<string, unknown> | undefined;

    const sessionsCompleted = Number(current?.sessionsCompleted ?? 0) + 1;
    const quickDrillCount = Number(current?.quickDrillCount ?? 0) + incrementQuickDrill;
    const fullSessionCount = Number(current?.fullSessionCount ?? 0) + incrementFullSession;

    const prevAvgScore = Number(current?.avgScore ?? 0);
    const prevAvgFillerRate = Number(current?.avgFillerRate ?? 0);
    const prevConciseness = Number(current?.concisenessAvg ?? 0);
    const prevStructure = Number(current?.structureAvg ?? 0);

    const nextAvgScore = Number((((prevAvgScore * (sessionsCompleted - 1)) + avgScore) / sessionsCompleted).toFixed(1));
    const nextAvgFiller = Number((((prevAvgFillerRate * (sessionsCompleted - 1)) + fillerAvg) / sessionsCompleted).toFixed(1));
    const nextConciseness = Number((((prevConciseness * (sessionsCompleted - 1)) + concisenessAvg) / sessionsCompleted).toFixed(1));
    const nextStructure = Number((((prevStructure * (sessionsCompleted - 1)) + structureAvg) / sessionsCompleted).toFixed(1));

    tx.set(
      progressRef,
      {
        uid: request.uid,
        date: today,
        sessionsCompleted,
        quickDrillCount,
        fullSessionCount,
        avgScore: nextAvgScore,
        avgFillerRate: nextAvgFiller,
        concisenessAvg: nextConciseness,
        structureAvg: nextStructure,
        streakCurrent: streak.current,
        streakBest: streak.best,
        latestSessionScore: finalScore,
        latestImprovementDelta: improvementDelta,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tx.set(
      userRef,
      {
        streakCurrent: streak.current,
        streakBest: streak.best,
        lastPracticeDate: today,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  const trendSnapshot = await computeTrend(request.uid);

  return {
    sessionScore: finalScore,
    improvementDelta,
    streakUpdated: {
      current: streak.current,
      best: streak.best,
    },
    trendSnapshot,
  };
}
