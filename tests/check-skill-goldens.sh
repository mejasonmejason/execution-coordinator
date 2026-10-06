#!/usr/bin/env bash
# Golden negative tests for .github/scripts/check-skill.py. Offline. Each mutation of a clean fixture must make the
# checker exit 1, and the clean fixture must exit 0. The fixture SKILL.md is minimal, so these cases do not depend on
# the real SKILL.md. CHECK_SKILL_TOTAL stops the checker from running tests/run.sh, which runs this script.
#   tests/check-skill-goldens.sh   prints PASS/FAIL lines and a final TOTAL line; exit 0 when all pass
set -u

S=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
N=7   # assertion count the fixture README claims; the checker gets the same number through the environment

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
  sed -i -E "s/(bash tests\/run\.sh +# )[0-9]+( cases)/\1${N}\2/" "$d/README.md"
}

check() { (cd "$1" && CHECK_SKILL_TOTAL="$N" python3 .github/scripts/check-skill.py >"$1/out.txt" 2>&1); }

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
expect 1 "short_description too short" "sed -i -E 's/(short_description: \").*\"/\\1Too short\"/' agents/openai.yaml" "short_description is"
expect 1 "short_description too long" "sed -i -E \"s/(short_description: \\\").*\\\"/\\1\$(printf 'x%.0s' \$(seq 70))\\\"/\" agents/openai.yaml" "short_description is"
expect 1 "default_prompt without the skill name" "sed -i 's/\\\$execution-coordinator/the coordinator/' agents/openai.yaml" "does not name"
expect 1 "default_prompt over 200 characters" "sed -i -E \"s/(default_prompt: \\\"[^\\\"]*)\\\"/\\1 \$(printf 'and more %.0s' \$(seq 20))\\\"/\" agents/openai.yaml" "(limit 200)"
expect 1 "default_prompt with two sentences" "sed -i -E 's/(default_prompt: \"[^\"]*)\"/\\1 Then stop.\"/' agents/openai.yaml" "single sentence"
expect 1 "compatibility over 500 characters" "sed -i -E \"s/^(compatibility: ).*/\\1\$(printf 'x%.0s' \$(seq 501))/\" SKILL.md" "compatibility is 501"
expect 1 "compatibility empty" "sed -i -E 's/^(compatibility:).*/\\1/' SKILL.md" "compatibility is empty"
expect 1 "README test count wrong" "sed -i -E 's/(bash tests\\/run\\.sh +# )[0-9]+/\\199/' README.md" "README.md says 99 cases"

echo "TOTAL pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
