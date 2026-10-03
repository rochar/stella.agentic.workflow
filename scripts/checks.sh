#!/usr/bin/env bash
# Repository checks (see CLAUDE.md, "Tests").
# Run locally from anywhere inside the repository, and in CI by
# .github/workflows/ci.yml. Runs every check and exits non-zero if any failed.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="${REPO_ROOT}/plugins/stella-agentic-workflow-docs"
TEMPLATES_DIR="${PLUGIN_DIR}/templates/docs"
DOCS_DIR="${REPO_ROOT}/docs"
CONTEXT_FILE="${PLUGIN_DIR}/context/docs-structure.md"

failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
note() { echo; echo "==> $*"; }
# Character count independent of locale (${#var} counts bytes under LC_ALL=C).
char_len() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

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
context_probe="$(head -n 1 "${CONTEXT_FILE}")"

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
  *"not fully bootstrapped"*"docs-init"*) echo "ok: hook flags a missing docs/ tree" ;;
  *) fail "hook did not flag the missing docs/ tree (or did not point at docs-init)" ;;
esac

# A partial tree (typically an older plugin version's bootstrap) needs the
# doctor, not just docs-init's backfill.
partial="${TMP_ROOT}/partial"
bash "${PLUGIN_DIR}/scripts/init-docs.sh" "${partial}" >/dev/null
rm -r "${partial}/docs/specs"
hook_out="$(CLAUDE_PROJECT_DIR="${partial}" CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
  bash "${PLUGIN_DIR}/hooks-handlers/session-start.sh")" \
  || fail "hook exited non-zero in a partially bootstrapped repo"
case "${hook_out}" in
  *"not fully bootstrapped"*"docs-doctor"*) echo "ok: hook points a partial docs/ tree at docs-doctor" ;;
  *) fail "hook did not point a partial docs/ tree at docs-doctor: ${hook_out}" ;;
esac

hook_out="$(CLAUDE_PROJECT_DIR="${target}" CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
  bash "${PLUGIN_DIR}/hooks-handlers/session-start.sh")" \
  || fail "hook exited non-zero in a bootstrapped repo"
case "${hook_out}" in
  *"not fully bootstrapped"*) fail "hook flagged a bootstrapped docs/ tree as missing files" ;;
  *) echo "ok: hook is quiet when docs/ is bootstrapped" ;;
esac

# --- 4b. stop.sh hook smoke test ---------------------------------------------
note "stop.sh hook"

# Session markers land under TMPDIR — point it at our temp root so runs are
# hermetic and the EXIT trap cleans the markers up.
run_stop() { # $1 = stop_hook_active, $2 = project dir, $3 = session id
  printf '{"session_id": "%s", "stop_hook_active": %s}' "$3" "$1" \
    | TMPDIR="${TMP_ROOT}" CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
      bash "${PLUGIN_DIR}/hooks-handlers/stop.sh"
}
sid="checks-$$"

stop_out="$(run_stop false "${target}" "${sid}")" \
  || fail "stop hook exited non-zero on a session's first stop with docs/"
if printf '%s' "${stop_out}" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  echo "ok: stop hook emits a valid JSON block decision on the session's first stop"
else
  fail "stop hook did not emit a valid block decision on the first stop: ${stop_out}"
fi

stop_out="$(run_stop false "${target}" "${sid}")" \
  || fail "stop hook exited non-zero on a later stop of the same session"
if [ -z "${stop_out}" ]; then
  echo "ok: stop hook nudges the same session only once"
else
  fail "stop hook nudged the same session twice: ${stop_out}"
fi

stop_out="$(run_stop true "${target}" "${sid}-active")" \
  || fail "stop hook exited non-zero when stop_hook_active is true"
if [ -z "${stop_out}" ]; then
  echo "ok: stop hook never blocks the same stop twice"
else
  fail "stop hook blocked again despite stop_hook_active: ${stop_out}"
fi

stop_out="$(run_stop false "${empty}" "${sid}-empty")" \
  || fail "stop hook exited non-zero in a repo without docs/"
if [ -z "${stop_out}" ]; then
  echo "ok: stop hook is silent without a docs/ tree"
else
  fail "stop hook nudged a repo that has no docs/ tree: ${stop_out}"
fi

plain="${TMP_ROOT}/plain"
mkdir -p "${plain}/docs"
stop_out="$(run_stop false "${plain}" "${sid}-plain")" \
  || fail "stop hook exited non-zero in a repo with a non-framework docs/"
if [ -z "${stop_out}" ]; then
  echo "ok: stop hook is silent when docs/ is not bootstrapped"
else
  fail "stop hook nudged a non-framework docs/ folder: ${stop_out}"
fi

# Without CLAUDE_PLUGIN_ROOT the hook must self-locate (the path
# for manual runs); run_stop covers the env-provided production path.
stop_out="$(printf '{"session_id": "%s", "stop_hook_active": false}' "${sid}-noenv" \
  | TMPDIR="${TMP_ROOT}" CLAUDE_PROJECT_DIR="${target}" \
    bash "${PLUGIN_DIR}/hooks-handlers/stop.sh")" \
  || fail "stop hook exited non-zero without CLAUDE_PLUGIN_ROOT"
if printf '%s' "${stop_out}" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  echo "ok: stop hook self-locates when CLAUDE_PLUGIN_ROOT is unset"
else
  fail "stop hook did not nudge via self-location fallback: ${stop_out}"
fi

# --- 5. This repo's docs/ carries the templates/docs scaffold ----------------
# Per CLAUDE.md: every *.template.md matches byte-for-byte; folder README.md
# prose matches, but docs/ indexes may ADD record index lines; the only extra
# files allowed under docs/ are dated records (PREFIX-YYYYMMDD-slug.md files).
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
      readme_diff="$(diff -u "${tmpl}" "${inst}" || true)"
      # The index placeholder goes once the first index line is added.
      removed="$(printf '%s' "${readme_diff}" | grep '^-' | grep -v '^--- ' | grep -vE '^-_No .* yet\._$' || true)"
      if [ -n "${removed}" ]; then
        fail "README prose diverged from template (only added index lines are allowed): docs/${rel}"
      fi
      # The added lines are index lines; the folder READMEs cap them at 120 characters.
      while IFS= read -r added; do
        added="${added#+}"
        [ -n "${added}" ] || continue
        len="$(char_len "${added}")"
        if [ "${len}" -gt 120 ]; then
          fail "index line over 120 characters (${len}) in docs/${rel}: ${added}"
        fi
      done < <(printf '%s' "${readme_diff}" | grep '^+' | grep -v '^+++ ' || true)
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
    case "${rel}" in
      */*/*) fail "unexpected nested file under docs/ (records are single files): docs/${rel}" ;;
      */[A-Z]*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*.md) : ;; # dated record file — expected
      *)
        fail "unexpected non-record file under docs/: docs/${rel}"
        ;;
    esac
  fi
done < <(cd "${DOCS_DIR}" && find . -type f | sed 's|^\./||' | sort)
[ "${failures}" -eq "${failures_before}" ] && echo "ok: scaffold in sync"

# --- 5b. doctor-docs.sh: clean trees pass, drift is found and repaired -------
note "doctor-docs.sh"
DOCTOR="${PLUGIN_DIR}/scripts/doctor-docs.sh"

fresh="${TMP_ROOT}/doctor-fresh"
mkdir -p "${fresh}"
bash "${PLUGIN_DIR}/scripts/init-docs.sh" "${fresh}" >/dev/null
if bash "${DOCTOR}" "${fresh}" >/dev/null; then
  echo "ok: a fresh bootstrap conforms"
else
  fail "doctor reports findings on a fresh bootstrap (a template without an \`id: <PREFIX>-YYYYMMDD-slug\` line?)"
fi
if bash "${DOCTOR}" "${REPO_ROOT}" >/dev/null; then
  echo "ok: this repository's docs/ conforms"
else
  fail "doctor reports findings on this repository's docs/: run scripts/doctor-docs.sh here"
fi

drift="${TMP_ROOT}/doctor-drift"
cp -R "${fresh}" "${drift}"
# fill_record <template> <out> <sed-expr>: a record built from its template,
# every <placeholder> line filled, then the given front-matter edits applied.
fill_record() {
  sed 's/^<.*/Filled./; s/: <.*/: filled/; s/YYYY-MM-DD/2026-01-01/g' "$1" | sed "$3" > "$2"
}
index_line="- PLAN-20260101-add-cache — done — Cache responses"
fill_record "${TEMPLATES_DIR}/plans/plan.template.md" "${drift}/docs/plans/PLAN-20260101-add-cache.md" \
  's/^id: .*/id: PLAN-20260101-add-cache/; s/^status: proposed/status: done/; s/^spec: .*/spec: none/; s/^adrs: .*/adrs: ADR-20260101-use-x, ADR-20260102-other/'
sed -i.bak "s/^_No plans yet\._\$/${index_line}/; s/^Plans produced/Plans (old wording) produced/" \
  "${drift}/docs/plans/README.md" && rm "${drift}/docs/plans/README.md.bak"
echo "stale" >> "${drift}/docs/adrs/adr.template.md"
echo "# old" > "${drift}/docs/plans/problem.template.md"
rm "${drift}/docs/specs/README.md"
echo "# 0001 — Wrong layout" > "${drift}/docs/memories/0001-wrong-layout.txt"

doctor_out="$(bash "${DOCTOR}" "${drift}")" && fail "doctor exited 0 on a drifted tree"
for code in README_DRIFT TEMPLATE_DRIFT OBSOLETE_TEMPLATE MISSING BAD_NAME; do
  case "${doctor_out}" in
    *"] ${code} "*) echo "ok: doctor reports ${code}" ;;
    *) fail "doctor did not report ${code}: ${doctor_out}" ;;
  esac
done
case "${doctor_out}" in
  *PLAN-20260101-add-cache*) fail "doctor flagged a conforming record: ${doctor_out}" ;;
esac

bash "${DOCTOR}" --fix "${drift}" >/dev/null
if grep -qxF -- "${index_line}" "${drift}/docs/plans/README.md" \
  && cmp -s <(sed '/^## Index$/q' "${TEMPLATES_DIR}/plans/README.md") \
            <(sed '/^## Index$/q' "${drift}/docs/plans/README.md"); then
  echo "ok: --fix refreshes README prose and keeps index lines"
else
  fail "--fix did not refresh docs/plans/README.md prose while keeping its index line"
fi
if [ ! -e "${drift}/docs/plans/problem.template.md" ] && [ -f "${drift}/docs/specs/README.md" ] \
  && cmp -s "${TEMPLATES_DIR}/adrs/adr.template.md" "${drift}/docs/adrs/adr.template.md"; then
  echo "ok: --fix repairs missing, drifted, and obsolete scaffold files"
else
  fail "--fix did not repair the scaffold"
fi
# OS metadata files are never findings; --fix never deletes a *.template.md in
# a folder the plugin does not own; index-line length counts characters, not
# bytes, whatever the locale.
touch "${drift}/docs/.DS_Store" "${drift}/docs/plans/.DS_Store"
mkdir -p "${drift}/docs/guides"
echo "# team template" > "${drift}/docs/guides/runbook.template.md"
printf -- '---\nid: PLAN-20260103-long-summary\nstatus: abandoned\ndate: 2026-01-03\nspec: none\nadrs: none\nsummary: Long\n---\n' \
  > "${drift}/docs/plans/PLAN-20260103-long-summary.md"
# exactly 120 characters (126 bytes: each em dash is three)
long_line="- PLAN-20260103-long-summary — abandoned — $(printf 'x%.0s' $(seq 1 77))"
echo "${long_line}" >> "${drift}/docs/plans/README.md"
doctor_out="$(LC_ALL=C bash "${DOCTOR}" --fix "${drift}")"
case "${doctor_out}" in
  *.DS_Store*|*LINE_TOO_LONG*) fail "doctor flagged OS metadata or a <=120-char index line: ${doctor_out}" ;;
esac
if [ -f "${drift}/docs/guides/runbook.template.md" ]; then
  echo "ok: --fix leaves templates outside the scaffold locations alone"
else
  fail "--fix deleted a *.template.md outside the plugin's scaffold locations"
fi
rm -r "${drift}/docs/guides"
# An abandoned record may be a pointer stub without the template's sections.
printf -- '---\nid: PLAN-20260102-old-pointer\nstatus: abandoned\ndate: 2026-01-02\nspec: none\nadrs: none\nsummary: Moved to SPEC-20260101-x\n---\nMoved to SPEC-20260101-x.\n' \
  > "${drift}/docs/plans/PLAN-20260102-old-pointer.md"
echo "- PLAN-20260102-old-pointer — abandoned — Moved to SPEC-20260101-x" >> "${drift}/docs/plans/README.md"
rm "${drift}/docs/memories/0001-wrong-layout.txt"
# Every folder's records are prefixed single files checked by their front
# matter; the pre-0.3.0 directory layout and unprefixed names are findings.
adrs="${drift}/docs/adrs"
fill_record "${TEMPLATES_DIR}/adrs/adr.template.md" "${adrs}/ADR-20260101-use-x.md" \
  's/^id: .*/id: ADR-20260101-use-x/; s/^status: proposed/status: accepted/'
sed -i.bak 's/^_No ADRs yet\._$/- ADR-20260101-use-x — accepted — Use X/' "${adrs}/README.md" \
  && rm "${adrs}/README.md.bak"
fill_record "${TEMPLATES_DIR}/memories/memory.template.md" "${drift}/docs/memories/MEM-20260101-a-fact.md" \
  's/^id: .*/id: MEM-20260101-a-fact/'
echo "- MEM-20260101-a-fact — environment — A fact" >> "${drift}/docs/memories/README.md"
sed -i.bak '/^_No memories yet\._$/d' "${drift}/docs/memories/README.md" && rm "${drift}/docs/memories/README.md.bak"
sed 's/^id: .*/id: ADR-20260101-bad-one/; s/^status: .*/status: bogus/; /^summary:/d' "${adrs}/ADR-20260101-use-x.md" \
  > "${adrs}/ADR-20260101-bad-one.md"
mkdir -p "${adrs}/0003-old-layout" && echo "# 0003 — Old" > "${adrs}/0003-old-layout/decision.md"
echo "# 0004 — Bare" > "${adrs}/0004-bare.md"
# Unfilled `Binds:` line, a value that is not valid YAML unquoted, a wrong-case
# prefix, and front matter that never closes.
sed 's/^id: .*/id: ADR-20260101-raw-binds/; s/^Binds: .*/Binds: <what future work must respect>/; s/^summary: .*/summary: Use X: it is fast/' \
  "${adrs}/ADR-20260101-use-x.md" > "${adrs}/ADR-20260101-raw-binds.md"
cp "${adrs}/ADR-20260101-use-x.md" "${adrs}/adr-20260101-lower-case.md"
{ echo "---"; sed 's/^id: .*/id: ADR-20260101-unclosed/; /^---$/d' "${adrs}/ADR-20260101-use-x.md"; } > "${adrs}/ADR-20260101-unclosed.md"
# Dated naming: a pre-0.4.0 sequence-numbered record and its old-format index
# line, an id that is not the file stem, a date: that differs from the name, an
# impossible date, and a superseded-by that is not a dated id.
sed 's/^id: .*/id: ADR-0008/' "${adrs}/ADR-20260101-use-x.md" > "${adrs}/ADR-0008-legacy.md"
echo "- ADR-0008-legacy — accepted — 2026-01-01 — Legacy" >> "${adrs}/README.md"
sed 's/^id: .*/id: ADR-20260101-other/' "${adrs}/ADR-20260101-use-x.md" > "${adrs}/ADR-20260101-wrong-id.md"
sed 's/^id: .*/id: ADR-20260202-wrong-date/' "${adrs}/ADR-20260101-use-x.md" > "${adrs}/ADR-20260202-wrong-date.md"
sed 's/^id: .*/id: ADR-20261301-bad-month/; s/^date: .*/date: 2026-13-01/' "${adrs}/ADR-20260101-use-x.md" \
  > "${adrs}/ADR-20261301-bad-month.md"
sed 's/^id: .*/id: ADR-20260101-old-ref/; s/^status: .*/status: superseded/; s/^superseded-by:.*/superseded-by: ADR-0001/' \
  "${adrs}/ADR-20260101-use-x.md" > "${adrs}/ADR-20260101-old-ref.md"
# A date with nine digits, a calendar date that does not exist, a plan still
# referencing a sequence-numbered spec, and an index line that kept its old
# date column after the record was renamed.
cp "${adrs}/ADR-20260101-use-x.md" "${adrs}/ADR-202601011-typo.md"
sed 's/^id: .*/id: ADR-20260231-feb-thirty/; s/^date: .*/date: 2026-02-31/' "${adrs}/ADR-20260101-use-x.md" \
  > "${adrs}/ADR-20260231-feb-thirty.md"
sed 's/^id: .*/id: PLAN-20260101-old-refs/; s/^spec: .*/spec: SPEC-0001-old/' \
  "${drift}/docs/plans/PLAN-20260101-add-cache.md" > "${drift}/docs/plans/PLAN-20260101-old-refs.md"
fill_record "${TEMPLATES_DIR}/learnings/learning.template.md" "${drift}/docs/learnings/LRN-20260101-a-lesson.md" \
  's/^id: .*/id: LRN-20260101-a-lesson/'
sed -i.bak 's/^_No learnings yet\._$/- LRN-20260101-a-lesson — 2026-01-01 — A lesson/' "${drift}/docs/learnings/README.md" \
  && rm "${drift}/docs/learnings/README.md.bak"
doctor_out="$(bash "${DOCTOR}" "${drift}")"
for expect in "WRONG_LAYOUT docs/adrs/0003-old-layout/" "BAD_NAME docs/adrs/0004-bare.md" \
  "INVALID_VALUE docs/adrs/ADR-20260101-bad-one.md — status" "MISSING_FIELD docs/adrs/ADR-20260101-bad-one.md" \
  "UNFILLED_PLACEHOLDER docs/adrs/ADR-20260101-raw-binds.md — still contains template text: Binds:" \
  "INVALID_VALUE docs/adrs/ADR-20260101-raw-binds.md — \`summary:\`" "BAD_NAME docs/adrs/adr-20260101-lower-case.md" \
  "MISSING_FRONT_MATTER docs/adrs/ADR-20260101-unclosed.md" "NUMBERED_ID docs/adrs/ADR-0008-legacy.md" \
  "INDEX_FORMAT docs/adrs/README.md — expected \`- ADR-YYYYMMDD-slug — status — one-line summary\`: - ADR-0008-legacy" \
  "INVALID_VALUE docs/adrs/ADR-20260101-wrong-id.md — id 'ADR-20260101-other' must be the file stem" \
  "INVALID_VALUE docs/adrs/ADR-20260202-wrong-date.md — date '2026-01-01' does not match" \
  "BAD_NAME docs/adrs/ADR-20261301-bad-month.md — '20261301' in the name is not a YYYYMMDD date" \
  "INVALID_VALUE docs/adrs/ADR-20260101-old-ref.md — status superseded needs" \
  "BAD_NAME docs/adrs/ADR-202601011-typo.md" \
  "BAD_NAME docs/adrs/ADR-20260231-feb-thirty.md — '20260231' in the name is not a YYYYMMDD date" \
  "INVALID_VALUE docs/plans/PLAN-20260101-old-refs.md — spec 'SPEC-0001-old' is not a SPEC-YYYYMMDD-slug id" \
  "INDEX_FORMAT docs/learnings/README.md — LRN-20260101-a-lesson: drop the old date column"; do
  case "${doctor_out}" in
    *"] ${expect}"*) echo "ok: doctor reports ${expect}" ;;
    *) fail "doctor did not report ${expect}: ${doctor_out}" ;;
  esac
done
case "${doctor_out}" in
  *ADR-20260101-use-x*|*MEM-20260101-a-fact*|*PLAN-20260101-add-cache*) fail "doctor flagged a conforming record: ${doctor_out}" ;;
esac
rm -r "${adrs}/ADR-20260101-bad-one.md" "${adrs}/0003-old-layout" "${adrs}/0004-bare.md" \
  "${adrs}/ADR-20260101-raw-binds.md" "${adrs}/adr-20260101-lower-case.md" "${adrs}/ADR-20260101-unclosed.md" \
  "${adrs}/ADR-0008-legacy.md" "${adrs}/ADR-20260101-wrong-id.md" "${adrs}/ADR-20260202-wrong-date.md" \
  "${adrs}/ADR-20261301-bad-month.md" "${adrs}/ADR-20260101-old-ref.md" "${adrs}/ADR-202601011-typo.md" \
  "${adrs}/ADR-20260231-feb-thirty.md" "${drift}/docs/plans/PLAN-20260101-old-refs.md"
sed -i.bak '/^- ADR-0008-legacy /d' "${adrs}/README.md" && rm "${adrs}/README.md.bak"
sed -i.bak 's/^- LRN-20260101-a-lesson — 2026-01-01 — /- LRN-20260101-a-lesson — /' "${drift}/docs/learnings/README.md" \
  && rm "${drift}/docs/learnings/README.md.bak"
if LC_ALL=C bash "${DOCTOR}" "${drift}" >/dev/null; then
  echo "ok: tree conforms once the record findings are resolved (abandoned pointer stub allowed)"
else
  fail "doctor still reports findings after --fix and the record fixes: $(bash "${DOCTOR}" "${drift}")"
fi

# --- 6. Injected context stays within its word budget ------------------------
# context/docs-structure.md is added to every session of every consuming repo;
# CLAUDE.md requires it to stay a thin pointer. The budget is a ratchet against
# creep — if a change genuinely needs more room, raise it deliberately here.
note "injected context word budget"
CONTEXT_WORD_BUDGET=200
if [ -f "${CONTEXT_FILE}" ]; then
  # wc -w is the same command CLAUDE.md documents for the manual check.
  context_words="$(( $(wc -w < "${CONTEXT_FILE}") ))"
  if [ "${context_words}" -le "${CONTEXT_WORD_BUDGET}" ]; then
    echo "ok: context/docs-structure.md is ${context_words} words (budget ${CONTEXT_WORD_BUDGET})"
  else
    fail "context/docs-structure.md is ${context_words} words, over the ${CONTEXT_WORD_BUDGET}-word budget — it is injected into every session of every consuming repo; trim it or move detail into the folder READMEs"
  fi
else
  fail "injected context file is missing (was it moved without updating checks.sh?): ${CONTEXT_FILE}"
fi

# --- summary -----------------------------------------------------------------
echo
if [ "${failures}" -gt 0 ]; then
  echo "${failures} check(s) FAILED." >&2
  exit 1
fi
echo "All checks passed."
