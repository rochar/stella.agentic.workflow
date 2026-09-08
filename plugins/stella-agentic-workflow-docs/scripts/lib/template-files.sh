#!/usr/bin/env bash
# Single definition of the framework files that make up the docs/ structure.
# scripts/init-docs.sh (which copies them) and hooks-handlers/session-start.sh
# (which checks whether they are present) both source this file, so the
# bootstrapper and the bootstrap check can never disagree about what is required.

# Prints one path per line, relative to the templates/docs/ tree.
# Usage: template_files <templates_dir>
template_files() {
  local templates_dir="$1" src
  find "${templates_dir}" -type f -name '*.md' | sort | while IFS= read -r src; do
    printf '%s\n' "${src#"${templates_dir}/"}"
  done
}
