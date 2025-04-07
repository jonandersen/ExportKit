import Foundation

public enum Rotation {
    case zero
    case ninety
    case oneEighty
    case twoSeventy
    
    var degrees: Double {
        switch self {
        case .zero: return 0
        case .ninety: return 90
        case .oneEighty: return 180
        case .twoSeventy: return 270
        }
    }
    
    var radians: Double {
        switch self {
        case .zero: return 0
        case .ninety: return .pi / 2
        case .oneEighty: return .pi
        case .twoSeventy: return .pi * 1.5
        }
    }
}
