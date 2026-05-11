#!/bin/bash
# PreToolUse hook: when a .plain file is being written or edited,
# output the relevant rules so Claude Code follows them.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

if [[ "$FILE_PATH" != *.plain ]]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
RULES_DIR="$PROJECT_DIR/.claude/rules"

echo "You are editing a .plain spec file. Follow these rules:" >&2

for rule_file in "$RULES_DIR"/definitions.md "$RULES_DIR"/func-specs.md "$RULES_DIR"/impl-reqs.md "$RULES_DIR"/test-reqs.md "$RULES_DIR"/import-modules.md "$RULES_DIR"/requires-modules.md "$RULES_DIR"/exported-concepts.md "$RULES_DIR"/required-concepts.md; do
  if [ -f "$rule_file" ]; then
    echo "" >&2
    cat "$rule_file" >&2
  fi
done

exit 0
