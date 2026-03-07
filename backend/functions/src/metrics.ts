import { FILLER_WORDS } from "./constants";
import { CoachingSignals, PacingBand, SpeechMetrics } from "./types";

function countFillers(text: string): number {
  const lowered = text.toLowerCase();
  let total = 0;
  for (const phrase of FILLER_WORDS) {
    const safe = phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const matches = lowered.match(new RegExp(`\\b${safe}\\b`, "g"));
    total += matches?.length ?? 0;
  }
  return total;
}

function sentenceParts(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function pauseEstimate(text: string): number {
  const punctuationPauses = (text.match(/[.,;:!?]/g) ?? []).length;
  const conjunctionPauses = (text.match(/\b(and|but|so|because|then)\b/gi) ?? []).length;
  return Math.max(0, Math.round((punctuationPauses * 0.7) + (conjunctionPauses * 0.3)));
}

export function computeSpeechMetrics(transcript: string, durationSec: number): SpeechMetrics {
  const words = transcript.trim().split(/\s+/).filter(Boolean);
  const wordCount = words.length;
  const fillerCount = countFillers(transcript);
  const wpm = durationSec > 0 ? Math.round((wordCount / durationSec) * 60) : 0;
  const fillerRate = wordCount > 0 ? Number(((fillerCount / wordCount) * 100).toFixed(1)) : 0;

  return {
    wpm,
    fillerCount,
    fillerRate,
    pauseCount: pauseEstimate(transcript),
  };
}

export function pacingBandForWpm(wpm: number): PacingBand {
  if (wpm < 105) {
    return "slow";
  }
  if (wpm > 165) {
    return "fast";
  }
  return "steady";
}

export function fillerHotspotForTranscript(transcript: string): string {
  const words = transcript.trim().split(/\s+/).filter(Boolean);
  if (words.length < 9) {
    return "No clear filler cluster detected.";
  }

  const third = Math.max(1, Math.ceil(words.length / 3));
  const segments = [
    { label: "opening", text: words.slice(0, third).join(" ") },
    { label: "middle", text: words.slice(third, third * 2).join(" ") },
    { label: "close", text: words.slice(third * 2).join(" ") },
  ];

  const counts = segments.map((segment) => ({
    label: segment.label,
    count: countFillers(segment.text),
  }));

  const top = counts.reduce((best, current) => (current.count > best.count ? current : best), counts[0]);
  if (top.count === 0) {
    return "No clear filler cluster detected.";
  }

  return `Most filler words showed up in the ${top.label}.`;
}

export function transcriptFlags(
  transcript: string,
  metrics: SpeechMetrics,
): Pick<CoachingSignals, "fillerHotspot" | "pacingBand" | "openingOverlong" | "weakConclusion"> {
  const sentences = sentenceParts(transcript);
  const firstSentence = sentences[0] ?? transcript;
  const lastSentence = sentences[sentences.length - 1] ?? transcript;
  const openingWords = firstSentence.split(/\s+/).filter(Boolean).length;
  const weakConclusion = !/\b(result|impact|outcome|next|therefore|so|finally|because)\b/i.test(lastSentence);

  return {
    fillerHotspot: fillerHotspotForTranscript(transcript),
    pacingBand: pacingBandForWpm(metrics.wpm),
    openingOverlong: openingWords > 20,
    weakConclusion,
  };
}
