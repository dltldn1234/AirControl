import SwiftUI

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.title, systemImage: category.symbol)
                    .tag(category)
                    .accessibilityHint(category.subtitle)
            }
            .listStyle(.sidebar)
            .navigationTitle("AirControl")
            .frame(minWidth: 170)
        } detail: {
            VStack(alignment: .leading, spacing: AirSettingsMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCategory.title)
                        .font(.title2.weight(.semibold))
                    Text(selectedCategory.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AirSettingsMetrics.contentInset)
                .padding(.top, AirSettingsMetrics.contentInset)

                SettingsCategoryForm(category: selectedCategory)
                    .padding(.horizontal, AirSettingsMetrics.contentInset)
            }
            .frame(minWidth: 480, minHeight: 420)
            .background(AirSettingsColors.canvas)
            .animation(.easeInOut(duration: 0.16), value: selectedCategory)
        }
        .frame(minWidth: 680, minHeight: 500)
    }
}
