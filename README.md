# agent-skills

A personal [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) holding my preferences and skills in one place.

## Install

Add the marketplace once:

```
/plugin marketplace add hiroshisuda/agent-skills
```

Then install the plugins you want:

```
/plugin install git@hiroshisuda
/plugin install preferences@hiroshisuda
/plugin install docs@hiroshisuda
/plugin install code@hiroshisuda
```

To pick up changes after pushing to this repo:

```
/plugin marketplace update hiroshisuda
```

## Plugins

| Plugin | What it provides |
|--------|------------------|
| [git](plugins/git/) | Skills: `commit-messages` (Conventional Commits for commits and PR titles, concise, references tickets/docs), `branching` (feature-named branches from an up-to-date `main`), `history-cleanup` (fixups, squashing, reflog recovery). In cloud sessions, a hook blocks git commands that create or push a branch whose name breaks the `branching` convention. In every session, a hook blocks PR titles and squash-merge commit titles that aren't Conventional Commits subjects, so squash merges keep the history that release tooling reads. After `gh stack submit --auto`, it checks the generated titles and asks Claude to fix them. The hooks' tests run with `plugins/git/tests/run.sh`. Depends on `gh-stack`, so installing it installs that too. Needs the [GitHub CLI](https://cli.github.com), logged in with `gh auth login`, plus `gh extension install github/gh-stack`; a session-start check notes anything missing |
| [gh-stack](https://github.com/github/gh-stack/tree/main/skills/gh-stack) | GitHub's own skill for stacked PRs with the `gh stack` extension, pulled from GitHub's repo and pinned to a commit |
| [docs](plugins/docs/) | Skill: `writing-docs` (a feature doc for every new feature and an ADR for every major decision, with [templates](plugins/docs/skills/writing-docs/templates/) and the writing rules). A hook lints each `.md` file Claude writes or edits with [vale-ai-tells](https://github.com/tbhb/vale-ai-tells) and sends the findings back to Claude to fix. Needs [Vale](https://vale.sh/docs/install); the first check downloads the style package |
| [code](plugins/code/) | A SessionStart hook that loads [`CONVENTIONS.md`](plugins/code/CONVENTIONS.md), my coding conventions. Claude writes modular code with strict types, and improves the codebase as it works, such as by removing dead code and merging repeated logic. After each code file Claude writes or edits, a hook formats it and applies automatic fixes, then sends the remaining findings back. The tools are [ruff](https://docs.astral.sh/ruff/) and [ty](https://docs.astral.sh/ty/) for Python, [Prettier](https://prettier.io), [ESLint](https://eslint.org), and `tsc` for TypeScript, and `terraform fmt` and [TFLint](https://github.com/terraform-linters/tflint) for Terraform. It uses the project's own config and tools, falling back to the plugin's strict defaults. Needs [uv](https://docs.astral.sh/uv/) for Python, npm for TypeScript, and Terraform and TFLint for Terraform |
| [preferences](plugins/preferences/) | A SessionStart hook that loads [`PREFERENCES.md`](plugins/preferences/PREFERENCES.md) into every session: my always-on working preferences |

## Layout

```
.claude-plugin/
  marketplace.json          # lists every plugin in this repo
plugins/
  <plugin>/
    .claude-plugin/
      plugin.json           # name, description, version
    skills/<skill>/SKILL.md # on-demand skills
    hooks/hooks.json        # optional hooks
    .mcp.json               # optional MCP servers
```

Plugins are grouped by domain, so each machine or project can enable only what it needs.

The `SKILL.md` files follow the open skill format (YAML frontmatter plus Markdown), so they can be reused by other agents that support it.

## Adding things

**A skill in an existing plugin:** create `plugins/<plugin>/skills/<skill-name>/SKILL.md`:

```markdown
---
name: skill-name
description: Use when ... (this is how Claude decides when to load the skill, so write it as a trigger condition)
---

# Instructions
```

To add a plugin, create `plugins/<plugin>/.claude-plugin/plugin.json` and add an entry to `.claude-plugin/marketplace.json`.

**Always-on preferences:** edit `plugins/preferences/PREFERENCES.md`. Its whole text goes into the context of each session, so add only what each session needs.

To use a skill from another repo, add a marketplace entry whose `git-subdir` source points at the skill's folder there and is pinned with `sha`. Then list it in `dependencies` of the plugin that needs it, as `marketplace.json` does for `gh-stack`. To take upstream changes, review them, then move the `sha` in a PR.

Each PR that changes a plugin bumps its `version` once. The new version goes in both `plugin.json` and `marketplace.json`, and installed copies update when they see it. Don't bump again for later commits in the same PR, and don't bump a plugin the PR adds (it starts at `0.1.0`). Then check the result:

```sh
claude plugin validate .
```
