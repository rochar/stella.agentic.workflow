#!/usr/bin/env bash
# Diagnoses how far a repository's docs/ tree is from the conventions of the
# plugin's templates/docs/ scaffold — the structural half of the docs-doctor
# skill. Everything it checks is derived from templates/docs/ (scaffold files,
# record prefixes, front-matter keys and vocabularies, sections, index-line
# formats), so a template change is picked up here automatically.
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

# awk helper shared by every front-matter reader: a value as YAML reads it —
# trimmed, its surrounding quotes removed, or else a trailing `# comment` dropped.
FM_VAL_AWK='function val(s,   q, j) {
  sub(/^[ \t]+/, "", s); q = substr(s, 1, 1)
  if (q == "\"" || q == "\047") { j = index(substr(s, 2), q); if (j) return substr(s, 2, j - 1) }
  sub(/[ \t]+#.*$/, "", s); sub(/^#.*$/, "", s); sub(/[ \t]+$/, "", s)
  return s
}'

# Value of a YAML front-matter key (first `---` block).
fm_value() { # file key
  awk -v k="$2" "${FM_VAL_AWK}"'
    NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit}
    NR>1 && index($0, k ":")==1 { print val(substr($0, length(k) + 2)); exit }' "$1"
}

# Rebuilds a folder README: the template's prose up to `## Index`, followed by
# the index lines currently in the file (placeholder dropped when there are any).
rebuild_readme() { # template current
  local tmpl="$1" cur="$2" body
  if grep -q '^## Index$' "${cur}"; then
    body="$(sed -n '/^## Index$/,$p' "${cur}" | sed '1d')"
  else
    body="$(grep -E '^- ([A-Z]+-)?[0-9]{4}([0-9]{4})?-' "${cur}" || true)" # older formats too
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

# A real calendar date written as YYYYMMDD (month lengths and leap years included).
valid_ymd() {
  local y m d max
  [[ $1 =~ ^([0-9]{4})(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$ ]] || return 1
  y=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]})) d=$((10#${BASH_REMATCH[3]}))
  case "${m}" in
    4|6|9|11) max=30 ;;
    2) if [ $((y % 4)) -eq 0 ] && { [ $((y % 100)) -ne 0 ] || [ $((y % 400)) -eq 0 ]; }; then
         max=29
       else
         max=28
       fi ;;
    *) max=31 ;;
  esac
  [ "${d}" -le "${max}" ]
}

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
# Checks one record against its folder's template in a single awk pass (the
# template, then the record) and prints one `CODE<US>message` line per finding.
# Front matter: present and closed; every template key present; a `# a | b`
# comment is the value vocabulary; YYYY-MM-DD is a date; a <placeholder> needs a
# real value, and one whose placeholder names a <PREFIX>-YYYYMMDD-slug (a plan's
# `spec:` / `adrs:`) is a comma-separated list of such ids or `none`; a
# YYYYMMDD-slug value (the `id:`) must be the record's file stem, and a
# YYYY-MM-DD `date:` must equal the date in its name; an empty template
# value is optional, but `superseded-by` is required exactly
# when `status` is superseded; every value must be valid YAML as written.
# Body: every `## ` section unless its first line is an `<optional...` hint,
# every `Label: <...>` line (e.g. an ADR's `Binds:`) filled in, and no line left
# as the template's placeholder text. An abandoned record is history and may be
# kept as a pointer stub (front matter plus one line saying where its content
# went), so its body is not checked.
RECORD_AWK="${FM_VAL_AWK}"'
FNR == 1 { f++; s = ($0 == "---") ? "fm" : "body"; if (f == 2) hasfm = (s == "fm"); if (s == "fm") next }
s == "fm" && $0 == "---" { s = "body"; if (f == 2) closed = 1; next }
s == "fm" {
  i = index($0, ":"); if (!i) next
  k = substr($0, 1, i - 1); v = substr($0, i + 1)
  if (f == 1) {
    if (!(k in tval)) { keys[++n] = k; tval[k] = val(v); j = index(v, " # "); tcom[k] = j ? substr(v, j + 3) : "" }
  } else if (!(k in rval)) {
    rkeys[++rn] = k; rval[k] = val(v); r = v; sub(/^[ \t]+/, "", r); quoted[k] = (r ~ /^["\047]/)
  }
  next
}
f == 1 {
  if ($0 ~ /^## /) { h = $0; next }
  if (h != "" && NF) { if ($0 !~ /^<optional/) need[++nh] = h; h = "" }
  if ($0 ~ /^</) ph[++np] = $0
  else if ($0 ~ /^[A-Za-z][A-Za-z -]*: </) { ph[++np] = $0; lab[++nl] = substr($0, 1, index($0, ":")) }
  next
}
{
  have[$0] = 1
  for (x = 1; x <= nl; x++) if (index($0, lab[x]) == 1) {
    r = substr($0, length(lab[x]) + 1); gsub(/[ \t]/, "", r); if (r != "") hasl[x] = 1
  }
}
END {
  if (!hasfm) print "MISSING_FRONT_MATTER\037must start with a `---` front-matter block"
  else if (!closed) print "MISSING_FRONT_MATTER\037front matter has no closing `---` line"
  for (x = 1; hasfm && x <= n; x++) {
    k = keys[x]; t = tval[k]; c = tcom[k]
    if (!(k in rval)) { print "MISSING_FIELD\037no `" k ":` in front matter"; continue }
    v = rval[k]
    if (t == "") continue # optional
    if (t == "YYYY-MM-DD") {
      if (v !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) print "INVALID_VALUE\037" k " \047" v "\047 is not YYYY-MM-DD"
      else if (k == "date") { w = v; gsub(/-/, "", w)
        if (w != ndate) print "INVALID_VALUE\037date \047" v "\047 does not match the date in the file name (" ndate ")" }
    } else if (index(c, " | ")) {
      m = split(c, opt, " [|] "); ok = 0
      for (y = 1; y <= m; y++) if (v == opt[y]) ok = 1
      if (!ok) print "INVALID_VALUE\037" k " \047" v "\047 is not one of: " c
    } else if (substr(t, 1, 1) == "<") {
      if (v == "") print "MISSING_FIELD\037`" k ":` is empty"
      else if (substr(v, 1, 1) == "<") print "UNFILLED_PLACEHOLDER\037`" k ":` still contains template text"
      else if (match(t, /[A-Z]+-YYYYMMDD-slug/)) {
        # References: each item `none` or a dated id of the type the placeholder names.
        rpre = substr(t, RSTART, RLENGTH - 13); m = split(v, ref, ",")
        for (y = 1; y <= m; y++) {
          r = ref[y]; gsub(/^[ \t]+|[ \t]+$/, "", r)
          if (r != "none" && r !~ ("^" rpre "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*$")) {
            print "INVALID_VALUE\037" k " \047" r "\047 is not a " rpre "YYYYMMDD-slug id (or none)"; break
          }
        }
      }
    } else if (index(t, "YYYYMMDD-slug")) {
      if (v != stem) print "INVALID_VALUE\037" k " \047" v "\047 must be the file stem " stem
    }
  }
  if (hasfm && ("superseded-by" in tval)) {
    v = rval["superseded-by"]
    if (rval["status"] == "superseded") {
      if (v !~ ("^" prefix "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*$"))
        print "INVALID_VALUE\037status superseded needs `superseded-by: " prefix "YYYYMMDD-slug`"
    } else if (v != "") print "INVALID_VALUE\037superseded-by is set but status is not superseded"
  }
  # Unquoted, a value with `: ` or a leading YAML indicator breaks every YAML reader.
  for (x = 1; x <= rn; x++) {
    k = rkeys[x]; v = rval[k]
    if (!quoted[k] && (v ~ /: |:$/ || v ~ /^([][{},&*!|>%@`]|[-?:]( |$))/))
      print "INVALID_VALUE\037`" k ":` is not valid YAML unquoted; wrap the value in quotes"
  }
  if (rval["status"] == "abandoned") exit
  for (x = 1; x <= nh; x++) { hd = need[x]; if (!(hd in have)) print "MISSING_SECTION\037no `" hd "` section" }
  for (x = 1; x <= nl; x++) if (!hasl[x]) print "MISSING_SECTION\037no filled-in `" lab[x] "` line"
  for (x = 1; x <= np; x++) { hd = ph[x]; if (hd in have) { print "UNFILLED_PLACEHOLDER\037still contains template text: " hd; break } }
}'

check_record() { # template record-file stem name-date prefix
  local code msg rp
  rp="$(rel_path "$2")"
  while IFS=$'\x1f' read -r code msg; do
    report record "${code}" "${rp}" "${msg}"
  done < <(awk -v stem="$3" -v ndate="$4" -v prefix="$5" "${RECORD_AWK}" "$1" "$2")
}

for tdir in "${TEMPLATES_DIR}"/*/; do
  folder="$(basename "${tdir}")"
  fdir="${DOCS_DIR}/${folder}"
  [ -d "${fdir}" ] || continue
  # One template per record type; its `id: <PREFIX>-YYYYMMDD-slug` names the record prefix.
  tmpl="$(find "${tdir}" -maxdepth 1 -type f -name '*.template.md' | sort | head -n 1)"
  prefix=""
  if [ -n "${tmpl}" ]; then
    tid="$(fm_value "${tmpl}" id)"
    case "${tid}" in [A-Z]*-YYYYMMDD-slug) prefix="${tid%YYYYMMDD-slug}" ;; esac
  fi
  if [ -z "${prefix}" ]; then
    report scaffold UNKNOWN_PREFIX "docs/${folder}/" "the plugin template for this folder has no \`id: <PREFIX>-YYYYMMDD-slug\` front-matter line"
    continue
  fi
  re_dated="^${prefix}[0-9]{8}-"
  re_kebab="^${prefix}[0-9]{8}-[a-z0-9]+(-[a-z0-9]+)*\$"
  # An attempted record name: this prefix and any digits (a mistyped date), or
  # 4+ digits under any or no prefix (a bare, other-prefix, or other-case name).
  re_misnamed="^${prefix}[0-9]+-|^([A-Za-z]+-)?[0-9]{4,}-"
  records=""

  for entry in "${fdir}"/* "${fdir}"/.[!.]*; do
    [ -e "${entry}" ] || continue
    name="$(basename "${entry}")"
    rp="$(rel_path "${entry}")"
    case "${name}" in README.md|*.template.md) continue ;; esac
    is_os_junk "${name}" && continue
    stem="${name%.md}"
    if [[ ! ${stem} =~ ${re_dated} ]]; then
      if [[ -d ${entry} && ${stem} =~ ^[0-9]{4}- ]]; then
        # Pre-0.3.0 layout: ADRs, specs, and plans were NNNN-slug/ directories.
        report record WRONG_LAYOUT "${rp}/" "old directory layout; merge its parts into one ${prefix}YYYYMMDD-slug.md"
      elif [[ -f ${entry} && ${name} != "${stem}" && ${stem} =~ ^${prefix}[0-9]{4}- ]]; then
        # 0.3.0 naming: a per-folder sequence number instead of the creation date.
        report record NUMBERED_ID "${rp}" "sequence-numbered; rename to ${prefix}YYYYMMDD-slug.md using its date:"
      elif [[ ${stem} =~ ${re_misnamed} ]]; then
        # A record under a pre-0.3.0 bare name, another prefix, another case, or
        # a date with the wrong number of digits.
        report record BAD_NAME "${rp}" "records here are named ${prefix}YYYYMMDD-slug.md"
      else
        report stray UNDATED "${rp}" "not a ${prefix}YYYYMMDD-slug record; adopt it as one or move it out of docs/${folder}/"
      fi
      continue
    fi
    if [ -d "${entry}" ] || [ "${name}" = "${stem}" ]; then
      report record WRONG_LAYOUT "${rp}" "records are single ${prefix}YYYYMMDD-slug.md files"
      continue
    fi
    [[ ${stem} =~ ${re_kebab} ]] \
      || report record BAD_NAME "${rp}" "slug must be kebab-case (lowercase letters, digits, hyphens)"
    bare="${stem#"${prefix}"}"
    ndate="${bare%%-*}"
    valid_ymd "${ndate}" \
      || report record BAD_NAME "${rp}" "'${ndate}' in the name is not a YYYYMMDD date"
    dashes="${bare#????????-}"; dashes="${dashes//[!-]/}"
    words=$(( ${#dashes} + 1 ))
    [ "${words}" -le 4 ] \
      || report record SLUG_TOO_LONG "${rp}" "slug has ${words} words (at most 4)"
    records="${records}${stem}"$'\n'
    check_record "${tmpl}" "${entry}" "${stem}" "${ndate}" "${prefix}"
  done

  # Index lines: format comes from the template README's `**Index line:**` spec.
  readme="${fdir}/README.md"
  [ -f "${readme}" ] || continue
  # shellcheck disable=SC2016 # the backticks are literal Markdown, not expansions
  fmt="$(sed -n 's/^\*\*Index line:\*\* `- \([^`]*\)`.*/\1/p' "${tdir}README.md" | head -n 1)"
  [ -n "${fmt}" ] || continue
  n_fields="$(printf '%s\n' "${fmt}" | awk -F' — ' '{print NF}')"
  # With three fields or more, the 2nd names a front-matter key (status, type).
  value_field=""
  [ "${n_fields}" -ge 3 ] && value_field="$(printf '%s\n' "${fmt}" | awk -F' — ' '{print $2}')"
  indexed=""
  while IFS= read -r line; do
    case "${line}" in "- "*) ;; *) continue ;; esac
    body="${line#- }"
    # One awk pass splits the line: stem, field count, last and 2nd fields, and
    # the field where the summary belongs (unit-separator delimited, so empty
    # fields do not collapse).
    IFS=$'\x1f' read -r stem count last f2 fsum < <(printf '%s\n' "${body}" \
      | awk -F' — ' -v n="${n_fields}" '{printf "%s\037%s\037%s\037%s\037%s\n", $1, NF, $NF, $2, $n}')
    loc="docs/${folder}/README.md"
    len="$(char_len "${line}")"
    if [ "${len}" -gt 120 ]; then
      report record LINE_TOO_LONG "${loc}" "index line for ${stem} is ${len} characters (at most 120)"
    fi
    if [[ ! ${stem} =~ ${re_dated} ]] || [ "${count}" -lt "${n_fields}" ]; then
      report record INDEX_FORMAT "${loc}" "expected \`- ${fmt}\`: ${line}"
      continue
    fi
    # A pre-0.4.0 line keeps a YYYY-MM-DD column where the summary now goes.
    if [ "${count}" -gt "${n_fields}" ] && [[ ${fsum} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      report record INDEX_FORMAT "${loc}" "${stem}: drop the old date column '${fsum}'; expected \`- ${fmt}\`"
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
    if [ -n "${value_field}" ]; then
      rvalue="$(fm_value "${fdir}/${stem}.md" "${value_field}")"
      [ -z "${rvalue}" ] || [ "${f2}" = "${rvalue}" ] \
        || report record INDEX_MISMATCH "${loc}" "${stem}: index says ${value_field} '${f2}', record says '${rvalue}'"
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
