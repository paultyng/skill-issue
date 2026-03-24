# taskfile-not-make

Use [go-task](https://taskfile.dev/) (`Taskfile.yaml`) for task automation. Do not use Makefiles.

- Task definitions go in `Taskfile.yaml` at the repo root.
- Use `task <name>` to run tasks (e.g. `task test`, `task db`).
- Use colon-separated namespacing for related tasks (e.g. `task db:stop`).
- When adding new automation, add a task to `Taskfile.yaml` rather than creating a Makefile or shell script.
