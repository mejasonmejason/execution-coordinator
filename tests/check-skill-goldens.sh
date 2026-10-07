#!/usr/bin/env bash
# Golden negative tests for scripts/check-skill.py. Offline. Each mutation of a clean fixture must make the
# checker exit 1, and the clean fixture must exit 0. The fixture SKILL.md is minimal, so these cases do not depend on
# the real SKILL.md. CHECK_SKILL_TOTAL stops the checker from running tests/run.sh, which runs this script.
#   tests/check-skill-goldens.sh   prints PASS/FAIL lines and a final TOTAL line; exit 0 when all pass
set -u

S=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
N=7   # assertion count the fixture README claims; the checker gets the same number through the environment

# In-place edit that works with GNU and BSD sed: sedi <sed options and script...> <file>. BSD sed treats the argument
# after a bare -i as the backup suffix, so GNU-style `sed -i 's/a/b/' f` fails on macOS.
sedi() { local f="${!#}"; sed "${@:1:$#-1}" "$f" > "$f.new" && mv "$f.new" "$f"; }

fixture() {  # fixture <dir>: a clean copy of the repo with a minimal SKILL.md and one reference file
  local d="$1"
  mkdir -p "$d"
  (cd "$S" && tar --exclude=.git --exclude=SKILL.md --exclude=references --exclude=evals -cf - .) | tar -xf - -C "$d"
  mkdir -p "$d/references"
  cat > "$d/SKILL.md" <<'MD'
---
name: execution-coordinator
description: Coordinates engineering work from plan to merge. Use for execution and PR completion.
compatibility: Needs git and the GitHub CLI; works in Claude Code and Codex.
---

# Execution Coordinator

Read [the detail](references/detail.md) when a task needs it.
MD
  printf '# Detail\n\nMore text.\n' > "$d/references/detail.md"
  sedi -E "s/(bash tests\/run\.sh +# )[0-9]+( cases)/\1${N}\2/" "$d/README.md"
}

check() { (cd "$1" && CHECK_SKILL_TOTAL="$N" python3 scripts/check-skill.py >"$1/out.txt" 2>&1); }

expect() {  # expect <want exit> <label> <mutation snippet> <text the checker must print>
  local want="$1" label="$2" mutate="$3" msg="${4:-}" d="$W/$2"
  fixture "$d"
  ( cd "$d" && eval "$mutate" )
  check "$d"; local rc=$?
  if [ "$rc" -eq "$want" ] && { [ -z "$msg" ] || grep -qF -- "$msg" "$d/out.txt"; }; then echo "PASS golden: $label"; pass=$((pass + 1))
  else echo "FAIL golden: $label (exit $rc, want $want, message '$msg')"; sed 's/^/    /' "$d/out.txt"; fail=$((fail + 1)); fi
}

expect 0 "clean fixture passes" ":"
expect 1 "body over 20000 characters" "python3 -c \"print('word ' * 4001)\" >> SKILL.md" "characters (limit 20000)"
expect 1 "body over 5000 words" "python3 -c \"print('a ' * 5001)\" >> SKILL.md" "words (limit 5000)"
expect 1 "body over 500 lines" "python3 -c \"print('x\n' * 501)\" >> SKILL.md" "lines (limit 500)"
expect 1 "broken references link" "echo 'See [gone](references/missing.md).' >> SKILL.md" "which does not exist"
expect 1 "orphan reference file" "echo '# Orphan' > references/orphan.md" "not linked from SKILL.md"
expect 1 "reference links to another reference" "echo 'See [other](other.md).' >> references/detail.md; echo '# Other' > references/other.md; echo '[o](references/other.md)' >> SKILL.md" "one level deep"
expect 1 "section sign in SKILL.md" "printf 'See \\xc2\\xa73.\\n' >> SKILL.md" "SKILL.md contains a section sign"
expect 1 "section sign in a reference" "printf 'See \\xc2\\xa73.\\n' >> references/detail.md" "references/detail.md contains a section sign"
expect 1 "short_description too short" "sedi -E 's/(short_description: \").*\"/\\1Too short\"/' agents/openai.yaml" "short_description is"
expect 1 "short_description too long" "sedi -E \"s/(short_description: \\\").*\\\"/\\1\$(printf 'x%.0s' \$(seq 70))\\\"/\" agents/openai.yaml" "short_description is"
expect 1 "default_prompt without the skill name" "sedi 's/\\\$execution-coordinator/the coordinator/' agents/openai.yaml" "does not name"
expect 1 "default_prompt over 200 characters" "sedi -E \"s/(default_prompt: \\\"[^\\\"]*)\\\"/\\1 \$(printf 'and more %.0s' \$(seq 20))\\\"/\" agents/openai.yaml" "(limit 200)"
expect 1 "default_prompt with two sentences" "sedi -E 's/(default_prompt: \"[^\"]*)\"/\\1 Then stop.\"/' agents/openai.yaml" "single sentence"
expect 1 "compatibility over 500 characters" "sedi -E \"s/^(compatibility: ).*/\\1\$(printf 'x%.0s' \$(seq 501))/\" SKILL.md" "compatibility is 501"
expect 1 "compatibility empty" "sedi -E 's/^(compatibility:).*/\\1/' SKILL.md" "compatibility is empty"
# Block-scalar compatibility values (#26): the checker must measure the whole value, not the first line.
set_compat() {  # set_compat <line>...: replace the compatibility line of SKILL.md with the given lines
  python3 -c '
import re, sys
s = open("SKILL.md").read()
s = re.sub(r"^compatibility:.*\n", lambda m: "".join(a + "\n" for a in sys.argv[1:]), s, count=1, flags=re.M)
open("SKILL.md", "w").write(s)
' "$@"
}
long_block() {  # long_block <indicator>: a block scalar of six 99-character lines (each line alone is under 500)
  local l; l=$(printf 'y%.0s' $(seq 99))
  set_compat "compatibility: $1" "  $l" "  $l" "  $l" "  $l" "  $l" "" "  $l"
}
expect 1 "compatibility folded block over 500" "long_block '>'" "compatibility is 600"
expect 1 "compatibility folded strip block over 500" "long_block '>-'" "compatibility is 599"
expect 1 "compatibility literal block over 500" "long_block '|'" "compatibility is 601"
expect 1 "compatibility literal strip block over 500" "long_block '|-'" "compatibility is 600"
expect 0 "compatibility short folded block passes" "set_compat 'compatibility: >-' '  Needs git' '  and gh.'"
expect 1 "compatibility double-quoted over 500" "set_compat \"compatibility: \\\"\$(printf 'x%.0s' \$(seq 501))\\\"\"" "compatibility is 501"
expect 1 "compatibility single-quoted multi-line over 500" "set_compat \"compatibility: '\$(printf 'x%.0s' \$(seq 300))\" \"  \$(printf 'z%.0s' \$(seq 300))'\"" "compatibility is 601"
expect 1 "compatibility unsupported flow form" "set_compat 'compatibility: [git, gh]'" "compatibility uses an unsupported YAML form"
expect 1 "compatibility unsupported tag" "set_compat 'compatibility: !!str >' '  Needs git.'" "compatibility uses an unsupported YAML form"
# Every local Markdown link in SKILL.md and references/*.md must resolve (#26). Inline code is not a link.
append() { local f="$1"; shift; printf '%s\n' "$@" >> "$f"; }
expect 1 "SKILL.md link to a missing script" "append SKILL.md 'Run [it](scripts/not-a-file.sh).'" "SKILL.md links to scripts/not-a-file.sh, which does not exist"
expect 1 "reference link to a missing file" "append references/detail.md 'See [x](../scripts/gone.sh#top).'" "references/detail.md links to scripts/gone.sh, which does not exist"
expect 1 "reference-style link to a missing file" "append SKILL.md '' '[ref]: docs/nope.md'" "SKILL.md links to docs/nope.md, which does not exist"
expect 0 "inline code, URLs and anchors are not checked as files" "append SKILL.md 'Run \`scripts/not-a-file.sh\` or \`[a](nope.md)\`.' 'See [web](https://example.com/x), [mail](mailto:a@b.c), [top](#execution-coordinator), [ready](scripts/ready.sh#usage \"Ready\").' '' '\`\`\`' '[fenced](scripts/nope.sh)' '\`\`\`'"
expect 1 "README test count wrong" "sedi -E 's/(bash tests\\/run\\.sh +# )[0-9]+/\\199/' README.md" "README.md says 99 cases"

echo "TOTAL pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
