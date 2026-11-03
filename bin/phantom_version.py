"""Version parsing shared by the installer and update checker."""
import re
import sys

VERSION_RE = re.compile(r"^(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$")


def clean(value):
    value = (value or "").strip().removeprefix("v").removeprefix("V")
    match = VERSION_RE.fullmatch(value)
    if not match:
        return ""
    if match.group(3) is not None and any(len(x) > 1 and x.startswith("0") for x in match.group(1, 2, 3)):
        return ""
    pre = match.group(4)
    if pre and any(x.isdigit() and len(x) > 1 and x.startswith("0") for x in pre.split(".")):
        return ""
    return value


def key(value):
    value = clean(value)
    if not value:
        return None
    match = VERSION_RE.fullmatch(value)
    major, minor, patch = (int(x or 0) for x in match.group(1, 2, 3))
    pre = match.group(4)
    identifiers = tuple((0, int(x)) if x.isdigit() else (1, x) for x in pre.split(".")) if pre else ()
    return major, minor, patch, 0 if pre else 1, identifiers


if __name__ == "__main__":
    a = key(sys.argv[1]) if len(sys.argv) > 1 else None
    b = key(sys.argv[2]) if len(sys.argv) > 2 else None
    sys.exit(0 if a is not None and b is not None and a > b else 1)
