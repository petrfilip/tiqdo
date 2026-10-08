import Foundation

let defaults = UserDefaults.standard
let prefix = "tiqdo-test-\(UUID().uuidString)"
let oldDomain = "\(prefix).old"
let newDomain = "\(prefix).new"
defer {
    defaults.removePersistentDomain(forName: oldDomain)
    defaults.removePersistentDomain(forName: newDomain)
}

PersistenceManager.migratePreferences(defaults: defaults, from: oldDomain, to: newDomain)
assert(defaults.persistentDomain(forName: newDomain)?.isEmpty != false)

let oldTasks = Data("legacy tasks".utf8)
defaults.setPersistentDomain(["tiqdo.appearance": "dark", "tiqdo.tasks": oldTasks], forName: oldDomain)
PersistenceManager.migratePreferences(defaults: defaults, from: oldDomain, to: newDomain)
let migrated = defaults.persistentDomain(forName: newDomain)
assert(migrated?["tiqdo.appearance"] as? String == "dark")
assert(migrated?["tiqdo.tasks"] as? Data == oldTasks)
assert(defaults.persistentDomain(forName: oldDomain)?["tiqdo.tasks"] as? Data == oldTasks)

defaults.setPersistentDomain(["tiqdo.appearance": "light"], forName: newDomain)
PersistenceManager.migratePreferences(defaults: defaults, from: oldDomain, to: newDomain)
assert(defaults.persistentDomain(forName: newDomain)?["tiqdo.appearance"] as? String == "light")
assert(defaults.persistentDomain(forName: newDomain)?["tiqdo.tasks"] == nil)

print("Preference migration checks passed")
