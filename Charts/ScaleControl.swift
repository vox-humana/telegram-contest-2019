import UIKit

class ChartScaleControl: UIControl {
    private let gestureDelta: CGFloat = 16
    private var minRange: CGFloat {
        return bounds.width > 0 ? 50 / bounds.width : 0.1
    }

    var theme: Theme = Theme.light {
        didSet {
            theme.lineWidth = 1

            backgroundColor = theme.mainBackgroundColor

            dimLayer.backgroundColor = theme.scrollBackground.cgColor

            sectionView.image = sectionImage(theme.scrollSelector)
        }
    }

    var dataSource: DataSource!
    var range: Range<CGFloat> = 0 ..< 1 {
        didSet {
            if range.upperBound - range.lowerBound < minRange {
                let delta = (minRange - (range.upperBound - range.lowerBound)) / 2
                range = range.lowerBound - delta ..< range.upperBound + delta
            }
            let distance = range.upperBound - range.lowerBound
            if range.lowerBound < 0 {
                range = 0 ..< distance
            } else if range.upperBound > 1 {
                range = (1 - distance) ..< 1
            }

            let rect = CGRect(x: sectionStartPosition, y: 0, width: sectionEndPosition - sectionStartPosition, height: layer.bounds.height)

            sectionView.frame = rect

            guard let maskLayer = maskLayer else {
                return
            }

            let path = UIBezierPath(rect: rect.insetBy(dx: Constants.scaleControlImageWidth, dy: 0))
            path.append(UIBezierPath(rect: layer.bounds))
            maskLayer.fillRule = .evenOdd
            maskLayer.path = path.cgPath
        }
    }

    var panGesture: UIPanGestureRecognizer = UIPanGestureRecognizer() {
        didSet {
            if oldValue.view == self {
                removeGestureRecognizer(oldValue)
            }
            oldValue.removeTarget(self, action: #selector(panGesture(gesture:)))
            oldValue.delegate = nil
            panGesture.addTarget(self, action: #selector(panGesture(gesture:)))
            panGesture.delegate = self
        }
    }

    private let dataLayer = CALayer()
    private let sectionLayer = CALayer()
    private let sectionView = UIImageView()
    private let dimLayer = CALayer()
    private var maskLayer: CAShapeLayer? {
        return dimLayer.mask as? CAShapeLayer
    }

    private enum PanGestureInteraction {
        case startLayer
        case endLayer
        case both
    }

    private var gestureInteraction: PanGestureInteraction = .both

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override func layoutSublayers(of layer: CALayer) {
        guard layer == self.layer else {
            return
        }

        dimLayer.frame = layer.bounds.insetBy(dx: 0, dy: Constants.scaleControlBorderHeight)

        let rect = CGRect(x: sectionStartPosition, y: 0, width: sectionEndPosition - sectionStartPosition, height: layer.bounds.height)
        sectionView.frame = rect

        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: rect.insetBy(dx: Constants.scaleControlImageWidth, dy: 0))
        path.append(UIBezierPath(rect: layer.bounds))
        maskLayer.fillRule = .evenOdd
        maskLayer.path = path.cgPath
        dimLayer.mask = maskLayer

        dataLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let projection = Projection(dataSource: dataSource)
        projection.drawingFrame = dimLayer.frame.insetBy(dx: 0, dy: 4)

        let columns = dataSource.stacked ? dataSource.stackedColumns : dataSource.selectedColumns
        let transform = projection.affineTransform()
        let minPoint = CGPoint(x: CGFloat(0), y: projection.minValue).applying(transform)
        let maxPoint = CGPoint(x: CGFloat(projection.dataSource.count - 1), y: projection.minValue).applying(transform)
        columns.forEach {
            let transform = projection.affineTransform(for: $0)
            let sublayer: CAShapeLayer
            switch dataSource.type {
            case .line:
                sublayer = CAShapeLayer(color: $0.color, lineWidth: 1)
            case .area:
                sublayer = CAShapeLayer(color: $0.color)
            case .bar:
                sublayer = CAShapeLayer(color: $0.color)
            }

            let path: CGMutablePath
            switch dataSource.type {
            case .area:
                path = $0.cgPath(transform: transform)
                path.addLine(to: maxPoint)
                path.addLine(to: minPoint)
            case .bar:
                path = $0.cgBarPath(transform: transform)
                path.addLine(to: maxPoint)
                path.addLine(to: minPoint)
            case .line:
                path = $0.cgPath(transform: transform)
            }

            sublayer.path = path
            dataSource.stacked ? dataLayer.insertSublayer(sublayer, at: 0) : dataLayer.addSublayer(sublayer)
        }
        dataLayer.frame = projection.drawingFrame
    }

    func updateRange(range: Range<CGFloat>) {
        let length = range.upperBound - range.lowerBound
        if length < minRange {
            let delta = (minRange - length) / 2
            self.range = range.lowerBound - delta ..< range.upperBound + delta
        } else {
            self.range = range
        }
        sendActions(for: .valueChanged)
    }

    private var sectionStartPosition: CGFloat {
        return layer.bounds.width * range.lowerBound
    }

    private var sectionEndPosition: CGFloat {
        return layer.bounds.width * range.upperBound
    }

    private func setup() {
        layer.addSublayer(dataLayer)
        layer.cornerRadius = Constants.scaleControlcornerRadius
        layer.masksToBounds = true

        dimLayer.backgroundColor = theme.scrollBackground.cgColor
        layer.addSublayer(dimLayer)

        theme = .light
        addSubview(sectionView)

        panGesture.addTarget(self, action: #selector(panGesture(gesture:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGesture(gesture:)))
        addGestureRecognizer(tapGesture)
    }

    @objc private func tapGesture(gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let location = gesture.location(in: gesture.view)
        let length = range.upperBound - range.lowerBound
        let center = location.x / bounds.width
        let lower = center - length / 2
        let upper = center + length / 2
        range = lower ..< upper
        sendActions(for: .valueChanged)
    }

    @objc private func panGesture(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .possible:
            break
        case .began:
            let location = gesture.location(in: self)

            if abs(sectionStartPosition - location.x) < gestureDelta {
                gestureInteraction = .startLayer
                break
            }

            if abs(sectionEndPosition - location.x) < gestureDelta {
                gestureInteraction = .endLayer
                break
            }

            gestureInteraction = .both
        case .changed:
            let location = gesture.location(in: self).x
            let value = (location / bounds.width).normalized()

            switch gestureInteraction {
            case .startLayer:
                let normalized = min(value, range.upperBound - minRange)
                range = normalized ..< range.upperBound
            case .endLayer:
                let normalized = max(value, range.lowerBound + minRange)
                range = range.lowerBound ..< normalized
            case .both:
                let translation = gesture.translation(in: gesture.view)
                let lower = range.lowerBound + translation.x / bounds.width
                let upper = range.upperBound + translation.x / bounds.width
                range = lower ..< upper
                gesture.setTranslation(.zero, in: gesture.view)
            }
            sendActions(for: .valueChanged)

        case .ended, .cancelled, .failed:
            break
        @unknown default:
            fatalError()
        }
    }
}

extension ChartScaleControl: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGesture else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let location = gestureRecognizer.location(in: self).x
        let range = (sectionStartPosition - gestureDelta) ..< (sectionEndPosition + gestureDelta)
        return range.contains(location)
    }
}
