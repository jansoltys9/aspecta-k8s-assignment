#!/usr/bin/env python3
"""Promote two verified GHCR images in the existing Aspecta Helm values file.

No third-party YAML dependencies. Fail closed if the expected keys are absent.
"""

import argparse
import re
from pathlib import Path


def promote(text: str, owner: str, sha: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Expected a 40-character lowercase Git SHA")
    owner = owner.lower()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", owner):
        raise ValueError("Invalid GitHub owner")

    active = None
    inside_image = False
    seen = set()
    result = []
    for line in text.splitlines(keepends=True):
        if re.match(r"^[a-zA-Z][a-zA-Z0-9_-]*:\s*(?:#.*)?(?:\n)?$", line):
            active = line.split(":", 1)[0]
            inside_image = False
        elif line.startswith("  ") and not line.startswith("    ") and line.strip() and not line.lstrip().startswith("#"):
            inside_image = line.strip().split(":", 1)[0] == "image"

        if active in {"backend", "frontend"} and inside_image:
            field_match = re.match(r"^(    )(repository|tag):[^\n\r]*(\r?\n)?$", line)
            if field_match:
                key = field_match.group(2)
                desired = (f"ghcr.io/{owner}/aspecta-{active}"
                           if key == "repository" else f"sha-{sha}")
                line = f"    {key}: {desired}{field_match.group(3) or ''}"
                if (active, key) in seen:
                    raise ValueError(f"Duplicate {active}.{key}")
                seen.add((active, key))
        result.append(line)

    expected = {(component, key) for component in ("backend", "frontend") for key in ("repository", "tag")}
    if seen != expected:
        raise ValueError(f"Unexpected Helm values layout; found {seen}, expected {expected}")
    return "".join(result)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--file", default="helm/aspecta/values.yaml")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    path = Path(args.file)
    old = path.read_text(encoding="utf-8")
    new = promote(old, args.owner, args.sha)
    if args.dry_run:
        print(new)
    elif new != old:
        path.write_text(new, encoding="utf-8")
        print(f"Updated {path}: backend/frontend -> sha-{args.sha}")
    else:
        print(f"Already up to date: {path}")


if __name__ == "__main__":
    main()
