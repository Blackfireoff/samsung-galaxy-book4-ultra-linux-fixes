Reference patch for the tested Samsung 960XGL DSDT.

The authoritative/reproducible path is:

  acpi/scripts/patch-dsdt-bat1.py dsdt.dsl dsdt-patched.dsl

Core BAT1 change:

--- a/dsdt.dsl
+++ b/dsdt-patched.dsl
@@
             Name (WDC2, Zero)
             Method (_STA, 0, Serialized)  // _STA: Status
             {
-                If ((LINX != One))
-                {
-                    If (((WDC0 == 0x81) && (ACEX != PWRS)))
-                    {
-                        WDC2 = 0x81
-                        Return (Zero)
-                    }
-                }
-
+                /* PATCH: do not hide BAT1 when booting Linux without AC adapter */
                 If ((PBTE == One))
                 {
                     Local0 = 0x0F

FAN0 fan-status compatibility change:

The tested firmware exposes `FAN0` as `PNP0C0B`, but Linux logs repeated
`AE_AML_OPERAND_TYPE` failures when evaluating `_FST`. The failing operation is
the `Add` after reading a package element from `FANT`. ACPICA needs the package
element dereferenced before arithmetic.

--- a/dsdt.dsl
+++ b/dsdt-patched.dsl
@@
-                    Local1 = FANT [Local0]
+                    /* PATCH: ACPICA needs the package element dereferenced before Add */
+                    Local1 = DerefOf (FANT [Local0])
                     Local1 += 0x0A

Compile fixes applied by the script:

--- a/dsdt.dsl
+++ b/dsdt-patched.dsl
@@
-DefinitionBlock ("", "DSDT", 2, "SECCSD", "LH43STAR", 0x01072009)
+DefinitionBlock ("", "DSDT", 2, "SECCSD", "LH43STAR", 0x0107200A)
@@
-    External (_SB_.PC00.XHCI._PS0.PS0X, MethodObj)    // 0 Arguments
-    External (_SB_.PC00.XHCI._PS3.PS3X, MethodObj)    // 0 Arguments
@@
-    External (_SB_.PC02.XHCI._PS0.PS0X, MethodObj)    // 0 Arguments
-    External (_SB_.PC02.XHCI._PS3.PS3X, MethodObj)    // 0 Arguments
@@
-                    If (CondRefOf (PS0X))
+                    If (CondRefOf (\_SB.PC00.XHCI.RHUB.PS0X))
                     {
-                        PS0X ()
+                        \_SB.PC00.XHCI.RHUB.PS0X ()
                     }
@@
-                    If (CondRefOf (PS3X))
+                    If (CondRefOf (\_SB.PC00.XHCI.RHUB.PS3X))
                     {
-                        PS3X ()
+                        \_SB.PC00.XHCI.RHUB.PS3X ()
                     }
@@
-                    If (CondRefOf (PS0X))
+                    If (CondRefOf (\_SB.PC02.XHCI.RHUB.PS0X))
                     {
-                        PS0X ()
+                        \_SB.PC02.XHCI.RHUB.PS0X ()
                     }
@@
-                    If (CondRefOf (PS3X))
+                    If (CondRefOf (\_SB.PC02.XHCI.RHUB.PS3X))
                     {
-                        PS3X ()
+                        \_SB.PC02.XHCI.RHUB.PS3X ()
                     }
