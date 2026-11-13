# Coding conventions

These are the user's standing coding conventions. Apply them to all code in this project unless the user says otherwise.

## Own the codebase

Treat this codebase as yours. Leave each area you touch better than you found it, without being asked:

- Delete dead code: unused functions, imports, parameters, variables, flags, and commented-out code. Git keeps the history.
- When logic repeats, extract it into one reusable function or module and point every caller at it.
- Fix inefficiencies such as repeated work in loops, needless copies, and N+1 queries.
- Rename unclear names, simplify convoluted control flow, and fix bugs you notice.
- Drop compatibility shims, wrappers, and re-exports that nothing outside the project depends on.
- Keep tests passing, and update them along with the code they cover.

Make these changes in the same task, and list them in your summary so the user can review them. Ask first only before changes that alter behavior users or other systems depend on, such as a public API, a data format, or a schema.

## Modular code

- Give each function, class, and module one responsibility. Split a file when it mixes unrelated concerns.
- Keep side effects at the edges: core logic in pure functions, with I/O, network, and state in thin layers around it.
- Depend on narrow interfaces, and pass dependencies in rather than reaching for globals.
- Prefer composition and small functions over deep inheritance and long parameter lists.
- Export only what other modules need, and don't import another module's internals.

## Strict types

- Turn on the strictest type checking the language offers, and keep the code free of type errors.
- Annotate every function signature and public attribute.
- Model data precisely. Use literal types, discriminated unions, dataclasses, `TypedDict`, and interfaces instead of loose dicts and strings.
- Avoid `any` (TypeScript) and `Any` (Python). Use `unknown` or `object` and narrow it.
- Validate untrusted input at the boundary and convert it to typed values once, so inner code can trust its types.
- Don't suppress checker errors with casts or `type: ignore` / `@ts-ignore`. For a real false positive, use a suppression scoped to that rule and line (`# ty: ignore[rule]`, `@ts-expect-error`) with a comment giving the reason.

## Checks after each write

A hook lints and type checks each code file you write or edit, and sends findings back to you. Fix every finding at its cause before moving on.

| Language | Lint | Types |
|----------|------|-------|
| Python | ruff | ty |
| TypeScript | eslint | tsc |

The hook uses the project's own config and tools when it has them. Otherwise it falls back to this plugin's strict defaults, and tells you once per session so you can suggest that the user add a project config. When setting up a new project, add strict configs from the start.
