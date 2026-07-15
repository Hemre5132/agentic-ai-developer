import UIKit

/// Scroll view that lets horizontal drags take over from action buttons quickly.
private final class AIActionsScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl { return true }
        return super.touchesShouldCancel(in: view)
    }
}

/// Soft edge fade + chevron hint that the action row scrolls horizontally.
private final class ScrollEdgeAffordanceView: UIView {
    enum Edge { case leading, trailing }

    private let gradient = CAGradientLayer()
    private let chevron = UIImageView()

    init(edge: Edge) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        gradient.startPoint = edge == .leading ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 1, y: 0.5)
        gradient.endPoint = edge == .leading ? CGPoint(x: 1, y: 0.5) : CGPoint(x: 0, y: 0.5)
        layer.addSublayer(gradient)

        let symbol = edge == .trailing ? "chevron.right" : "chevron.left"
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        chevron.image = UIImage(systemName: symbol, withConfiguration: cfg)
        chevron.tintColor = UIColor.label.withAlphaComponent(0.35)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevron)

        NSLayoutConstraint.activate([
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            edge == .trailing
                ? chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)
                : chevron.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    func apply(isDark: Bool, visible: Bool) {
        alpha = visible ? 1 : 0
        let base = isDark ? UIColor.black : UIColor.white
        gradient.colors = [
            base.withAlphaComponent(0.55).cgColor,
            base.withAlphaComponent(0).cgColor,
        ]
        chevron.tintColor = (isDark ? UIColor.white : UIColor.black).withAlphaComponent(0.28)
    }
}

/// AI action strip mounted above the Apple-style keyplane (Improve / Shorten / Expand + settings).
final class KeyboardAIActionsBar: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    fileprivate let actionsScrollView = AIActionsScrollView()
    let actionsRow = UIStackView()
    let trailingHost = UIStackView()

    /// Keyboard extensions only deliver haptics when Full Access is enabled.
    var allowsScrollHaptics = false

    private let bottomHairline = UIView()
    private let leadingAffordance = ScrollEdgeAffordanceView(edge: .leading)
    private let trailingAffordance = ScrollEdgeAffordanceView(edge: .trailing)
    private let barPanGesture = UIPanGestureRecognizer()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private var panStartOffsetX: CGFloat = 0
    private var lastHapticOffsetX: CGFloat = 0
    private var lastIsDark = false

    private let contentGuide = UILayoutGuide()
    private let hapticStep: CGFloat = 56

    override init(frame: CGRect) {
        super.init(frame: frame)

        addLayoutGuide(contentGuide)
        NSLayoutConstraint.activate([
            contentGuide.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            contentGuide.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            contentGuide.topAnchor.constraint(equalTo: topAnchor),
            contentGuide.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
        ])

        actionsScrollView.delegate = self
        actionsScrollView.showsHorizontalScrollIndicator = false
        actionsScrollView.showsVerticalScrollIndicator = false
        actionsScrollView.alwaysBounceHorizontal = true
        actionsScrollView.alwaysBounceVertical = false
        actionsScrollView.canCancelContentTouches = true
        actionsScrollView.delaysContentTouches = false
        actionsScrollView.decelerationRate = .fast
        actionsScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        actionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        actionsScrollView.panGestureRecognizer.delaysTouchesBegan = false

        actionsRow.axis = .horizontal
        actionsRow.spacing = 8
        actionsRow.alignment = .center
        actionsRow.distribution = .fill
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        actionsScrollView.addSubview(actionsRow)

        NSLayoutConstraint.activate([
            actionsRow.leadingAnchor.constraint(equalTo: actionsScrollView.contentLayoutGuide.leadingAnchor),
            actionsRow.trailingAnchor.constraint(equalTo: actionsScrollView.contentLayoutGuide.trailingAnchor),
            actionsRow.topAnchor.constraint(equalTo: actionsScrollView.contentLayoutGuide.topAnchor),
            actionsRow.bottomAnchor.constraint(equalTo: actionsScrollView.contentLayoutGuide.bottomAnchor),
            actionsRow.heightAnchor.constraint(equalTo: actionsScrollView.frameLayoutGuide.heightAnchor),
        ])

        trailingHost.axis = .horizontal
        trailingHost.alignment = .center
        trailingHost.distribution = .fill
        trailingHost.spacing = 4
        trailingHost.setContentHuggingPriority(.required, for: .horizontal)
        trailingHost.setContentCompressionResistancePriority(.required, for: .horizontal)
        trailingHost.translatesAutoresizingMaskIntoConstraints = false

        for view in [actionsScrollView, leadingAffordance, trailingAffordance, trailingHost] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            actionsScrollView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            actionsScrollView.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            actionsScrollView.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            actionsScrollView.trailingAnchor.constraint(equalTo: trailingHost.leadingAnchor, constant: -4),

            trailingHost.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            trailingHost.centerYAnchor.constraint(equalTo: contentGuide.centerYAnchor),

            leadingAffordance.leadingAnchor.constraint(equalTo: actionsScrollView.leadingAnchor),
            leadingAffordance.topAnchor.constraint(equalTo: actionsScrollView.topAnchor),
            leadingAffordance.bottomAnchor.constraint(equalTo: actionsScrollView.bottomAnchor),
            leadingAffordance.widthAnchor.constraint(equalToConstant: 18),

            trailingAffordance.trailingAnchor.constraint(equalTo: actionsScrollView.trailingAnchor),
            trailingAffordance.topAnchor.constraint(equalTo: actionsScrollView.topAnchor),
            trailingAffordance.bottomAnchor.constraint(equalTo: actionsScrollView.bottomAnchor),
            trailingAffordance.widthAnchor.constraint(equalToConstant: 22),
        ])

        bottomHairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomHairline)

        NSLayoutConstraint.activate([
            bottomHairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomHairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomHairline.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomHairline.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        barPanGesture.addTarget(self, action: #selector(handleBarPan(_:)))
        barPanGesture.delegate = self
        barPanGesture.cancelsTouchesInView = false
        addGestureRecognizer(barPanGesture)

        bringSubviewToFront(trailingHost)
        bringSubviewToFront(leadingAffordance)
        bringSubviewToFront(trailingAffordance)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateScrollAffordances()
    }

    func applyDividerAppearance(isDark: Bool) {
        lastIsDark = isDark
        bottomHairline.backgroundColor = isDark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.06)
        updateScrollAffordances()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollAffordances()
        emitScrollHapticIfNeeded(for: scrollView.contentOffset.x)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastHapticOffsetX = scrollView.contentOffset.x
        if allowsScrollHaptics {
            selectionFeedback.prepare()
        }
    }

    private func updateScrollAffordances() {
        let scrollable = actionsScrollView.contentSize.width
            > actionsScrollView.bounds.width + 4
        let offsetX = actionsScrollView.contentOffset.x
        let maxOffset = max(
            0,
            actionsScrollView.contentSize.width - actionsScrollView.bounds.width + actionsScrollView.contentInset.right
        )

        leadingAffordance.apply(isDark: lastIsDark, visible: scrollable && offsetX > 4)
        trailingAffordance.apply(isDark: lastIsDark, visible: scrollable && offsetX < maxOffset - 4)
    }

    private func emitScrollHapticIfNeeded(for offsetX: CGFloat) {
        guard allowsScrollHaptics else { return }
        let scrollable = actionsScrollView.contentSize.width > actionsScrollView.bounds.width + 4
        guard scrollable else { return }
        guard abs(offsetX - lastHapticOffsetX) >= hapticStep else { return }
        lastHapticOffsetX = offsetX
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    @objc private func handleBarPan(_ gesture: UIPanGestureRecognizer) {
        let dx = gesture.translation(in: actionsScrollView).x
        let maxX = max(
            0,
            actionsScrollView.contentSize.width
                - actionsScrollView.bounds.width
                + actionsScrollView.contentInset.right
        )

        switch gesture.state {
        case .began:
            panStartOffsetX = actionsScrollView.contentOffset.x
            lastHapticOffsetX = panStartOffsetX
            if allowsScrollHaptics {
                selectionFeedback.prepare()
            }
        case .changed:
            var next = panStartOffsetX - dx
            if actionsScrollView.contentSize.width <= actionsScrollView.bounds.width + 1 {
                next = panStartOffsetX - dx * 0.35
            } else {
                next = max(0, min(next, maxX))
            }
            actionsScrollView.contentOffset.x = next
            emitScrollHapticIfNeeded(for: next)
        case .ended, .cancelled:
            if actionsScrollView.contentSize.width > actionsScrollView.bounds.width + 1 {
                let vx = gesture.velocity(in: actionsScrollView).x
                var target = actionsScrollView.contentOffset.x - vx * 0.08
                target = max(0, min(target, maxX))
                actionsScrollView.setContentOffset(CGPoint(x: target, y: 0), animated: true)
            } else {
                UIView.animate(withDuration: 0.22) {
                    self.actionsScrollView.contentOffset.x = 0
                }
            }
        default:
            break
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === barPanGesture else { return true }
        layoutIfNeeded()
        let location = barPanGesture.location(in: self)
        guard actionsScrollView.frame.contains(location), !trailingHost.frame.contains(location) else {
            return false
        }
        let pan = barPanGesture.translation(in: self)
        if abs(pan.x) > 2 { return abs(pan.x) > abs(pan.y) }
        let velocity = barPanGesture.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y) * 0.5
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
