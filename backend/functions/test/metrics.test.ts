import { describe, expect, it } from "vitest";
import { computeSpeechMetrics, transcriptFlags } from "../src/metrics";

describe("computeSpeechMetrics", () => {
  it("computes filler count and rate", () => {
    const transcript = "Um I think we should move forward because uh this solves the issue.";
    const result = computeSpeechMetrics(transcript, 30);

    expect(result.fillerCount).toBeGreaterThanOrEqual(2);
    expect(result.fillerRate).toBeGreaterThan(0);
    expect(result.wpm).toBeGreaterThan(0);
  });

  it("detects delivery flags from transcript shape", () => {
    const transcript =
      "So to give a bit of context, we had a release issue across two dashboards and I spent most of the morning tracing it. I fixed the broken query and reran the checks. The result was that the release went out on time.";
    const metrics = computeSpeechMetrics(transcript, 35);
    const flags = transcriptFlags(transcript, metrics);

    expect(flags.pacingBand).toBe("slow");
    expect(flags.openingOverlong).toBe(true);
    expect(flags.weakConclusion).toBe(false);
  });
});
