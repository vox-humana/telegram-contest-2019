import UIKit

class ListViewController: UITableViewController {
    var dataSources = [DataSource]()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Statistics"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Night Mode", style: .plain, target: self, action: #selector(toggleTheme))
        tableView.register(ChartCell.self, forCellReuseIdentifier: "ChartCell")
    }

    @objc private func toggleTheme() {
        let newTheme: Theme = AppDelegate.theme == .light ? .dark : .light
        navigationItem.rightBarButtonItem?.title = newTheme == .light ? "Night Mode" : "Day Mode"
        AppDelegate.theme = newTheme
    }
}

extension ListViewController {
    override func numberOfSections(in _: UITableView) -> Int {
        return dataSources.count
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataSources[section].name ?? "Chart #\(section + 1)"
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let dequeue: (String) -> (UITableViewCell) = { identifier in
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
            (cell as? Themable)?.apply(AppDelegate.theme)
            return cell
        }

        let tableCell = dequeue("ChartCell") as! ChartCell
        setupChartView(container: tableCell.containerView, indexPath: indexPath)
        return tableCell
    }

    private func setupChartView(container: ChartContainerView, indexPath: IndexPath) {
        let dataSource = dataSources[indexPath.section]
        container.dataSource = dataSource
        container.chartView.projection.range = container.scaleControl.range

        let buttons: [UIView] = setupButton(dataSource: dataSource, in: container)
        container.buttonsPanel.tagViews = buttons.count > 1 ? buttons : []
        container.chartView.setNeedsLayout()
        container.scaleControl.setNeedsLayout()
    }

    private func setupButton(dataSource: DataSource, in container: ChartContainerView) -> [UIView] {
        return zip(dataSource.makeButtons(), dataSource.columns.indices).map { [weak container] in
            let button = $0.0
            let index = $0.1
            button.isSelected = dataSource.selectedColumnsIndexes.contains(index)
            button.action = { button in
                if dataSource.selectedColumnsIndexes.contains(index) == true {
                    if dataSource.selectedColumnsIndexes.count < 2 {
                        return
                    }
                    dataSource.selectedColumnsIndexes.remove(index)
                } else {
                    dataSource.selectedColumnsIndexes.insert(index)
                }
                if let currentDatasource = container?.chartView.dataSource,
                    currentDatasource !== dataSource,
                    currentDatasource.columns.count == dataSource.columns.count {
                    currentDatasource.selectedColumnsIndexes = dataSource.selectedColumnsIndexes
                }
                button.isSelected = !button.isSelected
                container?.chartView.selectedPieChart = nil
                container?.chartView.setNeedsLayout()
                container?.scaleControl.setNeedsLayout()
            }
            return button
        }
    }
}

extension ListViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let dataSource = dataSources[indexPath.section]
        let buttons = dataSource.makeButtons()
        return ChartContainerView.height(for: buttons, in: tableView.bounds.width)
    }
}

extension DataSource {
    func makeButtons() -> [LozengeButton] {
        return zip(columns, columns.indices).map {
            let index = $0.1
            let button = LozengeButton()
            button.setTitle($0.0.name, for: .normal)
            button.color = $0.0.color
            button.isSelected = selectedColumnsIndexes.contains(index)
            button.sizeToFit()
            return button
        }
    }
}
