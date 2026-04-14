import AppKit

/// A container that holds multiple panels in a tabbed interface within one dock area.
/// Each panel gets a tab in the header. Only one panel is visible at a time.
@available(macOS 13.0, *)
public final class PanelContainerController: NSViewController {

    let position: PanelPosition

    private struct Entry {
        let descriptor: PanelDescriptor
        let viewController: NSViewController
        var isVisible: Bool
    }

    private var panels: [Entry] = []
    private var selectedPanelId: String?

    private let headerView = NSStackView()
    private let contentArea = NSView()

    init(position: PanelPosition) {
        self.position = position
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func loadView() {
        let container = NSView()
        container.wantsLayer = true

        // Header with panel tabs
        headerView.orientation = .horizontal
        headerView.spacing = 0
        headerView.distribution = .fill
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Content area
        contentArea.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(headerView)
        container.addSubview(contentArea)

        let headerHeight: CGFloat = 28

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: container.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),

            contentArea.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            contentArea.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentArea.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentArea.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.view = container
    }

    // MARK: - Panel Management

    func addPanel(_ viewController: NSViewController, descriptor: PanelDescriptor) {
        // Guard against duplicate panel IDs
        guard !panels.contains(where: { $0.descriptor.id == descriptor.id }) else { return }

        let entry = Entry(descriptor: descriptor, viewController: viewController, isVisible: false)
        panels.append(entry)
        addChild(viewController)
        rebuildHeader()
    }

    func removePanel(id: String) {
        guard let index = panels.firstIndex(where: { $0.descriptor.id == id }) else { return }
        let entry = panels[index]
        if selectedPanelId == id {
            entry.viewController.view.removeFromSuperview()
            selectedPanelId = nil
        }
        entry.viewController.removeFromParent()
        panels.remove(at: index)
        rebuildHeader()

        // Select first available panel
        if selectedPanelId == nil, let first = panels.first(where: { $0.isVisible }) {
            selectPanel(id: first.descriptor.id)
        }
    }

    func selectPanel(id: String) {
        // Skip if already selected
        guard id != selectedPanelId else { return }

        // Only select visible panels
        guard let entry = panels.first(where: { $0.descriptor.id == id && $0.isVisible }) else { return }

        // Hide current
        if let currentId = selectedPanelId,
           let current = panels.first(where: { $0.descriptor.id == currentId }) {
            current.viewController.view.removeFromSuperview()
        }

        selectedPanelId = id

        let panelView = entry.viewController.view
        panelView.translatesAutoresizingMaskIntoConstraints = false
        contentArea.addSubview(panelView)
        NSLayoutConstraint.activate([
            panelView.topAnchor.constraint(equalTo: contentArea.topAnchor),
            panelView.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor),
        ])

        updateHeaderSelection()
    }

    /// Toggles a panel's visibility. Returns the new visibility state.
    @discardableResult
    func togglePanel(id: String) -> Bool {
        guard let index = panels.firstIndex(where: { $0.descriptor.id == id }) else { return false }
        panels[index].isVisible.toggle()
        let visible = panels[index].isVisible

        if visible {
            selectPanel(id: id)
        } else if selectedPanelId == id {
            panels[index].viewController.view.removeFromSuperview()
            selectedPanelId = nil
            // Select next visible panel
            if let next = panels.first(where: { $0.isVisible }) {
                selectPanel(id: next.descriptor.id)
            }
        }

        rebuildHeader()
        return visible
    }

    func hasPanel(id: String) -> Bool {
        return panels.contains(where: { $0.descriptor.id == id })
    }

    func isPanelVisible(id: String) -> Bool {
        return panels.first(where: { $0.descriptor.id == id })?.isVisible ?? false
    }

    var hasVisiblePanels: Bool {
        return panels.contains(where: { $0.isVisible })
    }

    // MARK: - Header

    private func rebuildHeader() {
        headerView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for entry in panels where entry.isVisible {
            let button = NSButton(title: entry.descriptor.title, target: self, action: #selector(headerTabClicked(_:)))
            button.bezelStyle = .accessoryBarAction
            button.setButtonType(.onOff)
            button.identifier = NSUserInterfaceItemIdentifier(entry.descriptor.id)
            button.state = (entry.descriptor.id == selectedPanelId) ? .on : .off
            button.font = .systemFont(ofSize: 11, weight: .medium)
            if let img = NSImage(systemSymbolName: entry.descriptor.iconSystemName, accessibilityDescription: nil) {
                button.image = img
                button.imagePosition = .imageLeading
            }
            headerView.addArrangedSubview(button)
        }

        // Spacer to push tabs left
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerView.addArrangedSubview(spacer)
    }

    private func updateHeaderSelection() {
        for case let button as NSButton in headerView.arrangedSubviews {
            button.state = (button.identifier?.rawValue == selectedPanelId) ? .on : .off
        }
    }

    @objc private func headerTabClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        selectPanel(id: id)
    }
}
