import AppKit

if let bundleID = Bundle.main.bundleIdentifier {
    PersistenceManager.migratePreferences(defaults: .standard, from: "cz.fg.tiqdo", to: bundleID)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
