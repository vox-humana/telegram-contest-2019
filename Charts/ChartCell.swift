import UIKit

class ChartCell: UITableViewCell, Themable {
    func apply(_ theme: Theme) {
        contentView.backgroundColor = theme.mainBackgroundColor
        backgroundColor = theme.mainBackgroundColor
        containerView.apply(theme)
    }

    let containerView = ChartContainerView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        containerView.prepareForReuse()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.frame = contentView.bounds
    }
}
