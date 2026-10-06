"""Check SKILL.md against the claude.ai and Codex skill rules, and agents/openai.yaml. Exit 1 on any failure."""
import re
import sys

text = open("SKILL.md", encoding="utf-8").read()
errors = []
parts = text.split("---")
if not text.startswith("---") or len(parts) < 3:
    sys.exit("SKILL.md: frontmatter missing (must start with ---)")
fm = parts[1]
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
if set(keys) - {"name", "description", "license", "allowed-tools", "metadata"}:
    errors.append(f"unexpected frontmatter keys: {keys}")

# Codex metadata: agents/openai.yaml must carry the interface fields and name the skill in its default prompt.
try:
    oy = open("agents/openai.yaml", encoding="utf-8").read()
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
if block and f"${name}" not in fields.get("default_prompt", ""):
    errors.append(f"agents/openai.yaml: interface.default_prompt does not name ${name}")

for e in errors:
    print("ERROR", e)
print(f"name={name} description={len(desc)} chars keys={keys}")
sys.exit(1 if errors else 0)
