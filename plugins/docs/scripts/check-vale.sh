#!/usr/bin/env bash
# SessionStart: stay silent when vale is installed; otherwise tell Claude the Markdown check is off.
if ! command -v vale >/dev/null 2>&1; then
  echo "Note from the docs plugin, relevant only if you write Markdown: vale is not installed, so the vale-ai-tells check after each .md write is skipped. Tell the user once, when you first write a .md file, to install it (https://vale.sh/docs/install, e.g. 'brew install vale')."
fi
exit 0
