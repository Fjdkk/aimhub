import Foundation

public enum IFixPatchSynthesizer {
    public static func synthesize(baseData: Data, activeSlots: Set<String>) -> Data {
        var b = [UInt8](baseData)
        guard b.count == 8517 || b.count == 7821 else { return baseData }

        let shift = (b.count == 8517) ? 0x128 : 0

        let hasBox = activeSlots.contains("esp_2d_box")
        let hasLine = activeSlots.contains("esp_line")
        let hasAimSilent = activeSlots.contains("aim_silent")
        let hasAimLock = activeSlots.contains("aim_lock")
        let hasAimLegit = activeSlots.contains("aim_legit")
        let hasAimScope = activeSlots.contains("aim_on_scope")
        let hasHealth = activeSlots.contains("esp_health")
        let hasName = activeSlots.contains("esp_name")

        let hasHighJump = activeSlots.contains("high_jump")
        let hasFastGun = activeSlots.contains("fast_weapon_switch")
        let hasNoRecoil = activeSlots.contains("weapon_no_recoil")
        let hasCamXa = activeSlots.contains("camera_zoom_out")
        let hasFastMedkit = activeSlots.contains("fast_medkit")
        let hasNoDelay = activeSlots.contains("no_delay_shoot")
        let hasUnlimitedAmmo = activeSlots.contains("double_gun") || activeSlots.contains("fast_reload")

        func writeI32(_ offset: Int, _ val: Int32) {
            var v = val.littleEndian
            withUnsafeBytes(of: &v) { ptr in
                for i in 0..<4 {
                    b[offset + i] = ptr[i]
                }
            }
        }

        // 1. ESP Logic (Method 0 at 0x0B2E + shift)
        if hasLine {
            // Line mode: loop = 0, positionCount = 2
            writeI32(0x0B32 + shift, 57)
            writeI32(0x0B32 + shift + 4, 1310728)
            writeI32(0x0B3A + shift, 28)
            writeI32(0x0B3A + shift + 4, 0)

            writeI32(0x12DA + shift + 4, 0) // loop = 0
            writeI32(0x12F2 + shift + 4, 2) // positionCount = 2

            // Point 0 (IL_298..300): Screen Top Center (X=1200f, Y=1000f, Depth=0.4f)
            writeI32(0x1482 + shift, 3) // Ldc_R4 1200f
            writeI32(0x1482 + shift + 4, 1150681088)
            writeI32(0x148A + shift, 3) // Ldc_R4 1000f
            writeI32(0x148A + shift + 4, 1148846080)
            writeI32(0x1492 + shift, 3) // Ldc_R4 0.4f (Camera Screen Plane Depth)
            writeI32(0x1492 + shift + 4, 1053609165)

            // Point 1 (IL_307, IL_308): Enemy Head Top
            writeI32(0x14CA + shift, 20) // Ldloc 9
            writeI32(0x14CA + shift + 4, 9)
            writeI32(0x14D2 + shift, 20) // Ldloc 7
            writeI32(0x14D2 + shift + 4, 7)
            writeI32(0x14DA + shift, 20) // Ldloc 15 (Enemy distance)
            writeI32(0x14DA + shift + 4, 15)

            // Nop out points 2 and 3
            for p in stride(from: 0x14FA + shift, through: 0x1582 + shift, by: 8) {
                writeI32(p, 89) // Nop
                writeI32(p + 4, 0)
            }
        } else if hasBox {
            // Box mode: loop = 1, positionCount = 4
            writeI32(0x0B32 + shift, 57)
            writeI32(0x0B32 + shift + 4, 1310728)
            writeI32(0x0B3A + shift, 28)
            writeI32(0x0B3A + shift + 4, 0)

            writeI32(0x12DA + shift + 4, 1)
            writeI32(0x12F2 + shift + 4, 4)

            // Point 0
            writeI32(0x1482 + shift, 20); writeI32(0x1482 + shift + 4, 11)
            writeI32(0x148A + shift, 20); writeI32(0x148A + shift + 4, 6)
            // Point 1
            writeI32(0x14CA + shift, 20); writeI32(0x14CA + shift + 4, 11)
            writeI32(0x14D2 + shift, 20); writeI32(0x14D2 + shift + 4, 7)

            // Restore Point 2
            writeI32(0x14FA + shift, 20); writeI32(0x14FA + shift + 4, 2)
            writeI32(0x1502 + shift, 180); writeI32(0x1502 + shift + 4, 2)
            writeI32(0x150A + shift, 20); writeI32(0x150A + shift + 4, 3)
            writeI32(0x1512 + shift, 20); writeI32(0x1512 + shift + 4, 12)
            writeI32(0x151A + shift, 20); writeI32(0x151A + shift + 4, 7)
            writeI32(0x1522 + shift, 20); writeI32(0x1522 + shift + 4, 15)
            writeI32(0x152A + shift, 105); writeI32(0x152A + shift + 4, 196622)
            writeI32(0x1532 + shift, 175); writeI32(0x1532 + shift + 4, 131108)
            writeI32(0x153A + shift, 175); writeI32(0x153A + shift + 4, 196655)

            // Restore Point 3
            writeI32(0x1542 + shift, 20); writeI32(0x1542 + shift + 4, 2)
            writeI32(0x154A + shift, 180); writeI32(0x154A + shift + 4, 3)
            writeI32(0x1552 + shift, 20); writeI32(0x1552 + shift + 4, 3)
            writeI32(0x155A + shift, 20); writeI32(0x155A + shift + 4, 12)
            writeI32(0x1562 + shift, 20); writeI32(0x1562 + shift + 4, 6)
            writeI32(0x156A + shift, 20); writeI32(0x156A + shift + 4, 15)
            writeI32(0x1572 + shift, 105); writeI32(0x1572 + shift + 4, 196622)
            writeI32(0x157A + shift, 175); writeI32(0x157A + shift + 4, 131108)
            writeI32(0x1582 + shift, 175); writeI32(0x1582 + shift + 4, 196655)
        } else {
            // Disable ESP
            writeI32(0x0B32 + shift, 180)
            writeI32(0x0B32 + shift + 4, 0)
            writeI32(0x0B3A + shift, 136)
            writeI32(0x0B3A + shift + 4, 1)
        }

        // 2. AIM Logic (Method 1 at 0x165E + shift)
        if hasAimSilent {
            // Silent Aim: silent trajectory lock to HeadCollider without rotating camera
            writeI32(0x1662 + shift, 57); writeI32(0x1662 + shift + 4, 65538)
            writeI32(0x166A + shift, 28); writeI32(0x166A + shift + 4, 0)
            writeI32(0x1672 + shift + 4, 65540) // get_HeadCollider
        } else if hasAimLock || hasAimScope {
            // Aim Lock: snap to head collider directly
            writeI32(0x1662 + shift, 57); writeI32(0x1662 + shift + 4, 65538)
            writeI32(0x166A + shift, 28); writeI32(0x166A + shift + 4, 0)
            writeI32(0x1672 + shift + 4, 65540) // get_HeadCollider
        } else if hasAimLegit {
            // Aim Legit (Dev cũ chuẩn): targets hip/body transform (GetHipTF, extern method 7 = 0x10007 = 65543).
            // Không bị đơ cam, di chuyển mượt mà, khi đè bắn bám thân địch và vuốt nhẹ lên đầu!
            writeI32(0x1662 + shift, 57); writeI32(0x1662 + shift + 4, 65538)
            writeI32(0x166A + shift, 28); writeI32(0x166A + shift + 4, 0)
            writeI32(0x1672 + shift + 4, 65543) // GetHipTF (chuẩn dev cũ)
        } else {
            // Disable Aim
            writeI32(0x1662 + shift, 180); writeI32(0x1662 + shift + 4, 1)
            writeI32(0x166A + shift, 136); writeI32(0x166A + shift + 4, 1)
        }

        // 3. ESP Visible (Wall ESP) — always show through walls by default when ESP is on
        if hasBox || hasLine {
            writeI32(0x0CDA + shift, 160) // Pop (consume IsVisible bool)
            writeI32(0x0CDA + shift + 4, 0)
        }

        // 4. ESP Health (HP Color Indicator)
        if hasHealth && (hasBox || hasLine) {
            writeI32(0x136A + shift + 4, 0) // R = 0f
            writeI32(0x1372 + shift + 4, 1065353216) // G = 1f
            writeI32(0x137A + shift + 4, 0) // B = 0f
            writeI32(0x1382 + shift + 4, 1065353216) // A = 1f
        }

        // 5. Multi-Feature Handlers (if 8517 bytes patch)
        if b.count == 8517 {
            // Method 2 (High Jump get_MaxJumpHeight): 12.0f (1094713344) or normal 1.5f (1069547520)
            let jumpVal: Int32 = hasHighJump ? 1094713344 : 1069547520
            writeI32(0x17EA + 4, jumpVal)

            // Method 3 (Fast Gun / Đổi Súng Nhanh get_InSwapWeaponCD): 0 (false) or normal 1 (true)
            let gunVal: Int32 = hasFastGun ? 0 : 1
            writeI32(0x1802 + 4, gunVal)

            // Method 4 (No Recoil GetScatterRate): 0.0f (0) or normal 1.0f (1065353216)
            let recoilVal: Int32 = hasNoRecoil ? 0 : 1065353216
            writeI32(0x181A + 4, recoilVal)

            // Method 5 (Cam Xa get_OffsetForNormal): 8.0f (1090519040) or normal 3.5f (1079975936)
            let camVal: Int32 = hasCamXa ? 1090519040 : 1079975936
            writeI32(0x1832 + 4, camVal)

            // Method 6 (Fast Medkit get_FSModeUseMedikitFasterRate): 5.0f (1084227584) or normal 1.0f (1065353216)
            let medVal: Int32 = hasFastMedkit ? 1084227584 : 1065353216
            writeI32(0x184A + 4, medVal)

            // Method 7 (Bắn Không Delay IsPlayerReadyNeedDelay): 0 (false) or normal 1 (true)
            let delayVal: Int32 = hasNoDelay ? 0 : 1
            writeI32(0x1862 + 4, delayVal)

            // Method 8 (Unlimited Ammo get_IsAmmoFree): 1 (true) or normal 0 (false)
            let ammoVal: Int32 = hasUnlimitedAmmo ? 1 : 0
            writeI32(0x187A + 4, ammoVal)
        }

        return Data(b)
    }
}
