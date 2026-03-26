# Agent Skills

Reusable skills for AI coding agents. Each skill is a self-contained prompt template that an agent can invoke based on user intent.

Skills follow an open format: a directory containing a `SKILL.md` file with YAML frontmatter and markdown instructions. Any agent platform that supports the skill spec can discover and use them.

## Structure

```
skills/
  jira-link/
    SKILL.md
```

Each `SKILL.md` contains:

- **Frontmatter** — `name`, `description`, and `version`
- **Body** — Markdown instructions that guide the agent's behavior

## Skills

| Skill | Description |
|-------|-------------|
| [jira-link](jira-link/) | Create, delete, and manage links between Jira issues using the Atlassian MCP |

## Installation

How you install depends on your agent platform. For example, with Claude Code:

```sh
git clone <repo-url> ~/.claude/skills
```

Or symlink individual skill directories into your agent's skills folder.

## Creating a New Skill

1. Create a new directory for the skill
2. Add a `SKILL.md` with the following frontmatter:

```markdown
---
name: my-skill
description: When and how the agent should use this skill.
version: 1.0.0
---

# Skill instructions go here
```

The `description` field is how agents decide when to invoke the skill, so write it as a trigger condition (e.g. "Use this skill when the user wants to...").
