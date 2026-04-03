import SwiftUI
import AVFoundation

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable {
    case general, asr, textProcessing, ai, usage

    var icon: String {
        switch self {
        case .general: return "house"
        case .asr: return "waveform"
        case .textProcessing: return "textformat"
        case .ai: return "sparkles"
        case .usage: return "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .general: return L10n.tabGeneral
        case .asr: return L10n.tabASR
        case .textProcessing: return L10n.tabTextProcessing
        case .ai: return L10n.tabAI
        case .usage: return L10n.tabUsage
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var selectedTab: SettingsTab = .general

    var isStartup: Bool = false
    var onLaunch: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    sidebarButton(tab)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 150)

            Divider()

            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralTabView(isStartup: isStartup, onLaunch: onLaunch)
                    case .asr:
                        ASRTabView()
                    case .textProcessing:
                        TextProcessingTabView()
                    case .ai:
                        AITabView()
                    case .usage:
                        UsageTabView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 520)
    }

    private func sidebarButton(_ tab: SettingsTab) -> some View {
        let isActive = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.orange : Color.clear)
                    .frame(width: 3, height: 20)

                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: isActive ? .bold : .regular))
                    .foregroundColor(isActive ? .orange : .secondary)
                    .frame(width: 20)

                Text(tab.label)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.orange.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let header: String
    var trailing: AnyView? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(header)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                if let trailing {
                    Spacer()
                    trailing
                }
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct CardRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct CardDivider: View {
    var body: some View {
        Divider().padding(.leading, 12)
    }
}

// MARK: - General Tab

struct GeneralTabView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var micAuthorized = false
    @State private var accessibilityAuthorized = false

    var isStartup: Bool = false
    var onLaunch: (() -> Void)?

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var allPermissionsGranted: Bool {
        micAuthorized && accessibilityAuthorized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(header: L10n.permissionsHeader) {
                permissionRow(
                    name: L10n.micPermission,
                    description: L10n.micDescription,
                    granted: micAuthorized,
                    action: openMicrophoneSettings
                )
                CardDivider()
                permissionRow(
                    name: L10n.accessibilityPermission,
                    description: L10n.accessibilityDescription,
                    granted: accessibilityAuthorized,
                    action: openAccessibilitySettings
                )
            }

            SectionCard(header: L10n.appSettingsHeader) {
                CardRow(label: L10n.languageHeader) {
                    Picker("", selection: $store.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                CardDivider()
                CardRow(label: L10n.showMenuBarIcon) {
                    Toggle("", isOn: $store.showMenuBar)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            if isStartup {
                HStack {
                    Spacer()
                    Button(action: { onLaunch?() }) {
                        Text(L10n.launchApp)
                            .frame(minWidth: 120)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!allPermissionsGranted)
                    Spacer()
                }
            }
        }
        .onAppear { checkPermissions() }
        .onReceive(permissionTimer) { _ in checkPermissions() }
    }

    private func permissionRow(name: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(granted ? .green : .red)
                    .frame(width: 20)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(granted ? L10n.permissionGranted : L10n.permissionNotGranted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if !granted {
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(granted ? Color.green.opacity(0.04) : Color.red.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func checkPermissions() {
        micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityAuthorized = AXIsProcessTrusted()
    }

    private func openMicrophoneSettings() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { self.micAuthorized = granted }
            }
        }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

// MARK: - ASR Tab

struct ASRTabView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var showAccessKey = false
    @State private var testState: TestState = .idle

    enum TestState {
        case idle, testing
        case success(String)
        case failure(String)
    }

    private var isTestRunning: Bool {
        if case .testing = testState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(
                header: L10n.asrApiHeader,
                trailing: AnyView(
                    Link(L10n.getKey, destination: URL(string: "https://console.volcengine.com/speech/service/10038")!)
                        .font(.system(size: 11))
                )
            ) {
                CardRow(label: "App Key") {
                    TextField("", text: $store.appKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }
                CardDivider()
                CardRow(label: "Access Key") {
                    HStack(spacing: 4) {
                        if showAccessKey {
                            TextField("", text: $store.accessKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("", text: $store.accessKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: { showAccessKey.toggle() }) {
                            Image(systemName: showAccessKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity)
                }
                CardDivider()
                CardRow(label: "Resource ID") {
                    Picker("", selection: $store.resourceId) {
                        Text(L10n.resourceHourly20).tag("volc.seedasr.sauc.duration")
                        Text(L10n.resourceConcurrent20).tag("volc.seedasr.sauc.concurrent")
                        Text(L10n.resourceHourly10).tag("volc.bigasr.sauc.duration")
                        Text(L10n.resourceConcurrent10).tag("volc.bigasr.sauc.concurrent")
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                CardDivider()

                // Test connection row
                HStack {
                    Button(action: runTest) {
                        HStack(spacing: 4) {
                            if case .testing = testState {
                                ProgressView().controlSize(.small)
                            }
                            Text(L10n.testConnection)
                        }
                    }
                    .disabled(store.appKey.isEmpty || store.accessKey.isEmpty || isTestRunning)

                    Spacer()

                    switch testState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        Text(L10n.connecting)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    case .success(let msg):
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    case .failure:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                if case .failure(let msg) = testState {
                    Text(msg)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color.red.opacity(0.06))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func runTest() {
        testState = .testing
        ASRClient.testConnection(
            appKey: store.appKey,
            accessKey: store.accessKey,
            resourceId: store.resourceId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let msg):
                    testState = .success(msg)
                case .failure(let error):
                    testState = .failure(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Text Processing Tab

struct TextProcessingTabView: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(header: L10n.punctuationHeader) {
                Picker("", selection: $store.punctuationMode) {
                    Text(L10n.keepOriginal).tag(PunctuationMode.keepOriginal)
                    Text(L10n.punctSpaceReplace).tag(PunctuationMode.spaceReplace)
                    Text(L10n.punctRemoveTrailing).tag(PunctuationMode.removeTrailing)
                    Text(L10n.punctKeepAll).tag(PunctuationMode.keepAll)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .padding(12)
            }

            SectionCard(header: L10n.spacingHeader) {
                Picker("", selection: $store.englishSpacingMode) {
                    Text(L10n.keepOriginal).tag(EnglishSpacingMode.keepOriginal)
                    Text(L10n.spacingNone).tag(EnglishSpacingMode.noSpaces)
                    Text(L10n.spacingAdd).tag(EnglishSpacingMode.addSpaces)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .padding(12)
            }
        }
    }
}

// MARK: - AI Tab

struct AITabView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var showAIKey = false
    @State private var fetchedModels: [String] = []
    @State private var isFetchingModels = false
    @State private var fetchError: String? = nil
    @State private var showModelPopover = false
    @State private var modelSearchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(header: L10n.aiHeader) {
                // Enable toggle
                CardRow(label: L10n.aiEnabled) {
                    Toggle("", isOn: $store.aiEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if store.aiEnabled {
                    CardDivider()

                    // Provider
                    CardRow(label: L10n.aiProviderLabel) {
                        Picker("", selection: $store.aiProvider) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    // Base URL (only for Custom)
                    if store.aiProvider == .custom {
                        CardDivider()
                        CardRow(label: L10n.aiBaseURL) {
                            TextField("https://api.example.com/v1", text: $store.aiBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    CardDivider()

                    // API Key
                    CardRow(label: L10n.aiApiKeyLabel) {
                        HStack(spacing: 4) {
                            if showAIKey {
                                TextField("sk-...", text: $store.aiApiKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("sk-...", text: $store.aiApiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button(action: { showAIKey.toggle() }) {
                                Image(systemName: showAIKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    CardDivider()

                    // Model with fetch
                    CardRow(label: L10n.aiModel) {
                        HStack(spacing: 6) {
                            modelSelector
                            Button(action: fetchModels) {
                                if isFetchingModels {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(store.aiApiKey.isEmpty || isFetchingModels)
                            .help(L10n.lang == .zh ? "拉取可用模型" : "Fetch available models")
                        }
                    }

                    if let fetchError {
                        Text(fetchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 6)
                    }
                }
            }

            if store.aiEnabled {
                SectionCard(header: L10n.aiPrompt) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextEditor(text: $store.aiPrompt)
                            .font(.system(size: 12))
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                        Text(L10n.aiPromptPlaceholder)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Model Selector

    private var filteredModels: [String] {
        if modelSearchText.isEmpty { return fetchedModels }
        return fetchedModels.filter { $0.localizedCaseInsensitiveContains(modelSearchText) }
    }

    private var modelSelector: some View {
        Button(action: { showModelPopover.toggle() }) {
            HStack {
                Text(store.aiModel.isEmpty ? L10n.aiModelPlaceholder : store.aiModel)
                    .font(.system(size: 12))
                    .foregroundColor(store.aiModel.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: showModelPopover ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .popover(isPresented: $showModelPopover, arrowEdge: .bottom) {
            modelPopoverContent
        }
    }

    private var modelPopoverContent: some View {
        VStack(spacing: 0) {
            // Search field
            TextField(L10n.aiSearchModels, text: $modelSearchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredModels, id: \.self) { model in
                        Button(action: {
                            store.aiModel = model
                            showModelPopover = false
                            modelSearchText = ""
                        }) {
                            Text(model)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    store.aiModel == model
                                        ? Color.orange.opacity(0.15)
                                        : Color.clear
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Allow custom model name
                    if !modelSearchText.isEmpty && !fetchedModels.contains(modelSearchText) {
                        Divider()
                        Button(action: {
                            store.aiModel = modelSearchText
                            showModelPopover = false
                            modelSearchText = ""
                        }) {
                            Text("Use \"\(modelSearchText)\"")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }

                    if fetchedModels.isEmpty && modelSearchText.isEmpty {
                        Text(L10n.lang == .zh ? "点击拉取按钮获取模型列表" : "Click fetch to load models")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(12)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .frame(width: 260)
    }

    // MARK: - Fetch Models

    private func fetchModels() {
        isFetchingModels = true
        fetchError = nil

        let baseURL = store.aiBaseURL.hasSuffix("/")
            ? String(store.aiBaseURL.dropLast())
            : store.aiBaseURL
        guard let url = URL(string: "\(baseURL)/models") else {
            fetchError = "Invalid URL"
            isFetchingModels = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(store.aiApiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isFetchingModels = false

                if let error {
                    fetchError = error.localizedDescription
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["data"] as? [[String: Any]] else {
                    fetchError = L10n.aiFetchFailed
                    return
                }

                fetchedModels = models.compactMap { $0["id"] as? String }.sorted()
                fetchError = nil
            }
        }.resume()
    }
}

// MARK: - Usage Tab

struct UsageTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(header: L10n.usageHeader) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.usageText)
                        .font(.system(size: 13))
                    Text(L10n.usageTip)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
            }
        }
    }
}
