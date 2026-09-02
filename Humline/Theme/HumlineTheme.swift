import SpriteKit
import SwiftUI

enum HumlineTheme {
    static let sky = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let land = Color(red: 0.09, green: 0.11, blue: 0.18)
    static let corridor = Color(red: 0.91, green: 0.77, blue: 0.47)
    static let craft = Color(red: 0.98, green: 0.90, blue: 0.70)
    static let ink = Color(red: 0.93, green: 0.91, blue: 0.86)

    static var skySK: SKColor { SKColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1) }
    static var landSK: SKColor { SKColor(red: 0.09, green: 0.11, blue: 0.18, alpha: 1) }
    static var corridorSK: SKColor { SKColor(red: 0.91, green: 0.77, blue: 0.47, alpha: 1) }
    static var craftSK: SKColor { SKColor(red: 0.98, green: 0.90, blue: 0.70, alpha: 1) }
    static var ghostSK: SKColor { SKColor(white: 1, alpha: 0.28) }
}
