# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Personal user-level Claude Code skills, rules, and settings. The canonical clone (this repo) is the source of truth; `~/.claude/` is populated by `./install.sh`.

## Repository Structure

- `skills/` — Multi-step agent workflows (SKILL.md per directory). See `.claude/rules/skill-authoring.md` for conventions.
- `rules/` — Behavioral rules that auto-load every session. See `.claude/rules/rule-authoring.md` for conventions.
- `scripts/` — Shell scripts including statusline.
- `settings.merge.json` — Curated keys merged into `~/.claude/settings.json` (model, permissions, hooks, plugins).
- `install.sh` / `Taskfile.yaml` — Install/sync tooling.

## Creating Skills and Rules

Use `/create-skill` and `/create-rule` respectively. Do not author SKILL.md or rule files from scratch.

## Sync workflow

- `~/.claude/` is populated by `./install.sh` (or `task install`) running from this canonical clone.
- Edits to `skills/`, `rules/`, `scripts/`, and top-level files in this repo flow into `~/.claude/` on each install.
- Personal/local skills/rules/scripts in `~/.claude/` are preserved (never deleted).
- `settings.json` is jq-merged: specific keys (`model`, `effortLevel`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`, `permissions.allow`, `hooks`) flow from `settings.merge.json`; everything else stays user-local.

## Portability

This repo must remain portable and free of company-specific content:

- No internal URLs, proprietary tool names, or org-specific workflows in skills, rules, or settings.
- Skills that need org-specific context should read it from project-level `CLAUDE.md`, `REVIEW.md`, or `.claude/rules/` at runtime.
- MCP tool references use fully qualified names (`ServerName:tool_name`).
