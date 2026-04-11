# taskfile-not-make

Use [go-task](https://taskfile.dev/) (`Taskfile.yaml`) for task automation. Do not use Makefiles.

- Task definitions go in `Taskfile.yaml` at the repo root.
- Use `task <name>` to run tasks (e.g. `task test`, `task db`).
- Use colon-separated namespacing for related tasks (e.g. `task db:stop`).
- When adding new automation, add a task to `Taskfile.yaml` rather than creating a Makefile or shell script.
- **Project override**: if a project has no `Taskfile.yaml` but has `package.json` with scripts, use `npm`/`yarn`/`pnpm` instead. Respect the project's existing build tool.
