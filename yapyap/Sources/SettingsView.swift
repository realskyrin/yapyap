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
                TextField("App Key", text: $store.appKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if showAccessKey {
                        TextField("Access Key", text: $store.accessKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Access Key", text: $store.accessKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showAccessKey.toggle() }) {
                        Image(systemName: showAccessKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Resource ID", selection: $store.resourceId) {
                    Text("2.0 小时版").tag("volc.seedasr.sauc.duration")
                    Text("2.0 并发版").tag("volc.seedasr.sauc.concurrent")
                    Text("1.0 小时版").tag("volc.bigasr.sauc.duration")
                    Text("1.0 并发版").tag("volc.bigasr.sauc.concurrent")
                }

                HStack {
                    Button(action: runTest) {
                        HStack(spacing: 4) {
                            if case .testing = testState {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(store.appKey.isEmpty || store.accessKey.isEmpty || isTestRunning)

                    Spacer()

                    switch testState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        Text("Connecting...")
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
                Text("豆包 ASR API")
            }

            Section {
                Picker("", selection: $store.punctuationMode) {
                    Text("空格代替标点").tag(PunctuationMode.spaceReplace)
                    Text("句末不加标点").tag(PunctuationMode.removeTrailing)
                    Text("保留所有标点").tag(PunctuationMode.keepAll)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text("标点展示")
            }

            Section {
                Picker("", selection: $store.englishSpacingMode) {
                    Text("前后无空格").tag(EnglishSpacingMode.noSpaces)
                    Text("前后加空格").tag(EnglishSpacingMode.addSpaces)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text("数字、英文展示")
            }

            Section {
                Text("Hold **fn** key to start recording.\nRelease to stop and insert text at cursor.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Tip: In System Settings → Keyboard, set \"Press 🌐 key to\" → \"Do Nothing\" for best experience.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Usage")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 520)
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
