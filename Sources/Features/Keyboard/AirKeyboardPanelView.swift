import SwiftUI

struct AirKeyboardPanelView: View {
    @ObservedObject var coordinator: AirKeyboardCoordinator
    @AppStorage("airKeyboardFeedback") private var showsFeedback = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                    Text("Air Keyboard")
                        .font(.system(.headline, design: .rounded))
                    Text(coordinator.layoutLanguage.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if showsFeedback {
                        Text(coordinator.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Button {
                        coordinator.deactivate()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide Air Keyboard")
                }
                .frame(height: 24)

                VStack(spacing: 6) {
                    ForEach(Array(coordinator.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 6) {
                            ForEach(row) { key in
                                keyButton(key)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(14)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func keyButton(_ key: AirKeyboardKey) -> some View {
        let isHighlighted = coordinator.hoveredKeyID == key.id
        return Button {
            coordinator.activateManually(key)
        } label: {
            Text(key.label)
                .font(.system(size: key.label.count > 2 ? 12 : 16, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 32)
                .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                .background(
                    isHighlighted ? Color.accentColor : Color.primary.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isHighlighted ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                }
                .scaleEffect(isHighlighted ? 1.025 : 1)
                .animation(.easeOut(duration: 0.1), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.label)
        .accessibilityIdentifier("air-key-\(key.id)")
    }
}
