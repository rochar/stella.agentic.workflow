#!/usr/bin/env bash
# SessionStart hook for stella-agentic-workflow-docs.
# Whatever this script prints to stdout is added to the session context,
# so every session (local CLI, desktop, or cloud) learns the docs/ conventions.
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
# scripts/init-docs.sh copies), so adding a folder there is picked up here too.
TEMPLATES_DIR="${PLUGIN_ROOT}/templates/docs"
if [ ! -d "${TEMPLATES_DIR}" ]; then
  echo "stella-agentic-workflow-docs: templates directory not found: ${TEMPLATES_DIR} — cannot check whether docs/ is bootstrapped." >&2
  exit 1
fi

missing=""
while IFS= read -r src; do
  rel="${src#"${TEMPLATES_DIR}/"}"                       # e.g. adrs/README.md
  if [ ! -f "${PROJECT_DIR}/docs/${rel}" ]; then
    dir="docs/${rel%README.md}"
    missing="${missing} ${dir%/}"
  fi
done < <(find "${TEMPLATES_DIR}" -type f -name 'README.md' | sort)

if [ -n "${missing}" ]; then
  echo ""
  echo "NOTE: this repository is missing the following documentation folders (or their README.md indexes):${missing}."
  echo "The structure is not bootstrapped yet. Run /stella-agentic-workflow-docs:docs-init"
  echo "(or execute \"${PLUGIN_ROOT}/scripts/init-docs.sh\") to create it before writing any docs."
fi

exit 0
