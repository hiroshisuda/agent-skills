---
name: jira-link
description: Use this skill when the user wants to create, delete, or manage links between Jira issues (e.g. "link DEV-95 to DEV-97", "DEV-95 blocks DEV-97", "create a blocks link", "remove a link between issues"). Always use the Atlassian MCP (not acli) for all Jira interactions in this skill.
version: 1.0.0
---

# Jira Issue Linking Skill

This skill creates and manages links between Jira issues using the **Atlassian MCP tools** exclusively.

## Key Concept: Inward vs Outward

Jira link types are directional. For the "Blocks" type:

| Field | Label shown in UI | Meaning |
|-------|-------------------|---------|
| `outwardIssue` | "blocks" | The issue that is doing the blocking |
| `inwardIssue` | "is blocked by" | The issue that is being blocked |

**Critical:** If you want "DEV-95 blocks DEV-97", DEV-97 must be the `outwardIssue` on the link created from DEV-95's perspective — or equivalently, create the link on DEV-97 with DEV-95 as the `inwardIssue`.

The safest mental model: when creating a link, think of it as annotating the **source issue**:
- Source issue + `outwardIssue` = source **blocks** target
- Source issue + `inwardIssue` = source **is blocked by** target

## Step-by-Step: Creating a Link

### 1. Get the Cloud ID

```
mcp__atlassian__getAccessibleAtlassianResources
```

Use the `id` field from the response as `cloudId` in all subsequent calls.

### 2. (Optional) Confirm available link types

```
mcp__atlassian__getIssueLinkTypes { cloudId }
```

Common types: `Blocks`, `Cloners`, `Duplicate`, `Relates`.

### 3. Create the link

```
mcp__atlassian__createIssueLink {
  cloudId,
  type: { name: "Blocks" },
  outwardIssue: { key: "DEV-97" },   // the issue being blocked
  inwardIssue:  { key: "DEV-95" }    // the blocker
}
```

This produces: **DEV-95 is blocked by** / **DEV-97 blocks DEV-95** — adjust to match the user's intent.

## Common Scenarios

### "A blocks B" (A must be done before B)

```json
{
  "type": { "name": "Blocks" },
  "outwardIssue": { "key": "B" },
  "inwardIssue":  { "key": "A" }
}
```

UI on A: **"blocks" → B**
UI on B: **"is blocked by" → A**

### "A is blocked by B" (B must be done before A)

```json
{
  "type": { "name": "Blocks" },
  "outwardIssue": { "key": "A" },
  "inwardIssue":  { "key": "B" }
}
```

### "A relates to B"

```json
{
  "type": { "name": "Relates" },
  "outwardIssue": { "key": "B" },
  "inwardIssue":  { "key": "A" }
}
```

## Verifying Links

After creating, confirm with:

```
mcp__atlassian__getJiraIssue {
  cloudId,
  issueIdOrKey: "DEV-95",
  fields: ["issuelinks", "summary"]
}
```

Check the `issuelinks` array: each entry has a `type` (with `inward`/`outward` labels) and either an `inwardIssue` or `outwardIssue` key showing the linked issue.

## Fixing Backwards Links

If links were created in the wrong direction (a common mistake):

1. Note the link `id` from the `issuelinks` array
2. Delete it — use `mcp__atlassian__fetch` to call `DELETE /rest/api/3/issueLink/{linkId}`
3. Recreate with the correct `inwardIssue` / `outwardIssue` assignment

## MCP Tools Reference

| Tool | Purpose |
|------|---------|
| `mcp__atlassian__getAccessibleAtlassianResources` | Get cloudId |
| `mcp__atlassian__getIssueLinkTypes` | List available link type names |
| `mcp__atlassian__createIssueLink` | Create a link between two issues |
| `mcp__atlassian__getJiraIssue` | Verify links on an issue |
| `mcp__atlassian__fetch` | Raw API calls (e.g. DELETE a link) |
