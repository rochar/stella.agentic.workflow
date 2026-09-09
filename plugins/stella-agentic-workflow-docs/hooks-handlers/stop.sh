#!/usr/bin/env bash
# Stop hook for stella-agentic-workflow-docs.
# Nudges the agent once per session to record anything durable the session
# produced (decision, plan, memory, learning) in docs/.
#
# Claude Code fires Stop at the end of every assistant turn, not once per
# session, so this hook keeps a per-session marker file (keyed on the payload's
# session_id) and nudges only the session's first stop — no hook can know which
# stop is the last. Emitting {"decision": "block", "reason": ...} on stdout
# makes the agent continue with the reason as guidance; when the incoming
# payload has stop_hook_active=true this stop cycle was already nudged, so exit
# 0 to let it through (never loop).
set -uo pipefail

input="$(cat)"

# Already continued once because of this hook's own block — never re-block the
# same stop cycle. Bash's own regex match avoids piping the (potentially large)
# payload through external tools. Quotes inside JSON string values arrive
# escaped as \", so this pattern can only match the structural top-level key.
re_active='"stop_hook_active"[[:space:]]*:[[:space:]]*true'
if [[ "${input}" =~ ${re_active} ]]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Fall back to self-location so the hook also works when run outside Claude
# Code (e.g. manual testing) where CLAUDE_PLUGIN_ROOT is not exported.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Nudge only when the docs structure is actually bootstrapped, using the same
# definition as session-start.sh (every templates/docs file present, via the
# helper all the scripts share) — a repo with an unrelated docs/ folder gets
# the bootstrap pointer at SessionStart, not a capture nudge pointing at
# README files that do not exist.
TEMPLATES_DIR="${PLUGIN_ROOT}/templates/docs"
[ -d "${TEMPLATES_DIR}" ] || exit 0
# shellcheck source=../scripts/lib/template-files.sh
. "${PLUGIN_ROOT}/scripts/lib/template-files.sh" 2>/dev/null || exit 0
while IFS= read -r rel; do
  [ -f "${PROJECT_DIR}/docs/${rel}" ] || exit 0
done < <(template_files "${TEMPLATES_DIR}")

# Once per session: record the nudge in a marker file before blocking, so every
# later stop of this session passes through. Without a session_id (e.g. manual
# invocation) fall back to relying on stop_hook_active alone; if the marker
# cannot be written, degrade the same way rather than blocking the stop.
re_sid='"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9._-]+)"'
if [[ "${input}" =~ ${re_sid} ]]; then
  marker_dir="${TMPDIR:-/tmp}/stella-agentic-workflow-docs"
  marker="${marker_dir}/nudged-${BASH_REMATCH[1]}"
  [ -e "${marker}" ] && exit 0
  mkdir -p "${marker_dir}" 2>/dev/null && : >"${marker}" 2>/dev/null
fi

cat <<'EOF'
{"decision": "block", "reason": "stella-agentic-workflow-docs: before finishing, check whether this session produced anything durable — an architectural decision (docs/adrs/), a plan worth keeping (docs/plans/), a fact a future session would otherwise rediscover (docs/memories/), or a lesson from something that failed (docs/learnings/). Each folder's README.md defines when a record qualifies and how to write it; update the folder index in the same change. If nothing qualifies — true for most sessions — finish now; do not invent records."}
EOF
