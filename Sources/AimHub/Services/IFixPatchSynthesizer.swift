import Foundation

public enum IFixPatchSynthesizer {
    public static func synthesize(baseData: Data, activeSlots: Set<String>) -> Data {
        var b = [UInt8](baseData)
        guard b.count == 8037 || b.count == 8517 || b.count == 7821 else { return baseData }

        let isMaster8037 = (b.count == 8037)
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

        // 1. ESP Logic (Method 0)
        if isMaster8037 {
            if hasBox && hasLine {
                // PHƯƠNG ÁN 2: DUAL MODE (Vẽ đồng thời cả Tia Line lẫn Khung Box 2D)
                // Nối 7 điểm liên tục: Line từ đỉnh màn hình xuống đầu -> bao trọn 4 góc thân Box -> khép kín về đầu
                writeI32(0x0B32, 57); writeI32(0x0B36, 1310728)
                writeI32(0x0B3A, 28); writeI32(0x0B3E, 0)

                writeI32(0x12DE, 0) // loop = 0 (false)
                writeI32(0x12F6, 7) // positionCount = 7

                // Độ dày chuẩn laser siêu nét (0.0012f)
                writeI32(0x142E, 981668463)
                writeI32(0x1456, 981668463)

                // Điểm 0 (Đỉnh màn hình theo trục X của đầu địch): X=loc 9, Y=1000f, Z=loc 15
                writeI32(0x1482, 20); writeI32(0x1486, 9)
                writeI32(0x148A, 3);  writeI32(0x148E, 1148846080) // Ldc_R4 1000f

                // Điểm 1 (Đầu địch - Tia Line chạm đầu): X=loc 9, Y=loc 7, Z=loc 15
                writeI32(0x14CA, 20); writeI32(0x14CE, 9)
                writeI32(0x14D2, 20); writeI32(0x14D6, 7)

                // Điểm 2 (Góc trên trái Box): X=loc 11, Y=loc 7, Z=loc 15
                writeI32(0x1512, 20); writeI32(0x1516, 11)
                writeI32(0x151A, 20); writeI32(0x151E, 7)

                // Điểm 3 (Góc dưới trái Box): X=loc 11, Y=loc 6, Z=loc 15
                writeI32(0x155A, 20); writeI32(0x155E, 11)
                writeI32(0x1562, 20); writeI32(0x1566, 6)

                // Điểm 4 (Góc dưới phải), Điểm 5 (Góc trên phải), Điểm 6 (Khép về đầu) đã có sẵn trong Master 8037
            } else if hasLine {
                // Chỉ bật ESP Line
                writeI32(0x0B32, 57); writeI32(0x0B36, 1310728)
                writeI32(0x0B3A, 28); writeI32(0x0B3E, 0)

                writeI32(0x12DE, 0) // loop = 0
                writeI32(0x12F6, 2) // positionCount = 2

                writeI32(0x142E, 981668463) // 0.0012f
                writeI32(0x1456, 981668463)

                // Điểm 0 (Đỉnh màn hình): X=loc 9, Y=1000f
                writeI32(0x1482, 20); writeI32(0x1486, 9)
                writeI32(0x148A, 3);  writeI32(0x148E, 1148846080)

                // Điểm 1 (Đầu địch): X=loc 9, Y=loc 7
                writeI32(0x14CA, 20); writeI32(0x14CE, 9)
                writeI32(0x14D2, 20); writeI32(0x14D6, 7)
            } else if hasBox {
                // Chỉ bật ESP Box 2D
                writeI32(0x0B32, 57); writeI32(0x0B36, 1310728)
                writeI32(0x0B3A, 28); writeI32(0x0B3E, 0)

                writeI32(0x12DE, 1) // loop = 1
                writeI32(0x12F6, 4) // positionCount = 4

                writeI32(0x142E, 984285184) // 0.0015f
                writeI32(0x1456, 984285184)

                // Điểm 0: Dưới-Trái (loc 11, loc 6)
                writeI32(0x1482, 20); writeI32(0x1486, 11)
                writeI32(0x148A, 20); writeI32(0x148E, 6)

                // Điểm 1: Trên-Trái (loc 11, loc 7)
                writeI32(0x14CA, 20); writeI32(0x14CE, 11)
                writeI32(0x14D2, 20); writeI32(0x14D6, 7)

                // Điểm 2: Trên-Phải (loc 12, loc 7)
                writeI32(0x1512, 20); writeI32(0x1516, 12)
                writeI32(0x151A, 20); writeI32(0x151E, 7)

                // Điểm 3: Dưới-Phải (loc 12, loc 6)
                writeI32(0x155A, 20); writeI32(0x155E, 12)
                writeI32(0x1562, 20); writeI32(0x1566, 6)
            } else {
                // Tắt ESP
                writeI32(0x0B32, 180); writeI32(0x0B36, 0)
                writeI32(0x0B3A, 136); writeI32(0x0B3E, 1)
            }
        } else {
            // Legacy fallback (7821 / 8517)
            if hasLine {
                writeI32(0x0B32 + shift, 57); writeI32(0x0B32 + shift + 4, 1310728)
                writeI32(0x0B3A + shift, 28); writeI32(0x0B3A + shift + 4, 0)

                writeI32(0x12DA + shift + 4, 0)
                writeI32(0x12F2 + shift + 4, 2)

                writeI32(0x1482 + shift, 20); writeI32(0x1482 + shift + 4, 9)
                writeI32(0x148A + shift, 3);  writeI32(0x148A + shift + 4, 1148846080)

                writeI32(0x14CA + shift, 20); writeI32(0x14CA + shift + 4, 9)
                writeI32(0x14D2 + shift, 20); writeI32(0x14D2 + shift + 4, 7)
                writeI32(0x14DA + shift, 20); writeI32(0x14DA + shift + 4, 15)

                for p in stride(from: 0x14FA + shift, through: 0x1582 + shift, by: 8) {
                    writeI32(p, 89); writeI32(p + 4, 0)
                }
            } else if hasBox {
                writeI32(0x0B32 + shift, 57); writeI32(0x0B32 + shift + 4, 1310728)
                writeI32(0x0B3A + shift, 28); writeI32(0x0B3A + shift + 4, 0)

                writeI32(0x12DA + shift + 4, 1)
                writeI32(0x12F2 + shift + 4, 4)

                writeI32(0x1482 + shift, 20); writeI32(0x1482 + shift + 4, 11)
                writeI32(0x148A + shift, 20); writeI32(0x148A + shift + 4, 6)

                writeI32(0x14CA + shift, 20); writeI32(0x14CA + shift + 4, 11)
                writeI32(0x14D2 + shift, 20); writeI32(0x14D2 + shift + 4, 7)

                writeI32(0x14FA + shift, 20); writeI32(0x14FA + shift + 4, 2)
                writeI32(0x1502 + shift, 180); writeI32(0x1502 + shift + 4, 2)
                writeI32(0x150A + shift, 20); writeI32(0x150A + shift + 4, 3)
                writeI32(0x1512 + shift, 20); writeI32(0x1512 + shift + 4, 12)
                writeI32(0x151A + shift, 20); writeI32(0x151A + shift + 4, 7)
                writeI32(0x1522 + shift, 20); writeI32(0x1522 + shift + 4, 15)
                writeI32(0x152A + shift, 105); writeI32(0x152A + shift + 4, 196622)
                writeI32(0x1532 + shift, 175); writeI32(0x1532 + shift + 4, 131108)
                writeI32(0x153A + shift, 175); writeI32(0x153A + shift + 4, 196655)

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
                writeI32(0x0B32 + shift, 180); writeI32(0x0B32 + shift + 4, 0)
                writeI32(0x0B3A + shift, 136); writeI32(0x0B3A + shift + 4, 1)
            }
        }

        // 2. AIM Logic (Method 1)
        let m1Start = isMaster8037 ? 0x173A : (0x1662 + shift)
        if hasAimLegit || hasAimSilent {
            // GetHipTF (65543) - Chuẩn dev cũ: Bám thân mượt mà, di chuyển tự do 100%, không bị đơ giật cam
            writeI32(m1Start, 57); writeI32(m1Start + 4, 65538)
            writeI32(m1Start + 8, 28); writeI32(m1Start + 12, 0)
            writeI32(m1Start + 16, 175); writeI32(m1Start + 20, 65543)
        } else if hasAimLock || hasAimScope {
            // Head Collider (65540) - Khóa trực diện đầu
            writeI32(m1Start, 57); writeI32(m1Start + 4, 65538)
            writeI32(m1Start + 8, 28); writeI32(m1Start + 12, 0)
            writeI32(m1Start + 16, 175); writeI32(m1Start + 20, 65540)
        } else {
            // Tắt Aim
            writeI32(m1Start, 180); writeI32(m1Start + 4, 1)
            writeI32(m1Start + 8, 136); writeI32(m1Start + 12, 1)
        }

        // 3. ESP Visible (Wallhack) - Luôn hiển thị xuyên tường khi bật ESP
        if hasBox || hasLine {
            writeI32(0x0CDA + shift, 160) // Pop (bỏ qua check vật cản che khuất)
            writeI32(0x0CDA + shift + 4, 0)
        }

        // 4. ESP Health (Màu thanh máu)
        if hasHealth && (hasBox || hasLine) {
            writeI32(0x136A + shift + 4, 0) // R = 0f
            writeI32(0x1372 + shift + 4, 1065353216) // G = 1f
            writeI32(0x137A + shift + 4, 0) // B = 0f
            writeI32(0x1382 + shift + 4, 1065353216) // A = 1f
        }

        // 5. Multi-Feature Handlers (if 8517 bytes patch)
        if b.count == 8517 {
            let jumpVal: Int32 = hasHighJump ? 1094713344 : 1069547520
            writeI32(0x17EA + 4, jumpVal)

            let gunVal: Int32 = hasFastGun ? 0 : 1
            writeI32(0x1802 + 4, gunVal)

            let recoilVal: Int32 = hasNoRecoil ? 0 : 1065353216
            writeI32(0x181A + 4, recoilVal)

            let camVal: Int32 = hasCamXa ? 1090519040 : 1079975936
            writeI32(0x1832 + 4, camVal)

            let medVal: Int32 = hasFastMedkit ? 1084227584 : 1065353216
            writeI32(0x184A + 4, medVal)

            let delayVal: Int32 = hasNoDelay ? 0 : 1
            writeI32(0x1862 + 4, delayVal)

            let ammoVal: Int32 = hasUnlimitedAmmo ? 1 : 0
            writeI32(0x187A + 4, ammoVal)
        }

        return Data(b)
    }
}
