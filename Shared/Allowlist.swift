#if os(iOS)
import FamilyControls
import Foundation
import ManagedSettings

/// What stays open during a session, shared by the app and the shield extensions.
///
/// Shields can only exempt single apps, and the picker doesn't reliably hand back the
/// apps inside a picked category. So the shield fills them in: when it comes up over an
/// app whose category is on the allowlist, it remembers that app and lifts the shield.
/// After that first time the app stays open in every session.
enum Allowlist {
    private static let key = "allowlist"
    private static let learnedKey = "allowlist.learned"

    /// An app met on the shield, with the allowed category it belongs to.
    private struct Learned: Codable, Hashable {
        var app: ApplicationToken
        var category: ActivityCategoryToken
    }

    /// The picker's selection. Opens in whole-category mode so a picked category
    /// brings back its apps whenever the picker does.
    static var selection: FamilyActivitySelection {
        get {
            var sel = FamilyActivitySelection(includeEntireCategory: true)
            if let data = Shared.defaults.data(forKey: key),
               let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                sel.applicationTokens = saved.applicationTokens
                sel.categoryTokens = saved.categoryTokens
                sel.webDomainTokens = saved.webDomainTokens
            }
            return sel
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                Shared.defaults.set(data, forKey: key)
            }
        }
    }

    private static var learned: Set<Learned> {
        get {
            guard let data = Shared.defaults.data(forKey: learnedKey) else { return [] }
            return (try? JSONDecoder().decode(Set<Learned>.self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                Shared.defaults.set(data, forKey: learnedKey)
            }
        }
    }

    /// Picked apps plus the apps learned from categories that are still picked.
    static var openApps: Set<ApplicationToken> {
        let sel = selection
        let fromCategories = learned.filter { sel.categoryTokens.contains($0.category) }.map(\.app)
        return sel.applicationTokens.union(fromCategories)
    }

    /// Remembers `app` if its category is on the allowlist. Returns whether it should stay open.
    @discardableResult
    static func learn(_ app: ApplicationToken?, in category: ActivityCategoryToken?) -> Bool {
        guard let app, let category, selection.categoryTokens.contains(category) else { return false }
        learned.insert(Learned(app: app, category: category))
        return true
    }

    /// Shields everything except what stays open.
    static func shield(_ store: ManagedSettingsStore) {
        store.shield.applicationCategories = .all(except: openApps)
        store.shield.webDomainCategories = .all(except: selection.webDomainTokens)
    }
}
#endif
