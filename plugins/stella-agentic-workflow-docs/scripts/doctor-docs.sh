#!/usr/bin/env bash
# Diagnoses how far a repository's docs/ tree is from the conventions of the
# plugin's templates/docs/ scaffold — the structural half of the docs-doctor
# skill. Everything it checks is derived from templates/docs/ (scaffold files,
# part files, template fields and sections, index-line formats), so a template
# change is picked up here automatically; only each folder's record layout
# (directory vs single file) is encoded below, mirroring the folder READMEs.
#
# Usage: doctor-docs.sh [--fix] [target-dir]
#   --fix  also repair scaffold findings in place: create missing scaffold
#          files, restore drifted *.template.md, refresh folder README prose
#          while keeping their index lines, remove obsolete *.template.md.
#          Records are never touched; they need judgment (the skill's job).
#
# Output: one finding per line, `[category] CODE path — message`, where
# category is scaffold (mechanical), record (a record or index line breaks a
# convention), or stray (content outside the conventions to reconcile).
# Exit: 0 conforms (stray items are advisory), 1 scaffold or record findings
# remain, 2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/../templates/docs"

# shellcheck source=lib/template-files.sh
. "${SCRIPT_DIR}/lib/template-files.sh"

FIX=0
TARGET_DIR=""
for arg in "$@"; do
  case "${arg}" in
    --fix) FIX=1 ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "error: unknown option: ${arg}" >&2; exit 2 ;;
    *) TARGET_DIR="${arg}" ;;
  esac
done
TARGET_DIR="${TARGET_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
DOCS_DIR="${TARGET_DIR}/docs"

if [ ! -d "${TEMPLATES_DIR}" ]; then
  echo "error: templates directory not found: ${TEMPLATES_DIR}" >&2
  exit 2
fi

n_scaffold=0 n_record=0 n_stray=0 n_fixed=0
report() { # category code path message
  printf '[%s] %s %s — %s\n' "$1" "$2" "$3" "$4"
  case "$1" in
    scaffold) n_scaffold=$((n_scaffold + 1)) ;;
    record) n_record=$((n_record + 1)) ;;
    stray) n_stray=$((n_stray + 1)) ;;
  esac
}
fixed() { # code path message
  printf '[fixed] %s %s — %s\n' "$1" "$2" "$3"
  n_fixed=$((n_fixed + 1))
}

# Record layout per folder, as the folder READMEs' Naming rules define it:
# "dir <main part>" for NNNN-slug/ directories, "file" for NNNN-slug.md files.
layout_of() {
  case "$1" in
    adrs) echo "dir decision.md" ;;
    specs) echo "dir spec.md" ;;
    plans) echo "dir plan.md" ;;
    memories|learnings) echo "file" ;;
    *) echo "unknown" ;;
  esac
}

# Rebuilds a folder README: the template's prose up to `## Index`, followed by
# the index lines currently in the file (placeholder dropped when there are any).
rebuild_readme() { # template current
  local tmpl="$1" cur="$2" body
  if grep -q '^## Index$' "${cur}"; then
    body="$(sed -n '/^## Index$/,$p' "${cur}" | sed '1d')"
  else
    body="$(grep -E '^- [0-9]{4}-' "${cur}" || true)"
  fi
  body="$(printf '%s\n' "${body}" | grep -vE '^_No .* yet\._$' | sed '/./,$!d' || true)"
  sed '/^## Index$/q' "${tmpl}"
  echo
  if printf '%s\n' "${body}" | grep -q '^- '; then
    # trim trailing blank lines
    printf '%s\n' "${body}" | awk 'NF{for(;b>0;b--)print "";print;next}{b++}'
  else
    sed -n '/^## Index$/,$p' "${tmpl}" | sed '1d' | sed '/./,$!d'
  fi
}

rel_path() { printf '%s' "${1#"${TARGET_DIR}/"}"; }

# OS metadata files that file managers drop into any folder they open; never
# content, so never findings.
is_os_junk() { case "$1" in .DS_Store|Thumbs.db|desktop.ini) return 0 ;; esac; return 1; }

# Length in characters, not bytes, whatever the locale: count the bytes that
# are not UTF-8 continuation bytes (0x80-0xBF). `${#var}` counts bytes under
# LC_ALL=C, which would count each em dash of an index line as three.
char_len() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

# --- 1. Scaffold -------------------------------------------------------------
if [ ! -d "${DOCS_DIR}" ]; then
  if [ "${FIX}" -eq 1 ]; then
    mkdir -p "${DOCS_DIR}"
    fixed NO_DOCS docs/ "created docs/"
  else
    report scaffold NO_DOCS docs/ "docs/ does not exist; run docs-init (or this script with --fix)"
  fi
fi

TEMPLATE_LIST="$(template_files "${TEMPLATES_DIR}")"

while IFS= read -r rel; do
  [ -n "${rel}" ] || continue
  tmpl="${TEMPLATES_DIR}/${rel}"
  inst="${DOCS_DIR}/${rel}"
  if [ ! -f "${inst}" ]; then
    [ -d "${DOCS_DIR}" ] || continue # already reported as NO_DOCS
    if [ "${FIX}" -eq 1 ]; then
      mkdir -p "$(dirname "${inst}")" && cp "${tmpl}" "${inst}"
      fixed MISSING "docs/${rel}" "created from the plugin scaffold"
    else
      report scaffold MISSING "docs/${rel}" "scaffold file missing"
    fi
    continue
  fi
  case "${rel}" in
    */README.md)
      expected="$(rebuild_readme "${tmpl}" "${inst}")"
      if [ "${expected}" != "$(cat "${inst}")" ]; then
        if [ "${FIX}" -eq 1 ]; then
          printf '%s\n' "${expected}" > "${inst}"
          fixed README_DRIFT "docs/${rel}" "prose refreshed from the plugin template; index lines kept"
        else
          report scaffold README_DRIFT "docs/${rel}" "prose or index placeholder differs from the plugin template"
        fi
      fi
      ;;
    README.md)
      # Root README: no index section. Extra lines (e.g. table rows a team added)
      # are allowed; missing or changed template lines are drift.
      removed="$(diff "${tmpl}" "${inst}" | grep '^< ' || true)"
      added="$(diff "${tmpl}" "${inst}" | grep '^> ' || true)"
      if [ -n "${removed}" ]; then
        if [ "${FIX}" -eq 1 ] && [ -z "${added}" ]; then
          cp "${tmpl}" "${inst}"
          fixed README_DRIFT "docs/${rel}" "restored from the plugin template"
        elif [ "${FIX}" -eq 1 ]; then
          report scaffold README_MERGE "docs/${rel}" "differs from the plugin template and has local additions; merge by hand"
        else
          report scaffold README_DRIFT "docs/${rel}" "differs from the plugin template"
        fi
      fi
      ;;
    *)
      if ! cmp -s "${tmpl}" "${inst}"; then
        if [ "${FIX}" -eq 1 ]; then
          cp "${tmpl}" "${inst}"
          fixed TEMPLATE_DRIFT "docs/${rel}" "restored from the plugin template"
        else
          report scaffold TEMPLATE_DRIFT "docs/${rel}" "differs from the plugin template"
        fi
      fi
      ;;
  esac
done <<< "${TEMPLATE_LIST}"

# Only scaffold locations are scanned — docs/ itself and the plugin's folders,
# never record directories or folders the plugin does not own — so --fix can
# never delete a record's file or a team's own templates.
if [ -d "${DOCS_DIR}" ]; then
  while IFS= read -r f; do
    [ -n "${f}" ] || continue
    rel="${f#"${DOCS_DIR}/"}"
    case "${rel}" in
      */*) [ -d "${TEMPLATES_DIR}/${rel%%/*}" ] || continue ;;
    esac
    if ! printf '%s\n' "${TEMPLATE_LIST}" | grep -qxF "${rel}"; then
      if [ "${FIX}" -eq 1 ]; then
        rm "${f}"
        fixed OBSOLETE_TEMPLATE "docs/${rel}" "removed: no longer part of the plugin scaffold"
      else
        report scaffold OBSOLETE_TEMPLATE "docs/${rel}" "template no longer in the plugin scaffold (left over from an older version)"
      fi
    fi
  done < <(find "${DOCS_DIR}" -maxdepth 2 -type f -name '*.template.md' | sort)
fi

# --- 2. Records and indexes --------------------------------------------------
# Checks one record part against its template: title, metadata fields (the
# `- Key:` lines above the first section) and their vocabularies, required sections, unfilled placeholder text.
check_part() { # template part-file record-number
  local tmpl="$1" part="$2" num="$3" rp key vocab value line heading
  rp="$(rel_path "${part}")"
  if ! head -n 1 "${part}" | grep -qE "^# ${num} — ."; then
    report record BAD_TITLE "${rp}" "first line must be \`# ${num} — <title>\`"
  fi
  while IFS= read -r line; do
    key="${line#- }"; key="${key%%:*}"
    vocab="${line#*: }"
    value="$(sed -n "s/^- ${key}: *//p" "${part}" | head -n 1)"
    if ! grep -qE "^- ${key}:" "${part}"; then
      report record MISSING_FIELD "${rp}" "no \`- ${key}:\` line"
      continue
    fi
    case "${vocab}" in
      YYYY-MM-DD)
        printf '%s' "${value}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
          || report record INVALID_VALUE "${rp}" "${key} '${value}' is not YYYY-MM-DD"
        ;;
      *"<"*) : ;; # free text
      *" | "*)
        pattern="$(printf '%s' "${vocab}" | sed 's/ | /|/g; s/NNNN/[0-9]{4}/g')"
        printf '%s' "${value}" | grep -qxE "(${pattern})" \
          || report record INVALID_VALUE "${rp}" "${key} '${value}' is not one of: ${vocab}"
        ;;
    esac
  done < <(awk '/^## /{exit} {print}' "${tmpl}" | grep -E '^- [A-Z][A-Za-z]*: ')
  # An abandoned record is history and may be kept as a pointer stub (metadata
  # plus one line saying where its content went), so its sections are not required.
  grep -qE '^- Status: abandoned$' "${part}" && return 0
  # A `## ` section is required unless its first line is an `<optional...` hint.
  while IFS= read -r heading; do
    grep -qxF "${heading}" "${part}" \
      || report record MISSING_SECTION "${rp}" "no \`${heading}\` section"
  done < <(awk '/^## /{h=$0; next} h!="" && NF{ if ($0 !~ /^<optional/) print h; h="" }' "${tmpl}")
  while IFS= read -r line; do
    if grep -qxF "${line}" "${part}"; then
      report record UNFILLED_PLACEHOLDER "${rp}" "still contains template text: ${line}"
      break
    fi
  done < <(grep -E '^<' "${tmpl}")
}

for tdir in "${TEMPLATES_DIR}"/*/; do
  folder="$(basename "${tdir}")"
  fdir="${DOCS_DIR}/${folder}"
  [ -d "${fdir}" ] || continue
  layout="$(layout_of "${folder}")"
  if [ "${layout}" = "unknown" ]; then
    report scaffold UNKNOWN_LAYOUT "docs/${folder}/" "doctor-docs.sh has no record layout for this folder; update layout_of()"
    continue
  fi
  main_part="${layout#dir }"
  parts="$(find "${tdir}" -maxdepth 1 -type f -name '*.template.md' -exec basename {} \; | sort | sed 's/\.template\.md$/.md/')"
  records="" numbers=""

  for entry in "${fdir}"/* "${fdir}"/.[!.]*; do
    [ -e "${entry}" ] || continue
    name="$(basename "${entry}")"
    rp="$(rel_path "${entry}")"
    case "${name}" in README.md|*.template.md) continue ;; esac
    is_os_junk "${name}" && continue
    if [ "${layout}" = "file" ] && [ -f "${entry}" ] && [ "${name%.md}" = "${name}" ] \
      && printf '%s' "${name}" | grep -qE '^[0-9]{4}-'; then
      report record BAD_NAME "${rp}" "records are NNNN-slug.md files"
      continue
    fi
    stem="${name%.md}"
    if ! printf '%s' "${stem}" | grep -qE '^[0-9]{4}-'; then
      report stray UNNUMBERED "${rp}" "not a NNNN-slug record; adopt it as one or move it out of docs/${folder}/"
      continue
    fi
    printf '%s' "${stem}" | grep -qE '^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$' \
      || report record BAD_NAME "${rp}" "slug must be kebab-case (lowercase letters, digits, hyphens)"
    words="$(printf '%s' "${stem#????-}" | awk -F- '{print NF}')"
    [ "${words}" -le 4 ] \
      || report record SLUG_TOO_LONG "${rp}" "slug has ${words} words (at most 4)"
    num="${stem%%-*}"
    numbers="${numbers}${num}"$'\n'
    records="${records}${stem}"$'\n'
    if [ "${layout}" = "file" ]; then
      # a directory is a promoted record — allowed, parts are free-form
      [ -f "${entry}" ] && check_part "${tdir}${parts%.md}.template.md" "${entry}" "${num}"
    elif [ -f "${entry}" ]; then
      report record WRONG_LAYOUT "${rp}" "records here are NNNN-slug/ directories with: $(printf '%s' "${parts}" | tr '\n' ' ')"
    else
      while IFS= read -r p; do
        if [ -f "${entry}/${p}" ]; then
          check_part "${tdir}${p%.md}.template.md" "${entry}/${p}" "${num}"
        else
          report record MISSING_PART "${rp}/" "no ${p}"
        fi
      done <<< "${parts}"
      for f in "${entry}"/* "${entry}"/.[!.]*; do
        [ -e "${f}" ] || continue
        is_os_junk "$(basename "${f}")" && continue
        printf '%s\n' "${parts}" | grep -qxF "$(basename "${f}")" \
          || report record EXTRA_PART "$(rel_path "${f}")" "not a part file of this record type ($(printf '%s' "${parts}" | tr '\n' ' '))"
      done
    fi
  done

  while IFS= read -r dup; do
    [ -n "${dup}" ] && report record DUP_NUMBER "docs/${folder}/${dup}-*" "number used by more than one record"
  done < <(printf '%s' "${numbers}" | sort | uniq -d)

  # Index lines: format comes from the template README's `**Index line:**` spec.
  readme="${fdir}/README.md"
  [ -f "${readme}" ] || continue
  # shellcheck disable=SC2016 # the backticks are literal Markdown, not expansions
  fmt="$(sed -n 's/^\*\*Index line:\*\* `- \([^`]*\)`.*/\1/p' "${tdir}README.md" | head -n 1)"
  [ -n "${fmt}" ] || continue
  n_fields="$(printf '%s\n' "${fmt}" | awk -F' — ' '{print NF}')"
  value_field="$(printf '%s\n' "${fmt}" | awk -F' — ' '{print $2}')"
  indexed=""
  while IFS= read -r line; do
    case "${line}" in "- "*) ;; *) continue ;; esac
    body="${line#- }"
    # One awk pass splits the line: stem, field count, last, 2nd and 3rd fields
    # (unit-separator delimited, so empty fields do not collapse).
    IFS=$'\x1f' read -r stem count last f2 f3 < <(printf '%s\n' "${body}" \
      | awk -F' — ' '{printf "%s\037%s\037%s\037%s\037%s\n", $1, NF, $NF, $2, $3}')
    loc="docs/${folder}/README.md"
    len="$(char_len "${line}")"
    if [ "${len}" -gt 120 ]; then
      report record LINE_TOO_LONG "${loc}" "index line for ${stem} is ${len} characters (at most 120)"
    fi
    if ! printf '%s' "${stem}" | grep -qE '^[0-9]{4}-' || [ "${count}" -lt "${n_fields}" ]; then
      report record INDEX_FORMAT "${loc}" "expected \`- ${fmt}\`: ${line}"
      continue
    fi
    if printf '%s\n' "${indexed}" | grep -qxF "${stem}"; then
      report record DUP_INDEX "${loc}" "${stem} is indexed more than once"
    fi
    indexed="${indexed}${stem}"$'\n'
    if ! printf '%s' "${records}" | grep -qxF "${stem}"; then
      # a deleted memory keeps its index line, suffixed `— deleted`, by design
      [ "${last}" = "deleted" ] && [ "${count}" -gt "${n_fields}" ] && continue
      report record ORPHAN_INDEX "${loc}" "${stem} is indexed but has no record"
      continue
    fi
    if [ "${value_field}" = "YYYY-MM-DD" ]; then date_pos=2 idate="${f2}"; else date_pos=3 idate="${f3}"; fi
    printf '%s' "${idate}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
      || report record INDEX_FORMAT "${loc}" "${stem}: '${idate}' is not a YYYY-MM-DD date"
    if [ "${date_pos}" -eq 3 ]; then
      key="$(printf '%s' "${value_field}" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
      if [ "${layout}" = "file" ]; then src="${fdir}/${stem}.md"; else src="${fdir}/${stem}/${main_part}"; fi
      ivalue="${f2}"
      if [ -f "${src}" ]; then
        rvalue="$(sed -n "s/^- ${key}: *//p" "${src}" | head -n 1)"
        [ -z "${rvalue}" ] || [ "${ivalue}" = "${rvalue}" ] \
          || report record INDEX_MISMATCH "${loc}" "${stem}: index says ${value_field} '${ivalue}', record says '${rvalue}'"
      fi
    fi
  done < <(sed -n '/^## Index$/,$p' "${readme}")

  while IFS= read -r stem; do
    [ -n "${stem}" ] || continue
    printf '%s\n' "${indexed}" | grep -qxF "${stem}" \
      || report record UNINDEXED "docs/${folder}/${stem}" "record has no index line in docs/${folder}/README.md"
  done <<< "${records}"
done

# --- 3. Stray content --------------------------------------------------------
if [ -d "${DOCS_DIR}" ]; then
  for entry in "${DOCS_DIR}"/* "${DOCS_DIR}"/.[!.]*; do
    [ -e "${entry}" ] || continue
    name="$(basename "${entry}")"
    [ "${name}" = "README.md" ] && continue
    is_os_junk "${name}" && continue
    if [ -d "${entry}" ] && [ -d "${TEMPLATES_DIR}/${name}" ]; then continue; fi
    report stray OUTSIDE_STRUCTURE "$(rel_path "${entry}")$( [ -d "${entry}" ] && echo /)" \
      "not part of the docs structure; adopt what fits a record type, leave the rest"
  done
fi

# Likely agent knowledge kept elsewhere in the repository (heuristic; depth-limited).
while IFS= read -r cand; do
  [ -n "${cand}" ] || continue
  report stray CANDIDATE "${cand#./}" "may hold decisions, specs, plans, memories, or learnings outside docs/"
done < <(cd "${TARGET_DIR}" && {
  find . -maxdepth 3 \( -name .git -o -name node_modules -o -name vendor -o -path ./docs \) -prune -o -type d \
    \( -iname adr -o -iname adrs -o -iname decisions -o -iname decision-records -o -iname rfcs \
       -o -iname specs -o -iname plans -o -iname memories -o -iname learnings -o -iname lessons \
       -o -iname postmortems \) -print
  find . -maxdepth 2 \( -name .git -o -name node_modules -o -name vendor -o -path ./docs \) -prune -o -type f \
    \( -iname '*adr*.md' -o -iname 'decision*.md' -o -iname 'plan*.md' -o -iname 'spec*.md' \
       -o -iname 'learning*.md' -o -iname 'lesson*.md' -o -iname 'memor*.md' -o -iname 'postmortem*.md' \) -print
} | sort)

# --- summary -----------------------------------------------------------------
# Stray findings are advisory: docs/ may legitimately hold other documentation
# (user guides, API references), so they never fail the check on their own.
echo
[ "${n_fixed}" -gt 0 ] && echo "Fixed ${n_fixed} scaffold finding(s)."
strays=""
[ "${n_stray}" -gt 0 ] && strays=" ${n_stray} stray item(s) to review."
if [ $((n_scaffold + n_record)) -eq 0 ]; then
  echo "docs/ conforms to the stella-agentic-workflow-docs conventions.${strays}"
  exit 0
fi
echo "Not conforming: ${n_scaffold} scaffold and ${n_record} record finding(s).${strays}"
exit 1
