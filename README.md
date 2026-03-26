# Claude Code Skills

Custom skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Skills are reusable prompt templates that Claude Code can invoke automatically based on user intent.

## Structure

Each skill lives in its own directory and contains a `SKILL.md` file with frontmatter (name, description, version) and instructions that guide Claude's behavior.

```
skills/
  jira-link/
    SKILL.md
```

## Skills

| Skill | Description |
|-------|-------------|
| [jira-link](jira-link/) | Create, delete, and manage links between Jira issues using the Atlassian MCP |

## Installation

Clone this repo into your Claude Code skills directory:

```sh
git clone <repo-url> ~/.claude/skills
```

Or symlink individual skill directories into an existing `~/.claude/skills/` folder.

## Creating a New Skill

1. Create a new directory under `skills/`
2. Add a `SKILL.md` with the following frontmatter:

```markdown
---
name: my-skill
description: When and how Claude should use this skill.
version: 1.0.0
---

# Skill instructions go here
```

The `description` field is key -- Claude Code uses it to decide when to invoke the skill, so write it as a trigger condition (e.g. "Use this skill when the user wants to...").
