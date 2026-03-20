import SwiftUI

struct PlaylistExpansionView: View {
    let metadata: PlaylistMetadata
    @Binding var items: [ExpandedSourceItem]
    let skippedItems: [ExpandedSourceItem]
    let isCreatingBatch: Bool
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onCreateBatch: () -> Void
    let onClear: () -> Void

    @State private var sortOrder: SortOrder = .default
    @State private var minDurationSeconds: Int = 0
    @State private var maxDurationSeconds: Int = 0 // 0 = no limit
    @State private var showFilters: Bool = false

    enum SortOrder: String, CaseIterable {
        case `default` = "Default"
        case titleAsc = "Title A→Z"
        case titleDesc = "Title Z→A"
        case durationAsc = "Shortest first"
        case durationDesc = "Longest first"
    }

    var body: some View {
        SectionCardView(title: "Playlist Expansion") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                headerSection
                Divider()
                controlsSection
                if showFilters { filtersSection }
                Divider()
                itemListSection
                if !skippedItems.isEmpty { skippedSection }
                actionRow
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metadata.title)
                .font(.headline)
            Text(metadata.sourceURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)

            HStack(spacing: AppTheme.Spacing.md) {
                Label("\(selectedCount) selected", systemImage: "checkmark.circle")
                Label("\(validCount) valid", systemImage: "list.bullet")
                if skippedItems.count > 0 {
                    Label("\(skippedItems.count) skipped", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let totalDuration = totalDurationText {
                    Label(totalDuration, systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Controls

    private var controlsSection: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Button(AppCopy.Buttons.selectAll, action: onSelectAll)
                .disabled(filteredValidItems.isEmpty)
            Button(AppCopy.Buttons.deselectAll, action: onDeselectAll)
                .disabled(filteredValidItems.isEmpty)

            Button("Select filtered") {
                applySelectionToFiltered(selected: true)
            }
            .disabled(filteredValidItems.isEmpty)

            Spacer()

            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .frame(maxWidth: 160)

            Button(showFilters ? "Hide filters" : "Filters…") {
                showFilters.toggle()
            }

            Button("Clear", action: onClear)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Duration filter")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Min:")
                    .font(.caption)
                    .frame(width: 28, alignment: .trailing)
                TextField("0", value: $minDurationSeconds, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text("sec")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer().frame(width: AppTheme.Spacing.md)

                Text("Max:")
                    .font(.caption)
                    .frame(width: 28, alignment: .trailing)
                TextField("0 = no limit", value: $maxDurationSeconds, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("sec")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Apply to selection") {
                    applyDurationFilter()
                }
                .font(.caption)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
    }

    // MARK: Item list

    private var itemListSection: some View {
        Group {
            if displayedItems.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "No Expandable Items",
                    message: "This playlist expansion did not produce valid entries."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        ForEach($items) { $item in
                            if shouldDisplay(item) {
                                itemRow(item: $item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
    }

    private func itemRow(item: Binding<ExpandedSourceItem>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Toggle(isOn: item.isSelected) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.wrappedValue.displayTitle)
                            .lineLimit(2)
                        if let url = item.wrappedValue.sourceURL {
                            Text(url)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let secs = item.wrappedValue.durationSeconds {
                            Text(durationText(seconds: secs))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(!item.wrappedValue.isValid)

                if !item.wrappedValue.isValid {
                    StatusBadgeView(text: "Skipped", tint: .yellow)
                }
            }
            if let reason = item.wrappedValue.skipReason {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Skipped

    private var skippedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Skipped Entries")
                .font(.subheadline.bold())
            ForEach(skippedItems.prefix(5)) { item in
                Text("• \(item.displayTitle): \(item.skipReason ?? "Unavailable")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if skippedItems.count > 5 {
                Text("+\(skippedItems.count - 5) more skipped")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Action row

    private var actionRow: some View {
        HStack {
            Button(AppCopy.Buttons.createPlaylistBatch, action: onCreateBatch)
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0 || isCreatingBatch)

            if isCreatingBatch {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Spacer()

            Text("\(selectedCount) items will be added to the batch")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Computed

    private var selectedCount: Int {
        items.filter { $0.isSelected && $0.isValid }.count
    }

    private var validCount: Int {
        items.filter(\.isValid).count
    }

    private var displayedItems: [ExpandedSourceItem] {
        sortedItems.filter { shouldDisplay($0) }
    }

    private var filteredValidItems: [ExpandedSourceItem] {
        displayedItems.filter(\.isValid)
    }

    private var sortedItems: [ExpandedSourceItem] {
        switch sortOrder {
        case .default: return items
        case .titleAsc: return items.sorted { $0.displayTitle < $1.displayTitle }
        case .titleDesc: return items.sorted { $0.displayTitle > $1.displayTitle }
        case .durationAsc:
            return items.sorted { ($0.durationSeconds ?? Int.max) < ($1.durationSeconds ?? Int.max) }
        case .durationDesc:
            return items.sorted { ($0.durationSeconds ?? -1) > ($1.durationSeconds ?? -1) }
        }
    }

    private var totalDurationText: String? {
        let selectedDurations = items.filter { $0.isSelected && $0.isValid }.compactMap(\.durationSeconds)
        guard !selectedDurations.isEmpty else { return nil }
        let total = selectedDurations.reduce(0, +)
        return "~\(durationText(seconds: total)) total"
    }

    private func shouldDisplay(_ item: ExpandedSourceItem) -> Bool {
        guard let duration = item.durationSeconds else { return true }
        if minDurationSeconds > 0, duration < minDurationSeconds { return false }
        if maxDurationSeconds > 0, duration > maxDurationSeconds { return false }
        return true
    }

    private func applySelectionToFiltered(selected: Bool) {
        let ids = Set(filteredValidItems.map(\.id))
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isSelected = selected
        }
    }

    private func applyDurationFilter() {
        for index in items.indices {
            guard items[index].isValid else { continue }
            items[index].isSelected = shouldDisplay(items[index])
        }
    }

    private func durationText(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
