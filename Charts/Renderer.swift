import CoreGraphics
import UIKit

struct Renderer {
    enum TooltipPosition {
        case top
        case side // left side unless it's in the leading part
        case halfSide // switch side from mid point
        case auto // top and all sides
    }

    private let style: Theme
    private var dataSource: DataSource {
        return projection.dataSource
    }

    private let projection: Projection

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE, d MMM yyyy"
        return formatter
    }()

    private let yAxisFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 2
        return formatter
    }()

    private let tooltipValueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.groupingSize = 3
        formatter.groupingSeparator = " "
        return formatter
    }()

    init(projection: Projection, style: Theme) {
        self.projection = projection
        self.style = style
    }

    private func dateString(for timestamp: Int) -> String {
        return dateFormatter.string(from: timestamp)
    }

    private func fullDateString(for timestamp: Int) -> String {
        return fullDateFormatter.string(from: timestamp)
    }

    // MARK: - Drawing

    func drawColumns(in context: CGContext) {
        dataSource.selectedColumns.forEach {
            draw(column: $0, in: context)
        }
    }

    func draw(column: Column, in context: CGContext) {
        let range = projection.dataRange

        let firstPoint = projection.makePoint(for: column, index: range.lowerBound)
        context.move(to: firstPoint)
        for i in range.dropFirst() {
            context.addLine(to: projection.makePoint(for: column, index: i))
        }
        context.setStrokeColor(column.color.cgColor)
        context.setLineWidth(style.lineWidth)
        context.strokePath()
    }

    func drawYAxis(in context: CGContext) {
        let textFont = UIFont.axisFont
        let textOffset: CGFloat = 4

        let steps = dataSource.percentage ? 4 : 5
        let yOffset = dataSource.percentage ? 0 : textFont.lineHeight + 2 * textOffset
        let maxHeight = projection.drawingFrame.height - yOffset
        let step = maxHeight / CGFloat(steps)
        let xOffset: CGFloat = 0

        let path = UIBezierPath()
        path.move(to: CGPoint(x: projection.drawingFrame.origin.x + xOffset, y: projection.drawingFrame.minY + yOffset))
        path.addLine(to: CGPoint(x: projection.drawingFrame.maxX - xOffset, y: projection.drawingFrame.minY + yOffset))
        path.lineWidth = 1

        context.setStrokeColor(style.gridLines.cgColor)

        context.saveGState()
        path.stroke()
        for _ in 0 ..< steps {
            context.translateBy(x: 0, y: rint(step))
            path.stroke()
        }
        context.restoreGState()

        let drawText = { (projection: Projection, minValue: CGFloat, maxValue: CGFloat, color: UIColor?, isRight: Bool) in
            for i in 0 ... steps {
                let value = (maxValue - minValue) / projection.drawingFrame.height * step * CGFloat(i) + minValue
                let string = self.yAxisFormatter.abbreviatedString(for: Int(value))
                let yOrigin = projection.drawingFrame.minY + rint(step * CGFloat(steps - i))

                let maxX = isRight ? projection.drawingFrame.maxX : 0
                self.draw(text: string, at: CGPoint(x: projection.drawingFrame.minX + xOffset, y: yOrigin), color: color, font: textFont, maxX: maxX)
            }
        }

        if dataSource.yScaled {
            if dataSource.selectedColumnsIndexes.contains(0) {
                let leftColumn = dataSource.columns[0]
                let minValue1 = projection.minValue(for: leftColumn)
                let maxValue1 = projection.maxValue(for: leftColumn)
                drawText(projection, minValue1, maxValue1, leftColumn.color, false)
            }
            if dataSource.selectedColumnsIndexes.contains(1) {
                let rigthColumn = dataSource.columns[1]
                let minValue2 = projection.minValue(for: rigthColumn)
                let maxValue2 = projection.maxValue(for: rigthColumn)
                drawText(projection, minValue2, maxValue2, rigthColumn.color, true)
            }
            return
        }

        if dataSource.percentage {
            for i in 0 ... steps {
                let value = 100 / maxHeight * step * CGFloat(i)
                let string = yAxisFormatter.abbreviatedString(for: Int(value))
                let yOrigin = projection.drawingFrame.minY + rint(step * CGFloat(steps - i))
                draw(text: string, at: CGPoint(x: projection.drawingFrame.minX + xOffset, y: yOrigin - textFont.lineHeight), font: textFont)
            }
            return
        }

        drawText(projection, projection.minValue, projection.maxValue, nil, false)
    }

    func drawXAxis(in _: CGContext) {
        let font = UIFont.axisFont
        let formatter = dateFormatter
        let estimatedString = formatter.string(from: 31_190_400_000)
        let stepWidth = textSize(text: estimatedString, font: font).width + 8
        let steps = Int(projection.drawingFrame.width / stepWidth)
        let step = projection.duration / steps

        let range = projection.dataRange

        for i in 0 ..< steps {
            let value = dataSource.xValues[range.lowerBound] + step * i
            let string = formatter.string(from: value)
            let xOrigin = projection.drawingFrame.minX + projection.drawingFrame.width / CGFloat(steps) * CGFloat(i)
            draw(text: string, at: CGPoint(x: xOrigin, y: projection.drawingFrame.maxY + 5), font: font)
        }
    }

    func drawTimedXAxis(in _: CGContext) {
        let font = UIFont.axisFont
        let estimatedString = timeFormatter.string(from: 31_190_400_000)
        let stepWidth = textSize(text: estimatedString, font: font).width + 8

        var i = max(projection.dataRange.lowerBound - 1, 0)
        var xOffset: CGFloat = -stepWidth / 2
        while xOffset < (projection.drawingFrame.maxX - stepWidth / 2), i < dataSource.xValues.count {
            let value = dataSource.xValues[i]
            let string = timeFormatter.string(from: value)
            let x = projection.xOrigin(at: i) - stepWidth / 2
            if x - xOffset >= stepWidth {
                draw(text: string, at: CGPoint(x: x, y: projection.drawingFrame.maxY + 5), font: font, maxX: x + stepWidth, isCentered: true)
                xOffset = x
            }
            i += 1
        }
    }

    var estimatedXDateWidth: CGFloat {
        let font = UIFont.axisFont
        let estimatedString = dateString(for: 31_190_400_000)
        let stepWidth = textSize(text: estimatedString, font: font).width + 8
        return stepWidth
    }

    private let textPagging: CGFloat = 8
    private var percentageWidth: CGFloat {
        return dataSource.percentage ? textSize(text: "100%", font: UIFont.tooltipFont).width : 0
    }

    private var tooltipWidth: CGFloat {
        let dateString = fullDateString(for: 31_190_400_000)
        let dateSize = textSize(text: dateString, font: UIFont.tooltipFont)

        let maxValue = dataSource.selectedColumns.reduce(0) {
            max($0, $1.values[projection.dataRange].max() ?? 1)
        }
        let maxValueString = tooltipValueFormatter.string(from: NSNumber(integerLiteral: maxValue))!
        let nameWidth: CGFloat = dataSource.selectedColumns.reduce(0) {
            let width = self.textSize(text: $1.name, font: UIFont.tooltipNameFont).width
            return max(width, $0)
        }
        let valueWidth = textSize(text: maxValueString, font: UIFont.tooltipFont).width
        let arrowWidth: CGFloat = 24
        return max(dateSize.width + arrowWidth, textPagging + percentageWidth + textPagging + nameWidth + textPagging + valueWidth + textPagging)
    }

    func drawPieTooltip(in context: CGContext, at point: CGPoint, index: Int) {
        let valueFont = UIFont.tooltipFont
        let nameFont = UIFont.tooltipNameFont
        let name = dataSource.columns[index].name
        let color = dataSource.columns[index].color
        let valueString = String(projection.pieValues[index])

        let padding: CGFloat = 4
        let panelHeight: CGFloat = valueString.textSize(font: valueFont).height + 2 * padding
        let panelWidth: CGFloat = padding + name.textSize(font: nameFont).width + padding + valueString.textSize(font: valueFont).width + padding

        context.saveGState()
        context.translateBy(x: point.x - panelWidth / 2, y: point.y - panelHeight / 2)
        context.setFillColor(style.secondaryBackgroundColor.cgColor)
        UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight), cornerRadius: 4).fill()

        draw(text: name, at: CGPoint(x: padding, y: padding), color: style.tooltipTextColor, font: nameFont)
        draw(text: valueString, at: CGPoint(x: 0, y: padding), color: color, font: valueFont, maxX: panelWidth - padding)

        context.restoreGState()
    }

    func drawTooltip(in context: CGContext, at index: Int, position: TooltipPosition, time: Bool) -> CGRect {
        let x = projection.xOrigin(at: index)
        let columns = dataSource.stacked ? dataSource.stackedColumns : dataSource.selectedColumns

        let topValuePoint = columns.reduce(CGPoint(x: x, y: projection.drawingFrame.maxY)) {
            let point = projection.makePoint(for: $1, index: index)
            return CGPoint(x: x, y: min(point.y, $0.y))
        }

        let tooltipFont = UIFont.tooltipFont
        let valueFont = UIFont.tooltipFont
        let nameFont = UIFont.tooltipNameFont
        let padding: CGFloat = textPagging
        let topOffset: CGFloat = projection.drawingFrame.minY
        let lineHeight: CGFloat = tooltipFont.lineHeight + 2
        let linesCount = dataSource.selectedColumns.count + 1
        let panelHeight: CGFloat = lineHeight * CGFloat(linesCount) + 2 * padding
        let panelWidth: CGFloat = tooltipWidth

        let formatter = time ? timeFormatter : fullDateFormatter
        let dateString = formatter.string(from: dataSource.xValues[index])

        var xOffset = x - panelWidth / 2
        let drawTooltipPanel: (CGRect) -> Void = { frame in
            if xOffset + panelWidth > frame.maxX {
                xOffset = frame.maxX - panelWidth
            }
            if xOffset < frame.minX {
                xOffset = frame.minX
            }

            let barWidth = self.dataSource.type == .bar ? self.projection.xScale / 2 : 0
            if position == .auto {
                if topValuePoint.y < panelHeight + topOffset {
                    xOffset = x + padding + barWidth
                    if x + panelWidth > frame.maxX {
                        xOffset = x - panelWidth - barWidth - padding
                    }
                }
            } else if position == .halfSide {
                xOffset = x > frame.midX ? x - panelWidth - barWidth - padding : x + barWidth + padding
            } else if position == .side {
                xOffset = x - panelWidth - barWidth - padding
                if xOffset < frame.minX {
                    xOffset = x + barWidth + padding
                }
            }

            context.translateBy(x: xOffset, y: topOffset)
            context.setFillColor(self.style.secondaryBackgroundColor.cgColor)
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight), cornerRadius: 4).fill()

            self.draw(text: dateString, at: CGPoint(x: padding, y: padding), color: self.style.tooltipTextColor, font: tooltipFont)
            if !time {
                self.drawImage(self.style.tooltipArrowImage, in: context, at: CGPoint(x: panelWidth - padding - self.style.tooltipArrowImage.size.width, y: padding + 2))
            }
        }

        context.saveGState()
        drawTooltipPanel(projection.drawingFrame)

        var offsetPercentValue = 0
        for (i, column) in dataSource.selectedColumns.enumerated() {
            let name = column.name
            let valueString = tooltipValueFormatter.string(from: NSNumber(integerLiteral: column.values[index]))!
            let y = padding + CGFloat(i + 1) * lineHeight
            var left = padding

            if dataSource.percentage {
                let stackedValue = dataSource.stackedColumns[i].values[index]
                let percent = "\(stackedValue - offsetPercentValue)%"
                offsetPercentValue = stackedValue
                draw(text: percent, at: CGPoint(x: left, y: y), font: valueFont, maxX: left + percentageWidth)
                left += padding + percentageWidth
            }

            draw(text: name, at: CGPoint(x: left, y: y), color: style.tooltipTextColor, font: nameFont)
            draw(text: valueString, at: CGPoint(x: 0, y: y), color: column.color, font: valueFont, maxX: panelWidth - padding)
        }
        context.restoreGState()

        return CGRect(x: xOffset, y: topOffset, width: panelWidth, height: panelHeight)
    }

    func drawDateLine(in context: CGContext, at index: Int) {
        let x = projection.xOrigin(at: index)
        context.setStrokeColor(style.gridLines.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: projection.drawingFrame.minY))
        context.addLine(to: CGPoint(x: x, y: projection.drawingFrame.maxY))
        context.strokePath()

        guard dataSource.type == .line else { return }

        let columns = dataSource.stacked ? dataSource.stackedColumns : dataSource.selectedColumns
        columns.forEach { column in
            let center = projection.makePoint(for: column, index: index)
            context.setFillColor(style.mainBackgroundColor.cgColor)
            context.setLineWidth(style.lineWidth)
            context.setStrokeColor(column.color.cgColor)
            context.addArc(center: center, radius: 3, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
            context.drawPath(using: .fillStroke)
        }
    }

    // MARK: - Private Methods

    private func draw(text: String, at point: CGPoint, color: UIColor? = nil, font: UIFont, maxX: CGFloat = 0, isCentered: Bool = false) {
        let textColor = color ?? style.axisText

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = maxX > 0 ? (isCentered ? .center : .right) : .left

        let textAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.paragraphStyle: paragraph,
        ]

        if maxX > 0 {
            (text as NSString).draw(in: CGRect(origin: point, size: CGSize(width: maxX - point.x, height: font.lineHeight)), withAttributes: textAttributes)
        } else {
            (text as NSString).draw(at: point, withAttributes: textAttributes)
        }
    }

    private func textSize(text: String, font: UIFont) -> CGSize {
        return text.textSize(font: font)
    }

    private func drawImage(_ image: UIImage, in ctx: CGContext, at point: CGPoint) {
        guard let cgImage = image.cgImage else { return }
        ctx.draw(cgImage, in: CGRect(origin: point, size: image.size))
    }
}
