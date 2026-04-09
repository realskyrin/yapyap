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
            ? "长按模式：按住 fn 键开始录音，松开后自动完成识别并插入文本。\n\n单击模式：单击 fn 键开始录音，再次单击 fn 键结束录音并插入文本。\n\n识别结果会实时显示在悬浮预览窗中，最终文本插入到当前光标位置。"
            : "Hold mode: Press and hold fn to record, release to finish and insert text.\n\nTap mode: Tap fn once to start recording, tap again to stop and insert text.\n\nRecognized text is previewed in a floating overlay and inserted at the current cursor position."
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
    static var menuHoldFn: String { lang == .zh ? "长按/单击 fn 开始录音" : "Hold or tap fn to record" }
    static var menuQuit: String { lang == .zh ? "退出 yapyap" : "Quit yapyap" }

    // Alert
    static var notConfiguredTitle: String { lang == .zh ? "yapyap 未配置" : "yapyap Not Configured" }
    static var notConfiguredMessage: String { lang == .zh ? "请在设置中填写 App Key 和 Access Key。" : "Please set your App Key and Access Key in Settings." }
    static var openSettings: String { lang == .zh ? "打开设置" : "Open Settings" }
    static var cancel: String { lang == .zh ? "取消" : "Cancel" }

    // AI Post-Processing
    static var aiHeader: String { lang == .zh ? "后处理" : "Post-Processing" }
    static var aiEnabled: String { lang == .zh ? "启用 AI 文本纠正" : "Enable AI text correction" }
    static var aiBaseURL: String { lang == .zh ? "API 地址" : "API Base URL" }
    static var aiModel: String { lang == .zh ? "模型" : "Model" }
    static var aiPrompt: String { lang == .zh ? "系统提示词" : "System Prompt" }
    static var aiPromptPlaceholder: String {
        lang == .zh
            ? "留空使用默认提示词（修正语音识别错误和语法问题）"
            : "Leave empty for default (fix speech recognition errors and grammar)"
    }
    static var processing: String { lang == .zh ? "处理中" : "Processing" }
    static var aiTermsHeader: String { lang == .zh ? "术语" : "Terms" }
    static var aiTermsPlaceholder: String { lang == .zh ? "添加术语..." : "Add term..." }
    static var aiTermsAdd: String { lang == .zh ? "添加" : "Add" }
    static var aiTermsTooltip: String {
        lang == .zh
            ? "添加常用术语，AI 会在后处理时优先使用这些词（例如：口语「cloud code」→「Claude Code」，「slash new」→「/new」）"
            : "Add terms that AI should preserve during post-processing (e.g. spoken \"cloud code\" → \"Claude Code\", \"slash new\" → \"/new\")"
    }

    // Sidebar tabs
    static var tabGeneral: String { lang == .zh ? "通用" : "General" }
    static var tabASR: String { lang == .zh ? "模型设置" : "Model" }
    static var tabTextProcessing: String { lang == .zh ? "文本处理" : "Text" }
    static var tabAI: String { lang == .zh ? "后处理" : "AI" }
    static var tabUsage: String { lang == .zh ? "使用帮助" : "Help" }

    // Section headers
    static var appSettingsHeader: String { lang == .zh ? "应用" : "App" }

    // AI tab extras
    static var aiProviderLabel: String { lang == .zh ? "提供商" : "Provider" }
    static var aiApiKeyLabel: String { lang == .zh ? "API 密钥" : "API Key" }
    static var aiModelPlaceholder: String { lang == .zh ? "输入模型名称" : "Enter model name" }
    static var aiSearchModels: String { lang == .zh ? "搜索..." : "Search..." }
    static var aiFetchFailed: String { lang == .zh ? "拉取失败" : "Fetch failed" }

    // Startup dialog
    static var soundHeader: String { lang == .zh ? "提示音" : "Sound" }
    static var soundEnabled: String { lang == .zh ? "启用提示音" : "Enable sound feedback" }
    static var soundTheme: String { lang == .zh ? "提示音" : "Sound" }
    static var soundPreview: String { lang == .zh ? "试听" : "Preview" }

    // ASR mode
    static var asrModeHeader: String { lang == .zh ? "识别模式" : "ASR Mode" }
    static var localModelsHeader: String { lang == .zh ? "本地模型" : "Local Models" }
    static var modelDownload: String { lang == .zh ? "下载" : "Download" }
    static var modelDelete: String { lang == .zh ? "删除" : "Delete" }
    static var modelActive: String { lang == .zh ? "使用中" : "Active" }
    static var modelDownloading: String { lang == .zh ? "下载中..." : "Downloading..." }
    static var modelExtracting: String { lang == .zh ? "解压中..." : "Extracting..." }
    static var modelNotDownloaded: String { lang == .zh ? "未下载" : "Not downloaded" }
    static var modelDownloaded: String { lang == .zh ? "已下载" : "Downloaded" }
    static var noModelHint: String {
        lang == .zh
            ? "请先下载一个模型以使用本地识别"
            : "Please download a model to use local recognition"
    }
    static var notConfiguredLocalTitle: String { lang == .zh ? "模型未就绪" : "Model Not Ready" }
    static var notConfiguredLocalMessage: String {
        lang == .zh
            ? "请在设置中下载并选择一个本地模型。"
            : "Please download and select a local model in Settings."
    }
    static var cancelDownload: String { lang == .zh ? "取消" : "Cancel" }
    static var languages99: String { lang == .zh ? "99 种语言" : "99 languages" }
    static var languagesCJKE: String { lang == .zh ? "中/英/日/韩/粤" : "zh/en/ja/ko/yue" }

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

enum AIProvider: String, CaseIterable {
    case openai = "openai"
    case deepseek = "deepseek"
    case siliconflow = "siliconflow"
    case groq = "groq"
    case moonshot = "moonshot"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        case .siliconflow: return "SiliconFlow"
        case .groq: return "Groq"
        case .moonshot: return "Moonshot"
        case .custom: return "Custom"
        }
    }

    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .siliconflow: return "https://api.siliconflow.cn/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .moonshot: return "https://api.moonshot.cn/v1"
        case .custom: return ""
        }
    }

    static func detect(from url: String) -> AIProvider {
        for provider in AIProvider.allCases where provider != .custom {
            if url == provider.baseURL {
                return provider
            }
        }
        return .custom
    }
}

enum SoundTheme: String, CaseIterable {
    case sound1 = "1"
    case sound2 = "2"

    var displayName: String {
        switch self {
        case .sound1: return L10n.lang == .zh ? "提示音 1" : "Sound 1"
        case .sound2: return L10n.lang == .zh ? "提示音 2" : "Sound 2"
        }
    }

    var startFile: String {
        switch self {
        case .sound1: return "start1"
        case .sound2: return "start2"
        }
    }

    var stopFile: String {
        switch self {
        case .sound1: return "stop1"
        case .sound2: return "stop2"
        }
    }
}

enum ASRMode: String, CaseIterable {
    case online = "online"
    case local = "local"

    var displayName: String {
        switch self {
        case .online: return L10n.lang == .zh ? "在线 (豆包)" : "Online (Doubao)"
        case .local: return L10n.lang == .zh ? "本地模型" : "Local Model"
        }
    }
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
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var soundTheme: SoundTheme {
        didSet { UserDefaults.standard.set(soundTheme.rawValue, forKey: "soundTheme") }
    }
    @Published var asrMode: ASRMode {
        didSet { UserDefaults.standard.set(asrMode.rawValue, forKey: "asrMode") }
    }
    @Published var selectedModelId: String {
        didSet { UserDefaults.standard.set(selectedModelId, forKey: "selectedModelId") }
    }
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: "aiEnabled") }
    }
    @Published var aiProvider: AIProvider {
        didSet {
            UserDefaults.standard.set(aiProvider.rawValue, forKey: "aiProvider")
            if aiProvider != .custom {
                aiBaseURL = aiProvider.baseURL
            }
        }
    }
    @Published var aiBaseURL: String {
        didSet { UserDefaults.standard.set(aiBaseURL, forKey: "aiBaseURL") }
    }
    @Published var aiApiKey: String {
        didSet { UserDefaults.standard.set(aiApiKey, forKey: "aiApiKey") }
    }
    @Published var aiModel: String {
        didSet { UserDefaults.standard.set(aiModel, forKey: "aiModel") }
    }
    @Published var aiPrompt: String {
        didSet { UserDefaults.standard.set(aiPrompt, forKey: "aiPrompt") }
    }
    @Published var aiTerms: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(aiTerms) {
                UserDefaults.standard.set(data, forKey: "aiTerms")
            }
        }
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
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            self.soundEnabled = true
        } else {
            self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        }
        self.soundTheme = SoundTheme(rawValue: UserDefaults.standard.string(forKey: "soundTheme") ?? "") ?? .sound1
        self.asrMode = ASRMode(rawValue: UserDefaults.standard.string(forKey: "asrMode") ?? "") ?? .online
        self.selectedModelId = UserDefaults.standard.string(forKey: "selectedModelId") ?? ""
        self.aiEnabled = UserDefaults.standard.bool(forKey: "aiEnabled")
        let storedBaseURL = UserDefaults.standard.string(forKey: "aiBaseURL") ?? "https://api.openai.com/v1"
        self.aiBaseURL = storedBaseURL
        if let raw = UserDefaults.standard.string(forKey: "aiProvider"),
           let provider = AIProvider(rawValue: raw) {
            self.aiProvider = provider
        } else {
            self.aiProvider = AIProvider.detect(from: storedBaseURL)
        }
        self.aiApiKey = UserDefaults.standard.string(forKey: "aiApiKey") ?? ""
        self.aiModel = UserDefaults.standard.string(forKey: "aiModel") ?? "gpt-4o-mini"
        self.aiPrompt = UserDefaults.standard.string(forKey: "aiPrompt") ?? ""
        if let data = UserDefaults.standard.data(forKey: "aiTerms"),
           let terms = try? JSONDecoder().decode([String].self, from: data) {
            self.aiTerms = terms
        } else {
            self.aiTerms = []
        }
    }
}
