import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        switch cleaned.count {
        case 8:
            red = CGFloat((value & 0xff00_0000) >> 24) / 255
            green = CGFloat((value & 0x00ff_0000) >> 16) / 255
            blue = CGFloat((value & 0x0000_ff00) >> 8) / 255
            alpha = CGFloat(value & 0x0000_00ff) / 255
        case 6:
            red = CGFloat((value & 0xff0000) >> 16) / 255
            green = CGFloat((value & 0x00ff00) >> 8) / 255
            blue = CGFloat(value & 0x0000ff) / 255
            alpha = 1
        default:
            red = 0.07
            green = 0.09
            blue = 0.15
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}
