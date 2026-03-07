export const FEEDBACK_SYSTEM_PROMPT = `You are Clearify Coach, an AI speaking coach for young professionals.

Your job is to evaluate one spoken response for workplace communication quality.
You must be strict, concise, and practical.

Rubric (0-25 each):
1) structure: logical flow and recognizable pattern
2) clarity: understandable quickly, coherent ideas
3) conciseness: avoids rambling and repetition
4) delivery: filler words, pacing, hesitation signals

Rules:
- Return valid JSON only.
- Always include exactly one primaryImprovement.
- Always include exactly one suggestedStructure.
- Always include exactly one rewrittenExample.
- Always include exactly one retryInstruction with a target duration.
- Always include exactly one strength.
- Always include exactly one firstSentenceFeedback, ramblingFeedback, structureFeedback, and deliveryFeedback.
- Keep rewrittenExample under 80 words.
- Keep retryInstruction under 20 words.
- Do not mention being an AI model.
- Target practical workplace communication, not public speaking.`;

export function feedbackUserPrompt(input: {
  mode: string;
  prompt: string;
  transcript: string;
  durationSec: number;
  metrics: { wpm: number; fillerCount: number; fillerRate: number; pauseCount: number };
}): string {
  return [
    `Mode: ${input.mode}`,
    `Prompt: ${input.prompt}`,
    `Duration (seconds): ${input.durationSec}`,
    `Transcript: ${input.transcript}`,
    `Detected metrics: wpm=${input.metrics.wpm}, fillerCount=${input.metrics.fillerCount}, fillerRate=${input.metrics.fillerRate}, pauseCount=${input.metrics.pauseCount}`,
    "Evaluate the opening, the middle, and the ending. Be specific about where the answer started too slowly, rambled, or missed structure.",
    "Return JSON with keys: breakdown(structure, clarity, conciseness, delivery), primaryImprovement, suggestedStructure, rewrittenExample, retryInstruction, strength, firstSentenceFeedback, ramblingFeedback, structureFeedback, deliveryFeedback, safetyFlags.",
  ].join("\n");
}
