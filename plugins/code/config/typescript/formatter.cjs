// ESLint formatter: one "path:line:col: severity message [rule]" line per message.
const path = require("node:path");

module.exports = (results) =>
  results
    .flatMap((result) =>
      result.messages.map((m) => {
        const file = path.relative(process.cwd(), result.filePath);
        const severity = m.severity === 2 ? "error" : "warning";
        return `${file}:${m.line ?? 0}:${m.column ?? 0}: ${severity} ${m.message}${m.ruleId ? ` [${m.ruleId}]` : ""}`;
      }),
    )
    .join("\n");
