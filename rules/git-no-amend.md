# git-no-amend

Do **not** use `git commit --amend` unless the user explicitly asks to amend. Always create new commits for additional changes, even if they logically belong with the previous commit.

Use [Conventional Commits](https://www.conventionalcommits.org/) format for all commit messages:

```
<type>[optional scope]: <description>
```

Common types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`.
