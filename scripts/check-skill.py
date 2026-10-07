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
# Frontmatter runs from the first line to the next line that is only ---. A --- inside a value does not end it.
fm_m = re.match(r"---[ \t]*\n(.*?)^---[ \t]*$", text, re.S | re.M)
if not fm_m:
    sys.exit("SKILL.md: frontmatter missing (must start with ---)")
fm = fm_m.group(1)
body = text[fm_m.end():].lstrip("\n")
keys = re.findall(r"^([\w-]+):(?=\s|$)", fm, re.M)
# Every top-level line must be a plain key, so a quoted key, a space before the colon or a ? key is not missed.
for ln in fm.split("\n"):
    if ln.strip() and ln[0] not in " \t#" and not re.match(r"[\w-]+:(\s|$)", ln):
        errors.append(f"frontmatter line {ln[:40]!r} is not a plain top-level key")
dupes = sorted({k for k in keys if keys.count(k) > 1})
if dupes:
    errors.append(f"frontmatter repeats a key: {', '.join(dupes)} (YAML keeps the last value)")


class Unsupported(Exception):
    pass


class NotText(Exception):
    pass


# Unquoted values that a YAML loader reads as a boolean, number or date, not as text (YAML 1.1 and 1.2 core schema).
TYPED_PLAIN = re.compile(r"""(?x)
    true|True|TRUE|false|False|FALSE|yes|Yes|YES|no|No|NO|on|On|ON|off|Off|OFF
  | [-+]?(?:0|[1-9][0-9_]*)(?::[0-5]?[0-9])* | [-+]?0[0-7_]+ | 0o[0-7]+ | 0x[0-9a-fA-F_]+ | 0b[01_]+
  | [-+]?(?:\.[0-9]+|[0-9][0-9_]*(?:\.[0-9_]*)?)(?:[eE][-+]?[0-9]+)? | [-+]?\.(?:inf|Inf|INF) | \.(?:nan|NaN|NAN)
  | [0-9]{4}-[0-9]{1,2}-[0-9]{1,2}(?:(?:[Tt]|[ \t]+)[0-9]{1,2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]*)?
        (?:[ \t]*(?:Z|[-+][0-9]{1,2}(?::[0-9]{2})?))?)?
""")


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


ESCAPE = re.compile(r"x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.", re.S)


def flow_quoted(inner, double):
    """Decode the text between the quotes of a quoted scalar.

    A line break folds to a space, and each blank line after it gives a newline. Whitespace around a line break is
    removed, but an escaped character is content and is never removed. In a double-quoted scalar a backslash before a
    line break joins the lines with nothing between; an even run of backslashes is escaped backslashes instead.
    """
    out, kept, i = [], 0, 0  # out[:kept] must not lose trailing whitespace to a fold
    while i < len(inner):
        c = inner[i]
        if c == "\n":
            while len(out) > kept and out[-1] in (" ", "\t"):
                out.pop()
            breaks, i = 0, i + 1
            while True:
                j = i
                while j < len(inner) and inner[j] in " \t":
                    j += 1
                if j < len(inner) and inner[j] == "\n":
                    breaks, i = breaks + 1, j + 1
                else:
                    i = j
                    break
            out.append("\n" * breaks if breaks else " ")
            kept = len(out)
        elif double and c == "\\" and inner[i + 1:i + 2] == "\n":
            i += 2
            while True:  # the next line's indentation goes; each blank line after the escaped break is a newline
                while i < len(inner) and inner[i] in " \t":
                    i += 1
                if i < len(inner) and inner[i] == "\n":
                    out.append("\n")
                    i += 1
                else:
                    break
            kept = len(out)
        elif double and c == "\\":
            m = ESCAPE.match(inner, i + 1)
            e = m.group(0) if m else ""
            if e in DQ_ESCAPES:
                out.append(DQ_ESCAPES[e])
            elif len(e) > 1:
                out.append(chr(int(e[1:], 16)))
            else:
                raise Unsupported(f"unknown escape \\{e}")
            kept, i = len(out), i + 1 + len(e)
        elif not double and inner.startswith("''", i):
            out.append("'")
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def quoted(rest, cont, q):
    """Value of a single- or double-quoted scalar that starts on the key line and may continue on indented lines."""
    raw = "\n".join([rest[1:]] + cont)
    m = re.match(r"((?:[^']|'')*)'" if q == "'" else r'((?:[^"\\]|\\[\s\S])*)"', raw)
    if not m:
        raise Unsupported("unterminated quoted scalar")
    if not re.fullmatch(r"(?:[ \t]+(?:#[^\n]*)?)?(?:\n[ \t]*(?:#[^\n]*)?)*", raw[m.end():]):
        raise Unsupported("text after the closing quote")
    return flow_quoted(m.group(1), q == '"')


def block_scalar(header, cont):
    """Value of a literal (|) or folded (>) block scalar, with optional chomping (+ or -) and indentation digit."""
    m = re.fullmatch(r"([|>])(?:([1-9])([+-]?)|([+-])([1-9]?))?(?:[ \t]+#.*)?", header)
    if not m:
        raise Unsupported(f"bad block scalar header {header!r}")
    style, chomp = m.group(1), m.group(3) or m.group(4) or ""
    explicit = m.group(2) or m.group(5)
    # A line of spaces only is blank. A tab is content, so "  <tab>" is a content line.
    at = next((k for k, ln in enumerate(cont) if ln.strip(" ")), None)
    if at is None:
        return "\n" * len(cont) if chomp == "+" else ""
    indent = int(explicit) if explicit else len(cont[at]) - len(cont[at].lstrip(" "))
    if indent == 0:
        raise Unsupported("block scalar content is not indented")
    if not explicit and any(len(ln) > indent for ln in cont[:at]):
        raise Unsupported("a leading blank line is longer than the block indentation")
    # A less-indented line ends the block. Only comment lines may follow it.
    end = next((k for k in range(at, len(cont)) if cont[k].strip(" ") and not cont[k].startswith(" " * indent)), None)
    if end is not None:
        if not all(ln.lstrip(" \t").startswith("#") or not ln.strip() for ln in cont[end:]):
            raise Unsupported("block scalar line is less indented than the first line")
        cont = cont[:end]
    lines = []
    for ln in cont:
        if not ln.strip(" "):
            lines.append(ln[indent:])  # spaces past the block indentation are content, in | and > alike
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
    lines = fm.split("\n")[:-1]  # fm ends with a newline; the empty item after it is not a line
    for i, ln in enumerate(lines):
        m = re.match(rf"{re.escape(key)}:(?:[ \t]+(.*)|[ \t]*)$", ln)
        if m:
            break
    else:
        return None
    raw_rest = (m.group(1) or "").lstrip()  # a quoted value may end in an escaped space
    if raw_rest.startswith("#"):
        raw_rest = ""  # a comment, not a value
    rest = raw_rest.rstrip()
    cont = []
    for ln in lines[i + 1:]:
        if ln.strip() and ln[0] not in " \t":
            break
        cont.append(ln)
    if not rest:  # the value can start on a later line; a quote or block header there sets its form
        while cont and (not cont[0].strip() or cont[0].lstrip().startswith("#")):
            cont = cont[1:]
        if cont and cont[0].lstrip()[:1] in ("'", '"', "|", ">"):
            raw_rest, cont = cont[0].lstrip(), cont[1:]
            rest = raw_rest.rstrip()
    if rest[:1] in ("|", ">"):
        return block_scalar(rest, cont)
    if rest[:1] in ("'", '"'):
        return quoted(raw_rest, cont, rest[0])
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
    value = fold_flow(plain).strip()
    if TYPED_PLAIN.fullmatch(value):
        raise NotText(value)
    return "" if value in ("~", "null", "Null", "NULL") else value


def field(key):
    """scalar(key) as a string; an unsupported form is an error and reads as empty."""
    try:
        return scalar(key) or ""
    except Unsupported as e:
        errors.append(f"{key} uses an unsupported YAML form ({e}); use a plain, quoted, | or > scalar")
        return ""
    except NotText as e:
        errors.append(f"{key} must be a quoted or plain text value: YAML reads {e} as a boolean, number or date")
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
# references/ is one level deep and every file in it is linked from SKILL.md. Code (fenced, indented or in a code
# span), HTML comments, footnote definitions and an escaped \[ are not links.
LINK_TEXT = r"(?:[^\[\]\\]|\\.|\[(?:[^\[\]\\]|\\.)*\])*"  # one level of nested brackets, as in [![badge](img)](x)
INLINE_LINK = re.compile(r"\[" + LINK_TEXT + r"\]\(\s*(<[^>\n]*>|(?:\\.|[^()\s\\]|\((?:\\.|[^()\s\\])*\))+)(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")
REF_DEF = re.compile(r"^ {0,3}\[(?!\^)(?:[^\]\\]|\\.)+\]:[ \t]*(<[^>\n]*>|\S+)", re.M)
CODE_SPAN = re.compile(r"(`+)(?!`)(?:(?!\n[ \t]*\n).)*?(?<!`)\1(?!`)", re.S)  # never across a blank line
HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)
LIST_ITEM = re.compile(r" {0,3}(?:[-*+]|\d{1,9}[.)])(?:\s|$)")


def drop_fenced_code(text):
    """Blank out fenced code blocks. An unclosed fence runs to the end of the file, as in CommonMark."""
    out, fence = [], None
    for ln in text.split("\n"):
        if fence is None:
            m = re.match(r" {0,3}(`{3,}(?=[^`]*$)|~{3,})", ln)
            fence = m.group(1) if m else None
            out.append("" if m else ln)
        else:
            out.append("")
            if re.fullmatch(r" {0,3}%s{%d,}[ \t]*" % (re.escape(fence[0]), len(fence)), ln):
                fence = None
    return "\n".join(out)


def drop_indented_code(text):
    """Blank out indented code blocks: 4-space lines after a blank line that do not continue a list item."""
    lines, out, in_code, prev = text.split("\n"), [], False, ""  # prev: last non-blank line outside code
    for i, ln in enumerate(lines):
        blank, indented = not ln.strip(), ln.startswith(("    ", "\t"))
        if in_code and (blank or indented):
            out.append("")
            continue
        starts_code = indented and not blank and (i == 0 or not lines[i - 1].strip())
        if starts_code and (not prev or (prev[0] not in " \t" and not LIST_ITEM.match(prev))):
            in_code = True
            out.append("")
            continue
        in_code = False
        out.append(ln)
        if not blank:
            prev = ln
    return "\n".join(out)


def local_links(source_text, source_dir):
    """Local link targets, resolved to repo-root-relative paths. URLs, mailto: and #anchors are skipped."""
    prose = CODE_SPAN.sub("", drop_indented_code(HTML_COMMENT.sub("", drop_fenced_code(source_text))))
    found = []
    for m in re.finditer(r"\[", prose):  # every [ in turn, so a link inside another link's text is found too
        backslashes = len(prose[:m.start()]) - len(prose[:m.start()].rstrip("\\"))
        link = INLINE_LINK.match(prose, m.start()) if backslashes % 2 == 0 else None
        if link:
            found.append(link.group(1))
    out = []
    for target in found + REF_DEF.findall(prose):
        target = target.strip("<>")
        if re.match(r"[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith(("#", "//")):
            continue
        target = re.sub(r"\\([!-/:-@\[-`{-~])", r"\1", re.split(r"[#?]", target, maxsplit=1)[0])
        target = unquote(target)
        if target:
            out.append(target if target.startswith("/") else os.path.normpath(os.path.join(source_dir, target)))
    return list(dict.fromkeys(out))


def check_links(rel, source_text):
    """Report each local link in file rel whose target is missing or outside the repository, once per target.

    Return the targets that exist, so a later check does not report a missing target a second time.
    """
    good = []
    for target in local_links(source_text, os.path.dirname(rel)):
        if target.startswith("/"):
            errors.append(f"{rel} links to {target}, an absolute path (it resolves against the host, not the skill)")
        elif target == ".." or target.startswith(".." + os.sep):
            errors.append(f"{rel} links to {target}, which is outside the repository")
        elif not os.path.exists(path(target)):
            errors.append(f"{rel} links to {target}, which does not exist")
        else:
            good.append(target)
    return good


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
