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
```

To pick up changes after pushing to this repo:

```
/plugin marketplace update hiroshisuda
```

## Plugins

| Plugin | What it provides |
|--------|------------------|
| [git](plugins/git/) | Skills: `commit-messages` (Conventional Commits, concise, references tickets/docs), `branching` (feature-named branches from an up-to-date `main`), `stacked-prs` (dependent PR chains with the [`gh stack`](https://github.com/github/gh-stack) extension), `history-cleanup` (fixups, squashing, reflog recovery). Needs the [GitHub CLI](https://cli.github.com), logged in with `gh auth login`, plus `gh extension install github/gh-stack`; a session-start check notes anything missing |
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

**A new plugin:** create `plugins/<plugin>/.claude-plugin/plugin.json` and add an entry to `.claude-plugin/marketplace.json`.

**Always-on preferences:** edit `plugins/preferences/PREFERENCES.md`. Keep it short, because all of it is loaded into every session.

**After any change:** bump the plugin's `version` in both its `plugin.json` and `marketplace.json` so installed copies update, then check the result:

```sh
claude plugin validate .
```
