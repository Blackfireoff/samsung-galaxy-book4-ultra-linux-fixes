#!/usr/bin/env python3
"""Patch a Samsung 960XGL DSDT for BAT1 and FAN0 Linux compatibility.

This script intentionally patches a locally dumped/decompiled DSDT. Do not use
someone else's compiled AML on a different BIOS revision.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


BAT1_HIDE_BRANCH = """                If ((LINX != One))
                {
                    If (((WDC0 == 0x81) && (ACEX != PWRS)))
                    {
                        WDC2 = 0x81
                        Return (Zero)
                    }
                }

"""

BAT1_PATCH_COMMENT = """                /* PATCH: do not hide BAT1 when booting Linux without AC adapter */
"""

XHCI_TEMP_EXTERNALS = [
    "    External (_SB_.PC00.XHCI._PS0.PS0X, MethodObj)    // 0 Arguments\n",
    "    External (_SB_.PC00.XHCI._PS3.PS3X, MethodObj)    // 0 Arguments\n",
    "    External (_SB_.PC02.XHCI._PS0.PS0X, MethodObj)    // 0 Arguments\n",
    "    External (_SB_.PC02.XHCI._PS3.PS3X, MethodObj)    // 0 Arguments\n",
]

XHCI_PS0_BODY = """                    ADBG ("XHCI D0")
                    UPRU (Zero, 0xFFFFFFF7, Zero)
                    If ((DVID == 0xFFFF))
                    {
                        Return (Zero)
                    }

                    If (CondRefOf (PS0X))
                    {
                        PS0X ()
                    }
"""

XHCI_PS3_BODY = """                    ADBG ("XHCI D3")
                    UPRU (Zero, 0xFFFFFFFF, 0x08)
                    If ((DVID == 0xFFFF))
                    {
                        Return (Zero)
                    }

                    If (CondRefOf (PS3X))
                    {
                        PS3X ()
                    }
"""

FAN0_FST_BROKEN_READ = """                    Local1 = FANT [Local0]
                    Local1 += 0x0A
"""

FAN0_FST_FIXED_READ = """                    /* PATCH: ACPICA needs the package element dereferenced before Add */
                    Local1 = DerefOf (FANT [Local0])
                    Local1 += 0x0A
"""


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


def replace_nth(text: str, old: str, new: str, nth: int, label: str) -> str:
    pos = -1
    start = 0
    for _ in range(nth):
        pos = text.find(old, start)
        if pos == -1:
            raise SystemExit(f"{label}: match {nth} not found")
        start = pos + len(old)
    return text[:pos] + new + text[pos + len(old) :]


def bump_oem_revision(text: str) -> str:
    pattern = re.compile(
        r'(DefinitionBlock\s+\("[^"]*",\s+"DSDT",\s+\d+,\s+"[^"]+",\s+"[^"]+",\s+)'
        r'0x([0-9A-Fa-f]{8})(\))'
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit("DefinitionBlock OEM revision not found")

    revision = int(match.group(2), 16)
    bumped = f"0x{revision + 1:08X}"
    return text[: match.start()] + match.group(1) + bumped + match.group(3) + text[match.end() :]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", nargs="?", default="dsdt.dsl")
    parser.add_argument("output", nargs="?", default="dsdt-patched.dsl")
    args = parser.parse_args()

    source = Path(args.input)
    target = Path(args.output)
    text = source.read_text(encoding="utf-8")

    text = bump_oem_revision(text)
    text = replace_once(text, BAT1_HIDE_BRANCH, BAT1_PATCH_COMMENT, "BAT1._STA hide branch")

    for external in XHCI_TEMP_EXTERNALS:
        text = text.replace(external, "")

    text = replace_nth(
        text,
        XHCI_PS0_BODY,
        XHCI_PS0_BODY.replace("CondRefOf (PS0X)", r"CondRefOf (\_SB.PC00.XHCI.RHUB.PS0X)").replace(
            "PS0X ()", r"\_SB.PC00.XHCI.RHUB.PS0X ()"
        ),
        1,
        "PC00 XHCI _PS0",
    )
    text = replace_nth(
        text,
        XHCI_PS3_BODY,
        XHCI_PS3_BODY.replace("CondRefOf (PS3X)", r"CondRefOf (\_SB.PC00.XHCI.RHUB.PS3X)").replace(
            "PS3X ()", r"\_SB.PC00.XHCI.RHUB.PS3X ()"
        ),
        1,
        "PC00 XHCI _PS3",
    )
    text = replace_nth(
        text,
        XHCI_PS0_BODY,
        XHCI_PS0_BODY.replace("CondRefOf (PS0X)", r"CondRefOf (\_SB.PC02.XHCI.RHUB.PS0X)").replace(
            "PS0X ()", r"\_SB.PC02.XHCI.RHUB.PS0X ()"
        ),
        1,
        "PC02 XHCI _PS0",
    )
    text = replace_nth(
        text,
        XHCI_PS3_BODY,
        XHCI_PS3_BODY.replace("CondRefOf (PS3X)", r"CondRefOf (\_SB.PC02.XHCI.RHUB.PS3X)").replace(
            "PS3X ()", r"\_SB.PC02.XHCI.RHUB.PS3X ()"
        ),
        1,
        "PC02 XHCI _PS3",
    )

    text = replace_once(text, FAN0_FST_BROKEN_READ, FAN0_FST_FIXED_READ, "FAN0._FST package dereference")

    target.write_text(text, encoding="utf-8")
    print(f"Wrote patched DSDT: {target}")


if __name__ == "__main__":
    main()
