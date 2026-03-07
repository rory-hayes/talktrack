import { MAX_SCORE, MIN_SCORE } from "./constants";
import { fillerHotspotForTranscript, pacingBandForWpm, transcriptFlags } from "./metrics";
import { CoachingSignals, FeedbackPayload, ScoreBreakdown, SpeechMetrics } from "./types";

function clamp(value: number): number {
  if (!Number.isFinite(value)) {
    return MIN_SCORE;
  }
  return Math.max(MIN_SCORE, Math.min(MAX_SCORE, Math.round(value)));
}

export function normalizeBreakdown(input: ScoreBreakdown): ScoreBreakdown {
  return {
    structure: clamp(input.structure),
    clarity: clamp(input.clarity),
    conciseness: clamp(input.conciseness),
    delivery: clamp(input.delivery),
  };
}

export function workClarityScore(breakdown: ScoreBreakdown): number {
  const normalized = normalizeBreakdown(breakdown);
  return normalized.structure + normalized.clarity + normalized.conciseness + normalized.delivery;
}

export function fallbackFeedback(
  transcript: string,
  metrics: SpeechMetrics,
): Omit<FeedbackPayload, "speechMetrics"> & CoachingSignals {
  const deliveryPenalty = Math.min(12, Math.round(metrics.fillerRate));
  const concisenessPenalty = metrics.wpm > 170 ? 8 : metrics.wpm < 90 ? 6 : 3;
  const flags = transcriptFlags(transcript, metrics);

  const breakdown = normalizeBreakdown({
    structure: 16,
    clarity: 17,
    conciseness: 20 - concisenessPenalty,
    delivery: 20 - deliveryPenalty,
  });

  return {
    workClarityScore: workClarityScore(breakdown),
    breakdown,
    primaryImprovement: "Lead with your main point in the first sentence.",
    suggestedStructure: "Context -> Action -> Result",
    rewrittenExample:
      "We had a reporting issue before release. I traced it to a broken query and fixed it the same day. The release shipped on time.",
    retryInstruction: "Retry in 40-60 seconds with one clear result metric.",
    strength: "You already have useful detail. The answer just needs a cleaner headline.",
    firstSentenceFeedback: flags.openingOverlong
      ? "Your opening sentence is too long. State the main point faster."
      : "Your opening is understandable, but it should land the main point sooner.",
    ramblingFeedback:
      metrics.wpm > 165
        ? "You moved too fast and stacked ideas together. Trim side details and pause between points."
        : "A few details wandered away from the main point. Keep each sentence tied to the outcome.",
    structureFeedback:
      "Use one clear pattern from start to finish. A simple Context -> Action -> Result structure will be stronger.",
    deliveryFeedback:
      metrics.fillerRate > 4
        ? "Filler words are distracting. Slow down slightly and leave short pauses instead."
        : "Delivery is steady, but you can sound stronger by ending with a crisp result.",
    fillerHotspot: fillerHotspotForTranscript(transcript),
    pacingBand: pacingBandForWpm(metrics.wpm),
    openingOverlong: flags.openingOverlong,
    weakConclusion: flags.weakConclusion,
    safetyFlags: [],
  };
}
