import UIKit

extension Column {
    func cgPath(transform: CGAffineTransform) -> CGMutablePath {
        let point: (Int) -> (CGPoint) = { i in
            CGPoint(x: CGFloat(i), y: CGFloat(self.values[i])).applying(transform)
        }
        let path = CGMutablePath()
        path.move(to: point(0))
        for i in 1 ..< values.count {
            path.addLine(to: point(i))
        }
        return path
    }

    func cgBarPath(transform: CGAffineTransform) -> CGMutablePath {
        let point: (Int) -> (CGPoint) = { i in
            CGPoint(x: CGFloat(i), y: CGFloat(self.values[i])).applying(transform)
        }
        let path = CGMutablePath()
        var previousPoint = point(0)
        for i in 1 ..< values.count {
            let nextPoint = point(i)
            let halfBarWidth = (nextPoint.x - previousPoint.x) / 2
            if i == 1 {
                path.move(to: CGPoint(x: previousPoint.x - halfBarWidth, y: previousPoint.y))
                path.addLine(to: CGPoint(x: previousPoint.x + halfBarWidth, y: previousPoint.y))
            }
            path.addLine(to: CGPoint(x: nextPoint.x - halfBarWidth, y: nextPoint.y))
            path.addLine(to: CGPoint(x: nextPoint.x + halfBarWidth, y: nextPoint.y))
            previousPoint = nextPoint
        }
        return path
    }
}

extension CAShapeLayer {
    convenience init(column: Column, transform: CGAffineTransform, lineWidth: CGFloat) {
        self.init(color: column.color, lineWidth: lineWidth)
        path = column.cgPath(transform: transform)
    }

    convenience init(color: UIColor, lineWidth: CGFloat) {
        self.init()
        strokeColor = color.cgColor
        fillColor = nil
        lineJoin = .round
        self.lineWidth = lineWidth
    }

    convenience init(color: UIColor) {
        self.init()
        fillColor = color.cgColor
    }
}

extension Projection {
    var piePercentages: [CGFloat] {
        let totalColumnsValues = pieValues
        let totalSum = totalColumnsValues.reduce(0, +)
        return totalColumnsValues.map { CGFloat($0) / CGFloat(totalSum) }
    }

    var pieValues: [Int] {
        let totalColumnsValues = zip(dataSource.columns, dataSource.columns.indices).map { column, index -> Column.ValueType in
            if !dataSource.selectedColumnsIndexes.contains(index) {
                return 0
            }
            var range = self.dataRange
            if range.upperBound - range.lowerBound < 1 {
                if range.upperBound == column.values.count {
                    range = column.values.count - 1 ..< column.values.count
                } else if range.lowerBound == 0 {
                    range = 0 ..< 1
                } else {
                    range = range.lowerBound ..< range.upperBound + 1
                }
            }
            return column.values[range].reduce(0, +)
        }
        return totalColumnsValues
    }

    var pieCenters: [CGPoint] {
        let center = CGPoint(x: drawingFrame.midX, y: drawingFrame.midY)
        let radius = 2 * drawingFrame.height / 3

        var startAngle: CGFloat = 0
        let point = CGPoint(x: radius / 2, y: 0)
        return piePercentages.map {
            let angle = 2 * CGFloat.pi * $0
            let halfAngle = startAngle + angle / 2
            startAngle += angle
            return point
                .applying(CGAffineTransform(rotationAngle: halfAngle))
                .applying(CGAffineTransform(translationX: center.x, y: center.y))
        }
    }

    private func cgPieChartPath(at center: CGPoint, radius: CGFloat, from angle: CGFloat, percent: CGFloat) -> (CGPath, CGFloat) {
        let path = UIBezierPath()
        let endAngle = 2 * CGFloat.pi * percent + angle
        path.move(to: center)
        path.addArc(withCenter: center, radius: radius, startAngle: angle, endAngle: endAngle, clockwise: true)
        path.close()
        return (path.cgPath, endAngle)
    }

    func cgPieChartPaths() -> [CGPath] {
        let center = CGPoint(x: drawingFrame.width / 2, y: drawingFrame.height / 2)
        let radius = drawingFrame.height / 2

        var startAngle: CGFloat = 0
        return piePercentages.map { percent in
            let (path, endAngle) = cgPieChartPath(at: center, radius: radius, from: startAngle, percent: percent)
            startAngle = endAngle
            return path
        }
    }
}
