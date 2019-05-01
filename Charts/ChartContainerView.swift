import UIKit

class ChartContainerView: UIView, Themable {
    func apply(_ theme: Theme) {
        self.theme = theme
    }

    private var theme: Theme = Theme.light {
        didSet {
            chartView.theme = theme
            scaleControl.theme = theme
            backgroundColor = theme.mainBackgroundColor
            backgroundColor = theme.mainBackgroundColor

            chartView.setNeedsDisplay()
        }
    }

    let chartView = ChartView()
    let scaleControl = ChartScaleControl()
    let buttonsPanel = LozengesPanelView()
    var dataSource: DataSource! {
        didSet {
            chartView.dataSource = dataSource
            scaleControl.dataSource = dataSource
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(chartView)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scaleControl)
        scaleControl.translatesAutoresizingMaskIntoConstraints = false
        scaleControl.addTarget(self, action: #selector(onScaleChanged(scaleControl:)), for: .valueChanged)

        chartView.backgroundColor = theme.mainBackgroundColor
        scaleControl.backgroundColor = theme.mainBackgroundColor
        scaleControl.range = 0.7 ..< 1.0

        // to handle gesture outside view
        let panGesture = UIPanGestureRecognizer()
        addGestureRecognizer(panGesture)
        scaleControl.panGesture = panGesture

        addSubview(buttonsPanel)
        buttonsPanel.translatesAutoresizingMaskIntoConstraints = false

        chartView.zoomAction = { [weak self] isZoomed in
            guard let self = self else { return false }
            if isZoomed {
                guard let selectedDay = self.chartView.selectedDay,
                    let zoomedData = self.chartView.dataSource.zoomedData(for: self.chartView.dataSource.xValues[selectedDay])
                else {
                    return false
                }

                self.chartView.dataSource = zoomedData
                self.scaleControl.dataSource = zoomedData
                let range: Range<CGFloat>
                if self.dataSource.type == .bar,
                    zoomedData.columns.count != self.dataSource.columns.count {
                    range = 0 ..< 1
                } else {
                    let zoomedTimestamp = self.dataSource.xValues[selectedDay]
                    range = self.chartView.projection.dayRange(dayTimestamp: zoomedTimestamp)
                }
                self.scaleControl.range = range
                self.scaleControl.sendActions(for: .valueChanged)
                self.scaleControl.setNeedsLayout()
                return true
            }

            let data = self.chartView.dataSource.xValues[self.chartView.projection.dataRange]
            self.chartView.dataSource = self.dataSource
            self.scaleControl.dataSource = self.dataSource
            let range = self.chartView.projection.range(fromTimestamp: data.first!, toTimeStamp: data.last!)
            self.scaleControl.range = range
            self.scaleControl.sendActions(for: .valueChanged)
            self.scaleControl.setNeedsLayout()
            return true
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        chartView.selectedDay = nil
        chartView.isZoomed = false
        scaleControl.range = 0.7 ..< 1.0
        scaleControl.isHidden = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let contentRect = bounds
        chartView.frame = CGRect(x: 0, y: 0, width: contentRect.width, height: Constants.chartHeight)
        scaleControl.frame = CGRect(x: Constants.contentPadding, y: chartView.frame.maxY, width: contentRect.width - 2 * Constants.contentPadding, height: Constants.scaleControlHeight)
        buttonsPanel.frame = CGRect(x: Constants.contentPadding, y: scaleControl.frame.maxY, width: contentRect.width - 2 * Constants.contentPadding, height: contentRect.height - scaleControl.frame.maxY)
    }

    static func height(for buttons: [UIView], in width: CGFloat) -> CGFloat {
        let rect = CGRect(x: Constants.contentPadding, y: Constants.buttonsPanelHPadding, width: width - 2 * Constants.contentPadding, height: 0)
        let tagsHeight = buttons.count > 1 ? LozengesPanelView.tagLayout(views: buttons, in: rect) : 0
        return Constants.chartHeight + Constants.scaleControlHeight + tagsHeight + Constants.buttonsPanelHPadding
    }

    @objc private func onScaleChanged(scaleControl: ChartScaleControl) {
        chartView.range = scaleControl.range
        chartView.setNeedsDisplay()
    }
}
