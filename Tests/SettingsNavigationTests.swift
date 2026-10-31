import Testing
@testable import AirControl

struct SettingsNavigationTests {
    @Test
    func everySettingsCategoryHasDistinctNavigationMetadata() {
        let categories = SettingsCategory.allCases

        #expect(categories.count == 6)
        #expect(Set(categories.map(\.title)).count == categories.count)
        #expect(Set(categories.map(\.symbol)).count == categories.count)
        #expect(categories.allSatisfy { !$0.subtitle.isEmpty })
    }
}
