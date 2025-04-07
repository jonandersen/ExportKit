import Foundation

public enum AspectRatio: CaseIterable, Equatable {
    case portrait
    case landscape
    case square
    
    public var ratio: CGFloat {
        switch self {
        case .portrait: return 9/16.0
        case .landscape: return 16/9.0
        case .square : return 1.0
        }
    }
    
    public static func from(size: CGSize) -> AspectRatio {
        return if size.width > size.height {
            .landscape
        } else if size.height > size.width {
            .portrait
        } else {
            .square
        }
    }
    
    public func rotate(by rotation: Rotation) -> AspectRatio {
        return switch rotation {
        case .zero, .oneEighty:
            self
        case .ninety, .twoSeventy:
            if self == .portrait {
                .landscape
            } else {
                .portrait
            }
        }
    }
}
