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
from urllib.parse import unquote

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


class Unsupported(Exception):
    pass


def fold_flow(lines):
    """Fold the lines of a multi-line plain or quoted scalar: one line break is a space, each blank line is a newline."""
    out, blanks = "", 0
    for i, ln in enumerate(lines):
        ln = ln.strip(" \t") if 0 < i < len(lines) - 1 else (ln.rstrip(" \t") if i == 0 else ln.lstrip(" \t"))
        if i and not ln and i < len(lines) - 1:
            blanks += 1
            continue
        if i:
            out += "\n" * blanks if blanks else " "
        out, blanks = out + ln, 0
    return out


DQ_ESCAPES = {"0": "\0", "a": "\a", "b": "\b", "t": "\t", "\t": "\t", "n": "\n", "v": "\v", "f": "\f", "r": "\r",
              "e": "\x1b", " ": " ", '"': '"', "/": "/", "\\": "\\", "N": "\x85", "_": "\xa0", "L": "\u2028",
              "P": "\u2029"}


def quoted(rest, cont, q):
    """Value of a single- or double-quoted scalar that starts on the key line and may continue on indented lines."""
    lines = [rest[1:]] + cont
    raw = "\n".join(lines)
    if q == "'":
        m = re.match(r"((?:[^']|'')*)'", raw)
        if not m:
            raise Unsupported("unterminated single-quoted scalar")
        tail, value = raw[m.end():], fold_flow(m.group(1).split("\n")).replace("''", "'")
    else:
        m = re.match(r'((?:[^"\\]|\\.|\\\n)*)"', raw)
        if not m:
            raise Unsupported("unterminated double-quoted scalar")
        tail, inner = raw[m.end():], m.group(1)
        inner = re.sub(r"\\[ \t]*\n[ \t]*", "", inner)  # an escaped line break joins the lines with nothing between

        def esc(e):
            c = e.group(1)
            if c in DQ_ESCAPES:
                return DQ_ESCAPES[c]
            width = {"x": 2, "u": 4, "U": 8}.get(c[0])
            if width and re.fullmatch(r"[0-9A-Fa-f]{%d}" % width, c[1:]):
                return chr(int(c[1:], 16))
            raise Unsupported(f"unknown escape \\{c}")

        # Fold first, so an escaped \n is not treated as a line break.
        value = re.sub(r"\\(x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.)", esc, fold_flow(inner.split("\n")))
    if tail.strip() and not re.fullmatch(r"\s+#.*|\s*", tail, re.S):
        raise Unsupported("text after the closing quote")
    return value


def block_scalar(header, cont):
    """Value of a literal (|) or folded (>) block scalar, with optional chomping (+ or -) and indentation digit."""
    m = re.fullmatch(r"([|>])(?:([1-9])([+-]?)|([+-])([1-9]?))?(?:[ \t]+#.*)?", header)
    if not m:
        raise Unsupported(f"bad block scalar header {header!r}")
    style, chomp = m.group(1), m.group(3) or m.group(4) or ""
    explicit = m.group(2) or m.group(5)
    first = next((ln for ln in cont if ln.strip()), None)
    if first is None:
        return ""
    indent = int(explicit) if explicit else len(first) - len(first.lstrip(" "))
    if "\t" in first[:indent] or indent == 0:
        raise Unsupported("block scalar indentation is not spaces")
    lines = []
    for ln in cont:
        if not ln.strip():
            lines.append(ln[indent:] if style == "|" and len(ln) > indent else "")
        elif not ln.startswith(" " * indent):
            raise Unsupported("block scalar line is less indented than the first line")
        else:
            lines.append(ln[indent:])
    n = len(lines)
    while n and not lines[n - 1]:
        n -= 1
    content, trailing = lines[:n], len(lines) - n
    if style == "|":
        text = "\n".join(content)
    else:
        text, prev, blanks = "", None, 0
        for ln in content:
            if not ln:
                blanks += 1
                continue
            kind = "more" if ln[0] in " \t" else "text"
            if prev is None:
                text += "\n" * blanks
            elif prev == kind == "text":
                text += "\n" * blanks if blanks else " "
            else:
                text += "\n" * (blanks + 1)
            text, prev, blanks = text + ln, kind, 0
    if chomp == "-" or not text:
        return text
    return text + "\n" + ("\n" * trailing if chomp == "+" else "")


def scalar(key):
    """The real string value of a top-level frontmatter key, or None when the key is absent.

    Supports plain, single-quoted, double-quoted, literal (|) and folded (>) scalars, including multi-line values.
    Raises Unsupported for any other YAML form (flow collections, anchors, aliases, tags, nested mappings), so a
    value the checker cannot measure fails instead of passing on its first line.
    """
    lines = fm.split("\n")
    for i, ln in enumerate(lines):
        m = re.match(rf"{re.escape(key)}:(?:[ \t]+(.*)|[ \t]*)$", ln)
        if m:
            break
    else:
        return None
    rest = (m.group(1) or "").strip()
    cont = []
    for ln in lines[i + 1:]:
        if ln.strip() and ln[0] not in " \t":
            break
        cont.append(ln)
    if rest[:1] in ("|", ">"):
        return block_scalar(rest, cont)
    if rest[:1] in ("'", '"'):
        return quoted(rest, cont, rest[0])
    if rest[:1] in tuple("[]{}&*!%@`,") or re.match(r"[-?:](\s|$)", rest) or rest.startswith("#"):
        raise Unsupported(f"value starts with {rest[:1]!r}")
    while cont and not cont[-1].strip():
        cont.pop()
    plain = [re.split(r"[ \t]#", rest, maxsplit=1)[0]] + [re.split(r"(?:^|[ \t])#", c, maxsplit=1)[0] for c in cont]
    for part in plain:
        if re.search(r":(\s|$)", part.strip()) or re.match(r"\s*[-?](\s|$)", part):
            raise Unsupported("value holds a nested mapping or sequence")
    if not rest and cont:
        plain = plain[1:]
    return fold_flow(plain).strip()


def field(key):
    """scalar(key) as a string; an unsupported form is an error and reads as empty."""
    try:
        return scalar(key) or ""
    except Unsupported as e:
        errors.append(f"{key} uses an unsupported YAML form ({e}); use a plain, quoted, | or > scalar")
        return ""


name = field("name")
desc = field("description")

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
    n_err = len(errors)
    compat = field("compatibility")
    if not compat.strip() and len(errors) == n_err:
        errors.append("compatibility is empty")
    if len(compat) > 500:
        errors.append(f"compatibility is {len(compat)} characters (limit 500)")

# Size budget for the body (everything after the closing frontmatter ---).
n_lines, n_words, n_chars = len(body.splitlines()), len(body.split()), len(body)
for label, got, limit in (("lines", n_lines, 500), ("words", n_words, 5000), ("characters", n_chars, 20000)):
    if got > limit:
        errors.append(f"SKILL.md body is {got} {label} (limit {limit})")

# Links: every local Markdown link in SKILL.md and references/*.md must resolve, relative to the file that holds it.
# references/ is one level deep and every file in it is linked from SKILL.md. Code spans and fenced code are not links.
INLINE_LINK = re.compile(r"!?\[(?:[^\]\\]|\\.)*\]\(\s*(<[^>\n]*>|[^)\s]+)(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")
REF_DEF = re.compile(r"^ {0,3}\[(?:[^\]\\]|\\.)+\]:[ \t]*(<[^>\n]*>|\S+)", re.M)
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,}).*?(?:^ {0,3}\1[`~]*[ \t]*$|\Z)", re.M | re.S)
CODE_SPAN = re.compile(r"(`+)(?!`).*?(?<!`)\1(?!`)", re.S)


def local_links(source_text, source_dir):
    """Local link targets, resolved to repo-root-relative paths. URLs, mailto: and #anchors are skipped."""
    prose = CODE_SPAN.sub("", FENCE.sub("", source_text))
    out = []
    for target in INLINE_LINK.findall(prose) + REF_DEF.findall(prose):
        target = target.strip("<>")
        if re.match(r"[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith(("#", "//")):
            continue
        target = unquote(re.split(r"[#?]", target, maxsplit=1)[0])
        if target:
            base = "" if target.startswith("/") else source_dir
            out.append(os.path.normpath(os.path.join(base, target.lstrip("/"))))
    return out


def check_links(rel, source_text):
    """Report each local link in file rel whose target is missing or outside the repository; return the targets."""
    targets = local_links(source_text, os.path.dirname(rel))
    for target in targets:
        if target == ".." or target.startswith(".." + os.sep):
            errors.append(f"{rel} links to {target}, which is outside the repository")
        elif not os.path.exists(path(target)):
            errors.append(f"{rel} links to {target}, which does not exist")
    return targets


ref_dir = path("references")
ref_files = sorted(f for f in os.listdir(ref_dir) if f.endswith(".md")) if os.path.isdir(ref_dir) else []
linked = {t for t in check_links("SKILL.md", body) if t.startswith("references" + os.sep)}
for f in ref_files:
    rel = os.path.join("references", f)
    if rel not in linked:
        errors.append(f"{rel} is not linked from SKILL.md")
    for target in check_links(rel, read(rel)):
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
