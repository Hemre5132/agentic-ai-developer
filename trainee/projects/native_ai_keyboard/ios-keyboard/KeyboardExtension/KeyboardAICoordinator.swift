import UIKit

/// AI rewrite toolbar, status row, and preview overlay — separated from keyplane rendering.
final class KeyboardAICoordinator {
    weak var controller: KeyboardViewController?

    let toolbar = KeyboardToolbarView()
    let statusRow = KeyboardStatusRowView()
    let previewZone = KeyboardPreviewOverlayView()

    private var pendingRewriteFromTouchDown: (text: String, snapshot: RewriteSnapshot)?
    /// Mode + source text that produced the current preview (updated on bar chain; stable on regenerate).
    private var lastTransform: (mode: RewriteMode, text: String, snapshot: RewriteSnapshot)?
    /// Field snapshot to apply Confirm against — kept across chained bar presses while dialog is open.
    private var applySnapshot: RewriteSnapshot?
    private var isTransformInFlight = false
    private var previewHeightConstraint: NSLayoutConstraint?
    private var statusHeightConstraint: NSLayoutConstraint?
    private var toolbarHeightConstraint: NSLayoutConstraint?

    private var sessionPollTimer: Timer?
    private var settingsObserver: AppGroupSettingsObserverToken?
    private var lastChromeIsDark: Bool?

    var chromeToolbarAnchor: UIView { toolbar }

    // MARK: - Install

    func install(
        on parent: UIView,
        keyplane: UIView,
        toolbarDesignHeight: CGFloat
    ) -> (toolbarHeight: NSLayoutConstraint?, statusHeight: NSLayoutConstraint?, previewHeight: NSLayoutConstraint?) {
        buildPreviewContent()
        buildAIActions()
        buildStatusRow()
        buildToolbarChrome()

        let constraints = KeyboardRootViewLayout.install(
            on: parent,
            toolbarRow: toolbar,
            statusRow: statusRow,
            keyContainer: keyplane,
            previewOverlay: previewZone,
            toolbarDesignHeight: toolbarDesignHeight
        )

        toolbarHeightConstraint = constraints.toolbarHeight
        statusHeightConstraint = constraints.statusHeight
        previewHeightConstraint = constraints.previewHeight
        setPreviewVisible(false, animated: false)
        updateStatusVisibility()
        return (constraints.toolbarHeight, constraints.statusHeight, constraints.previewHeight)
    }

    func startObserving() {
        settingsObserver = AppGroupSettingsNotifier.observe { [weak self] in
            self?.syncFromAppGroup()
        }
        sessionPollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshOpenAppButton()
            self?.syncScrollHapticsAccess()
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionPollTimer = timer
        refreshOpenAppButton()
        syncFromAppGroup()
        refreshActionAvailability()
        syncScrollHapticsAccess()
    }

    func stopObserving() {
        sessionPollTimer?.invalidate()
        sessionPollTimer = nil
        settingsObserver = nil
    }

    private func syncScrollHapticsAccess() {
        toolbar.aiBar.allowsScrollHaptics = controller?.hasFullAccess ?? false
    }

    // MARK: - Appearance

    func applyAppearance(isDark: Bool) {
        lastChromeIsDark = isDark
        statusRow.statusLabel.textColor = isDark ? .lightGray : .darkGray
        toolbar.applyDividerAppearance(isDark: isDark)
        applyPreviewColors(isDark: isDark)
        refreshActionButtonChrome(isDark: isDark)
        refreshAccents()
    }

    func refreshActionButtonChrome(isDark: Bool) {
        lastChromeIsDark = isDark
        let accent = AppGroupStore.shared.keyboardChromeAccent.uiColor
        let fill = accent.withAlphaComponent(isDark ? 0.16 : 0.10)
        let stroke = accent.withAlphaComponent(isDark ? 0.45 : 0.32)

        for button in toolbar.actionsRow.arrangedSubviews.compactMap({ $0 as? UIButton }) {
            guard var cfg = button.configuration else { continue }
            cfg.baseForegroundColor = accent
            cfg.background.backgroundColor = fill
            cfg.background.cornerRadius = 16
            cfg.background.strokeWidth = 1
            cfg.background.strokeColor = stroke
            button.configuration = cfg
            button.backgroundColor = .clear
        }
    }

    func applyToolbarChromeBackground(_ color: UIColor) {
        toolbar.backgroundColor = color
        toolbar.aiBar.backgroundColor = color
    }

    func syncFromAppGroup() {
        rebuildAIActionsIfNeeded()
        if !AppGroupStore.shared.aiPreviewBeforeApply {
            hidePreview()
        }
        refreshOpenAppButton()
        refreshAccents()
        refreshActionAvailability()
        controller?.chromeOptionsPresenter?.rebuildIfVisible()
    }

    func refreshActionAvailability() {
        let hasText = controller?.hasRewriteText() ?? false
        for button in toolbar.actionsRow.arrangedSubviews.compactMap({ $0 as? UIButton }) {
            button.isEnabled = hasText
            button.alpha = hasText ? 1 : 0.42
        }
    }

    private func rebuildAIActionsIfNeeded() {
        let expectedCount = 4
        if toolbar.actionsRow.arrangedSubviews.count == expectedCount {
            refreshActionTitles()
            refreshActionAvailability()
            return
        }
        toolbar.actionsRow.arrangedSubviews.forEach { view in
            toolbar.actionsRow.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buildAIActions()
        refreshActionAvailability()
        let isDark = lastChromeIsDark ?? (toolbar.traitCollection.userInterfaceStyle == .dark)
        refreshActionButtonChrome(isDark: isDark)
    }

    func refreshAccents() {
        let accent = AppGroupStore.shared.keyboardChromeAccent.uiColor
        statusRow.openAppButton.tintColor = accent
        var ocfg = statusRow.openAppButton.configuration
        ocfg?.baseForegroundColor = accent
        statusRow.openAppButton.configuration = ocfg

        if var ac = previewZone.applyButton.configuration {
            ac.baseBackgroundColor = accent
            ac.cornerStyle = .fixed
            ac.background.cornerRadius = keyCornerRadius
            previewZone.applyButton.configuration = ac
        }
        let radius = keyCornerRadius
        let isDarkForIcons = lastChromeIsDark ?? (toolbar.traitCollection.userInterfaceStyle == .dark)
        let iconFill = accent.withAlphaComponent(isDarkForIcons ? 0.16 : 0.10)
        let iconStroke = accent.withAlphaComponent(isDarkForIcons ? 0.40 : 0.28)
        for button in [previewZone.closeButton, previewZone.copyButton, previewZone.regenerateButton] {
            guard var cfg = button.configuration else { continue }
            cfg.baseForegroundColor = accent
            cfg.background.backgroundColor = iconFill
            cfg.background.strokeColor = iconStroke
            cfg.background.cornerRadius = radius
            button.configuration = cfg
        }

        let accentColor = accent
        for button in toolbar.plusButtonHost.arrangedSubviews.compactMap({ $0 as? UIButton }) {
            button.tintColor = accentColor
        }

        let isDark = lastChromeIsDark ?? (toolbar.traitCollection.userInterfaceStyle == .dark)
        refreshActionButtonChrome(isDark: isDark)
        controller?.refreshKeyboardAccentChrome()
    }

    func fitToolbar(height: CGFloat) {
        toolbarHeightConstraint?.constant = height
    }

    /// Matches letter-key corner radius from `AppleKeyboardMetrics` (~4–6 pt).
    private var keyCornerRadius: CGFloat {
        let width = controller?.view.bounds.width ?? UIScreen.main.bounds.width
        return AppleKeyboardMetrics.resolve(width: max(320, width)).cornerRadius
    }

    // MARK: - Localization

    func localize(_ key: String) -> String {
        let code = AppGroupStore.shared.keyboardChromeStringsLanguageCode
        let main = Bundle(for: KeyboardAICoordinator.self)
        if let path = main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            let s = NSLocalizedString(key, tableName: nil, bundle: bundle, value: "\u{1}", comment: "")
            if s != "\u{1}" { return s }
        }
        if let path = main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    // MARK: - AI actions

    private func buildAIActions() {
        let items: [(String, String, RewriteMode)] = [
            ("checkmark.seal", "keyboard.action_grammar", .proofread),
            ("wand.and.stars", "keyboard.action_improve", .rewrite),
            ("arrow.down.forward.and.arrow.up.backward", "keyboard.action_shorten", .shorten),
            ("arrow.up.backward.and.arrow.down.forward", "keyboard.action_expand", .expand),
        ]
        for (symbol, key, mode) in items {
            let button = makeActionButton(symbol: symbol, titleKey: key)
            button.addAction(UIAction { [weak self] _ in self?.runTransform(mode: mode) }, for: .touchUpInside)
            toolbar.actionsRow.addArrangedSubview(button)
        }
        toolbar.aiBar.setNeedsLayout()
    }

    private func makeActionButton(symbol: String, titleKey: String) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.image = symbolImage(symbol)
        cfg.title = localize(titleKey)
        cfg.imagePlacement = .leading
        cfg.imagePadding = 5
        cfg.titleLineBreakMode = .byTruncatingTail
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        cfg.background.cornerRadius = 16
        cfg.background.strokeWidth = 1
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13, weight: .semibold)
            return out
        }
        let button = UIButton(configuration: cfg)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(rewriteTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(rewriteTouchCancel), for: [.touchUpOutside, .touchCancel])
        return button
    }

    private func symbolImage(_ name: String, pointSize: CGFloat = 14) -> UIImage {
        let fallback: String = switch name {
        case "checkmark.seal": "✓"
        case "wand.and.stars": "✦"
        case "arrow.down.forward.and.arrow.up.backward": "S"
        case "arrow.up.backward.and.arrow.down.forward": "X"
        case "doc.on.doc": "C"
        case "arrow.clockwise": "R"
        case "xmark.circle.fill", "xmark": "×"
        case "slider.horizontal.3": "≡"
        default: "•"
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        if let img = UIImage(systemName: name, withConfiguration: cfg) {
            return img.withRenderingMode(.alwaysTemplate)
        }
        let size = CGSize(width: 22, height: 22)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.label,
            ]
            let str = fallback as NSString
            let ts = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2), withAttributes: attrs)
        }.withRenderingMode(.alwaysTemplate)
    }

    private func refreshActionTitles() {
        let items: [(String, String)] = [
            ("checkmark.seal", "keyboard.action_grammar"),
            ("wand.and.stars", "keyboard.action_improve"),
            ("arrow.down.forward.and.arrow.up.backward", "keyboard.action_shorten"),
            ("arrow.up.backward.and.arrow.down.forward", "keyboard.action_expand"),
        ]
        let buttons = toolbar.actionsRow.arrangedSubviews.compactMap { $0 as? UIButton }
        for (i, button) in buttons.enumerated() where i < items.count {
            var cfg = button.configuration
            cfg?.title = localize(items[i].1)
            cfg?.image = symbolImage(items[i].0)
            button.configuration = cfg
        }
        previewZone.titleLabel.text = localize("keyboard.result_preview_title")
        previewZone.closeButton.accessibilityLabel = localize("keyboard.close_preview")
        previewZone.copyButton.accessibilityLabel = localize("keyboard.copy_result")
        previewZone.regenerateButton.accessibilityLabel = localize("keyboard.regenerate_result")
        var apply = previewZone.applyButton.configuration
        apply?.title = localize("keyboard.apply_result")
        previewZone.applyButton.configuration = apply
    }

    private func buildToolbarChrome() {
        let settings = UIButton(type: .system)
        let sym = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        settings.setImage(UIImage(systemName: "slider.horizontal.3", withConfiguration: sym), for: .normal)
        settings.tintColor = AppGroupStore.shared.keyboardChromeAccent.uiColor
        settings.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 0)
        settings.accessibilityLabel = localize("keyboard.chrome_more_accessibility")
        settings.addAction(UIAction { [weak self] _ in
            self?.controller?.toggleChromeOptionsPanel()
        }, for: .touchUpInside)
        toolbar.plusButtonHost.addArrangedSubview(settings)
    }

    // MARK: - Status + preview

    private func buildStatusRow() {
        statusRow.statusLabel.font = .preferredFont(forTextStyle: .caption2)
        var cfg = UIButton.Configuration.bordered()
        cfg.title = localize("keyboard.tap_open_app")
        cfg.baseForegroundColor = AppGroupStore.shared.keyboardChromeAccent.uiColor
        cfg.buttonSize = .mini
        cfg.cornerStyle = .capsule
        statusRow.openAppButton.configuration = cfg
        statusRow.openAppButton.addAction(UIAction { [weak self] _ in
            self?.controller?.openHostAppForSessionRefresh()
        }, for: .touchUpInside)
    }

    private func buildPreviewContent() {
        let outer = UIStackView()
        outer.axis = .vertical
        outer.spacing = 8
        outer.translatesAutoresizingMaskIntoConstraints = false
        previewZone.addSubview(outer)

        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: previewZone.leadingAnchor, constant: 12),
            outer.trailingAnchor.constraint(equalTo: previewZone.trailingAnchor, constant: -12),
            outer.topAnchor.constraint(equalTo: previewZone.topAnchor, constant: 10),
            outer.bottomAnchor.constraint(equalTo: previewZone.bottomAnchor, constant: -10),
        ])

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 8
        previewZone.titleLabel.text = localize("keyboard.result_preview_title")
        previewZone.titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let radius = keyCornerRadius
        let isDark = lastChromeIsDark ?? (toolbar.traitCollection.userInterfaceStyle == .dark)
        let accent = AppGroupStore.shared.keyboardChromeAccent.uiColor
        let iconFill = accent.withAlphaComponent(isDark ? 0.16 : 0.10)
        let iconStroke = accent.withAlphaComponent(isDark ? 0.40 : 0.28)

        func makeIconButton(symbol: String) -> UIButton.Configuration {
            var cfg = UIButton.Configuration.plain()
            cfg.image = symbolImage(symbol, pointSize: 11)
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
            cfg.baseForegroundColor = accent
            cfg.background.backgroundColor = iconFill
            cfg.background.cornerRadius = radius
            cfg.background.strokeWidth = 1
            cfg.background.strokeColor = iconStroke
            return cfg
        }

        previewZone.closeButton.configuration = makeIconButton(symbol: "xmark")
        previewZone.closeButton.accessibilityLabel = localize("keyboard.close_preview")
        previewZone.closeButton.addAction(UIAction { [weak self] _ in self?.hidePreview() }, for: .touchUpInside)
        previewZone.closeButton.setContentHuggingPriority(.required, for: .horizontal)

        titleRow.addArrangedSubview(previewZone.titleLabel)
        titleRow.addArrangedSubview(previewZone.closeButton)

        previewZone.textView.isScrollEnabled = true
        previewZone.textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        previewZone.textView.layer.cornerRadius = radius
        previewZone.textView.clipsToBounds = true
        previewZone.textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

        previewZone.copyButton.configuration = makeIconButton(symbol: "doc.on.doc")
        previewZone.copyButton.accessibilityLabel = localize("keyboard.copy_result")
        previewZone.copyButton.addAction(UIAction { [weak self] _ in self?.copyPreviewText() }, for: .touchUpInside)

        previewZone.regenerateButton.configuration = makeIconButton(symbol: "arrow.clockwise")
        previewZone.regenerateButton.accessibilityLabel = localize("keyboard.regenerate_result")
        previewZone.regenerateButton.addAction(UIAction { [weak self] _ in self?.regeneratePreview() }, for: .touchUpInside)

        var apply = UIButton.Configuration.filled()
        apply.title = localize("keyboard.apply_result")
        apply.cornerStyle = .fixed
        apply.background.cornerRadius = radius
        apply.buttonSize = .small
        apply.baseBackgroundColor = accent
        apply.baseForegroundColor = .white
        previewZone.applyButton.configuration = apply
        previewZone.applyButton.addAction(UIAction { [weak self] _ in self?.applyPreview() }, for: .touchUpInside)
        previewZone.applyButton.setContentHuggingPriority(.required, for: .horizontal)

        outer.addArrangedSubview(titleRow)
        outer.addArrangedSubview(previewZone.textView)
        outer.addArrangedSubview(previewZone.buttonRow)
    }

    private func applyPreviewColors(isDark: Bool) {
        let palette = KeyboardNativePalette.colors(isDark: isDark)
        previewZone.backgroundColor = palette.previewPanel
        previewZone.titleLabel.textColor = palette.primaryText
        previewZone.textView.backgroundColor = palette.previewField
        previewZone.textView.textColor = palette.primaryText

        let radius = keyCornerRadius
        previewZone.textView.layer.cornerRadius = radius

        let accent = AppGroupStore.shared.keyboardChromeAccent.uiColor
        let iconFill = accent.withAlphaComponent(isDark ? 0.16 : 0.10)
        let iconStroke = accent.withAlphaComponent(isDark ? 0.40 : 0.28)
        for button in [previewZone.closeButton, previewZone.copyButton, previewZone.regenerateButton] {
            guard var cfg = button.configuration else { continue }
            cfg.background.backgroundColor = iconFill
            cfg.background.strokeColor = iconStroke
            cfg.background.cornerRadius = radius
            cfg.baseForegroundColor = accent
            button.configuration = cfg
        }
        if var apply = previewZone.applyButton.configuration {
            apply.cornerStyle = .fixed
            apply.background.cornerRadius = radius
            apply.baseBackgroundColor = accent
            previewZone.applyButton.configuration = apply
        }
    }

    private func refreshOpenAppButton() {
        let need = !AppGroupStore.shared.isSessionValid()
        statusRow.openAppButton.isHidden = !need
        var cfg = statusRow.openAppButton.configuration
        cfg?.title = localize("keyboard.tap_open_app")
        statusRow.openAppButton.configuration = cfg
        updateStatusVisibility()
    }

    private func updateStatusVisibility() {
        let hasText = !(statusRow.statusLabel.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let show = hasText || !statusRow.openAppButton.isHidden
        statusRow.isHidden = !show
        statusHeightConstraint?.constant = show ? 22 : 0
    }

    private func setPreviewVisible(_ visible: Bool, animated: Bool) {
        previewZone.isHidden = !visible
        previewHeightConstraint?.constant = visible ? 218 : 0
        if animated {
            previewZone.superview?.layoutIfNeeded()
        }
    }

    func hidePreview() {
        previewZone.textView.text = ""
        setPreviewVisible(false, animated: true)
        controller?.clearPendingApplySnapshot()
        applySnapshot = nil
        updateRegenerateAvailability()
    }

    private func showPreview(with text: String) {
        guard AppGroupStore.shared.aiPreviewBeforeApply else { return }
        previewZone.textView.text = text
        setPreviewVisible(true, animated: true)
        updateRegenerateAvailability()
    }

    private func applyPreview() {
        guard let controller else { return }
        controller.applyPreviewResult(previewZone.textView.text ?? "")
        previewZone.textView.text = ""
        setPreviewVisible(false, animated: true)
        statusRow.statusLabel.text = ""
        updateStatusVisibility()
        applySnapshot = nil
        updateRegenerateAvailability()
    }

    private func copyPreviewText() {
        let text = previewZone.textView.text ?? ""
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        statusRow.statusLabel.text = localize("keyboard.copied")
        updateStatusVisibility()
    }

    private func regeneratePreview() {
        guard !isTransformInFlight, let last = lastTransform else { return }
        let previous = previewZone.textView.text ?? ""
        runTransform(
            mode: last.mode,
            sourceText: last.text,
            snapshot: last.snapshot,
            previousOutput: previous.isEmpty ? nil : previous,
            isRegenerate: true
        )
    }

    private func updateRegenerateAvailability() {
        let can = lastTransform != nil && !previewZone.isHidden && !isTransformInFlight
        previewZone.regenerateButton.isEnabled = can
        previewZone.regenerateButton.alpha = can ? 1 : 0.42
        let hasText = !(previewZone.textView.text ?? "").isEmpty
        previewZone.copyButton.isEnabled = hasText && !isTransformInFlight
        previewZone.copyButton.alpha = (hasText && !isTransformInFlight) ? 1 : 0.42
    }

    // MARK: - Rewrite

    @objc private func rewriteTouchDown() {
        pendingRewriteFromTouchDown = controller?.rewriteContext()
    }

    @objc private func rewriteTouchCancel() {
        pendingRewriteFromTouchDown = nil
    }

    private func runTransform(mode: RewriteMode) {
        guard !isTransformInFlight else { return }

        let previewVisible = !previewZone.isHidden
        let suggestion = (previewZone.textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Chain: while dialog is open, next bar press transforms the current suggestion.
        if previewVisible, !suggestion.isEmpty, let snap = applySnapshot ?? lastTransform?.snapshot {
            runTransform(
                mode: mode,
                sourceText: suggestion,
                snapshot: snap,
                previousOutput: nil,
                isRegenerate: false,
                preserveApplySnapshot: true
            )
            return
        }

        let touchDown = pendingRewriteFromTouchDown
        pendingRewriteFromTouchDown = nil
        guard let controller else { return }
        let live = controller.rewriteContext()
        let locked = KeyboardActionService.mergeRewriteContexts(touchDown: touchDown, live: live)
        let lockedText = locked.0.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lockedText.isEmpty else { return }

        runTransform(
            mode: mode,
            sourceText: lockedText,
            snapshot: locked.1,
            previousOutput: nil,
            isRegenerate: false,
            preserveApplySnapshot: false
        )
    }

    private func runTransform(
        mode: RewriteMode,
        sourceText: String,
        snapshot: RewriteSnapshot,
        previousOutput: String?,
        isRegenerate: Bool,
        preserveApplySnapshot: Bool = true
    ) {
        guard let controller else { return }
        guard !isTransformInFlight else { return }

        guard KeyboardExtensionFullAccess.allowsNetwork(for: controller.hasFullAccess) else {
            statusRow.statusLabel.text = localize("keyboard.ai_need_full_access")
            updateStatusVisibility()
            return
        }

        let lockedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lockedText.isEmpty else { return }

        guard AppGroupStore.shared.isSessionValid() else {
            statusRow.statusLabel.text = localize("keyboard.open_host")
            updateStatusVisibility()
            refreshOpenAppButton()
            return
        }

        controller.clearPendingApplySnapshot()
        if !isRegenerate && !preserveApplySnapshot {
            hidePreview()
            applySnapshot = snapshot
        } else if applySnapshot == nil {
            applySnapshot = snapshot
        }

        // Regenerate keeps the original source; chained bar presses update source to the suggestion.
        if isRegenerate {
            // lastTransform.source stays as the original request text
        } else {
            lastTransform = (mode: mode, text: lockedText, snapshot: applySnapshot ?? snapshot)
        }

        isTransformInFlight = true
        updateRegenerateAvailability()

        let workingKey: String
        if isRegenerate {
            workingKey = "keyboard.working_regenerate"
        } else {
            workingKey = switch mode {
            case .proofread: "keyboard.working_grammar"
            case .rewrite: "keyboard.working_improve"
            case .shorten: "keyboard.working_shorten"
            case .expand: "keyboard.working_expand"
            }
        }
        statusRow.statusLabel.text = localize(workingKey)
        updateStatusVisibility()

        let style = AppGroupStore.shared.conversationStyle
        // Regenerate always uses the original source from lastTransform.
        let textForAPI: String
        let modeForAPI: RewriteMode
        if isRegenerate, let last = lastTransform {
            textForAPI = last.text
            modeForAPI = last.mode
        } else {
            textForAPI = lockedText
            modeForAPI = mode
        }
        let snap = applySnapshot ?? snapshot
        let prev = previousOutput

        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                guard let self, let controller = self.controller else { return }

                if AppConfig.usesSupabaseTransform,
                   AppGroupStore.shared.deviceTransformToken?.isEmpty ?? true
                {
                    do {
                        try await SupabaseDeviceAPI.registerForceRefresh()
                    } catch {
                        self.isTransformInFlight = false
                        self.updateRegenerateAvailability()
                        self.statusRow.statusLabel.text = KeyboardExtensionL10n.userFacingError(error)
                        self.updateStatusVisibility()
                        return
                    }
                }

                do {
                    let out = try await RewriteAPI.rewrite(
                        text: textForAPI,
                        mode: modeForAPI,
                        style: style,
                        previousOutput: prev
                    )
                    if AppGroupStore.shared.aiPreviewBeforeApply {
                        controller.setPendingApplySnapshot(snap)
                        self.showPreview(with: out)
                        self.statusRow.statusLabel.text = self.localize("keyboard.preview_ready")
                    } else {
                        controller.applyRewrite(result: out, snapshot: snap)
                        self.statusRow.statusLabel.text = self.localize("keyboard.done")
                        self.applySnapshot = nil
                    }
                    self.isTransformInFlight = false
                    self.updateRegenerateAvailability()
                    self.updateStatusVisibility()
                    self.refreshOpenAppButton()
                } catch {
                    self.isTransformInFlight = false
                    self.updateRegenerateAvailability()
                    self.statusRow.statusLabel.text = KeyboardExtensionL10n.userFacingError(error)
                    self.updateStatusVisibility()
                }
            }
        }
    }
}
