"""Check SKILL.md, references/ and agents/openai.yaml against the claude.ai and Codex skill rules, and the README
test count against the real suite. Dependency-free. Exit 1 on any failure.

The repository root is the parent of scripts/, so the checker gives the same result from any directory.
Set CHECK_SKILL_TOTAL=N to supply the assertion count instead of running tests/run.sh (the golden tests do this,
because tests/run.sh runs them and the two would otherwise call each other).
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def path(*p):
    return os.path.join(ROOT, *p)


def read(*p):
    with open(path(*p), encoding="utf-8") as f:
        return f.read()


text = read("SKILL.md")
errors = []
parts = text.split("---")
if not text.startswith("---") or len(parts) < 3:
    sys.exit("SKILL.md: frontmatter missing (must start with ---)")
fm = parts[1]
body = text[len(parts[0]) + 3 + len(parts[1]) + 3:].lstrip("\n")
keys = re.findall(r"^([\w-]+):", fm, re.M)
name = (re.search(r"^name:\s*(.*)$", fm, re.M) or [None, ""])[1].strip().strip('"')
desc = (re.search(r"^description:\s*(.*)$", fm, re.M) or [None, ""])[1].strip().strip('"')

if name != "execution-coordinator":
    errors.append(f"name is {name!r}, expected 'execution-coordinator'")
if not re.fullmatch(r"[a-z0-9-]{1,64}", name):
    errors.append("name must be 1-64 lowercase letters, digits or hyphens")
if not desc:
    errors.append("description is empty")
if len(desc) > 1024:
    errors.append(f"description is {len(desc)} characters (limit 1024)")
if "<" in desc or ">" in desc:
    errors.append("description contains an angle bracket")
if set(keys) - {"name", "description", "license", "allowed-tools", "metadata", "compatibility"}:
    errors.append(f"unexpected frontmatter keys: {keys}")

if "compatibility" in keys:
    compat = (re.search(r"^compatibility:\s*(.*)$", fm, re.M) or [None, ""])[1].strip().strip('"')
    if not compat:
        errors.append("compatibility is empty")
    if len(compat) > 500:
        errors.append(f"compatibility is {len(compat)} characters (limit 500)")

# Size budget for the body (everything after the closing frontmatter ---).
n_lines, n_words, n_chars = len(body.splitlines()), len(body.split()), len(body)
for label, got, limit in (("lines", n_lines, 500), ("words", n_words, 5000), ("characters", n_chars, 20000)):
    if got > limit:
        errors.append(f"SKILL.md body is {got} {label} (limit {limit})")

# references/: one level deep, every file linked from SKILL.md, every link resolves.
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def local_links(source_text, source_dir):
    """Relative markdown link targets, resolved to repo-root-relative paths."""
    out = []
    for target in LINK.findall(source_text):
        if re.match(r"[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
            continue
        out.append(os.path.normpath(os.path.join(source_dir, target.split("#")[0])))
    return out


ref_dir = path("references")
ref_files = sorted(f for f in os.listdir(ref_dir) if f.endswith(".md")) if os.path.isdir(ref_dir) else []
linked = set()
for target in local_links(body, ""):
    if target.startswith("references" + os.sep):
        linked.add(target)
        if not os.path.isfile(path(target)):
            errors.append(f"SKILL.md links to {target}, which does not exist")
for f in ref_files:
    rel = os.path.join("references", f)
    if rel not in linked:
        errors.append(f"{rel} is not linked from SKILL.md")
    for target in local_links(read(rel), "references"):
        if target.startswith("references" + os.sep) and target != rel:
            errors.append(f"{rel} links to {target} (references must be one level deep)")
    if "\u00a7" in read(rel):
        errors.append(f"{rel} contains a section sign (use a heading name instead)")
if "\u00a7" in text:
    errors.append("SKILL.md contains a section sign (use a heading name instead)")

# Codex metadata: agents/openai.yaml must carry the interface fields and name the skill in its default prompt.
try:
    oy = read("agents", "openai.yaml")
except OSError:
    oy = ""
    errors.append("agents/openai.yaml is missing")
block = re.search(r"^interface:[ \t]*\n((?:[ \t]+.*\n?|[ \t]*\n)*)", oy, re.M)
iface = block.group(1) if block else ""
if oy and not block:
    errors.append("agents/openai.yaml: no top-level interface: block")
fields = dict(re.findall(r"^[ \t]+([\w-]+):[ \t]*(.*)$", iface, re.M))
for field in ("display_name", "short_description", "default_prompt"):
    if block and not fields.get(field, "").strip(' "'):
        errors.append(f"agents/openai.yaml: interface.{field} is missing")
prompt = fields.get("default_prompt", "").strip().strip('"')
short = fields.get("short_description", "").strip().strip('"')
if block and f"${name}" not in prompt:
    errors.append(f"agents/openai.yaml: interface.default_prompt does not name ${name}")
if block and short and not 25 <= len(short) <= 64:
    errors.append(f"agents/openai.yaml: interface.short_description is {len(short)} chars (want 25-64)")
if block and prompt:
    if len(prompt) > 200:
        errors.append(f"agents/openai.yaml: interface.default_prompt is {len(prompt)} chars (limit 200)")
    if re.search(r"[.!?](\s|$)", prompt.rstrip(".!?") + " "):
        errors.append("agents/openai.yaml: interface.default_prompt must be a single sentence")

# README test count must equal the number of assertions in tests/run.sh.
readme_count = re.search(r"bash tests/run\.sh\s+#\s*(\d+)\s+cases", read("README.md"))
total = os.environ.get("CHECK_SKILL_TOTAL")
if total is None:
    proc = subprocess.run(["bash", path("tests", "run.sh")], capture_output=True, text=True)
    m = re.search(r"^TOTAL pass=(\d+) fail=(\d+)", proc.stdout, re.M)
    total = str(int(m.group(1)) + int(m.group(2))) if m else None
if not readme_count:
    errors.append("README.md: no 'bash tests/run.sh   # N cases' line")
elif total is None:
    errors.append("tests/run.sh printed no TOTAL line")
elif readme_count.group(1) != total:
    errors.append(f"README.md says {readme_count.group(1)} cases, tests/run.sh has {total}")

for e in errors:
    print("ERROR", e)
print(f"name={name} description={len(desc)} chars keys={keys}")
print(f"body: {n_lines} lines, {n_words} words, {n_chars} chars; references: {len(ref_files)}; tests: {total}")
sys.exit(1 if errors else 0)
