---
name: start-day
description: Use at the start of a workday or when the user says "start my day", "good morning", "/start-day", "morning", "what should I work on today", or wants a catch-up on what happened while they were away. Use when the user wants a short ranked list of what to tackle today.
---

# Start Day

Produce a short morning brief: what happened since the user was last active, and 2–8 ranked things to do today. Discovery-driven — no hardcoded sources. Read-only; never posts, commits, or mutates anything.

## 1. Compute the lookback window

A `since:<date|weekday>` argument overrides everything below.

Two inputs, combined:

- **fixed_floor** — the minimum lookback. The last business day at 15:00 local (17:00 assumed end-of-day, minus 2h). Last business day: Mon → previous Fri; Sat/Sun → previous Fri; else → yesterday.
- **empirical** — extends the window *earlier only*. The end of the user's last genuinely active day: the later of (a) the newest local session under `~/.claude/projects/*/*.jsonl` dated before today, and (b) the user's last Slack message (`from:me sort:timestamp`).

**window_start = the earlier of fixed_floor and empirical.** Empirical can only push earlier — a low-focus weekend glance cannot shrink the window below fixed_floor, and a vacation gap extends it. window_end = now.

Compute fixed_floor (macOS `date`):

```bash
case $(date +%u) in 1) back=3;; 7) back=2;; *) back=1;; esac   # Mon→Fri, Sun→Fri, else yesterday (Sat→Fri via back=1)
floor=$(date -v-${back}d -v15H -v0M -v0S +%s)                  # last business day @ 15:00 local
```

Holidays need no special handling: if the last business day was a holiday, the user's empirical last-active day predates it and extends the window automatically.

## 2. Discover and run summarization skills

Scan the available skills. Run every skill whose **name matches `summarize-*`** OR whose **description declares summary / recap / status intent**. Do not hardcode which ones — discover them so newly added ones are picked up. Pass the window when a skill accepts a range. If none exist, skip this step.

## 3. Run local extensions

Run every available skill whose name matches **`start-day-*`** (there may be several). Machine- and context-specific morning setup lives there, outside this portable skill. Fold each extension's output into the brief as bullets.

## 4. Slack catch-up (read-only, consent-gated)

Slack search reaches DMs and private channels, so **ask once** before searching: *"Scan Slack DMs/private channels for saved items and pings since <window_start>?"* On yes:

- **Saved / "Later" list:** `Slack:slack_search_public_and_private` with query `is:saved`.
- **Pings since the window:** query `to:me`, `after:<window_start unix ts>`, `sort:timestamp`.
- **OOO garnish:** `Slack:slack_read_user_profile` — note if the user is currently OOO; deprioritize pings from colleagues whose status shows OOO.

Reminders are not reachable through the Slack API — skip them. Never send or post anything (per `no-post-without-confirmation`).

## 5. Synthesize the brief

Open with the window and an override hint:

> Caught up since **Fri Jun 19, 3:00pm** (~3d). Override: `/start-day since:monday`.

Then **2–8 ranked items, sampled across size** — a couple of quick wins to start the day, 1–2 big-rocks to advance a major project, plus anything time-sensitive from Slack. Tag each `[quick]` / `[project]` / `[slack]`. One terse line each, leading with the action.

Brief only: no auto-actions, no backlog writes, no posting. Stay independent of any tracker — when run inside a tool that supplies project context (system prompt, discovered skills), use it, but never depend on it.
