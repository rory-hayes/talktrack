import cors from "cors";
import express, { NextFunction, Request, Response } from "express";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

import { db, storage } from "./db";
import { analyzeAudioResponse } from "./openaiClient";
import { completeSession, startSession } from "./sessionService";
import { SyncEntitlementResponse } from "./types";
import { analyzeRepSchema, completeSessionSchema, startSessionSchema, syncEntitlementSchema } from "./validators";

export const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: "2mb" }));

interface AuthedRequest extends Request {
  uid?: string;
}

async function authMiddleware(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith("Bearer ")) {
      res.status(401).json({ error: "missing_auth_token" });
      return;
    }
    const token = header.replace("Bearer ", "").trim();
    const decoded = await getAuth().verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch (error) {
    logger.error("Auth failed", error);
    res.status(401).json({ error: "invalid_auth_token" });
  }
}

app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true, service: "clearify-functions" });
});

app.post("/startSession", authMiddleware, async (req: AuthedRequest, res: Response) => {
  const parsed = startSessionSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", issues: parsed.error.flatten() });
    return;
  }

  if (parsed.data.uid !== req.uid) {
    res.status(403).json({ error: "uid_mismatch" });
    return;
  }

  try {
    logger.info("startSession.request", {
      uid: parsed.data.uid,
      mode: parsed.data.mode,
      scenarioId: parsed.data.scenarioId,
      sessionType: parsed.data.sessionType,
    });
    const result = await startSession(parsed.data);
    logger.info("startSession.success", {
      uid: parsed.data.uid,
      sessionId: result.sessionId,
      allowed: result.allowed,
      reason: result.reason,
    });
    res.status(200).json(result);
  } catch (error) {
    logger.error("startSession.failed", {
      uid: parsed.data.uid,
      scenarioId: parsed.data.scenarioId,
      error,
    });
    res.status(500).json({ error: "start_session_failed" });
  }
});

app.post("/analyzeRep", authMiddleware, async (req: AuthedRequest, res: Response) => {
  const parsed = analyzeRepSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", issues: parsed.error.flatten() });
    return;
  }

  if (parsed.data.uid !== req.uid) {
    res.status(403).json({ error: "uid_mismatch" });
    return;
  }

  const payload = parsed.data;

  try {
    logger.info("analyzeRep.request", {
      uid: payload.uid,
      sessionId: payload.sessionId,
      repIndex: payload.repIndex,
      mode: payload.mode,
    });
    const sessionRef = db.collection("sessions").doc(payload.sessionId);
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      res.status(404).json({ error: "session_not_found" });
      return;
    }

    const session = sessionSnap.data() as { uid: string; expectedRepCount: number; repCount?: number; status?: string };
    if (session.uid !== payload.uid) {
      res.status(403).json({ error: "session_not_owned_by_user" });
      return;
    }

    if (session.status === "completed") {
      res.status(409).json({ error: "session_already_completed" });
      return;
    }

    if (payload.repIndex > session.expectedRepCount) {
      res.status(400).json({ error: "rep_index_exceeds_expected_reps" });
      return;
    }

    const { transcript, feedback } = await analyzeAudioResponse({
      mode: payload.mode,
      prompt: payload.prompt,
      audioStoragePath: payload.audioStoragePath,
      durationSec: payload.durationSec,
    });

    const repId = `rep-${payload.repIndex}`;
    await sessionRef.collection("reps").doc(repId).set({
      repId,
      repIndex: payload.repIndex,
      prompt: payload.prompt,
      transcript,
      durationSec: payload.durationSec,
      score: feedback.workClarityScore,
      breakdown: feedback.breakdown,
      speechMetrics: feedback.speechMetrics,
      feedback: {
        primaryImprovement: feedback.primaryImprovement,
        suggestedStructure: feedback.suggestedStructure,
        rewrittenExample: feedback.rewrittenExample,
        retryInstruction: feedback.retryInstruction,
        strength: feedback.strength,
        firstSentenceFeedback: feedback.firstSentenceFeedback,
        ramblingFeedback: feedback.ramblingFeedback,
        structureFeedback: feedback.structureFeedback,
        deliveryFeedback: feedback.deliveryFeedback,
        fillerHotspot: feedback.fillerHotspot,
        pacingBand: feedback.pacingBand,
        openingOverlong: feedback.openingOverlong,
        weakConclusion: feedback.weakConclusion,
      },
      safetyFlags: feedback.safetyFlags,
      createdAt: FieldValue.serverTimestamp(),
    });

    await sessionRef.set(
      {
        repCount: Math.max(payload.repIndex, session.repCount ?? 0),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      await storage.bucket().file(payload.audioStoragePath).delete({ ignoreNotFound: true });
    } catch (deleteError) {
      logger.warn("audio_cleanup_failed", deleteError);
    }

    logger.info("analyzeRep.success", {
      uid: payload.uid,
      sessionId: payload.sessionId,
      repIndex: payload.repIndex,
      score: feedback.workClarityScore,
    });

    res.status(200).json({
      transcript,
      ...feedback,
    });
  } catch (error) {
    logger.error("analyzeRep.failed", {
      uid: payload.uid,
      sessionId: payload.sessionId,
      repIndex: payload.repIndex,
      error,
    });
    res.status(500).json({ error: "analyze_rep_failed" });
  }
});

app.post("/completeSession", authMiddleware, async (req: AuthedRequest, res: Response) => {
  const parsed = completeSessionSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", issues: parsed.error.flatten() });
    return;
  }

  if (parsed.data.uid !== req.uid) {
    res.status(403).json({ error: "uid_mismatch" });
    return;
  }

  try {
    logger.info("completeSession.request", {
      uid: parsed.data.uid,
      sessionId: parsed.data.sessionId,
    });
    const result = await completeSession(parsed.data);
    logger.info("completeSession.success", {
      uid: parsed.data.uid,
      sessionId: parsed.data.sessionId,
      sessionScore: result.sessionScore,
      improvementDelta: result.improvementDelta,
    });
    res.status(200).json(result);
  } catch (error) {
    logger.error("completeSession.failed", {
      uid: parsed.data.uid,
      sessionId: parsed.data.sessionId,
      error,
    });
    res.status(500).json({ error: "complete_session_failed" });
  }
});

app.post("/syncEntitlement", authMiddleware, async (req: AuthedRequest, res: Response) => {
  const parsed = syncEntitlementSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "invalid_request", issues: parsed.error.flatten() });
    return;
  }

  if (parsed.data.uid !== req.uid) {
    res.status(403).json({ error: "uid_mismatch" });
    return;
  }

  try {
    logger.info("syncEntitlement.request", {
      uid: parsed.data.uid,
      status: parsed.data.status,
      tier: parsed.data.tier,
      productId: parsed.data.productId ?? null,
    });

    const entitlement: SyncEntitlementResponse = {
      tier: parsed.data.status === "active" ? parsed.data.tier : "free",
      status: parsed.data.status,
    };

    await db.collection("entitlements").doc(parsed.data.uid).set(
      {
        uid: parsed.data.uid,
        tier: entitlement.tier,
        status: entitlement.status,
        productId: parsed.data.productId ?? null,
        transactionId: parsed.data.transactionId ?? null,
        originalTransactionId: parsed.data.originalTransactionId ?? null,
        purchasedAt: parsed.data.purchasedAt ?? null,
        expiresAt: parsed.data.expiresAt ?? null,
        source: "storekit-client-verified",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await db.collection("users").doc(parsed.data.uid).set(
      {
        planTier: entitlement.tier,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info("syncEntitlement.success", {
      uid: parsed.data.uid,
      status: entitlement.status,
      tier: entitlement.tier,
    });
    res.status(200).json(entitlement);
  } catch (error) {
    logger.error("syncEntitlement.failed", {
      uid: parsed.data.uid,
      error,
    });
    res.status(500).json({ error: "sync_entitlement_failed" });
  }
});

export const api = onRequest(
  {
    cors: true,
    region: "us-central1",
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  app,
);
