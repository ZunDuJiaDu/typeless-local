import OSLog

public enum AppLogger {
    public static let permissions = Logger(subsystem: "TypelessApp", category: "permissions")
    public static let inputTap = Logger(subsystem: "TypelessApp", category: "inputTap")
    public static let audio = Logger(subsystem: "TypelessApp", category: "audio")
    public static let speech = Logger(subsystem: "TypelessApp", category: "speech")
    public static let overlay = Logger(subsystem: "TypelessApp", category: "overlay")
    public static let injection = Logger(subsystem: "TypelessApp", category: "injection")
    public static let llm = Logger(subsystem: "TypelessApp", category: "llm")
    public static let build = Logger(subsystem: "TypelessApp", category: "build")
}
