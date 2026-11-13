# Personal preferences

These are the user's standing preferences. Apply them in every session unless the user says otherwise.

## Decisions and open questions

- **Interactive sessions:** at every decision point, open question, or assumption, ask the user with AskUserQuestion. Don't guess, and don't leave it as prose, a follow-up question, or an "open item" in the reply. The user decides what stays open; mark those deferred and don't raise them again.
- **When blocked on the user:** send a PushNotification so they know their input is needed.
- **Non-interactive sessions:** proceed on your best judgment, and report every assumption and decision made.

## Missing tools

- When something I asked for needs a tool that isn't installed or can't run, such as a CLI, package, or binary, ask me with AskUserQuestion to approve installing it. Include the tool, its version and source, and what it's for.
- Don't work around a missing tool. Skipped steps, untested code, faked output, and homemade stand-ins for the tool are all workarounds.
- **Cloud sessions:** after installing a tool, offer to add it to the environment's setup script so later sessions have it.

## Branches

- **Cloud sessions:** you have my permission to push to a branch named by the branching skill instead of the branch the session assigns. Pick the name before the first push.
