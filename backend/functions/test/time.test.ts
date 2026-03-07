import { describe, expect, it } from "vitest";
import { dateDiffDays, dayKey } from "../src/time";

describe("time helpers", () => {
  it("builds day key with timezone", () => {
    const key = dayKey(new Date("2026-03-04T12:00:00Z"), "Europe/Dublin");
    expect(key).toBe("2026-03-04");
  });

  it("computes day difference", () => {
    expect(dateDiffDays("2026-03-03", "2026-03-04")).toBe(1);
  });
});
