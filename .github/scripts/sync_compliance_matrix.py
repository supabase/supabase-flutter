#!/usr/bin/env python3
"""Insert capability IDs from the canonical spec that are missing locally.

Reads the canonical capability files checked out under `_sdk-spec/capabilities/`
and inserts any IDs not already present in `sdk-compliance.yaml` as
`not_implemented`, next to their existing siblings (same `area.group.` prefix)
so they land in the right section. IDs belonging to a group with no local
sibling yet are appended at the end under a comment for manual placement. The
list of added IDs is written to `new_ids.txt` for the workflow's pull request
body.
"""
import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
COMPLIANCE_FILE = REPOSITORY_ROOT / "sdk-compliance.yaml"
CAPABILITIES_DIRECTORY = REPOSITORY_ROOT / "_sdk-spec" / "capabilities"

FEATURE_KEY = re.compile(r"^  ([a-z0-9_]+(?:\.[a-z0-9_]+)+):")
CANONICAL_ID = re.compile(r"^\s*-\s*id:\s*([a-z0-9_]+(?:\.[a-z0-9_]+)+)")


def read_canonical_ids():
    identifiers = set()
    for path in sorted(CAPABILITIES_DIRECTORY.glob("*.yaml")):
        for line in path.read_text().splitlines():
            found = CANONICAL_ID.match(line)
            if found:
                identifiers.add(found.group(1))
    return identifiers


def feature_key_at(lines, index):
    found = FEATURE_KEY.match(lines[index])
    return found.group(1) if found else None


def read_existing_ids(lines):
    return {key for index in range(len(lines)) if (key := feature_key_at(lines, index))}


def block_end(lines, start):
    end = start + 1
    while end < len(lines) and lines[end].startswith("    "):
        end += 1
    return end


def insertion_index(lines, prefix):
    last = None
    for index in range(len(lines)):
        key = feature_key_at(lines, index)
        if key and key.startswith(prefix):
            last = index
    if last is None:
        return None
    return block_end(lines, last)


def main():
    if not CAPABILITIES_DIRECTORY.is_dir():
        sys.exit(f"Canonical capabilities not found at {CAPABILITIES_DIRECTORY}")
    lines = COMPLIANCE_FILE.read_text().splitlines()
    new_identifiers = sorted(read_canonical_ids() - read_existing_ids(lines))
    Path("new_ids.txt").write_text("\n".join(new_identifiers))
    if not new_identifiers:
        print("No new capability IDs.")
        return

    orphans = []
    for identifier in new_identifiers:
        prefix = identifier.rsplit(".", 1)[0] + "."
        index = insertion_index(lines, prefix)
        if index is None:
            orphans.append(identifier)
            continue
        lines.insert(index, f"  {identifier}: not_implemented")

    if orphans:
        lines.append("")
        lines.append(
            "  # Newly synced from the canonical spec; no local group yet, place manually."
        )
        lines += [f"  {identifier}: not_implemented" for identifier in orphans]

    COMPLIANCE_FILE.write_text("\n".join(lines) + "\n")
    print(
        f"Added {len(new_identifiers)} new capability IDs "
        f"({len(orphans)} without an existing group)."
    )


if __name__ == "__main__":
    main()
