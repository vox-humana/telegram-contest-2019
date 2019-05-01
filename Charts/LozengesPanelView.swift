import UIKit

class LozengeButton: UIButton {
    typealias UIButtonAction = (UIButton) -> Void
    var action: UIButtonAction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleAction), for: .touchUpInside)
        titleLabel?.font = UIFont.lozengeButtonFont
        setImage(#imageLiteral(resourceName: "checkmark.png"), for: .selected)
        setImage(nil, for: .normal)
        tintColor = .white
        imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 5)
        titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var color: UIColor = .green {
        didSet {
            layer.cornerRadius = 6
            layer.borderWidth = 1
            layer.borderColor = color.cgColor
        }
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                backgroundColor = color
                setTitleColor(.white, for: .normal)
            } else {
                backgroundColor = .clear
                setTitleColor(color, for: .normal)
            }
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let buttonSize = titleLabel?.sizeThatFits(size) ?? .zero
        return CGSize(width: buttonSize.width + 42, height: buttonSize.height + 14)
    }

    @objc private func handleAction() {
        action?(self)
    }
}

class LozengesPanelView: UIView {
    var tagViews: [UIView] = [] {
        didSet {
            oldValue.forEach { $0.removeFromSuperview() }
            tagViews.forEach {
                $0.sizeToFit()
                addSubview($0)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        LozengesPanelView.tagLayout(views: tagViews, in: bounds.inset(by: UIEdgeInsets(top: Constants.buttonsPanelHPadding, left: 0, bottom: 0, right: 0)))
    }

    @discardableResult static func tagLayout(views: [UIView], in rect: CGRect) -> CGFloat {
        let offset: CGFloat = 8
        var origin: CGPoint = rect.origin
        for view in views {
            let viewSize = view.bounds.size
            if (origin.x + viewSize.width) > rect.maxX {
                origin.y += viewSize.height + offset
                origin.x = rect.origin.x
                view.frame = CGRect(origin: origin, size: viewSize)
            } else {
                view.frame = CGRect(origin: origin, size: viewSize)
            }
            origin.x += viewSize.width + offset
        }
        let lastRowHeight = views.last?.bounds.height ?? 0
        return origin.y + lastRowHeight
    }
}
