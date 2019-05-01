import CoreText
import UIKit

private let textLayerXAxis = false

class ChartView: UIView {
    var theme: Theme = Theme.light {
        didSet {
            backgroundColor = theme.mainBackgroundColor
            dateLineLayerDrawer.theme = theme
            axisLayerDrawer.theme = theme
            dateLineLayer.setNeedsDisplay()
            axisLayer.setNeedsDisplay()

            titleLabel.textColor = theme.mainTextColor
            barMaskLayer.backgroundColor = theme.barMask.cgColor
            zoomOutButton.setTitleColor(theme.zoomOutText, for: .normal)
            zoomOutButton.tintColor = theme.zoomOutText
        }
    }

    var selectedDay: Int? {
        didSet {
            dateLineLayerDrawer.selectedDay = selectedDay
            dateLineLayer.setNeedsDisplay()

            relayoutMaskLayer()
        }
    }

    var range: Range<CGFloat> = 0 ..< 1 {
        didSet {
            projection.range = range
            selectedDay = nil
            redrawData()
        }
    }

    var dataSource: DataSource! {
        didSet {
            selectedDay = nil
            dataLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            dataLayers = dataSource.columns.map {
                let sublayer: CAShapeLayer
                switch dataSource.type {
                case .line:
                    sublayer = CAShapeLayer(color: $0.color, lineWidth: theme.lineWidth)
                case .area:
                    sublayer = CAShapeLayer(color: $0.color)
                case .bar:
                    sublayer = CAShapeLayer(color: $0.color)
                }
                dataLayer.addSublayer(sublayer)
                return sublayer
            }
            dataLayers.forEach {
                dataSource.stacked ? dataLayer.insertSublayer($0, at: 0) : dataLayer.addSublayer($0)
            }
            projection = Projection(dataSource: dataSource)
            projection.drawingFrame = drawingFrame

            dateLineLayerDrawer.projection = projection
            dateLineLayerDrawer.drawLine = dataSource.type != .bar
            axisLayerDrawer.projection = projection
            dateLineLayer.setNeedsDisplay()
            axisLayer.setNeedsDisplay()

            updateTitle()
            setupXAxisLayers()
        }
    }

    var zoomAction: ((Bool) -> (Bool))?
    private let dataLayer = CALayer()
    private var dataLayers: [CAShapeLayer] = []
    private var pieLabelsLayers: [CATextLayer] = []

    private let dateLineLayerDrawer = DateLineLayerDrawer(layer: CALayer())
    private var dateLineLayer: CALayer {
        return dateLineLayerDrawer.layer
    }

    private let axisLayerDrawer = AxisLayerDrawer(layer: CALayer())
    private var axisLayer: CALayer {
        return axisLayerDrawer.layer
    }

    private var xAxisLayers: [CATextLayer] = []

    private let barMaskLayer = CALayer()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.titleFont
        return label
    }()

    private let zoomOutButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Zoom Out", for: .normal)
        button.titleLabel?.font = UIFont.lozengeButtonFont
        button.addTarget(self, action: #selector(zoomOut), for: .touchUpInside)
        button.isHidden = true
        button.setImage(arrowImage(false, .white), for: .normal)
        button.sizeToFit()
        return button
    }()

    lazy var projection: Projection = {
        Projection(dataSource: dataSource)
    }()

    private var drawingFrame: CGRect {
        return CGRect(x: Constants.contentPadding, y: 32, width: bounds.width - 2 * Constants.contentPadding, height: bounds.height - 32 - 32)
    }

    private let screenScale = UIScreen.main.scale
    var isZoomed: Bool {
        get {
            return !zoomOutButton.isHidden
        }
        set {
            zoomOutButton.isHidden = !newValue
            axisLayer.isHidden = dataSource.percentage && newValue
            dateLineLayerDrawer.zoomed = newValue
            axisLayerDrawer.zoomed = newValue

            if dataSource.percentage, newValue {
                setupPieLabels()
            }
            if !newValue {
                selectedPieChart = nil
                pieLabelsLayers.forEach { $0.removeFromSuperlayer() }
            }
        }
    }

    private var isPieChart: Bool {
        return isZoomed && dataSource.percentage
    }

    var selectedPieChart: Int? {
        didSet {
            defer {
                dateLineLayer.setNeedsDisplay()
            }
            if let oldValue = oldValue {
                dataLayers[oldValue].transform = CATransform3DIdentity
                pieLabelsLayers[oldValue].transform = CATransform3DIdentity
                dateLineLayerDrawer.selectedPieIndex = nil
            }
            guard let index = selectedPieChart else {
                return
            }

            guard selectedPieChart != oldValue else {
                selectedPieChart = nil
                return
            }

            dateLineLayerDrawer.selectedPieIndex = selectedPieChart

            let center = CGPoint(x: projection.drawingFrame.midX, y: projection.drawingFrame.midY)
            let offset = projection.pieCenters[index]
            let transform = CGAffineTransform(translationX: (offset.x - center.x) / 10, y: (offset.y - center.y) / 10)
            dataLayers[index].transform = CATransform3DMakeAffineTransform(transform)
            pieLabelsLayers[index].transform = CATransform3DMakeAffineTransform(transform)
        }
    }

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        layer.addSublayer(dataLayer)
        layer.addSublayer(barMaskLayer)

        dateLineLayer.contentsScale = screenScale
        axisLayer.contentsScale = screenScale

        layer.addSublayer(axisLayer)
        layer.addSublayer(dateLineLayer)

        addSubview(titleLabel)
        addSubview(zoomOutButton)
        setupGesture()
        clipsToBounds = true
    }

    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(gesture:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGesture(gesture:)))
        addGestureRecognizer(tapGesture)
    }

    private func setupXAxisLayers() {
        guard textLayerXAxis else { return }
        let renderer = Renderer(projection: projection, style: theme)
        let width = renderer.estimatedXDateWidth

        xAxisLayers.forEach { $0.removeFromSuperlayer() }
        xAxisLayers = zip(dataSource.xValues, dataSource.xValues.indices).map { timestamp, index in
            let layer = CATextLayer()
            layer.contentsScale = screenScale
            layer.font = UIFont.axisFont
            layer.fontSize = UIFont.axisFont.lineHeight
            layer.foregroundColor = self.theme.axisText.cgColor
            self.layer.insertSublayer(layer, at: 0)
            let x = self.projection.xOrigin(at: index)
            let y = projection.drawingFrame.maxY + 5
            layer.string = renderer.dateFormatter.string(from: timestamp)
            layer.frame = CGRect(x: x, y: y, width: width, height: 30)
            layer.anchorPoint.y = 0
            return layer
        }
    }

    private func layoutXAxis(animated: Bool) {
        guard textLayerXAxis else {
            return
        }
        CATransaction.begin()
        CATransaction.setValue(!animated, forKey: kCATransactionDisableActions)
        let renderer = Renderer(projection: projection, style: theme)
        let width = renderer.estimatedXDateWidth
        var prevX: CGFloat = -CGFloat.greatestFiniteMagnitude
        zip(xAxisLayers, xAxisLayers.indices).forEach { textLayer, i in
            let x = self.projection.xOrigin(at: i)
            let y = projection.drawingFrame.maxY + 5
            textLayer.position = CGPoint(x: x, y: y)
            if (textLayer.frame.maxX - prevX) > 1.5 * width {
                prevX = textLayer.frame.maxX
                textLayer.isHidden = false
            } else {
                textLayer.isHidden = true
            }
        }
        CATransaction.commit()
    }

    private func setupPieLabels() {
        assert(isPieChart)
        pieLabelsLayers.forEach { $0.removeFromSuperlayer() }

        let font = UIFont.lozengeButtonFont
        let size = "100%".textSize(font: font)
        pieLabelsLayers = dataSource.columns.indices.map { _ in
            let textLayer = CATextLayer()
            textLayer.contentsScale = screenScale
            textLayer.font = font
            textLayer.alignmentMode = .center
            textLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            textLayer.fontSize = font.pointSize
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.bounds.size = size
            self.layer.addSublayer(textLayer)
            return textLayer
        }
    }

    override func layoutSublayers(of layer: CALayer) {
        guard layer == self.layer else {
            return
        }

        projection.drawingFrame = drawingFrame

        dataLayer.frame = projection.drawingFrame
        dateLineLayer.frame = layer.bounds
        axisLayer.frame = layer.bounds

        redrawData(animated: false)

        titleLabel.frame.origin = CGPoint(x: drawingFrame.midX - titleLabel.bounds.width / 2, y: 5)
        zoomOutButton.frame.origin = CGPoint(x: drawingFrame.minX, y: 5)
        if !zoomOutButton.isHidden, zoomOutButton.frame.intersects(titleLabel.frame) {
            titleLabel.frame.origin = CGPoint(x: drawingFrame.maxX - titleLabel.bounds.width, y: 5)
        }

        barMaskLayer.frame = layer.bounds
    }

    func redrawZoomedPieChart(animated: Bool) {
        let paths = projection.cgPieChartPaths()
        for i in 0 ..< dataSource.columns.count {
            dataLayers[i].opacity = 1
            updateShapeLayer(at: i, path: paths[i], animated: animated)
        }

        zip(zip(projection.pieCenters, pieLabelsLayers), projection.piePercentages).forEach { arg0, value in
            let (center, labelLayer) = arg0
            labelLayer.string = "\(Int(value * 100))%"
            labelLayer.isHidden = value == 0
            labelLayer.position = center
        }

        updateTitle()
    }

    func redrawData(animated: Bool = true) {
        if isPieChart {
            redrawZoomedPieChart(animated: animated)
            return
        }

        let transform = projection.affineTransform()
        let minPoint = CGPoint(x: CGFloat(0), y: projection.minValue).applying(transform)
        let maxPoint = CGPoint(x: CGFloat(projection.dataSource.count - 1), y: projection.minValue).applying(transform)

        var selectedStackedColumnIndex = 0
        for i in 0 ..< dataSource.columns.count {
            let transform = projection.affineTransform(for: dataSource.columns[i])

            let column: Column
            if dataSource.selectedColumnsIndexes.contains(i), dataSource.stacked {
                column = dataSource.stackedColumns[selectedStackedColumnIndex]
                selectedStackedColumnIndex += 1
            } else {
                column = dataSource.columns[i]
            }

            let path: CGMutablePath
            if dataSource.type == .bar {
                path = column.cgBarPath(transform: transform)
            } else {
                path = column.cgPath(transform: transform)
            }

            switch dataSource.type {
            case .area:
                path.addLine(to: maxPoint)
                path.addLine(to: minPoint)
            case .bar:
                let xOffset = path.currentPoint.x - maxPoint.x
                path.addLine(to: CGPoint(x: path.currentPoint.x, y: maxPoint.y))
                path.addLine(to: CGPoint(x: minPoint.x - xOffset, y: maxPoint.y))
            case .line:
                break
            }

            updateShapeLayer(at: i, path: path, animated: animated)
            updateShapeLayerOpacity(at: i, animated: animated)
        }

        dateLineLayer.setNeedsDisplay()
        axisLayer.setNeedsDisplay()

        updateTitle()
        relayoutMaskLayer()
        layoutXAxis(animated: animated)
    }

    // MARK: - Private methods

    private func updateTitle() {
        let range = projection.dataRange
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        let formattedTimestamp = { (index: Int) -> String in
            let timestamp = self.dataSource.xValues[index]
            return formatter.string(from: timestamp)
        }
        let startDate = formattedTimestamp(range.lowerBound)
        let endDate = formattedTimestamp(range.upperBound - 1)
        if startDate != endDate {
            titleLabel.text = "\(startDate) - \(endDate)"
        } else {
            titleLabel.text = startDate
        }
        titleLabel.sizeToFit()
    }

    private func relayoutMaskLayer() {
        guard let index = selectedDay, dataSource.type == .bar else {
            barMaskLayer.isHidden = true
            return
        }

        let x = projection.xOrigin(at: index)
        let width = projection.xScale
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: CGRect(x: x - width / 2, y: 0, width: width, height: layer.bounds.height))
        path.append(UIBezierPath(rect: layer.bounds))
        maskLayer.fillRule = .evenOdd
        maskLayer.path = path.cgPath
        barMaskLayer.mask = maskLayer
        barMaskLayer.isHidden = false
    }

    @objc private func panGesture(gesture: UIGestureRecognizer) {
        switch gesture.state {
        case .possible, .cancelled, .failed:
            break
        case .began, .changed, .ended:
            let location = gesture.location(in: gesture.view)
            projection.drawingFrame = drawingFrame
            selectedDay = projection.dataIndex(at: location.x)
        @unknown default:
            fatalError()
        }
    }

    @objc private func tapGesture(gesture: UIGestureRecognizer) {
        if selectedDay != nil,
            gesture.state == .ended, dateLineLayerDrawer.tooltipFrame.contains(gesture.location(in: gesture.view)) {
            if zoomAction?(true) == true {
                isZoomed = true
                redrawData(animated: !dataSource.percentage)
            }
            return
        }

        if isPieChart {
            for (dataLayer, i) in zip(dataLayers, dataLayers.indices) {
                let location = gesture.location(in: gesture.view)
                let convertedPoint = dataLayer.convert(location, from: layer)
                if dataLayer.path?.contains(convertedPoint) == true {
                    selectedPieChart = i
                }
            }
            return
        }

        panGesture(gesture: gesture)
    }

    @objc private func zoomOut() {
        if zoomAction?(false) == true {
            isZoomed = false
            redrawData(animated: true)
        }
    }

    private func updateShapeLayerOpacity(at index: Int, animated: Bool) {
        let shapeLayer = dataLayers[index]
        let opacity: Float = dataSource.selectedColumnsIndexes.contains(index) ? 1 : 0
        guard animated else {
            shapeLayer.opacity = opacity
            return
        }

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = shapeLayer.opacity
        opacityAnimation.duration = Constants.animationDuration
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .default)
        opacityAnimation.fillMode = .forwards
        shapeLayer.opacity = opacity
        shapeLayer.add(opacityAnimation, forKey: "opacityAnimation")
    }

    private func updateShapeLayer(at index: Int, path: CGPath, animated: Bool) {
        let shapeLayer = dataLayers[index]
        guard animated else {
            shapeLayer.path = path
            return
        }

        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = shapeLayer.path
        pathAnimation.duration = Constants.animationDuration
        pathAnimation.timingFunction = CAMediaTimingFunction(name: .default)
        pathAnimation.fillMode = .forwards
        shapeLayer.path = path
        shapeLayer.add(pathAnimation, forKey: "pathAnimation")
    }
}

extension ChartView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // enable scroll in table
        if gestureRecognizer.view?.isKind(of: UITableView.self) == true {
            return true
        }

        return gestureRecognizer.view == self && (!isPieChart || gestureRecognizer is UITapGestureRecognizer)
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        return true
    }
}

class DateLineLayerDrawer: NSObject, CALayerDelegate {
    var projection: Projection!
    var theme: Theme = .light
    let layer: CALayer

    var selectedDay: Int? {
        didSet {
            if selectedDay == nil {
                tooltipFrame = .zero
            }
        }
    }

    var drawLine = true
    var zoomed = false
    var tooltipFrame: CGRect = .zero
    var selectedPieIndex: Int?

    init(layer: CALayer) {
        self.layer = layer
        super.init()
        layer.delegate = self
    }

    func draw(_: CALayer, in ctx: CGContext) {
        if let selectedPieIndex = selectedPieIndex {
            measure("draw tooltip") {
                UIGraphicsPushContext(ctx)
                let renderer = Renderer(projection: self.projection, style: self.theme)
                let point = CGPoint(x: self.projection.drawingFrame.midX, y: self.projection.drawingFrame.midY)
                renderer.drawPieTooltip(in: ctx, at: point, index: selectedPieIndex)
                UIGraphicsPopContext()
            }
            return
        }

        guard let selectedDay = self.selectedDay else {
            return
        }
        measure("draw tooltip") {
            UIGraphicsPushContext(ctx)
            let renderer = Renderer(projection: self.projection, style: self.theme)
            if drawLine {
                renderer.drawDateLine(in: ctx, at: selectedDay)
            }
            self.tooltipFrame = renderer.drawTooltip(in: ctx, at: selectedDay, position: .side, time: zoomed)
            UIGraphicsPopContext()
        }
    }
}

class AxisLayerDrawer: NSObject, CALayerDelegate {
    var projection: Projection!
    var theme: Theme = .light
    let layer: CALayer
    var zoomed = false

    init(layer: CALayer) {
        self.layer = layer
        super.init()
        layer.delegate = self
    }

    func draw(_: CALayer, in ctx: CGContext) {
        measure("draw axis") {
            UIGraphicsPushContext(ctx)

            let renderer = Renderer(projection: self.projection, style: self.theme)
            renderer.drawYAxis(in: ctx)
            if !textLayerXAxis {
                zoomed ? renderer.drawTimedXAxis(in: ctx) : renderer.drawXAxis(in: ctx)
            }
            UIGraphicsPopContext()
        }
    }
}
