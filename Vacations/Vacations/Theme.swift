import SwiftUI

// MARK: - Colors (from Figma design tokens)
extension Color {
    init(hex: String, opacity: Double = 1) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Palette {
    static let canvas       = Color(hex: "F8FAF5")   // screen background
    static let visaCanvas   = Color(hex: "F9FBF6")
    static let headerTop    = Color(hex: "347DA5")   // gradient start (blue)
    static let headerBottom = Color(hex: "FDD910")   // gradient end (yellow)
    static let textHigh     = Color(hex: "262B30")   // Text/High emphasis
    static let scapiaOrange = Color(hex: "F14D00")   // Primary/Scapia/400
    static let yellow500    = Color(hex: "D48806")   // Alert/Yellow/500
    static let yellow400    = Color(hex: "FAAD14")   // Alert/Yellow/400
    static let yellow100    = Color(hex: "FFF1B8")   // Alert/Yellow/100
    static let blue900      = Color(hex: "031223")   // Secondary/Blue/900
    static let grey900      = Color(hex: "121212")   // Neutral/Grey/900
    static let green500     = Color(hex: "389E0D")   // Success/Green/500
    static let greenText    = Color(hex: "F6FFED")
    static let pillBg       = Color(hex: "FCF8E3")
    static let pillBorder   = Color(hex: "F9E814")
    static let flightText   = Color(hex: "141C20")

    // Munich screen
    static let orangeTop    = Color(hex: "E97903")   // header gradient start (top)
    static let orangeBottom = Color(hex: "F1B90C")   // header gradient end (bottom)
    static let blue400      = Color(hex: "1268CB")   // Secondary/Blue/400
    static let yellow000    = Color(hex: "FFFBE6")   // Alert/Yellow/000 (countdown chip)
    static let green400     = Color(hex: "52C41A")   // Success/Green/400 (tray card bar)

    // My trips screen
    static let headerMint   = Color(hex: "FDF2E4")   // header gradient start (soft cream)
    static let headerSand   = Color(hex: "F3CB92")   // header gradient end (warm apricot)
    static let sheetCanvas  = Color(hex: "FAFCF7")   // sheet background
    static let bannerBg     = Color(hex: "FCFCF7")   // reward banner background
    static let coinGold     = Color(hex: "716102")   // points pill text
    static let chevChip     = Color(hex: "F0F2ED")   // small chevron circle bg
    static let toggleGold   = Color(hex: "F2B94D")   // coins pill toggle track
}

// MARK: - Lexend Deca typography
enum LDWeight {
    case regular, medium, semibold, bold, extrabold
    var swiftUI: Font.Weight {
        switch self {
        case .regular:   return .regular
        case .medium:    return .medium
        case .semibold:  return .semibold
        case .bold:      return .bold
        case .extrabold: return .heavy
        }
    }
}

extension Font {
    /// Lexend Deca variable font at the given size/weight.
    static func lexend(_ size: CGFloat, _ weight: LDWeight = .regular) -> Font {
        .custom("Lexend Deca", size: size).weight(weight.swiftUI)
    }
}

extension View {
    /// Applies Lexend Deca with a design line-height by adjusting line spacing.
    func lexend(_ size: CGFloat, _ weight: LDWeight = .regular, lineHeight: CGFloat? = nil) -> some View {
        self.font(.lexend(size, weight))
            .modifier(LineHeightModifier(fontSize: size, lineHeight: lineHeight))
    }
}

private struct LineHeightModifier: ViewModifier {
    let fontSize: CGFloat
    let lineHeight: CGFloat?
    func body(content: Content) -> some View {
        if let lh = lineHeight {
            content
                .lineSpacing(max(0, lh - fontSize))
                .padding(.vertical, max(0, (lh - fontSize) / 2))
        } else {
            content
        }
    }
}
