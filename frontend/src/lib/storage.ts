import type { NudgeLevel } from "./coach";

export type TaskItem = {
  id: string;
  title: string;
  steps: string[];
  createdAt: number;
  completedStepIndices: Set<number>;
};

type StoredTask = Omit<TaskItem, "completedStepIndices"> & {
  completedStepIndices: number[];
};

export type PersistedFile = {
  version: 1;
  nudgeLevel: NudgeLevel;
  tasks: StoredTask[];
  streak: number;
  lastStreakDate: string | null;
  totalMicroWins: number;
  dailySessions: Record<string, number>;
};

const KEY = "focus-scaffold-v1";

export function loadState(): PersistedFile | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const p = JSON.parse(raw) as PersistedFile;
    if (p.version !== 1) return null;
    return p;
  } catch {
    return null;
  }
}

export function taskFromStored(t: StoredTask): TaskItem {
  return {
    ...t,
    completedStepIndices: new Set(t.completedStepIndices ?? []),
  };
}

export function saveState(state: {
  nudgeLevel: NudgeLevel;
  streak: number;
  lastStreakDate: string | null;
  totalMicroWins: number;
  dailySessions: Record<string, number>;
  tasks: TaskItem[];
}): void {
  const serializable: PersistedFile = {
    version: 1,
    nudgeLevel: state.nudgeLevel,
    streak: state.streak,
    lastStreakDate: state.lastStreakDate,
    totalMicroWins: state.totalMicroWins,
    dailySessions: state.dailySessions,
    tasks: state.tasks.map((t) => ({
      ...t,
      completedStepIndices: [...t.completedStepIndices],
    })),
  };
  localStorage.setItem(KEY, JSON.stringify(serializable));
}
