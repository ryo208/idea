import Foundation

/// RGB値を日本語の色名に変換する
enum ColorClassifier {
    /// r, g, b: 0-255
    static func name(r: Double, g: Double, b: Double) -> String {
        let (h, s, v) = rgbToHsv(r: r / 255, g: g / 255, b: b / 255)

        // 無彩色の判定を先に行う
        if v < 0.15 { return "黒" }
        if s < 0.12 {
            if v > 0.85 { return "白" }
            if v > 0.55 { return "明るいグレー" }
            return "グレー"
        }

        // 茶色: 赤〜オレンジの色相で暗め
        if h >= 10 && h < 50 && v < 0.55 { return "茶色" }

        switch h {
        case ..<15: return v > 0.8 && s < 0.5 ? "ピンク" : "赤"
        case 15..<40: return "オレンジ"
        case 40..<65: return "黄色"
        case 65..<95: return "黄緑"
        case 95..<150: return "緑"
        case 150..<190: return "青緑"
        case 190..<250: return "青"
        case 250..<290: return "紫"
        case 290..<330: return s < 0.5 || v > 0.8 ? "ピンク" : "赤紫"
        default: return v > 0.8 && s < 0.5 ? "ピンク" : "赤"
        }
    }

    /// r, g, b: 0-1 → (hue: 0-360, saturation: 0-1, value: 0-1)
    static func rgbToHsv(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        var h = 0.0
        if delta > 0 {
            if maxC == r {
                h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                h = 60 * ((b - r) / delta + 2)
            } else {
                h = 60 * ((r - g) / delta + 4)
            }
        }
        if h < 0 { h += 360 }

        let s = maxC == 0 ? 0 : delta / maxC
        return (h, s, maxC)
    }
}
