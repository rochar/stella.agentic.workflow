#!/usr/bin/env bash
# Automated version of the manual verification steps in CLAUDE.md ("Testing
# changes"). Run locally from anywhere inside the repository, and in CI by
# .github/workflows/ci.yml. Runs every check and exits non-zero if any failed.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="${REPO_ROOT}/plugins/stella-agentic-workflow-docs"
TEMPLATES_DIR="${PLUGIN_DIR}/templates/docs"
DOCS_DIR="${REPO_ROOT}/docs"

failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
note() { echo; echo "==> $*"; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

# --- 1. Every tracked JSON file parses -------------------------------------
note "JSON files parse"
while IFS= read -r f; do
  if jq empty "${REPO_ROOT}/${f}" 2>/dev/null; then
    echo "ok: ${f}"
  else
    fail "invalid JSON: ${f}"
  fi
done < <(git -C "${REPO_ROOT}" ls-files -c -o --exclude-standard '*.json')

# --- 2. shellcheck on tracked shell scripts ---------------------------------
note "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r f; do
    # -x + SCRIPTDIR follow the sourced lib via the scripts' shellcheck source= directives
    if shellcheck -x --source-path=SCRIPTDIR "${REPO_ROOT}/${f}"; then
      echo "ok: ${f}"
    else
      fail "shellcheck: ${f}"
    fi
  done < <(git -C "${REPO_ROOT}" ls-files -c -o --exclude-standard '*.sh')
else
  echo "shellcheck not installed — skipped (CI runs it)."
fi

# --- 3. init-docs.sh: bootstraps, is idempotent, never overwrites -----------
note "init-docs.sh bootstrap / idempotency / no-overwrite"
target="${TMP_ROOT}/bootstrap"
mkdir -p "${target}"

out1="$(bash "${PLUGIN_DIR}/scripts/init-docs.sh" "${target}")" \
  || fail "init-docs.sh first run exited non-zero"
case "${out1}" in
  Created:*) echo "ok: first run created the structure" ;;
  *) fail "first run did not report created files: ${out1}" ;;
esac

out2="$(bash "${PLUGIN_DIR}/scripts/init-docs.sh" "${target}")" \
  || fail "init-docs.sh second run exited non-zero"
case "${out2}" in
  *"nothing to do"*) echo "ok: second run had nothing to do" ;;
  *) fail "second run is not idempotent: ${out2}" ;;
esac

sentinel="local edit that must survive re-running init-docs"
echo "${sentinel}" >> "${target}/docs/adrs/README.md"
rm "${target}/docs/plans/README.md"
bash "${PLUGIN_DIR}/scripts/init-docs.sh" "${target}" >/dev/null \
  || fail "init-docs.sh third run exited non-zero"
if grep -qF "${sentinel}" "${target}/docs/adrs/README.md"; then
  echo "ok: existing file left untouched"
else
  fail "init-docs.sh overwrote an existing file"
fi
if [ -f "${target}/docs/plans/README.md" ]; then
  echo "ok: missing file was recreated"
else
  fail "init-docs.sh did not recreate a deleted file"
fi

# --- 4. session-start.sh hook smoke test ------------------------------------
note "session-start.sh hook"
context_probe="$(head -n 1 "${PLUGIN_DIR}/context/docs-structure.md")"

empty="${TMP_ROOT}/empty"
mkdir -p "${empty}"
hook_out="$(CLAUDE_PROJECT_DIR="${empty}" CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
  bash "${PLUGIN_DIR}/hooks-handlers/session-start.sh")" \
  || fail "hook exited non-zero in a repo without docs/"
case "${hook_out}" in
  *"${context_probe}"*) echo "ok: hook injects the docs conventions" ;;
  *) fail "hook did not print context/docs-structure.md" ;;
esac
case "${hook_out}" in
  *"not fully bootstrapped"*) echo "ok: hook flags a missing docs/ tree" ;;
  *) fail "hook did not flag the missing docs/ tree" ;;
esac

hook_out="$(CLAUDE_PROJECT_DIR="${target}" CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
  bash "${PLUGIN_DIR}/hooks-handlers/session-start.sh")" \
  || fail "hook exited non-zero in a bootstrapped repo"
case "${hook_out}" in
  *"not fully bootstrapped"*) fail "hook flagged a bootstrapped docs/ tree as missing files" ;;
  *) echo "ok: hook is quiet when docs/ is bootstrapped" ;;
esac

# --- 5. This repo's docs/ carries the templates/docs scaffold ----------------
# Per CLAUDE.md: every *.template.md matches byte-for-byte; folder README.md
# prose matches, but docs/ indexes may ADD record index lines; the only extra
# files allowed under docs/ are numbered records (NNNN-slug entries and their
# part files).
note "docs/ scaffold matches templates/docs"
failures_before=${failures}
# shellcheck source=../plugins/stella-agentic-workflow-docs/scripts/lib/template-files.sh
. "${PLUGIN_DIR}/scripts/lib/template-files.sh"

# template_files enumerates only *.md — a non-markdown file in templates/docs
# would be silently invisible to init-docs.sh and the hook, so forbid it here.
while IFS= read -r rel; do
  case "${rel}" in
    *.md) : ;;
    *) fail "non-markdown file in templates/docs (invisible to init-docs.sh and the hook): ${rel}" ;;
  esac
done < <(cd "${TEMPLATES_DIR}" && find . -type f | sed 's|^\./||' | sort)

while IFS= read -r rel; do
  tmpl="${TEMPLATES_DIR}/${rel}"
  inst="${DOCS_DIR}/${rel}"
  if [ ! -f "${inst}" ]; then
    fail "scaffold file missing from docs/: docs/${rel}"
    continue
  fi
  case "${rel}" in
    *README.md)
      # Additions (index lines) are fine; changed or removed template prose is not.
      # (diff exits 1 on any difference, so under pipefail its output is
      # captured and tested rather than used as a pipeline exit status.)
      removed="$(diff -u "${tmpl}" "${inst}" | grep '^-' | grep -v '^--- ' || true)"
      if [ -n "${removed}" ]; then
        fail "README prose diverged from template (only added index lines are allowed): docs/${rel}"
      fi
      ;;
    *)
      if ! cmp -s "${tmpl}" "${inst}"; then
        fail "must match templates/docs byte-for-byte: docs/${rel}"
      fi
      ;;
  esac
done < <(template_files "${TEMPLATES_DIR}")

while IFS= read -r rel; do
  if [ ! -f "${TEMPLATES_DIR}/${rel}" ]; then
    case "/${rel}" in
      */[0-9][0-9][0-9][0-9]-*) : ;; # numbered record entry — expected
      *)
        fail "unexpected non-record file under docs/: docs/${rel}"
        ;;
    esac
  fi
done < <(cd "${DOCS_DIR}" && find . -type f | sed 's|^\./||' | sort)
[ "${failures}" -eq "${failures_before}" ] && echo "ok: scaffold in sync"

# --- summary -----------------------------------------------------------------
echo
if [ "${failures}" -gt 0 ]; then
  echo "${failures} check(s) FAILED." >&2
  exit 1
fi
echo "All checks passed."
