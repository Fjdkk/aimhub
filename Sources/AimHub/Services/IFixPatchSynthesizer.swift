import Foundation

public enum IFixPatchSynthesizer {
    public static func synthesize(baseData: Data, activeSlots: Set<String>) -> Data {
        var b = [UInt8](baseData)
        guard b.count == 7821 else { return baseData }

        let hasBox = activeSlots.contains("esp_2d_box")
        let hasLine = activeSlots.contains("esp_line")
        let hasAimLock = activeSlots.contains("aim_lock")
        let hasAimLegit = activeSlots.contains("aim_legit")

        func writeI32(_ offset: Int, _ val: Int32) {
            var v = val.littleEndian
            withUnsafeBytes(of: &v) { ptr in
                for i in 0..<4 {
                    b[offset + i] = ptr[i]
                }
            }
        }

        // 1. ESP Logic (Method 0 at 0x0B2E)
        if hasLine {
            // Line mode: loop = 0, positionCount = 2
            writeI32(0x0B32, 57)
            writeI32(0x0B32 + 4, 1310728)
            writeI32(0x0B3A, 28)
            writeI32(0x0B3A + 4, 0)

            writeI32(0x12DA + 4, 0) // loop = 0
            writeI32(0x12F2 + 4, 2) // positionCount = 2

            // Point 0 (IL_298, IL_299): Screen Top Center
            // X = local 9 (horizontal center), Y = local 7 + local 8 (head screen Y + box height, well above player head)
            writeI32(0x1482, 20) // Ldloc
            writeI32(0x1482 + 4, 9)
            writeI32(0x148A, 3) // Ldc_R4 1200f
            writeI32(0x148A + 4, 1150681088)

            // Point 1 (IL_307, IL_308): Head Top
            writeI32(0x14CA, 20) // Ldloc
            writeI32(0x14CA + 4, 9)
            writeI32(0x14D2, 20) // Ldloc
            writeI32(0x14D2 + 4, 7)

            // Nop out points 2 and 3
            for p in stride(from: 0x14FA, through: 0x1582, by: 8) {
                writeI32(p, 89) // Nop
                writeI32(p + 4, 0)
            }
        } else if hasBox {
            // Box mode: loop = 1, positionCount = 4
            writeI32(0x0B32, 57)
            writeI32(0x0B32 + 4, 1310728)
            writeI32(0x0B3A, 28)
            writeI32(0x0B3A + 4, 0)

            writeI32(0x12DA + 4, 1)
            writeI32(0x12F2 + 4, 4)

            // Point 0
            writeI32(0x1482, 20); writeI32(0x1482 + 4, 11)
            writeI32(0x148A, 20); writeI32(0x148A + 4, 6)
            // Point 1
            writeI32(0x14CA, 20); writeI32(0x14CA + 4, 11)
            writeI32(0x14D2, 20); writeI32(0x14D2 + 4, 7)

            // Restore Point 2
            writeI32(0x14FA, 20); writeI32(0x14FA + 4, 2)
            writeI32(0x1502, 180); writeI32(0x1502 + 4, 2)
            writeI32(0x150A, 20); writeI32(0x150A + 4, 3)
            writeI32(0x1512, 20); writeI32(0x1512 + 4, 12)
            writeI32(0x151A, 20); writeI32(0x151A + 4, 7)
            writeI32(0x1522, 20); writeI32(0x1522 + 4, 15)
            writeI32(0x152A, 105); writeI32(0x152A + 4, 196622)
            writeI32(0x1532, 175); writeI32(0x1532 + 4, 131108)
            writeI32(0x153A, 175); writeI32(0x153A + 4, 196655)

            // Restore Point 3
            writeI32(0x1542, 20); writeI32(0x1542 + 4, 2)
            writeI32(0x154A, 180); writeI32(0x154A + 4, 3)
            writeI32(0x1552, 20); writeI32(0x1552 + 4, 3)
            writeI32(0x155A, 20); writeI32(0x155A + 4, 12)
            writeI32(0x1562, 20); writeI32(0x1562 + 4, 6)
            writeI32(0x156A, 20); writeI32(0x156A + 4, 15)
            writeI32(0x1572, 105); writeI32(0x1572 + 4, 196622)
            writeI32(0x157A, 175); writeI32(0x157A + 4, 131108)
            writeI32(0x1582, 175); writeI32(0x1582 + 4, 196655)
        } else {
            // Disable ESP
            writeI32(0x0B32, 180)
            writeI32(0x0B32 + 4, 0)
            writeI32(0x0B3A, 136)
            writeI32(0x0B3A + 4, 1)
        }

        let hasAimScope = activeSlots.contains("aim_on_scope")

        // 2. AIM Logic (Method 1 at 0x165E)
        if hasAimLock || hasAimScope {
            // Head Lock
            writeI32(0x1662, 57); writeI32(0x1662 + 4, 65538)
            writeI32(0x166A, 28); writeI32(0x166A + 4, 0)
            writeI32(0x1672 + 4, 65540) // get_HeadCollider
        } else if hasAimLegit {
            // Legit Drag: targets head collider smoothly when dragged, no hip lock resistance
            writeI32(0x1662, 57); writeI32(0x1662 + 4, 65538)
            writeI32(0x166A, 28); writeI32(0x166A + 4, 0)
            writeI32(0x1672 + 4, 65540) // get_HeadCollider
        } else {
            // Disable Aim
            writeI32(0x1662, 180); writeI32(0x1662 + 4, 1)
            writeI32(0x166A, 136); writeI32(0x166A + 4, 1)
        }

        // 3. ESP Visible (Wall ESP) — always show through walls by default when ESP is on
        // IL_053 at offset 0x0CDA: Brfalse 281 → Pop 0
        // This makes ALL alive enemies render ESP even behind walls.
        // The Material already uses _ZTest=Always so it draws on top.
        if hasBox || hasLine {
            writeI32(0x0CDA, 160) // Pop (consume IsVisible bool)
            writeI32(0x0CDA + 4, 0)
        }

        // 4. ESP Health (HP Color Indicator)
        // Default color is Red (R=1f, G=0f, B=0f, A=1f) at IL_263..IL_266 (0x136A..0x1382)
        // When ESP Health is enabled, switch box/line color to Vibrant Neon Green (R=0f, G=1f, B=0f, A=1f)
        let hasHealth = activeSlots.contains("esp_health")
        if hasHealth && (hasBox || hasLine) {
            // IL_263 (R) = 0f
            writeI32(0x136A + 4, 0)
            // IL_264 (G) = 1f (0x3F800000 = 1065353216)
            writeI32(0x1372 + 4, 1065353216)
            // IL_265 (B) = 0f
            writeI32(0x137A + 4, 0)
            // IL_266 (A) = 1f
            writeI32(0x1382 + 4, 1065353216)
        }

        return Data(b)
    }
}
