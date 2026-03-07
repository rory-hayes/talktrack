function validTimezone(tz?: string): string {
  if (!tz) {
    return "UTC";
  }
  try {
    Intl.DateTimeFormat("en-US", { timeZone: tz }).format(new Date());
    return tz;
  } catch {
    return "UTC";
  }
}

function localDateParts(date: Date, timezone?: string): { year: number; month: number; day: number } {
  const tz = validTimezone(timezone);
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const year = Number(parts.find((p) => p.type === "year")?.value);
  const month = Number(parts.find((p) => p.type === "month")?.value);
  const day = Number(parts.find((p) => p.type === "day")?.value);

  return { year, month, day };
}

export function dayKey(date: Date, timezone?: string): string {
  const { year, month, day } = localDateParts(date, timezone);
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function isoWeek(date: Date): { year: number; week: number } {
  const temp = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNum = temp.getUTCDay() || 7;
  temp.setUTCDate(temp.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(temp.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((temp.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  return { year: temp.getUTCFullYear(), week: weekNo };
}

export function weekKey(date: Date, timezone?: string): string {
  const local = localDateParts(date, timezone);
  const localDate = new Date(Date.UTC(local.year, local.month - 1, local.day));
  const { year, week } = isoWeek(localDate);
  return `${year}-W${String(week).padStart(2, "0")}`;
}

export function dateDiffDays(previousDayKey: string, currentDayKey: string): number {
  const prev = new Date(`${previousDayKey}T00:00:00Z`);
  const curr = new Date(`${currentDayKey}T00:00:00Z`);
  return Math.round((curr.getTime() - prev.getTime()) / 86400000);
}
