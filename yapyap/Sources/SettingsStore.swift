import Foundation

enum PunctuationMode: String, CaseIterable {
    case spaceReplace = "spaceReplace"   // 空格代替标点
    case removeTrailing = "removeTrailing" // 句末不加标点
    case keepAll = "keepAll"             // 保留所有标点
}

enum EnglishSpacingMode: String, CaseIterable {
    case noSpaces = "noSpaces"           // 前后无空格
    case addSpaces = "addSpaces"         // 前后加空格
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

    private init() {
        self.appKey = UserDefaults.standard.string(forKey: "appKey") ?? ""
        self.accessKey = UserDefaults.standard.string(forKey: "accessKey") ?? ""
        self.resourceId = UserDefaults.standard.string(forKey: "resourceId") ?? "volc.seedasr.sauc.duration"
        self.punctuationMode = PunctuationMode(rawValue: UserDefaults.standard.string(forKey: "punctuationMode") ?? "") ?? .removeTrailing
        self.englishSpacingMode = EnglishSpacingMode(rawValue: UserDefaults.standard.string(forKey: "englishSpacingMode") ?? "") ?? .noSpaces
    }
}
