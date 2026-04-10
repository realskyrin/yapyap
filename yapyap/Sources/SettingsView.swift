import SwiftUI
import AVFoundation

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable {
    case general, asr, ai, textProcessing, usage

    var icon: String {
        switch self {
        case .general: return "house"
        case .asr: return "waveform"
        case .textProcessing: return "character.textbox.badge.sparkles"
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        sidebarButton(tab)
                    }
                    Spacer()
                    if isStartup {
                        Button(action: { onLaunch?() }) {
                            Text(L10n.launchApp)
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    }
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
                            GeneralTabView()
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
            .frame(maxHeight: .infinity)

            Divider()

            SettingsStatusBar()
        }
        .frame(width: 680, height: 556)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                }
                CardDivider()
                CardRow(label: L10n.showMenuBarIcon) {
                    Toggle("", isOn: $store.showMenuBar)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            SectionCard(header: L10n.soundHeader) {
                CardRow(label: L10n.soundEnabled) {
                    Toggle("", isOn: $store.soundEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                if store.soundEnabled {
                    CardDivider()
                    CardRow(label: L10n.soundTheme) {
                        HStack(spacing: 8) {
                            Picker("", selection: $store.soundTheme) {
                                ForEach(SoundTheme.allCases, id: \.self) { theme in
                                    Text(theme.displayName).tag(theme)
                                }
                            }
                            .labelsHidden()
                            Button(action: {
                                SoundFeedback.shared.previewStart()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    SoundFeedback.shared.previewStop()
                                }
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.soundPreview)
                        }
                    }
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
    @ObservedObject private var modelManager = ModelManager.shared
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
            // ASR Mode picker
            SectionCard(header: L10n.asrModeHeader) {
                Picker("", selection: $store.asrMode) {
                    ForEach(ASRMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(12)
            }

            if store.asrMode == .online {
                onlineSettingsSection
            } else {
                localModelsSection
            }
        }
    }

    // MARK: - Online Settings

    private var onlineSettingsSection: some View {
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
            }
            CardDivider()

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

    // MARK: - Local Models

    private var localModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if modelManager.downloadedModels.isEmpty {
                Text(L10n.noModelHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            } else if store.selectedModelId.isEmpty {
                Text(L10n.noModelHint)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 2)
            }

            ForEach(modelManager.catalog) { model in
                ModelCardView(model: model)
            }
        }
    }

    // MARK: - Test Connection

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

// MARK: - Model Card

struct ModelCardView: View {
    let model: ModelInfo
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var modelManager = ModelManager.shared

    private var isDownloaded: Bool { modelManager.isDownloaded(model.id) }
    private var isDownloading: Bool { modelManager.downloadProgress[model.id] != nil }
    private var isExtracting: Bool { modelManager.isExtracting[model.id] == true }
    private var isActive: Bool { store.selectedModelId == model.id }
    private var progress: Double { modelManager.downloadProgress[model.id] ?? 0 }
    private var speed: String { modelManager.downloadSpeed[model.id] ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(model.sizeDescription)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(model.languagesDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isExtracting {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text(L10n.modelExtracting)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isDownloading {
                    Button(L10n.cancelDownload) {
                        modelManager.cancelDownload(model.id)
                    }
                    .controlSize(.small)
                } else if isDownloaded {
                    HStack(spacing: 8) {
                        if isActive {
                            Text(L10n.modelActive)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        } else {
                            Button(action: { store.selectedModelId = model.id }) {
                                Text(L10n.lang == .zh ? "选择" : "Select")
                            }
                            .controlSize(.small)
                        }
                        Button(action: { modelManager.delete(model.id) }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button(L10n.modelDownload) {
                        modelManager.download(model.id)
                    }
                    .controlSize(.small)
                }
            }
            .padding(12)

            if isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !speed.isEmpty {
                            Text(speed)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? Color.orange.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.5),
                    lineWidth: isActive ? 1.5 : 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
    @ObservedObject private var llmManager = LLMModelManager.shared
    @State private var showAIKey = false
    @State private var fetchedModels: [String] = []
    @State private var isFetchingModels = false
    @State private var fetchError: String? = nil
    @State private var showModelPopover = false
    @State private var modelSearchText = ""
    @State private var newTermAliases = ""
    @State private var newTermTarget = ""
    @State private var showTermsTooltip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(header: L10n.aiHeader) {
                CardRow(label: L10n.aiEnabled) {
                    Toggle("", isOn: $store.aiEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            if store.aiEnabled {
                // Mode picker (parallel to ASR tab)
                SectionCard(header: L10n.aiModeHeader) {
                    Picker("", selection: $store.useLocalAI) {
                        Text(L10n.aiModeOnline).tag(false)
                        Text(L10n.aiModeLocal).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(12)
                    .onChange(of: store.useLocalAI) { _, enabled in
                        if enabled { llmManager.ensureLoaded() }
                    }
                }

                // Mode-specific settings
                if store.useLocalAI {
                    localAIModelCard
                } else {
                    onlineProviderSection
                }

                // Common: System Prompt (shared between online and local)
                // Common: System Prompt (shared between online and local)
                systemPromptSection

                // Common: Terms (shared between online and local)
                termsSection
            }
        }
    }

    // MARK: - Local AI Model Card

    private var localAIModelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(L10n.localAIModelName)
                            .font(.system(size: 13, weight: .medium))
                        Text(L10n.localAIModelSize)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if llmManager.isDownloading {
                        Text(L10n.localAIDownloading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if llmManager.isLoading {
                        Text(L10n.localAILoading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if llmManager.isDownloaded {
                        Text(L10n.localAIReady)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(L10n.localAINotDownloaded)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if llmManager.isDownloading {
                    Button(L10n.cancelDownload) {
                        llmManager.cancelDownload()
                    }
                    .controlSize(.small)
                } else if llmManager.isDownloaded {
                    HStack(spacing: 8) {
                        Text(L10n.modelActive)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                        Button(action: { llmManager.delete() }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button(L10n.modelDownload) {
                        llmManager.downloadAndLoad()
                    }
                    .controlSize(.small)
                }
            }
            .padding(12)

            if llmManager.isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: llmManager.downloadProgress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("\(Int(llmManager.downloadProgress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            if let error = llmManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    llmManager.isDownloaded ? Color.orange.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.5),
                    lineWidth: llmManager.isDownloaded ? 1.5 : 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Online Provider Section

    private var onlineProviderSection: some View {
        SectionCard(header: L10n.aiOnlineHeader) {
            CardRow(label: L10n.aiProviderLabel) {
                Picker("", selection: $store.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
            }

            if store.aiProvider == .custom {
                CardDivider()
                CardRow(label: L10n.aiBaseURL) {
                    TextField("https://api.example.com/v1", text: $store.aiBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }
            }

            CardDivider()

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

    // MARK: - System Prompt Section

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.aiPrompt)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 2)

            VStack(spacing: 8) {
                ForEach(AIPromptPreset.allCases, id: \.self) { preset in
                    PromptPresetCard(
                        preset: preset,
                        selection: $store.aiPromptPreset,
                        customText: $store.aiPrompt
                    )
                }
            }
        }
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(L10n.aiTermsHeader)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .onHover { showTermsTooltip = $0 }
                    .popover(isPresented: $showTermsTooltip, arrowEdge: .trailing) {
                        Text(L10n.aiTermsTooltip)
                            .font(.system(size: 12))
                            .padding(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 240)
                    }
            }
            .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField(L10n.aiTermsAliasesPlaceholder, text: $newTermAliases)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTerm() }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField(L10n.aiTermsTargetPlaceholder, text: $newTermTarget)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                        .onSubmit { addTerm() }
                    Button(L10n.aiTermsAdd) { addTerm() }
                        .disabled(newTermTarget.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if store.aiTerms.isEmpty {
                    Text(L10n.aiTermsEmpty)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                } else {
                    VStack(spacing: 6) {
                        ForEach(store.aiTerms) { entry in
                            TermEntryRow(entry: entry) {
                                store.aiTerms.removeAll { $0.id == entry.id }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Terms

    private func addTerm() {
        let target = newTermTarget.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }

        // Split aliases on both ASCII and Chinese comma, trim, drop empties and dedupe.
        let aliases = newTermAliases
            .split(whereSeparator: { $0 == "," || $0 == "\u{FF0C}" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let uniqueAliases = aliases.filter { seen.insert($0.lowercased()).inserted }

        // If an entry with the same target exists, merge aliases into it instead
        // of creating a duplicate row — keeps the list tidy when the user is
        // iteratively adding spoken forms for the same target.
        if let idx = store.aiTerms.firstIndex(where: { $0.target == target }) {
            var merged = store.aiTerms[idx].aliases
            for alias in uniqueAliases where !merged.contains(where: { $0.lowercased() == alias.lowercased() }) {
                merged.append(alias)
            }
            store.aiTerms[idx].aliases = merged
        } else {
            store.aiTerms.append(TermEntry(target: target, aliases: uniqueAliases))
        }

        newTermAliases = ""
        newTermTarget = ""
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

// MARK: - Prompt Preset Card

struct PromptPresetCard: View {
    let preset: AIPromptPreset
    @Binding var selection: AIPromptPreset
    @Binding var customText: String
    @State private var isExpanded: Bool
    @State private var copied: Bool = false

    init(preset: AIPromptPreset, selection: Binding<AIPromptPreset>, customText: Binding<String>) {
        self.preset = preset
        self._selection = selection
        self._customText = customText
        // Open the card initially if it's the active preset so the user sees the prompt.
        self._isExpanded = State(initialValue: selection.wrappedValue == preset)
    }

    private var isSelected: Bool { selection == preset }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — split into two buttons so the chevron only toggles
            // expansion and doesn't also change the selection.
            HStack(spacing: 8) {
                Button(action: handleBodyTap) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text(preset.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if isSelected {
                            Text(L10n.modelActive)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: toggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            if isExpanded {
                Divider()
                expandedBody
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.orange.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.5),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var expandedBody: some View {
        if preset == .custom {
            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $customText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.08))
                    )
                Text(L10n.aiPromptPlaceholder)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    Text(preset.promptText)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.08))
                )

                HStack {
                    Spacer()
                    Button(action: copyPrompt) {
                        Label(
                            copied ? L10n.aiPromptCopied : L10n.aiPromptCopy,
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
        }
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preset.promptText, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }

    /// Tap on the body area selects the preset (and opens it on first selection).
    private func handleBodyTap() {
        if isSelected {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        } else {
            selection = preset
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded = true }
        }
    }

    /// Tap on the chevron only toggles expansion — selection is unaffected.
    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
    }
}

// MARK: - Term Tag

struct TermEntryRow: View {
    let entry: TermEntry
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Aliases (left). Falls back to a muted "hint only" label when
            // there are none, so preserve-only entries still read clearly.
            Group {
                if entry.aliases.isEmpty {
                    Text(L10n.lang == .zh ? "（仅作术语保留）" : "(preserve only)")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(.tertiary)
                } else {
                    Text(entry.aliases.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Target (right)
            Text(entry.target)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 140, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
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

// MARK: - Status Bar: Quick Switch Row

struct QuickSwitchRow: View {
    let title: String
    let description: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Bar: Pill

struct StatusPill<PopoverContent: View>: View {
    let label: String
    let isActive: Bool
    @ViewBuilder let popoverContent: (Binding<Bool>) -> PopoverContent

    @State private var isOpen = false
    @State private var isHovering = false

    var body: some View {
        Button(action: { isOpen.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(pillBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            popoverContent($isOpen)
        }
    }

    private var pillBackground: Color {
        if isOpen {
            return Color(nsColor: .controlBackgroundColor)
        }
        if isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.7)
        }
        return Color.clear
    }
}

// MARK: - Settings Status Bar

struct SettingsStatusBar: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var llmManager = LLMModelManager.shared

    var body: some View {
        HStack(spacing: 8) {
            voicePill
            postProcessingPill
            Spacer()
            Text(versionString)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }

    // MARK: - Version

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "v\(version)"
    }

    // MARK: - Voice Pill

    private var voicePill: some View {
        StatusPill(
            label: voiceLabel,
            isActive: voiceActive
        ) { isOpen in
            VStack(spacing: 0) {
                QuickSwitchRow(
                    title: L10n.statusBarVoiceOnlineName,
                    description: L10n.statusBarVoiceOnlineDesc,
                    isActive: store.asrMode == .online
                ) {
                    store.asrMode = .online
                    isOpen.wrappedValue = false
                }
                ForEach(downloadedLocalModels, id: \.id) { model in
                    Divider()
                    QuickSwitchRow(
                        title: model.name,
                        description: localModelDescription(for: model.id),
                        isActive: store.asrMode == .local && store.selectedModelId == model.id
                    ) {
                        store.asrMode = .local
                        store.selectedModelId = model.id
                        isOpen.wrappedValue = false
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private var voiceLabel: String {
        switch store.asrMode {
        case .online:
            return L10n.statusBarVoiceOnlineName
        case .local:
            return modelManager.catalog.first { $0.id == store.selectedModelId }?.name ?? "Local"
        }
    }

    private var voiceActive: Bool {
        switch store.asrMode {
        case .online:
            return !store.appKey.isEmpty && !store.accessKey.isEmpty
        case .local:
            return !store.selectedModelId.isEmpty
        }
    }

    private var downloadedLocalModels: [ModelInfo] {
        modelManager.catalog.filter { modelManager.downloadedModels.contains($0.id) }
    }

    private func localModelDescription(for modelId: String) -> String {
        switch modelId {
        case "sensevoice-small": return L10n.statusBarModelSenseVoiceDesc
        case "whisper-small": return L10n.statusBarModelWhisperSmallDesc
        case "whisper-medium": return L10n.statusBarModelWhisperMediumDesc
        default: return ""
        }
    }

    // MARK: - Post-Processing Pill

    private var postProcessingPill: some View {
        StatusPill(
            label: postLabel,
            isActive: store.aiEnabled
        ) { isOpen in
            VStack(spacing: 0) {
                QuickSwitchRow(
                    title: L10n.statusBarPostOff,
                    description: L10n.statusBarPostOffDesc,
                    isActive: !store.aiEnabled
                ) {
                    store.aiEnabled = false
                    isOpen.wrappedValue = false
                }
                Divider()
                QuickSwitchRow(
                    title: store.aiProvider.displayName,
                    description: onlineRowDescription,
                    isActive: store.aiEnabled && !store.useLocalAI
                ) {
                    store.aiEnabled = true
                    store.useLocalAI = false
                    isOpen.wrappedValue = false
                }
                if llmManager.isDownloaded {
                    Divider()
                    QuickSwitchRow(
                        title: L10n.statusBarPostLocalName,
                        description: L10n.statusBarPostLocalDesc,
                        isActive: store.aiEnabled && store.useLocalAI
                    ) {
                        store.aiEnabled = true
                        store.useLocalAI = true
                        llmManager.ensureLoaded()
                        isOpen.wrappedValue = false
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private var postLabel: String {
        if !store.aiEnabled { return L10n.statusBarPostOff }
        if store.useLocalAI { return "Qwen3 4B" }
        return store.aiModel.isEmpty ? L10n.statusBarPostOnline : store.aiModel
    }

    private var onlineRowDescription: String {
        if store.aiModel.isEmpty {
            return L10n.statusBarPostOnlineHint
        }
        return store.aiModel
    }
}
