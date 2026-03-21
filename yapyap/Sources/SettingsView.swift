import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var showAccessKey = false
    @State private var testState: TestState = .idle

    enum TestState {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("App Key") {
                    TextField("", text: $store.appKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }

                LabeledContent("Access Key") {
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
                    .frame(width: 240)
                }

                Picker("Resource ID", selection: $store.resourceId) {
                    Text(L10n.resourceHourly20).tag("volc.seedasr.sauc.duration")
                    Text(L10n.resourceConcurrent20).tag("volc.seedasr.sauc.concurrent")
                    Text(L10n.resourceHourly10).tag("volc.bigasr.sauc.duration")
                    Text(L10n.resourceConcurrent10).tag("volc.bigasr.sauc.concurrent")
                }

                HStack {
                    Button(action: runTest) {
                        HStack(spacing: 4) {
                            if case .testing = testState {
                                ProgressView()
                                    .controlSize(.small)
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

                if case .failure(let msg) = testState {
                    Text(msg)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color.red.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            } header: {
                HStack {
                    Text(L10n.asrApiHeader)
                    Spacer()
                    Link(L10n.getKey, destination: URL(string: "https://console.volcengine.com/speech/service/10038")!)
                        .font(.callout)
                }
            }

            Section {
                Picker("", selection: $store.punctuationMode) {
                    Text(L10n.punctSpaceReplace).tag(PunctuationMode.spaceReplace)
                    Text(L10n.punctRemoveTrailing).tag(PunctuationMode.removeTrailing)
                    Text(L10n.punctKeepAll).tag(PunctuationMode.keepAll)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text(L10n.punctuationHeader)
            }

            Section {
                Picker("", selection: $store.englishSpacingMode) {
                    Text(L10n.spacingNone).tag(EnglishSpacingMode.noSpaces)
                    Text(L10n.spacingAdd).tag(EnglishSpacingMode.addSpaces)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text(L10n.spacingHeader)
            }

            Section {
                Picker("", selection: $store.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text(L10n.languageHeader)
            }

            Section {
                Text(L10n.usageText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(L10n.usageTip)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text(L10n.usageHeader)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 580)
    }

    private var isTestRunning: Bool {
        if case .testing = testState { return true }
        return false
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
