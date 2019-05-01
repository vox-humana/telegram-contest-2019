import CoreGraphics
import UIKit

func measure(_ block: () -> Void) -> UInt64 {
    var info = mach_timebase_info(numer: 0, denom: 0)
    mach_timebase_info(&info)

    let startTime = mach_absolute_time()
    block()
    let stopTime = mach_absolute_time()
    let ns = ((stopTime - startTime) * UInt64(info.numer)) / UInt64(info.denom)
    return ns / 1_000_000
}

func measure(_ title: String, block: () -> Void) {
    #if DEBUG
        print(title, measure(block), "ms")
    #else
        block()
    #endif
}

extension RandomAccessCollection where Element: Comparable {
    func binarySearch(element: Element) -> Index {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
            let pivot = self[mid]
            if pivot == element {
                return mid
            }

            if pivot < element {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }
}

extension CGFloat {
    func clamping(minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
        return CGFloat.maximum(CGFloat.minimum(maxValue, self), minValue)
    }

    func normalized() -> CGFloat {
        return clamping(minValue: 0, maxValue: 1)
    }
}

extension UIImage {
    static func image(color: UIColor, size: CGSize, cornerRadius: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            color.setFill()
            UIBezierPath(roundedRect: renderer.format.bounds, cornerRadius: cornerRadius).fill()
        }
    }
}

let sectionImage: (UIColor) -> UIImage = { borderColor in
    let horizontalBordersWidth: CGFloat = Constants.scaleControlImageWidth
    let totalWidth: CGFloat = horizontalBordersWidth * 2 + 3
    let borderWidth: CGFloat = Constants.scaleControlBorderHeight

    let totalHeight = Constants.scaleControlHeight

    let imageRect = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
    UIGraphicsBeginImageContextWithOptions(imageRect.size, false, 0)

    let context = UIGraphicsGetCurrentContext()!

    context.setFillColor(borderColor.cgColor)
    let cornerRadius = CGSize(width: Constants.scaleControlcornerRadius, height: Constants.scaleControlcornerRadius)
    let leftRect = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: horizontalBordersWidth, height: totalHeight), byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: cornerRadius)
    let rightRect = UIBezierPath(roundedRect: CGRect(x: totalWidth - horizontalBordersWidth, y: 0, width: horizontalBordersWidth, height: totalHeight), byRoundingCorners: [.topRight, .bottomRight], cornerRadii: cornerRadius)
    context.addPath(leftRect.cgPath)
    context.addPath(rightRect.cgPath)
    context.fillPath()

    let arrowHeight: CGFloat = 8
    let arrowWidth: CGFloat = 3
    context.setStrokeColor(UIColor.white.cgColor)
    context.setLineWidth(1.5)
    context.move(to: CGPoint(x: (horizontalBordersWidth + arrowWidth) / 2, y: totalHeight / 2 - arrowHeight / 2))
    context.addLine(to: CGPoint(x: (horizontalBordersWidth - arrowWidth) / 2, y: totalHeight / 2))
    context.addLine(to: CGPoint(x: (horizontalBordersWidth + arrowWidth) / 2, y: totalHeight / 2 + arrowHeight / 2))

    context.move(to: CGPoint(x: totalWidth - ((horizontalBordersWidth + arrowWidth) / 2), y: totalHeight / 2 - arrowHeight / 2))
    context.addLine(to: CGPoint(x: totalWidth - (horizontalBordersWidth - arrowWidth) / 2, y: totalHeight / 2))
    context.addLine(to: CGPoint(x: totalWidth - ((horizontalBordersWidth + arrowWidth) / 2), y: totalHeight / 2 + arrowHeight / 2))
    context.setLineCap(.round)
    context.strokePath()

    context.setStrokeColor(borderColor.cgColor)
    context.setLineWidth(borderWidth)

    context.move(to: CGPoint(x: horizontalBordersWidth, y: borderWidth / 2))
    context.addLine(to: CGPoint(x: totalWidth - horizontalBordersWidth, y: borderWidth / 2))

    context.move(to: CGPoint(x: horizontalBordersWidth, y: totalHeight - borderWidth / 2))
    context.addLine(to: CGPoint(x: totalWidth - horizontalBordersWidth, y: totalHeight - borderWidth / 2))
    context.strokePath()

    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: CGFloat(horizontalBordersWidth + 1), bottom: 0, right: CGFloat(horizontalBordersWidth + 1)))
}

let arrowImage: (Bool, UIColor) -> UIImage = { flipped, color in
    let size: CGFloat = 10
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image(actions: { imageContext in
        let arrowHeight: CGFloat = size
        let totalHeight: CGFloat = size
        let arrowWidth: CGFloat = 4.5
        let context = imageContext.cgContext
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)
        if flipped {
            context.move(to: CGPoint(x: size - (size + arrowWidth) / 2, y: totalHeight / 2 - arrowHeight / 2))
            context.addLine(to: CGPoint(x: size - (size - arrowWidth) / 2, y: totalHeight / 2))
            context.addLine(to: CGPoint(x: size - (size + arrowWidth) / 2, y: totalHeight / 2 + arrowHeight / 2))
        } else {
            context.move(to: CGPoint(x: (size + arrowWidth) / 2, y: totalHeight / 2 - arrowHeight / 2))
            context.addLine(to: CGPoint(x: (size - arrowWidth) / 2, y: totalHeight / 2))
            context.addLine(to: CGPoint(x: (size + arrowWidth) / 2, y: totalHeight / 2 + arrowHeight / 2))
        }
        context.strokePath()
    }).withRenderingMode(.alwaysTemplate)
}

extension NumberFormatter {
    func abbreviatedString(for value: Int) -> String {
        typealias Abbrevation = (threshold: Double, divisor: Double, suffix: String)
        let abbreviations: [Abbrevation] = [(0, 1, ""),
                                            (1000.0, 1000.0, "K"),
                                            (1_000_000.0, 1_000_000.0, "M"),
                                            (1_000_000_000.0, 1_000_000_000.0, "B")]
        let startValue = Double(abs(value))
        let abbreviation: Abbrevation = {
            var prevAbbreviation = abbreviations[0]
            for tmpAbbreviation in abbreviations {
                if startValue < tmpAbbreviation.threshold {
                    break
                }
                prevAbbreviation = tmpAbbreviation
            }
            return prevAbbreviation
        }()

        let scaledValue = Double(value) / abbreviation.divisor
        positiveSuffix = abbreviation.suffix
        negativeSuffix = abbreviation.suffix

        return string(from: NSNumber(floatLiteral: scaledValue))!
    }
}

extension DateFormatter {
    func string(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        return string(from: date)
    }
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        return Calendar.current.dateInterval(of: .day, for: self)!.end
    }

    var weekInterval: (Date, Date) {
        var start = DateComponents()
        start.day = -3

        var end = DateComponents()
        end.day = 3
        return (Calendar.current.date(byAdding: start, to: startOfDay)!, Calendar.current.date(byAdding: end, to: startOfDay)!)
    }
}

extension String {
    func textSize(font: UIFont) -> CGSize {
        let textAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
        ]
        let rect = (self as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: font.lineHeight),
            attributes: textAttributes,
            context: nil
        )
        return rect.size
    }
}
