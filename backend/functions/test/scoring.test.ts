import { describe, expect, it } from "vitest";
import { normalizeBreakdown, workClarityScore } from "../src/scoring";

describe("scoring", () => {
  it("normalizes breakdown to 0-25", () => {
    const normalized = normalizeBreakdown({
      structure: 100,
      clarity: -4,
      conciseness: 12.6,
      delivery: 19.2,
    });

    expect(normalized).toEqual({
      structure: 25,
      clarity: 0,
      conciseness: 13,
      delivery: 19,
    });
  });

  it("computes work clarity score", () => {
    expect(
      workClarityScore({
        structure: 20,
        clarity: 20,
        conciseness: 15,
        delivery: 17,
      }),
    ).toBe(72);
  });
});
