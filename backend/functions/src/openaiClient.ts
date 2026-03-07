import { storage } from "./db";
import { DEFAULT_FEEDBACK_MODEL, DEFAULT_TRANSCRIBE_MODEL } from "./constants";
import { feedbackUserPrompt, FEEDBACK_SYSTEM_PROMPT } from "./prompts";
import { feedbackSchema } from "./validators";
import { computeSpeechMetrics, transcriptFlags } from "./metrics";
import { fallbackFeedback, normalizeBreakdown, workClarityScore } from "./scoring";
import { AnalyzeRepResponse, ScenarioMode } from "./types";

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

const FEEDBACK_JSON_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "breakdown",
    "primaryImprovement",
    "suggestedStructure",
    "rewrittenExample",
    "retryInstruction",
    "strength",
    "firstSentenceFeedback",
    "ramblingFeedback",
    "structureFeedback",
    "deliveryFeedback",
    "safetyFlags",
  ],
  properties: {
    breakdown: {
      type: "object",
      additionalProperties: false,
      required: ["structure", "clarity", "conciseness", "delivery"],
      properties: {
        structure: { type: "number" },
        clarity: { type: "number" },
        conciseness: { type: "number" },
        delivery: { type: "number" },
      },
    },
    primaryImprovement: { type: "string" },
    suggestedStructure: { type: "string" },
    rewrittenExample: { type: "string" },
    retryInstruction: { type: "string" },
    strength: { type: "string" },
    firstSentenceFeedback: { type: "string" },
    ramblingFeedback: { type: "string" },
    structureFeedback: { type: "string" },
    deliveryFeedback: { type: "string" },
    safetyFlags: {
      type: "array",
      items: { type: "string" },
    },
  },
};

interface ChatCompletionResponse {
  choices: Array<{ message: { content: string | null } }>;
}

async function requireApiKey(): Promise<string> {
  if (!OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not configured");
  }
  return OPENAI_API_KEY;
}

async function transcribeAudio(audioStoragePath: string): Promise<string> {
  const key = await requireApiKey();
  const bucket = storage.bucket();
  const file = bucket.file(audioStoragePath);
  const [bytes] = await file.download();
  const audioBytes = new Uint8Array(bytes);

  const form = new FormData();
  form.append("model", DEFAULT_TRANSCRIBE_MODEL);
  form.append("response_format", "json");
  form.append("file", new Blob([audioBytes], { type: "audio/m4a" }), "rep.m4a");

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
    },
    body: form,
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Transcription failed: ${response.status} ${body}`);
  }

  const parsed = (await response.json()) as { text?: string };
  if (!parsed.text || !parsed.text.trim()) {
    throw new Error("Transcription returned empty text");
  }
  return parsed.text.trim();
}

async function generateFeedback(input: {
  mode: ScenarioMode;
  prompt: string;
  transcript: string;
  durationSec: number;
}): Promise<Omit<AnalyzeRepResponse, "transcript" | "speechMetrics">> {
  const key = await requireApiKey();
  const metrics = computeSpeechMetrics(input.transcript, input.durationSec);
  const flags = transcriptFlags(input.transcript, metrics);

  const requestBody = {
    model: DEFAULT_FEEDBACK_MODEL,
    temperature: 0.2,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "clearify_feedback",
        strict: true,
        schema: FEEDBACK_JSON_SCHEMA,
      },
    },
    messages: [
      { role: "system", content: FEEDBACK_SYSTEM_PROMPT },
      {
        role: "user",
        content: feedbackUserPrompt({
          mode: input.mode,
          prompt: input.prompt,
          transcript: input.transcript,
          durationSec: input.durationSec,
          metrics,
        }),
      },
    ],
  };

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Feedback generation failed: ${response.status} ${body}`);
  }

  const parsed = (await response.json()) as ChatCompletionResponse;
  const content = parsed.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("Feedback generation returned empty content");
  }

  const json = JSON.parse(content);
  const validated = feedbackSchema.parse(json);
  const normalizedBreakdown = normalizeBreakdown(validated.breakdown);

  return {
    workClarityScore: workClarityScore(normalizedBreakdown),
    breakdown: normalizedBreakdown,
    primaryImprovement: validated.primaryImprovement,
    suggestedStructure: validated.suggestedStructure,
    rewrittenExample: validated.rewrittenExample,
    retryInstruction: validated.retryInstruction,
    strength: validated.strength,
    firstSentenceFeedback: validated.firstSentenceFeedback,
    ramblingFeedback: validated.ramblingFeedback,
    structureFeedback: validated.structureFeedback,
    deliveryFeedback: validated.deliveryFeedback,
    fillerHotspot: flags.fillerHotspot,
    pacingBand: flags.pacingBand,
    openingOverlong: flags.openingOverlong,
    weakConclusion: flags.weakConclusion,
    safetyFlags: validated.safetyFlags,
  };
}

export async function analyzeAudioResponse(input: {
  mode: ScenarioMode;
  prompt: string;
  audioStoragePath: string;
  durationSec: number;
}): Promise<{ transcript: string; feedback: Omit<AnalyzeRepResponse, "transcript"> }> {
  const transcript = await transcribeAudio(input.audioStoragePath);
  const speechMetrics = computeSpeechMetrics(transcript, input.durationSec);

  try {
    const aiFeedback = await generateFeedback({
      mode: input.mode,
      prompt: input.prompt,
      transcript,
      durationSec: input.durationSec,
    });

    return {
      transcript,
      feedback: {
        ...aiFeedback,
        speechMetrics,
      },
    };
  } catch (error) {
    const fallback = fallbackFeedback(transcript, speechMetrics);
    return {
      transcript,
      feedback: {
        ...fallback,
        speechMetrics,
      },
    };
  }
}
