# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal user-level Claude Code skills, rules, and settings. Cloned/symlinked to `~/.claude/` and available across all projects.

## Repository Structure

- `skills/` — Multi-step agent workflows (SKILL.md per directory). See `.claude/rules/skill-authoring.md` for conventions.
- `rules/` — Behavioral rules that auto-load every session. See `.claude/rules/rule-authoring.md` for conventions.
- `settings.json` — Shared config (model, permissions, hooks, plugins).

## Creating Skills and Rules

Use `/create-skill` and `/create-rule` respectively. Do not author SKILL.md or rule files from scratch.

## Settings

`settings.json` is the only config file Claude Code reads from the user directory — there is no `settings.local.json` override mechanism here (unlike project-level `.claude/`). This means:

- **Local-only changes** (e.g., HTTP hooks for a local dev server) will show as dirty in git. This is expected — do not commit them.
- Before committing `settings.json`, review the diff carefully to ensure only intentional shared changes are staged. Use `git add -p settings.json` if needed.
- Permissions and hooks in this file apply to every project. Keep them minimal and general-purpose.

## Portability

This repo must remain portable and free of company-specific content:

- No internal URLs, proprietary tool names, or org-specific workflows in skills, rules, or settings.
- Skills that need org-specific context should read it from project-level `CLAUDE.md`, `REVIEW.md`, or `.claude/rules/` at runtime.
- MCP tool references use fully qualified names (`ServerName:tool_name`).
