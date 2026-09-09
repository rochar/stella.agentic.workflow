#!/usr/bin/env bash
# SessionStart hook for stella-agentic-workflow-docs.
# Whatever this script prints to stdout is added to the session context,
# so every session (local CLI, desktop, or cloud) learns the docs/ conventions.
# The injected file is paid for in every session — keep it a thin pointer.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Fall back to self-location so the hook also works when run outside Claude Code
# (e.g. manual testing) where CLAUDE_PLUGIN_ROOT is not exported.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if ! cat "${PLUGIN_ROOT}/context/docs-structure.md"; then
  echo "stella-agentic-workflow-docs: cannot read ${PLUGIN_ROOT}/context/docs-structure.md — docs conventions were NOT injected into this session." >&2
  exit 1
fi

# The expected structure is defined by templates/docs/ (the same tree
# scripts/init-docs.sh copies), enumerated by the helper both scripts share,
# so adding a file or folder there is picked up here too.
TEMPLATES_DIR="${PLUGIN_ROOT}/templates/docs"
if [ ! -d "${TEMPLATES_DIR}" ]; then
  # The conventions were already printed above; a non-zero exit would make
  # Claude Code discard that stdout, so degrade to a stderr warning and skip
  # the (secondary) bootstrap check rather than losing the context injection.
  echo "stella-agentic-workflow-docs: templates directory not found: ${TEMPLATES_DIR} — cannot check whether docs/ is bootstrapped." >&2
  exit 0
fi

# shellcheck source=../scripts/lib/template-files.sh
if ! . "${PLUGIN_ROOT}/scripts/lib/template-files.sh"; then
  echo "stella-agentic-workflow-docs: cannot load ${PLUGIN_ROOT}/scripts/lib/template-files.sh — skipped the docs/ bootstrap check." >&2
  exit 0
fi

missing=""
missing_count=0
total=0
while IFS= read -r rel; do                               # e.g. adrs/README.md
  total=$((total + 1))
  if [ ! -f "${PROJECT_DIR}/docs/${rel}" ]; then
    missing="${missing}"$'\n'"  docs/${rel}"
    missing_count=$((missing_count + 1))
  fi
done < <(template_files "${TEMPLATES_DIR}")

if [ "${total}" -eq 0 ]; then
  # The conventions were already printed above; a non-zero exit would make
  # Claude Code discard that stdout, so degrade to a stderr warning instead.
  echo "stella-agentic-workflow-docs: no framework files found under ${TEMPLATES_DIR} — cannot check whether docs/ is bootstrapped." >&2
  exit 0
fi

if [ "${missing_count}" -gt 0 ]; then
  echo ""
  echo "NOTE: docs/ is not fully bootstrapped (${missing_count} of ${total} framework files missing):${missing}"
  echo "Run /stella-agentic-workflow-docs:docs-init (or execute \"${PLUGIN_ROOT}/scripts/init-docs.sh\") to create them before writing any docs."
fi

exit 0
