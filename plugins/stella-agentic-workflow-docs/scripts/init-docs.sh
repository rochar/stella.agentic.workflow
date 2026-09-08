#!/usr/bin/env bash
# Bootstraps the standard agentic docs/ structure in a repository by copying the
# plugin's templates/docs/ tree. templates/docs/ is the single source of truth for
# the structure: adding a folder or index there is picked up here automatically.
# Idempotent: creates only what is missing and never overwrites an existing file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates/docs"

TARGET_DIR="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
DOCS_DIR="${TARGET_DIR}/docs"

if [ ! -d "${TEMPLATES_DIR}" ]; then
  echo "error: templates directory not found: ${TEMPLATES_DIR}" >&2
  exit 1
fi

created=""

copy_if_missing() {
  local src="$1" dest="$2"
  if [ -e "${dest}" ] || [ -L "${dest}" ]; then
    if [ ! -f "${dest}" ]; then
      echo "warning: ${dest} exists but is not a regular file — leaving it untouched." >&2
    fi
    return 0
  fi
  cp "${src}" "${dest}"
  created="${created}"$'\n'"  ${dest}"
}

while IFS= read -r src; do
  rel="${src#"${TEMPLATES_DIR}/"}"
  dest="${DOCS_DIR}/${rel}"
  mkdir -p "$(dirname "${dest}")"
  copy_if_missing "${src}" "${dest}"
done < <(find "${TEMPLATES_DIR}" -type f -name '*.md' | sort)

if [ -n "${created}" ]; then
  printf 'Created:%s\n' "${created}"
else
  echo "docs/ structure already present in ${TARGET_DIR} — nothing to do."
fi
