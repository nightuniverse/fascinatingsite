import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import "./App.css";
import { suggestMicroSteps } from "./lib/breakdown";
import { bodyDoubleLine, nudgeHint, NUDGE_LABELS, type NudgeLevel } from "./lib/coach";
import { uid } from "./lib/id";
import { loadState, saveState, taskFromStored, type TaskItem } from "./lib/storage";

const DURATIONS = [5, 15, 25, 45] as const;

function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

function isYesterday(iso: string): boolean {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return d.toISOString().slice(0, 10) === iso;
}

type View = "home" | "focus";

export default function App() {
  const initial = loadState();
  const [nudgeLevel, setNudgeLevel] = useState<NudgeLevel>(initial?.nudgeLevel ?? 2);
  const [tasks, setTasks] = useState<TaskItem[]>(() => {
    if (!initial?.tasks.length) return [];
    return initial.tasks.map(taskFromStored);
  });
  const [streak, setStreak] = useState(initial?.streak ?? 0);
  const [lastStreakDate, setLastStreakDate] = useState<string | null>(
    initial?.lastStreakDate ?? null,
  );
  const [totalMicroWins, setTotalMicroWins] = useState(initial?.totalMicroWins ?? 0);
  const [dailySessions, setDailySessions] = useState<Record<string, number>>(
    () => initial?.dailySessions ?? {},
  );

  const [draft, setDraft] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [activeStepIndex, setActiveStepIndex] = useState(0);
  const [view, setView] = useState<View>("home");
  const [minutes, setMinutes] = useState<25 | 15 | 5 | 45>(25);
  const [remainingSec, setRemainingSec] = useState(25 * 60);
  const [running, setRunning] = useState(false);
  const [celebrate, setCelebrate] = useState(false);
  const [speechError, setSpeechError] = useState<string | null>(null);

  const tickRef = useRef<number | null>(null);
  const selected = useMemo(
    () => tasks.find((t) => t.id === selectedId) ?? null,
    [tasks, selectedId],
  );

  useEffect(() => {
    saveState({
      nudgeLevel,
      streak,
      lastStreakDate,
      totalMicroWins,
      dailySessions,
      tasks: tasks.map((t) => ({
        ...t,
        completedStepIndices: t.completedStepIndices as Set<number>,
      })),
    });
  }, [nudgeLevel, streak, lastStreakDate, totalMicroWins, dailySessions, tasks]);

  const bumpSessionDay = useCallback(() => {
    const day = todayISO();
    setDailySessions((d) => ({ ...d, [day]: (d[day] ?? 0) + 1 }));
    setLastStreakDate((prev) => {
      if (prev === day) return prev;
      if (!prev) {
        setStreak(1);
        return day;
      }
      if (isYesterday(prev)) {
        setStreak((s) => s + 1);
      } else {
        setStreak(1);
      }
      return day;
    });
  }, []);

  useEffect(() => {
    if (!running || view !== "focus") return;
    tickRef.current = window.setInterval(() => {
      setRemainingSec((s) => {
        if (s <= 1) {
          setRunning(false);
          setCelebrate(true);
          window.setTimeout(() => setCelebrate(false), 2200);
          bumpSessionDay();
          return 0;
        }
        return s - 1;
      });
    }, 1000);
    return () => {
      if (tickRef.current) window.clearInterval(tickRef.current);
    };
  }, [running, view, bumpSessionDay]);

  const coachPhase = useMemo(() => {
    if (view !== "focus") return "idle" as const;
    if (celebrate) return "done" as const;
    if (remainingSec <= 60 && remainingSec > 0 && running) return "almost" as const;
    if (running) return "running" as const;
    return "idle" as const;
  }, [view, celebrate, remainingSec, running]);

  const coachText = bodyDoubleLine(nudgeLevel, coachPhase, { inFocus: view === "focus" });

  const addTask = useCallback(() => {
    const title = draft.trim();
    if (!title) return;
    const steps = suggestMicroSteps(title);
    const id = uid();
    setTasks((prev) => [
      {
        id,
        title,
        steps: steps.length ? steps : [title],
        createdAt: Date.now(),
        completedStepIndices: new Set(),
      },
      ...prev,
    ]);
    setDraft("");
    setSelectedId(id);
    setActiveStepIndex(0);
  }, [draft]);

  const startFocus = useCallback(() => {
    if (!selected || !selected.steps.length) return;
    const firstOpen = selected.steps.findIndex((_, i) => !selected.completedStepIndices.has(i));
    if (firstOpen < 0) return;
    setActiveStepIndex(firstOpen);
    setRemainingSec(minutes * 60);
    setRunning(false);
    setView("focus");
  }, [selected, minutes]);

  const exitFocus = useCallback(() => {
    setRunning(false);
    setView("home");
  }, []);

  const completeMicroStep = useCallback(() => {
    if (!selected) return;
    const idx = activeStepIndex;
    setTasks((prev) => {
      const t = prev.find((x) => x.id === selected.id);
      if (!t) return prev;
      const done = new Set(t.completedStepIndices);
      done.add(idx);
      const nextIncomplete = t.steps.findIndex((_, i) => !done.has(i));
      queueMicrotask(() => {
        if (nextIncomplete >= 0) setActiveStepIndex(nextIncomplete);
        else exitFocus();
      });
      return prev.map((x) =>
        x.id === selected.id ? { ...x, completedStepIndices: done } : x,
      );
    });
    setTotalMicroWins((n) => n + 1);
    setCelebrate(true);
    window.setTimeout(() => setCelebrate(false), 1600);
  }, [selected, activeStepIndex, exitFocus]);

  const startListening = useCallback(() => {
    setSpeechError(null);
    const w = window as unknown as {
      SpeechRecognition?: new () => SpeechRecognition;
      webkitSpeechRecognition?: new () => SpeechRecognition;
    };
    const SR = w.SpeechRecognition || w.webkitSpeechRecognition;
    if (!SR) {
      setSpeechError("Voice input is not supported in this browser. Try Chrome or type instead.");
      return;
    }
    const rec = new SR();
    rec.lang = "en-US";
    rec.interimResults = false;
    rec.maxAlternatives = 1;
    rec.onresult = (ev: SpeechRecognitionEvent) => {
      const text = ev.results[0][0].transcript.trim();
      if (text) setDraft((d) => (d ? `${d} ${text}` : text));
    };
    rec.onerror = () => {
      setSpeechError("Could not capture speech. Check microphone permission.");
    };
    rec.start();
  }, []);

  const mm = Math.floor(remainingSec / 60);
  const ss = remainingSec % 60;
  const progress =
    minutes * 60 > 0 ? remainingSec / (minutes * 60) : 0;

  const currentStepText =
    selected && selected.steps[activeStepIndex]
      ? selected.steps[activeStepIndex]
      : "Pick or add a task with micro-steps.";

  const sessionCountToday = dailySessions[todayISO()] ?? 0;
  const recentDays = useMemo(() => {
    const out: string[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      out.push(d.toISOString().slice(0, 10));
    }
    return out;
  }, []);

  return (
    <div className={`shell ${view === "focus" ? "shell--focus" : ""}`}>
      <header className="top">
        <div className="brand">
          <span className="brand__mark" aria-hidden />
          <div>
            <p className="brand__name">Focus Scaffold</p>
            <p className="brand__tag">Executive function support — English</p>
          </div>
        </div>
        <div className="stats" aria-live="polite">
          <span className="pill">Streak · {streak}d</span>
          <span className="pill">Micro-wins · {totalMicroWins}</span>
          <span className="pill">Today · {sessionCountToday} sessions</span>
        </div>
      </header>

      {view === "home" && (
        <>
          <section className="panel panel--nudge" aria-labelledby="nudge-heading">
            <div className="panel__head">
              <h2 id="nudge-heading" className="h2">
                Accountability dial
              </h2>
              <p className="muted small">{nudgeHint(nudgeLevel)}</p>
            </div>
            <label className="sr-only" htmlFor="nudge">
              Nudge intensity
            </label>
            <input
              id="nudge"
              type="range"
              min={0}
              max={4}
              step={1}
              value={nudgeLevel}
              onChange={(e) => setNudgeLevel(Number(e.target.value) as NudgeLevel)}
              className="dial"
            />
            <div className="dial-labels">
              <span>{NUDGE_LABELS[0]}</span>
              <strong>{NUDGE_LABELS[nudgeLevel]}</strong>
              <span>{NUDGE_LABELS[4]}</span>
            </div>
          </section>

          <section className="panel">
            <h2 className="h2">Capture (type or speak)</h2>
            <p className="muted lede">
              Brain-dump a task. We suggest tiny steps — edit them anytime. One step shows in focus
              mode.
            </p>
            <div className="capture">
              <textarea
                className="textarea"
                rows={3}
                placeholder="e.g. Reply to client email about the proposal…"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
                    e.preventDefault();
                    addTask();
                  }
                }}
              />
              <div className="capture__actions">
                <button type="button" className="btn btn--ghost" onClick={startListening}>
                  Voice
                </button>
                <button type="button" className="btn" onClick={addTask} disabled={!draft.trim()}>
                  Add task &amp; steps
                </button>
              </div>
              {speechError && (
                <p className="alert" role="alert">
                  {speechError}
                </p>
              )}
            </div>
          </section>

          <section className="panel">
            <h2 className="h2">Tasks</h2>
            {tasks.length === 0 ? (
              <p className="muted">No tasks yet. Add one above — steps appear automatically.</p>
            ) : (
              <ul className="task-list">
                {tasks.map((t) => (
                  <li key={t.id}>
                    <button
                      type="button"
                      className={`task-card ${selectedId === t.id ? "task-card--on" : ""}`}
                      onClick={() => {
                        setSelectedId(t.id);
                        const firstOpen = t.steps.findIndex(
                          (_, i) => !t.completedStepIndices.has(i),
                        );
                        setActiveStepIndex(firstOpen >= 0 ? firstOpen : 0);
                      }}
                    >
                      <span className="task-card__title">{t.title}</span>
                      <span className="task-card__meta">
                        {t.steps.filter((_, i) => t.completedStepIndices.has(i)).length}/
                        {t.steps.length} steps
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}

            {selected && (
              <div className="steps-editor">
                <h3 className="h3">Micro-steps for this task</h3>
                <ol className="steps">
                  {selected.steps.map((s, i) => (
                    <li key={i} className={selected.completedStepIndices.has(i) ? "step--done" : ""}>
                      <label className="step-label">
                        <input
                          type="checkbox"
                          checked={selected.completedStepIndices.has(i)}
                          onChange={() => {
                            setTasks((prev) =>
                              prev.map((x) => {
                                if (x.id !== selected.id) return x;
                                const set = new Set(x.completedStepIndices);
                                if (set.has(i)) set.delete(i);
                                else set.add(i);
                                return { ...x, completedStepIndices: set };
                              }),
                            );
                          }}
                        />
                        <input
                          className="step-input"
                          value={s}
                          onChange={(e) => {
                            const v = e.target.value;
                            setTasks((prev) =>
                              prev.map((x) => {
                                if (x.id !== selected.id) return x;
                                const steps = [...x.steps];
                                steps[i] = v;
                                return { ...x, steps };
                              }),
                            );
                          }}
                        />
                      </label>
                    </li>
                  ))}
                </ol>
                <div className="row-focus">
                  <div>
                    <span className="muted small">Block length</span>
                    <div className="durations">
                      {DURATIONS.map((m) => (
                        <button
                          key={m}
                          type="button"
                          className={`chip ${minutes === m ? "chip--on" : ""}`}
                          onClick={() => {
                            setMinutes(m);
                            setRemainingSec(m * 60);
                          }}
                        >
                          {m}m
                        </button>
                      ))}
                    </div>
                  </div>
                  <button
                    type="button"
                    className="btn btn--primary"
                    onClick={startFocus}
                    disabled={
                      !selected.steps.length ||
                      selected.steps.every((_, i) => selected.completedStepIndices.has(i))
                    }
                  >
                    Enter focus mode
                  </button>
                </div>
              </div>
            )}
          </section>

          <section className="panel panel--history">
            <h2 className="h2">Last 7 days</h2>
            <div className="heatmap" role="img" aria-label="Sessions per day last week">
              {recentDays.map((d) => {
                const n = dailySessions[d] ?? 0;
                const level = n === 0 ? 0 : n === 1 ? 1 : n <= 3 ? 2 : 3;
                return (
                  <div key={d} className="heat-cell" title={`${d}: ${n} sessions`}>
                    <div className={`heat heat--${level}`} />
                    <span className="heat-label">{d.slice(5)}</span>
                  </div>
                );
              })}
            </div>
          </section>

          <footer className="foot">
            <p>
              Focus Scaffold is a wellness-style productivity tool, not medical advice. If you need
              clinical support, talk to a qualified professional.
            </p>
          </footer>
        </>
      )}

      {view === "focus" && (
        <div className="focus" role="application" aria-label="Single-task focus session">
          <div className={`celebrate ${celebrate ? "celebrate--on" : ""}`} aria-hidden />

          <div className="focus__inner">
            <p className="focus__eyebrow">One micro-step · {NUDGE_LABELS[nudgeLevel]}</p>
            <h1 className="focus__step">{currentStepText}</h1>

            <div className="timer-wrap" aria-live="polite">
              <svg className="ring" viewBox="0 0 120 120" aria-hidden>
                <defs>
                  <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#5eead4" />
                    <stop offset="100%" stopColor="#34d399" />
                  </linearGradient>
                </defs>
                <circle className="ring__bg" cx="60" cy="60" r="54" />
                <circle
                  className="ring__fg"
                  cx="60"
                  cy="60"
                  r="54"
                  style={{
                    strokeDashoffset: `${(1 - progress) * 339.292}`,
                  }}
                />
              </svg>
              <div className="timer-digits">
                {String(mm).padStart(2, "0")}:{String(ss).padStart(2, "0")}
              </div>
            </div>

            <p className="coach">{coachText}</p>

            <div className="focus__controls">
              {!running && remainingSec > 0 && (
                <button type="button" className="btn btn--primary btn--xl" onClick={() => setRunning(true)}>
                  Start {minutes} min
                </button>
              )}
              {running && (
                <button type="button" className="btn btn--ghost" onClick={() => setRunning(false)}>
                  Pause
                </button>
              )}
              {!running && remainingSec > 0 && remainingSec < minutes * 60 && (
                <button type="button" className="btn" onClick={() => setRunning(true)}>
                  Resume
                </button>
              )}
              {remainingSec === 0 && (
                <button type="button" className="btn btn--primary" onClick={() => setRemainingSec(minutes * 60)}>
                  Reset timer
                </button>
              )}
              <button type="button" className="btn btn--success" onClick={completeMicroStep}>
                I finished this micro-step
              </button>
            </div>

            <button type="button" className="link-exit" onClick={exitFocus}>
              Exit focus mode
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
