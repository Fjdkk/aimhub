import Foundation

public enum IFixPatchSynthesizer {
    public static func synthesize(baseData: Data, activeSlots: Set<String>) -> Data {
        var b = [UInt8](baseData)
        guard b.count > 100 else { return baseData }

        // Nếu file từ server đã là bản cấu hình hoàn chỉnh hoặc kích thước động từ server:
        // Cho phép áp dụng trực tiếp mọi bản vá tải từ server xuống mà không cần build lại app
        let is11k = (b.count >= 11400 && b.count <= 11550)
        let isKnownSize = (b.count == 15636 || b.count == 8456 || b.count == 8037 || b.count == 8517 || b.count == 7821 || is11k)
        if !isKnownSize {
            return Data(b)
        }

        let is3105 = (b.count == 15636)
        let isRinStore8456 = (b.count == 8456)
        let isMaster8037 = (b.count == 8037 || b.count == 7821)
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
            guard offset >= 0 && offset + 4 <= b.count else { return }
            var v = val.littleEndian
            withUnsafeBytes(of: &v) { ptr in
                for i in 0..<4 {
                    b[offset + i] = ptr[i]
                }
            }
        }

        // -1. Dev 11k Base Patch (11400...11550 bytes: ESP Box/Line + Aim Legit/Lock)
        if is11k {
            // ESP Control (Method 0 at 0x1050)
            if !hasBox && !hasLine {
                // Tắt sạch ESP: Ldc_I4 0, Ret 1
                writeI32(0x1050, 180); writeI32(0x1054, 0)
                writeI32(0x1058, 136); writeI32(0x105C, 1)
            } else {
                // Bật ESP: StackSpace 3080208, Call 51
                writeI32(0x1050, 57);  writeI32(0x1054, 3080208)
                writeI32(0x1058, 175); writeI32(0x105C, 51)
            }

            // Aim Control (Method 1 at 0x2168, Method 3 at 0x2300)
            let hasAnyAim = hasAimSilent || hasAimLock || hasAimLegit || hasAimScope
            if !hasAnyAim {
                // TẮT AIM:
                // Method 1: Ldc_I4 1, Ret 1
                writeI32(0x2168, 180); writeI32(0x216C, 1)
                writeI32(0x2170, 136); writeI32(0x2174, 1)

                // Method 3: Trả về vị trí hông tự nhiên
                writeI32(0x2300, 57);  writeI32(0x2304, 262152)
                writeI32(0x2308, 28);  writeI32(0x230C, 0)
                writeI32(0x2310, 175); writeI32(0x2314, 65594) // GetHipTF
                writeI32(0x2318, 175); writeI32(0x231C, 65545) // get_position
                writeI32(0x2320, 136); writeI32(0x2324, 1)     // Ret 1
            } else {
                // BẬT AIM:
                // Method 1: Gọi set_LockedAimingCollider
                writeI32(0x2168, 57);  writeI32(0x216C, 65538)
                writeI32(0x2170, 28);  writeI32(0x2174, 0)
                writeI32(0x2210, 42);  writeI32(0x2214, 0)

                // Method 3: Khôi phục cấu trúc ngắm gốc
                writeI32(0x2300, 57);  writeI32(0x2304, 262152)
                writeI32(0x2308, 28);  writeI32(0x230C, 0)
                writeI32(0x2310, 175); writeI32(0x2314, 65537)
                writeI32(0x2318, 175); writeI32(0x231C, 65545)
                writeI32(0x2320, 176); writeI32(0x2324, 0)

                if hasAimLock {
                    // Aim Lock: chỏ thẳng vào đầu (HeadCollider 65540), khóa cứng factor = 0.0f
                    writeI32(0x2178 + 4, 65540)
                    writeI32(0x2398, 3); writeI32(0x239C, 0)
                    writeI32(0x23C8, 3); writeI32(0x23CC, 0)
                } else {
                    // Aim Legit: trợ lực ngắm vùng thân/ngực (GetHipTF 65543 - không chỏ sát đầu)
                    // và giảm tối đa lực cản (factor = 0.85f) giúp ngón tay vuốt kéo tâm lên cực nhẹ và mượt
                    writeI32(0x2178 + 4, 65543)
                    writeI32(0x2398, 3); writeI32(0x239C, 1063004406) // 0.85f
                    writeI32(0x23C8, 3); writeI32(0x23CC, 1063004406)
                }
            }

            return Data(b)
        }

        // 0. Reference 3105 AIO Patch (15636 bytes)
        if is3105 {
            // ESP Control (Method 0)
            if !hasBox && !hasLine && !hasName && !hasHealth {
                // Tắt toàn bộ ESP: Ret 1 an toàn
                writeI32(0x1244, 57);  writeI32(0x1248, 3670021)
                writeI32(0x124C, 180); writeI32(0x1250, 0)
                writeI32(0x1254, 136); writeI32(0x1258, 1)
            } else {
                // ESP BẬT: TUYỆT ĐỐI GIỮ NGUYÊN HEADER để Camera và Screen matrix hoạt động 100%
                if !hasBox {
                    // Tắt riêng Box: nhảy qua khối __cg
                    writeI32(0x2194, 62); writeI32(0x2198, 174)
                    writeI32(0x219C, 89); writeI32(0x21A0, 0)
                }
                if !hasLine {
                    // Tắt riêng Line: nhảy qua khối __ln
                    writeI32(0x28BC, 62); writeI32(0x28C0, 55)
                    writeI32(0x28C4, 89); writeI32(0x28C8, 0)
                }
                if !hasName && !hasHealth {
                    // Tắt riêng Text: nhảy qua khối __tx
                    writeI32(0x270C, 62); writeI32(0x2710, 53)
                    writeI32(0x2714, 89); writeI32(0x2718, 0)
                }
            }

            // Aim Control (Method 1)
            let hasAnyAim = hasAimSilent || hasAimLock || hasAimLegit || hasAimScope
            if !hasAnyAim {
                // TẮT AIM: Trả về thông số ngắm gốc (this.AKFLHNOIHED) mượt mà, không bị khóa tâm hay đơ súng
                writeI32(0x2D9C, 57);  writeI32(0x2DA0, 1245189) // StackSpace
                writeI32(0x2DA4, 28);  writeI32(0x2DA8, 0)       // Ldarg 0
                writeI32(0x2DAC, 38);  writeI32(0x2DB0, 3)       // Ldfld 3 (this.AKFLHNOIHED)
                writeI32(0x2DB4, 136); writeI32(0x2DB8, 1)       // Ret 1
            }
            // NẾU BẬT AIM: GIỮ NGUYÊN 100% BYTECODE GỐC CỦA METHOD 1 (Aim Silent bám mục tiêu chuẩn, không đơ tâm)

            return Data(b)
        }

        // 1. ESP Logic (Method 0)
        if isRinStore8456 {
            if hasBox || hasLine {
                // Method 0 header: StackSpace 1310728, Ldarg 0
                writeI32(0x0B9F, 57); writeI32(0x0BA3, 1310728)
                writeI32(0x0BA7, 28); writeI32(0x0BAB, 0)

                if hasBox {
                    // Chuẩn dev gốc: ESP Box 2D 4 điểm khép kín tuyệt đối
                    writeI32(0x13BB, 1) // loop = 1 (khép kín)
                    writeI32(0x13D3, 4) // positionCount = 4
                    writeI32(0x150B, 984285184) // 0.0015f nét đẹp
                    writeI32(0x1533, 984285184)

                    // Điểm 0: Dưới-Trái (loc 11, loc 6)
                    writeI32(0x155F, 20); writeI32(0x1563, 11)
                    writeI32(0x1567, 20); writeI32(0x156B, 6)

                    // Điểm 1: Trên-Trái (loc 11, loc 7)
                    writeI32(0x15A7, 20); writeI32(0x15AB, 11)
                    writeI32(0x15AF, 20); writeI32(0x15B3, 7)

                    // Điểm 2: Trên-Phải (loc 12, loc 7)
                    writeI32(0x15EF, 20); writeI32(0x15F3, 12)
                    writeI32(0x15F7, 20); writeI32(0x15FB, 7)

                    // Điểm 3: Dưới-Phải (loc 12, loc 6)
                    writeI32(0x1637, 20); writeI32(0x163B, 12)
                    writeI32(0x163F, 20); writeI32(0x1643, 6)
                } else {
                    // Chỉ bật ESP Line: 2 điểm (Từ đỉnh màn hình xuống đầu địch)
                    writeI32(0x13BB, 0) // loop = 0
                    writeI32(0x13D3, 2) // positionCount = 2
                    writeI32(0x150B, 981668463) // 0.0012f
                    writeI32(0x1533, 981668463)

                    // Điểm 0 (Đỉnh đầu địch trên cao): X=loc 9, Y=loc 7
                    writeI32(0x155F, 20); writeI32(0x1563, 9)
                    writeI32(0x1567, 20); writeI32(0x156B, 7)

                    // Điểm 1 (Gốc thân địch): X=loc 9, Y=loc 6
                    writeI32(0x15A7, 20); writeI32(0x15AB, 9)
                    writeI32(0x15AF, 20); writeI32(0x15B3, 6)
                }
            } else {
                // Tắt ESP an toàn: Giữ StackSpace hợp lệ rồi Ret 1
                writeI32(0x0B9F, 57);  writeI32(0x0BA3, 1310728)
                writeI32(0x0BA7, 180); writeI32(0x0BAB, 0) // Ldc_I4 0
                writeI32(0x0BAF, 136); writeI32(0x0BB3, 1) // Ret 1
            }
        } else if isMaster8037 {
            if hasBox && hasLine {
                writeI32(0x0B32, 57); writeI32(0x0B36, 1310728)
                writeI32(0x0B3A, 28); writeI32(0x0B3E, 0)

                writeI32(0x12DE, 0)
                writeI32(0x12F6, 4)

                writeI32(0x142E, 981668463)
                writeI32(0x1456, 981668463)

                // Điểm 0 (Đỉnh mép trên màn hình): X=loc 9, Y=1.0f
                writeI32(0x1482, 20); writeI32(0x1486, 9)
                writeI32(0x148A, 3);  writeI32(0x148E, 1065353216)

                // Điểm 1 (Đầu địch): X=loc 9, Y=loc 7
                writeI32(0x14CA, 20); writeI32(0x14CE, 9)
                writeI32(0x14D2, 20); writeI32(0x14D6, 7)

                // Điểm 2 (Góc trên trái Box): X=loc 11, Y=loc 7
                writeI32(0x1512, 20); writeI32(0x1516, 11)
                writeI32(0x151A, 20); writeI32(0x151E, 7)

                // Điểm 3 (Góc dưới trái Box): X=loc 11, Y=loc 6
                writeI32(0x155A, 20); writeI32(0x155E, 11)
                writeI32(0x1562, 20); writeI32(0x1566, 6)
            } else if hasLine {
                writeI32(0x0B32, 57); writeI32(0x0B36, 1310728)
                writeI32(0x0B3A, 28); writeI32(0x0B3E, 0)

                writeI32(0x12DE, 0)
                writeI32(0x12F6, 2)

                writeI32(0x142E, 981668463)
                writeI32(0x1456, 981668463)

                writeI32(0x1482, 20); writeI32(0x1486, 9)
                writeI32(0x148A, 3);  writeI32(0x148E, 1065353216) // Ldc_R4 1.0f (mép trên màn hình)

                writeI32(0x14CA, 20); writeI32(0x14CE, 9)
                writeI32(0x14D2, 20); writeI32(0x14D6, 7)
            } else if hasBox {
                writeI32(0x0B32, 57); writeI32(0x0B36, 1310728)
                writeI32(0x0B3A, 28); writeI32(0x0B3E, 0)

                writeI32(0x12DE, 1)
                writeI32(0x12F6, 4)

                writeI32(0x142E, 984285184)
                writeI32(0x1456, 984285184)

                writeI32(0x1482, 20); writeI32(0x1486, 11)
                writeI32(0x148A, 20); writeI32(0x148E, 6)

                writeI32(0x14CA, 20); writeI32(0x14CE, 11)
                writeI32(0x14D2, 20); writeI32(0x14D6, 7)

                writeI32(0x1512, 20); writeI32(0x1516, 12)
                writeI32(0x151A, 20); writeI32(0x151E, 7)

                writeI32(0x155A, 20); writeI32(0x155E, 12)
                writeI32(0x1562, 20); writeI32(0x1566, 6)
            } else {
                writeI32(0x0B32, 180); writeI32(0x0B36, 0)
                writeI32(0x0B3A, 136); writeI32(0x0B3E, 1)
            }
        } else {
            // Chuẩn 100% từ file gốc paneer cung cấp (7821 / 8517 bytes):
            // Method 0 đã tích hợp sẵn ESP Box 2D và ESP Line hoàn chỉnh mượt mà.
            // Khi bật ESP (Box hoặc Line): GIỮ NGUYÊN 100% BYTECODE GỐC, KHÔNG GHI ĐÈ GÂY LỖI RENDER!
            if !hasBox && !hasLine {
                // Chỉ khi tắt cả Box và Line mới trả về an toàn
                writeI32(0x0B32 + shift, 180); writeI32(0x0B32 + shift + 4, 0)
                writeI32(0x0B3A + shift, 136); writeI32(0x0B3A + shift + 4, 1)
            }
        }

        // 2. AIM Logic (Method 1)
        let m1Start: Int
        if isRinStore8456 {
            m1Start = 0x1817
        } else if isMaster8037 {
            m1Start = (b.count == 7821) ? 0x1662 : 0x173A
        } else {
            m1Start = 0x1662 + shift
        }

        if isRinStore8456 || isMaster8037 {
            if hasAimLegit || hasAimSilent {
                writeI32(m1Start, 57); writeI32(m1Start + 4, 65538)
                writeI32(m1Start + 8, 28); writeI32(m1Start + 12, 0)
                writeI32(m1Start + 16, 175); writeI32(m1Start + 20, 65543)
            } else if hasAimLock || hasAimScope {
                writeI32(m1Start, 57); writeI32(m1Start + 4, 65538)
                writeI32(m1Start + 8, 28); writeI32(m1Start + 12, 0)
                writeI32(m1Start + 16, 175); writeI32(m1Start + 20, 65540)
            } else {
                writeI32(m1Start, 57);      writeI32(m1Start + 4, 65538)
                writeI32(m1Start + 8, 180);  writeI32(m1Start + 12, 1)
                writeI32(m1Start + 16, 136); writeI32(m1Start + 20, 1)
            }
        } else {
            // Chuẩn 7821 và 8517 bytes patch:
            // Method 1 nguyên bản gồm 11 lệnh (88 bytes) - TUYỆT ĐỐI KHÔNG RÚT GỌN 3 LỆNH GÂY LỖI VM!
            if hasAimLock || hasAimScope {
                // Aim Head Lock: đổi mục tiêu sang HeadCollider (65540)
                writeI32(m1Start + 20, 65540)
            } else {
                // Giữ nguyên 11 lệnh gốc của dev (GetHipTF 65543)
                let origM1: [Int32] = [
                    57, 65538,    // StackSpace 65538
                    28, 0,        // Ldarg 0
                    175, 65543,   // Call 65543 (GetHipTF)
                    176, 0,       // Pop
                    20, 0,        // Ldloc 0
                    62, 4,        // Brfalse 4
                    28, 0,        // Ldarg 0
                    20, 0,        // Ldloc 0
                    175, 131077,  // Callvirt 131077
                    180, 1,       // Ldc_I4 1
                    136, 1        // Ret 1
                ]
                for (i, v) in origM1.enumerated() {
                    writeI32(m1Start + i * 4, v)
                }
            }
        }

        // 4. ESP Health (Màu thanh máu)
        if hasHealth && (hasBox || hasLine) {
            if isRinStore8456 {
                writeI32(0x144B, 0) // R = 0f
                writeI32(0x1453, 1065353216) // G = 1f
                writeI32(0x145B, 0) // B = 0f
                writeI32(0x1463, 1065353216) // A = 1f
            } else {
                let colOffset = 0x136A + shift
                writeI32(colOffset + 4, 0)
                writeI32(colOffset + 12, 1065353216)
                writeI32(colOffset + 20, 0)
                writeI32(colOffset + 28, 1065353216)
            }
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
