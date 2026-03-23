import Foundation

enum AppLanguage: String, CaseIterable {
    case en = "en"
    case zh = "zh"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        }
    }
}

enum L10n {
    static var lang: AppLanguage { SettingsStore.shared.language }

    static var asrApiHeader: String { lang == .zh ? "豆包 ASR API" : "Doubao ASR API" }
    static var testConnection: String { lang == .zh ? "测试连接" : "Test Connection" }
    static var connecting: String { lang == .zh ? "连接中..." : "Connecting..." }
    static var punctuationHeader: String { lang == .zh ? "标点展示" : "Punctuation" }
    static var punctSpaceReplace: String { lang == .zh ? "空格代替标点" : "Replace with spaces" }
    static var punctRemoveTrailing: String { lang == .zh ? "句末不加标点" : "Remove trailing" }
    static var punctKeepAll: String { lang == .zh ? "保留所有标点" : "Keep all" }
    static var spacingHeader: String { lang == .zh ? "数字、英文展示" : "Number / English spacing" }
    static var spacingNone: String { lang == .zh ? "前后无空格" : "No spaces" }
    static var spacingAdd: String { lang == .zh ? "前后加空格" : "Add spaces" }
    static var usageHeader: String { lang == .zh ? "使用方法" : "Usage" }
    static var usageText: String {
        lang == .zh
            ? "按住 **fn** 键开始录音，识别结果实时插入光标处。\n松开 **fn** 键停止录音。"
            : "Hold **fn** to record, text is inserted at cursor in real time.\nRelease **fn** to stop."
    }
    static var usageTip: String {
        lang == .zh
            ? "提示：在系统设置 → 键盘中，将「按下🌐键时」设为「不执行任何操作」以获得最佳体验。"
            : "Tip: In System Settings \u{2192} Keyboard, set \"Press \u{1F310} key to\" \u{2192} \"Do Nothing\" for best experience."
    }
    static var resourceHourly20: String { lang == .zh ? "2.0 小时版" : "2.0 Hourly" }
    static var resourceConcurrent20: String { lang == .zh ? "2.0 并发版" : "2.0 Concurrent" }
    static var resourceHourly10: String { lang == .zh ? "1.0 小时版" : "1.0 Hourly" }
    static var resourceConcurrent10: String { lang == .zh ? "1.0 并发版" : "1.0 Concurrent" }
    static var languageHeader: String { lang == .zh ? "语言" : "Language" }
    static var getKey: String { lang == .zh ? "获取 Key" : "Get Key" }
    static var listening: String { lang == .zh ? "正在倾听" : "Listening" }
    static var keepOriginal: String { lang == .zh ? "保持原样" : "Keep original" }

    // Menu bar
    static var menuSettings: String { lang == .zh ? "设置…" : "Settings…" }
    static var menuHoldFn: String { lang == .zh ? "按住 fn 开始录音" : "Hold fn to record" }
    static var menuQuit: String { lang == .zh ? "退出 yapyap" : "Quit yapyap" }

    // Alert
    static var notConfiguredTitle: String { lang == .zh ? "yapyap 未配置" : "yapyap Not Configured" }
    static var notConfiguredMessage: String { lang == .zh ? "请在设置中填写 App Key 和 Access Key。" : "Please set your App Key and Access Key in Settings." }
    static var openSettings: String { lang == .zh ? "打开设置" : "Open Settings" }
    static var cancel: String { lang == .zh ? "取消" : "Cancel" }

    // Startup dialog
    static var showMenuBarIcon: String { lang == .zh ? "显示菜单栏图标" : "Show Menu Bar Icon" }
    static var permissionsHeader: String { lang == .zh ? "所需权限" : "Required Permissions" }
    static var micPermission: String { lang == .zh ? "麦克风" : "Microphone" }
    static var micDescription: String {
        lang == .zh
            ? "用于捕获语音进行语音转文字"
            : "Used to capture voice for speech-to-text"
    }
    static var accessibilityPermission: String { lang == .zh ? "辅助功能" : "Accessibility" }
    static var accessibilityDescription: String {
        lang == .zh
            ? "用于在光标位置插入识别文字"
            : "Used to inject recognized text at cursor position"
    }
    static var launchApp: String { lang == .zh ? "启动应用" : "Launch App" }
    static var permissionGranted: String { lang == .zh ? "已授权" : "Granted" }
    static var permissionNotGranted: String { lang == .zh ? "未授权 — 点击前往设置" : "Not granted — click to open Settings" }
}

enum PunctuationMode: String, CaseIterable {
    case keepOriginal = "keepOriginal"
    case spaceReplace = "spaceReplace"
    case removeTrailing = "removeTrailing"
    case keepAll = "keepAll"
}

enum EnglishSpacingMode: String, CaseIterable {
    case keepOriginal = "keepOriginal"
    case noSpaces = "noSpaces"
    case addSpaces = "addSpaces"
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var appKey: String {
        didSet { UserDefaults.standard.set(appKey, forKey: "appKey") }
    }
    @Published var accessKey: String {
        didSet { UserDefaults.standard.set(accessKey, forKey: "accessKey") }
    }
    @Published var resourceId: String {
        didSet { UserDefaults.standard.set(resourceId, forKey: "resourceId") }
    }
    @Published var punctuationMode: PunctuationMode {
        didSet { UserDefaults.standard.set(punctuationMode.rawValue, forKey: "punctuationMode") }
    }
    @Published var englishSpacingMode: EnglishSpacingMode {
        didSet { UserDefaults.standard.set(englishSpacingMode.rawValue, forKey: "englishSpacingMode") }
    }
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published var showMenuBar: Bool {
        didSet { UserDefaults.standard.set(showMenuBar, forKey: "showMenuBar") }
    }
    private init() {
        self.appKey = UserDefaults.standard.string(forKey: "appKey") ?? ""
        self.accessKey = UserDefaults.standard.string(forKey: "accessKey") ?? ""
        self.resourceId = UserDefaults.standard.string(forKey: "resourceId") ?? "volc.seedasr.sauc.duration"
        self.punctuationMode = PunctuationMode(rawValue: UserDefaults.standard.string(forKey: "punctuationMode") ?? "") ?? .removeTrailing
        self.englishSpacingMode = EnglishSpacingMode(rawValue: UserDefaults.standard.string(forKey: "englishSpacingMode") ?? "") ?? .noSpaces
        self.language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .zh
        // Default to true if key has never been set
        if UserDefaults.standard.object(forKey: "showMenuBar") == nil {
            self.showMenuBar = true
        } else {
            self.showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBar")
        }
    }
}
