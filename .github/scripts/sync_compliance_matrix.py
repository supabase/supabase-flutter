#!/usr/bin/env python3
"""Append capability IDs from the canonical spec that are missing locally.

Reads the canonical capability files checked out under `_sdk-spec/capabilities/`
and appends any IDs not already present in `sdk-compliance.yaml` as
`not_implemented`, leaving them for a human to triage. The list of added IDs is
also written to `new_ids.txt` for the workflow to use in the pull request body.
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


def read_existing_ids(lines):
    identifiers = set()
    for line in lines:
        found = FEATURE_KEY.match(line)
        if found:
            identifiers.add(found.group(1))
    return identifiers


def main():
    if not CAPABILITIES_DIRECTORY.is_dir():
        sys.exit(f"Canonical capabilities not found at {CAPABILITIES_DIRECTORY}")
    text = COMPLIANCE_FILE.read_text()
    new_identifiers = sorted(read_canonical_ids() - read_existing_ids(text.splitlines()))
    Path("new_ids.txt").write_text("\n".join(new_identifiers))
    if not new_identifiers:
        print("No new capability IDs.")
        return
    if not text.endswith("\n"):
        text += "\n"
    block = [
        "",
        "  # Newly synced from the canonical spec; triage status and symbols before merge.",
    ]
    block += [f"  {identifier}: not_implemented" for identifier in new_identifiers]
    COMPLIANCE_FILE.write_text(text + "\n".join(block) + "\n")
    print(f"Added {len(new_identifiers)} new capability IDs.")


if __name__ == "__main__":
    main()
