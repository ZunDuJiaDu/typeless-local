import OSLog

public enum AppLogger {
    public static let permissions = Logger(subsystem: "WuZiApp", category: "permissions")
    public static let inputTap = Logger(subsystem: "WuZiApp", category: "inputTap")
    public static let audio = Logger(subsystem: "WuZiApp", category: "audio")
    public static let speech = Logger(subsystem: "WuZiApp", category: "speech")
    public static let overlay = Logger(subsystem: "WuZiApp", category: "overlay")
    public static let injection = Logger(subsystem: "WuZiApp", category: "injection")
    public static let llm = Logger(subsystem: "WuZiApp", category: "llm")
    public static let build = Logger(subsystem: "WuZiApp", category: "build")
}
