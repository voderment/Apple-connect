import SwiftUI

struct LLMProviderSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        SummaryPage(title: "Model Provider") {
            SummarySection(title: "Provider") {
                Toggle("Enable AI assistance", isOn: $model.providerConfiguration.isEnabled)
                    .toggleStyle(.switch)

                OrbiterSegmentedTextControl(
                    selection: $model.providerConfiguration.kind,
                    items: LLMProviderKind.allCases.map { kind in
                        .init(id: kind, title: LocalizedStringKey(kind.title))
                    }
                )

                SecureField("API Key", text: $model.providerConfiguration.apiKey)
                    .orbiterInputChrome()
                TextField("Base URL", text: $model.providerConfiguration.baseURL)
                    .orbiterInputChrome()
                TextField("Model", text: $model.providerConfiguration.model)
                    .orbiterInputChrome()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Temperature")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(OrbiterColor.textMuted)
                        Spacer()
                        Text(model.providerConfiguration.temperature, format: .number.precision(.fractionLength(2)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(OrbiterColor.textMuted)
                    }
                    Slider(value: $model.providerConfiguration.temperature, in: 0...1)
                }
            }

            SummarySection(title: "Actions") {
                Button {
                    Task { await model.testLLMProvider() }
                } label: {
                    Label("Test Provider", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(model.isBusy)
                .buttonStyle(.orbiter(.secondary))

                Button {
                    model.resetProviderConfiguration()
                } label: {
                    Label("Reset Provider Settings", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.orbiter(.danger))

                if let message = model.llmStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(OrbiterColor.textMuted)
                }
            }
        }
        .navigationTitle("Model Provider")
    }
}
