import CoreGraphics
import Foundation

class Projection {
    var range: Range<CGFloat> = 0 ..< 1
    var drawingFrame: CGRect = .zero
    let dataSource: DataSource

    init(dataSource: DataSource) {
        self.dataSource = dataSource
    }

    func dataIndex(at xOrigin: CGFloat) -> Int {
        let normalized = (xOrigin - drawingFrame.minX) / drawingFrame.width
        let value = dataSource.xValues[dataRange.lowerBound] + Int(normalized * CGFloat(duration))
        return min(dataSource.xValues.binarySearch(element: value), dataSource.count - 1)
    }

    func makePoint(for column: Column, index: Int) -> CGPoint {
        let value = column.values[index]
        let point = CGPoint(x: index, y: value)
        let offset = CGAffineTransform(translationX: drawingFrame.minX, y: drawingFrame.minY)
        return point.applying(affineTransform(for: column).concatenating(offset))
    }

    func xOrigin(at index: Int) -> CGFloat {
        let value = dataSource.xValues[index]
        let xOffset = CGFloat(value - dataSource.xValues[dataRange.lowerBound])
        let durationScale = drawingFrame.width / CGFloat(duration)
        return drawingFrame.minX + xOffset * durationScale
    }

    var xScale: CGFloat {
        let length = dataRange.upperBound - dataRange.lowerBound
        return drawingFrame.width / CGFloat(length)
    }

    private var yScale: CGFloat {
        return drawingFrame.height / (maxValue - minValue)
    }

    private func yScale(for colunm: Column) -> CGFloat {
        let min = CGFloat(colunm.values[dataRange].min() ?? 0)
        let max = CGFloat(colunm.values[dataRange].max() ?? 1)
        return drawingFrame.height / (max - min)
    }

    var dataRange: Range<Int> {
        let lower = dataSource.firstXValue + Int(range.lowerBound * CGFloat(dataSource.totalDuration))
        let upper = dataSource.firstXValue + Int(range.upperBound * CGFloat(dataSource.totalDuration))
        let lowerIndex = min(dataSource.xValues.binarySearch(element: lower), dataSource.count)
        let upperIndex = min(dataSource.xValues.binarySearch(element: upper), dataSource.count)
        return lowerIndex ..< upperIndex
    }

    var minValue: CGFloat {
        if dataSource.stacked || dataSource.percentage || dataSource.type == .bar {
            return 0
        }

        return dataSource.selectedColumns.reduce(CGFloat.greatestFiniteMagnitude) {
            min($0, CGFloat($1.values[dataRange].min() ?? 0))
        }
    }

    func minValue(for column: Column) -> CGFloat {
        return CGFloat(column.values[dataRange].min() ?? 0)
    }

    var maxValue: CGFloat {
        if dataSource.percentage {
            return 100
        }

        if dataSource.stacked {
            return CGFloat(dataSource.stackedColumns.last?.values[dataRange].max() ?? 1)
        }

        return dataSource.selectedColumns.reduce(0) {
            max($0, CGFloat($1.values[dataRange].max() ?? 1))
        }
    }

    func maxValue(for column: Column) -> CGFloat {
        return CGFloat(column.values[dataRange].max() ?? 1)
    }

    var duration: Int {
        return dataSource.xValues[dataRange.upperBound] - dataSource.xValues[dataRange.lowerBound]
    }

    func dayRange(dayTimestamp: Int) -> Range<CGFloat> {
        let date = Date(timeIntervalSince1970: TimeInterval(dayTimestamp / 1000))
        let startDayTimestamp = Int(date.startOfDay.timeIntervalSince1970 * 1000)
        let endDayTimestamp = Int(date.endOfDay.timeIntervalSince1970 * 1000)
        let startIndex = dataSource.xValues.binarySearch(element: startDayTimestamp)
        let endIndex = dataSource.xValues.binarySearch(element: endDayTimestamp)
        return CGFloat(startIndex) / CGFloat(dataSource.xValues.count) ..< CGFloat(endIndex) / CGFloat(dataSource.xValues.count)
    }

    func range(fromTimestamp: Int, toTimeStamp: Int) -> Range<CGFloat> {
        let startIndex = dataSource.xValues.binarySearch(element: fromTimestamp)
        let endIndex = dataSource.xValues.binarySearch(element: toTimeStamp)
        return CGFloat(startIndex) / CGFloat(dataSource.xValues.count) ..< CGFloat(endIndex + 1) / CGFloat(dataSource.xValues.count)
    }
}

extension Projection {
    func affineTransform(for column: Column) -> CGAffineTransform {
        let colunmY = dataSource.yScaled ? minValue(for: column) : minValue
        let origin = CGAffineTransform(translationX: CGFloat(-dataRange.lowerBound), y: -colunmY)
        let colunmScale = dataSource.yScaled ? yScale(for: column) : yScale
        let scale = CGAffineTransform(scaleX: xScale, y: -colunmScale)
        let offset = CGAffineTransform(translationX: 0, y: drawingFrame.height)
        return origin.concatenating(scale).concatenating(offset)
    }

    func affineTransform() -> CGAffineTransform {
        let colunmY = minValue
        let origin = CGAffineTransform(translationX: CGFloat(-dataRange.lowerBound), y: -colunmY)
        let colunmScale = yScale
        let scale = CGAffineTransform(scaleX: xScale, y: -colunmScale)
        let offset = CGAffineTransform(translationX: 0, y: drawingFrame.height)
        return origin.concatenating(scale).concatenating(offset)
    }
}
