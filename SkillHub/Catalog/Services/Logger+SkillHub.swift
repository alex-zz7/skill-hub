import os

nonisolated extension Logger {
    static let subsystem = "dev.lucy.SkillHub"

    static let access = Logger(subsystem: subsystem, category: "access")
    static let catalog = Logger(subsystem: subsystem, category: "catalog")
    static let meta = Logger(subsystem: subsystem, category: "meta")
}
