/**
 * Lightweight micro-step suggestions without an LLM — good enough for MVP.
 * Users can always edit steps manually.
 */
export function suggestMicroSteps(raw: string): string[] {
  const cleaned = raw.replace(/\s+/g, " ").trim();
  if (!cleaned) return [];

  const lines = cleaned
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (lines.length > 1) return lines.slice(0, 8);

  const parts = cleaned.split(/\s*(?:[,;]|(?:\band\b)|(?:\bthen\b))\s*/i).filter(Boolean);
  if (parts.length > 1 && parts.length <= 8) {
    return parts.map((p) => p.replace(/^[-•\d.)]+\s*/, "").trim()).filter(Boolean);
  }

  const t = cleaned.toLowerCase();
  const title = cleaned;

  if (/\bemail\b|\bmail\b/.test(t)) {
    return [
      `Open your email client and find the thread for: ${title}`,
      "Draft the first sentence or subject line only.",
      "Send, schedule, or save as draft — pick one.",
    ];
  }
  if (/\bcall\b|\bphone\b|\bmeet\b|zoom|teams/.test(t)) {
    return [
      "Open calendar or dialer — no commitment yet.",
      "Spend 60 seconds listing what you need from this conversation.",
      "Place the call or send one message to schedule.",
    ];
  }
  if (/\bwrite\b|\bessay\b|\breport\b|\bdraft\b/.test(t)) {
    return [
      "Open the doc and title it.",
      "Write one rough paragraph or bullet outline.",
      "Save and step away, or polish one section.",
    ];
  }
  if (/\bread\b|\breview\b|\bstudy\b/.test(t)) {
    return [
      "Open the material to the right page or tab.",
      "Read for 5 minutes or one section only.",
      "Jot one takeaway sentence.",
    ];
  }
  if (/\bclean\b|\borganize\b|\bsort\b/.test(t)) {
    return [
      "Set a 10-minute timer and touch only one area.",
      "Remove or relocate three obvious items.",
      "Stop when the timer ends — that's a win.",
    ];
  }

  return [
    `Name the smallest physical first move for: ${title}`,
    "Do that move for 2 minutes — timer optional.",
    "Check one box: started, paused with a note, or rescheduled.",
  ];
}
