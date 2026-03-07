export const FREE_FULL_SESSIONS_PER_WEEK = 3;
export const FREE_QUICK_DRILLS_PER_DAY = 1;

export const MAX_FULL_REPS = 3;
export const QUICK_REPS = 1;

export const MIN_SCORE = 0;
export const MAX_SCORE = 25;

export const DEFAULT_TRANSCRIBE_MODEL = process.env.OPENAI_TRANSCRIBE_MODEL ?? "gpt-4o-mini-transcribe";
export const DEFAULT_FEEDBACK_MODEL = process.env.OPENAI_FEEDBACK_MODEL ?? "gpt-4.1-mini";

export const FILLER_WORDS = [
  "um",
  "uh",
  "like",
  "you know",
  "sort of",
  "kind of",
  "actually",
  "basically",
  "literally",
  "i mean",
];
