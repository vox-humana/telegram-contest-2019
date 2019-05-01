import UIKit

protocol Column {
    typealias ValueType = Int
    var name: String { get }
    var color: UIColor { get }
    var values: [ValueType] { get }
}

enum ChartType {
    case line
    case area
    case bar
}

protocol DataSource: AnyObject {
    var type: ChartType { get }
    var count: Int { get }
    var percentage: Bool { get }
    var stacked: Bool { get }
    var yScaled: Bool { get }

    var xValues: [Int] { get }
    var columns: [Column] { get }

    var name: String? { get }

    func zoomedData(for timestamp: Int) -> DataSource?

    var selectedColumnsIndexes: Set<Int> { get set }

    var stackedColumns: [Column] { get } // for stacked only!
}

extension DataSource {
    var selectedColumns: [Column] {
        return columns.indices.filter { selectedColumnsIndexes.contains($0) }.map { columns[$0] }
    }
}

extension DataSource {
    var firstXValue: Int {
        return xValues.first ?? 0
    }

    var lastXValue: Int {
        return xValues.last ?? 1
    }

    var totalDuration: Int {
        assert(firstXValue < lastXValue)
        return lastXValue - firstXValue
    }
}

class ChartDataSource: DataSource {
    var stackedColumns: [Column] // cached stacked values
    var name: String?

    var selectedColumnsIndexes: Set<Int> {
        didSet {
            if oldValue != selectedColumnsIndexes {
                stackedColumns = ChartColumn.stacked(selectedColumns, percentage)
            }
        }
    }

    struct ChartColumn: Column {
        let name: String
        let color: UIColor
        let values: [Column.ValueType]

        static func stacked(_ columns: [Column], _ percentage: Bool) -> [Column] {
            guard let valuesCount = columns.first?.values.count else { return [] }
            var values: [[Column.ValueType]] = Array(repeating: [], count: columns.count)
            for i in 0 ..< valuesCount {
                var sumValue = 0
                for j in 0 ..< columns.count {
                    sumValue += columns[j].values[i]
                    values[j].append(sumValue)
                }
                if percentage {
                    for j in 0 ..< columns.count {
                        values[j][i] = values[j][i] * 100 / sumValue
                    }
                }
            }
            return zip(columns, values).map { ChartColumn(name: $0.0.name, color: $0.0.color, values: $0.1) }
        }
    }

    let type: ChartType
    let percentage: Bool
    let stacked: Bool
    let yScaled: Bool

    let count: Int
    let xValues: [Int]
    let columns: [Column]

    private let identifier: Int?

    init(xValues: [Int], columns: [Column], name: String? = nil, identifier: Int? = nil, type: ChartType = .line, percentage: Bool = false, stacked: Bool = false) {
        count = xValues.count
        self.columns = columns
        self.xValues = xValues
        selectedColumnsIndexes = Set(columns.indices)
        self.type = type
        self.percentage = percentage
        self.stacked = stacked
        yScaled = false
        selectedColumnsIndexes = Set(columns.indices)
        stackedColumns = ChartColumn.stacked(columns, percentage)
        self.identifier = identifier
        self.name = name
    }

    init?(source: CodableDataSource, name: String? = nil, identifier: Int?) {
        guard let xAxis = source.columns.first(where: { $0.xAxis }) else {
            assertionFailure("No X axis")
            return nil
        }
        assert(xAxis.values.sorted() == xAxis.values)

        xValues = xAxis.values
        count = xValues.count

        let values = source.columns.filter { !$0.xAxis }
        assert(values.first != nil)
        assert(xAxis.values.count == values.first!.values.count)

        // Do not support multiple types in one chart
        guard
            let firstColumnName = values.first?.name,
            let firstColumnType = source.types[firstColumnName]?.asChartType
        else {
            return nil
        }

        type = firstColumnType
        columns = values.compactMap { [type] in
            guard
                let name = source.names[$0.name],
                let colorString = source.colors[$0.name],
                let columnType = source.types[$0.name]?.asChartType
            else {
                fatalError()
            }
            assert(columnType == type)
            return ChartColumn(name: name, color: UIColor(hexString: colorString), values: $0.values)
        }

        percentage = source.percentage ?? false
        stacked = source.stacked ?? false
        yScaled = source.y_scaled ?? false
        if yScaled {
            assert(values.count <= 2)
        }
        selectedColumnsIndexes = Set(columns.indices)
        stackedColumns = ChartColumn.stacked(columns, percentage)
        self.identifier = identifier
        self.name = name
    }
}

struct CodableDataSource: Decodable {
    enum RowType: String, Decodable {
        case x
        case line
        case area
        case bar
        var asChartType: ChartType {
            switch self {
            case .line:
                return .line
            case .area:
                return .area
            case .bar:
                return .bar
            default:
                fatalError("Unsupported type")
            }
        }
    }

    struct Colum: Decodable {
        let name: String
        let values: [Int]
        let xAxis: Bool

        init(from decoder: Decoder) throws {
            var v = try decoder.unkeyedContainer()
            name = try v.decode(String.self)
            values = try (1 ..< v.count!).map { _ in try v.decode(Int.self) }
            xAxis = (name.caseInsensitiveCompare(RowType.x.rawValue) == .orderedSame)
        }
    }

    let colors: [String: String]
    let columns: [Colum]
    let types: [String: RowType]
    let names: [String: String]
    let percentage: Bool?
    let stacked: Bool?
    let y_scaled: Bool?
}

extension ChartDataSource {
    private static var dataURL: URL {
        return Bundle.main.bundleURL.appendingPathComponent("graph_data2")
    }

    static func loadStage1Data() -> [DataSource] {
        guard let url = Bundle.main.url(forResource: "chart_data", withExtension: "json") else {
            return []
        }

        guard let data = try? Data(contentsOf: url),
            let values = try? JSONDecoder().decode([CodableDataSource].self, from: data) else {
            return []
        }
        var i = 0
        return values.compactMap {
            i += 1
            return ChartDataSource(source: $0, name: "St1 #\(i)", identifier: nil)
        }
    }

    static func loadStage2Data() -> [DataSource] {
        let overviewFileName = "overview.json"
        let url = dataURL
        guard let content = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
            return []
        }

        return content
            .sorted(by: { (first, second) -> Bool in
                first.lastPathComponent.compare(second.lastPathComponent) == .orderedAscending
            })
            .compactMap {
                let identifier = Int($0.lastPathComponent)
                let url = $0.appendingPathComponent(overviewFileName)
                guard
                    let data = try? Data(contentsOf: url),
                    let value = try? JSONDecoder().decode(CodableDataSource.self, from: data)
                else { return nil }
                return ChartDataSource(source: value, identifier: identifier)
            }
    }

    func zoomedData(for timestamp: Int) -> DataSource? {
        guard let identifier = self.identifier else {
            return nil
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))

        if percentage, type == .area {
            // limited to 1 week
            let (start, end) = date.weekInterval
            return limited(from: Int(start.timeIntervalSince1970 * 1000), to: Int(end.timeIntervalSince1970 * 1000))
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        let monthFolder = String(format: "%d-%02d", components.year!, components.month!)
        let dayFile = String(format: "%02d.json", components.day!)

        let url = ChartDataSource.dataURL.appendingPathComponent(String(identifier), isDirectory: true).appendingPathComponent(monthFolder, isDirectory: true).appendingPathComponent(dayFile, isDirectory: false)
        guard
            let data = try? Data(contentsOf: url),
            let value = try? JSONDecoder().decode(CodableDataSource.self, from: data)
        else { return nil }
        let zoomedDataSource = ChartDataSource(source: value, identifier: 0)
        if columns.count == zoomedDataSource?.columns.count {
            zoomedDataSource?.selectedColumnsIndexes = selectedColumnsIndexes
        }
        return zoomedDataSource
    }
}

extension ChartDataSource {
    func limited(from startTimestamp: Int, to endTimestamp: Int) -> ChartDataSource {
        let range: Range<Int> = xValues.binarySearch(element: startTimestamp) ..< xValues.binarySearch(element: endTimestamp)
        let xValues = Array(self.xValues[range])
        let columns = self.columns.map { colunm -> Column in
            let values = Array(colunm.values[range])
            return ChartColumn(name: colunm.name, color: colunm.color, values: values)
        }
        let zoomedDataSource = ChartDataSource(xValues: xValues, columns: columns, identifier: identifier, type: type, percentage: percentage, stacked: stacked)
        zoomedDataSource.selectedColumnsIndexes = selectedColumnsIndexes
        return zoomedDataSource
    }
}
