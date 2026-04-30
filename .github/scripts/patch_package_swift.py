"""Patches Package.swift in-place: rewrites every binaryTarget block's url and
checksum to match the version + sha env vars supplied by the workflow."""
import os
import re
import sys

VERSION = os.environ["VERSION"]
SHAS = {
    "PromiseKit": os.environ["PROMISEKIT_SHA"],
}

URL_TEMPLATE = (
    "https://github.com/Cambly/Cambly-PromiseKit-Binary/releases/download/"
    "{version}/{name}.xcframework.zip"
)

PATH = "Package.swift"


def replace_block(text, name, version, sha):
    pattern = re.compile(
        r'(\.binaryTarget\(\s*\n?\s*name:\s*"' + re.escape(name) + r'",\s*\n?\s*url:\s*)"[^"]*"(\s*,\s*\n?\s*checksum:\s*)"[^"]*"',
        re.MULTILINE,
    )
    new_url = URL_TEMPLATE.format(version=version, name=name)
    new_text, n = pattern.subn(rf'\1"{new_url}"\2"{sha}"', text, count=1)
    if n != 1:
        sys.exit(f"❌ Failed to find binaryTarget block for {name} in {PATH}")
    return new_text


text = open(PATH).read()
for name, sha in SHAS.items():
    text = replace_block(text, name, VERSION, sha)
open(PATH, "w").write(text)
print(f"✅ Patched {PATH} for version {VERSION}")
