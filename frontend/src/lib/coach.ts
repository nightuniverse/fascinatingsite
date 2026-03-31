export type NudgeLevel = 0 | 1 | 2 | 3 | 4;

export const NUDGE_LABELS: Record<NudgeLevel, string> = {
  0: "Gentle companion",
  1: "Soft structure",
  2: "Balanced",
  3: "Firm accountability",
  4: "Direct mode",
};

type Phase = "idle" | "running" | "almost" | "done";

function pick<T>(arr: readonly T[], level: NudgeLevel): T {
  const i = Math.min(level, arr.length - 1);
  return arr[i] ?? arr[0];
}

export function bodyDoubleLine(
  level: NudgeLevel,
  phase: Phase,
  opts?: { inFocus?: boolean },
): string {
  const focusIdle = [
    "Timer ready. Start when you are — no rush.",
    "One step on screen. Everything else can wait.",
    "Hit start when your hands are on the task.",
    "This block is yours. Begin when it feels possible.",
    "Paused is okay. Resume when you're back.",
  ] as const;

  if (opts?.inFocus && phase === "idle") {
    return pick(focusIdle, level);
  }

  const idle = [
    "I'm here with you. One tiny step is enough to start.",
    "Pick one thing. We'll hold the rest outside the room.",
    "Nothing has to be perfect — only started.",
    "Your brain is loud; this screen stays quiet. One task.",
    "I'm not judging pace. I'm keeping the lane clear.",
  ] as const;
  const running = [
    "Stay with this block. The rest can wait in the queue.",
    "You're in motion — that's the win. Eyes on this step.",
    "Let the urge to switch tasks pass like weather.",
    "Single-task mode: I'm guarding the perimeter.",
    "Breathe once. Return to the one line in front of you.",
  ] as const;
  const almost = [
    "Last stretch of this slice. Finish strong, then pause.",
    "Under a minute — stay with it.",
    "Close the loop on this micro-step. Almost there.",
    "No new tasks — just land this one.",
    "Final push — then you choose: next step or break.",
  ] as const;
  const done = [
    "That counted. Name what you did in one phrase if you like.",
    "Micro-win logged. Your streak likes consistency, not size.",
    "Done beats perfect. Ready for the next tiny piece?",
    "You closed a loop — dopamine earned honestly.",
    "Pause, water, or next step — you're in control.",
  ] as const;

  const table = { idle, running, almost, done };
  return pick(table[phase], level);
}

export function nudgeHint(level: NudgeLevel): string {
  const hints: Record<NudgeLevel, string> = {
    0: "Minimal prompts. Quiet presence.",
    1: "Gentle reminders. No pressure copy.",
    2: "Clear cues and steady pacing.",
    3: "Sharper language. Assumes you want a push.",
    4: "Maximum directness — use only if it helps you.",
  };
  return hints[level];
}
