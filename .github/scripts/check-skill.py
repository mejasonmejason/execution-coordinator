"""Check SKILL.md against the claude.ai skill upload rules. Exit 1 on any failure."""
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

for e in errors:
    print("ERROR", e)
print(f"name={name} description={len(desc)} chars keys={keys}")
sys.exit(1 if errors else 0)
