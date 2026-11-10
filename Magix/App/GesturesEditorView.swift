import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GesturesEditorView: View {
    @ObservedObject var appModel: AppModel
    @State private var editorItem: GestureBinding?
    @State private var isAdding = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if appModel.config.bindings.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(appModel.config.bindings) { binding in
                        GestureBindingRow(
                            binding: binding,
                            onToggle: { enabled in
                                appModel.setBindingEnabled(id: binding.id, enabled: enabled)
                            },
                            onEdit: {
                                isAdding = false
                                editorItem = binding
                            },
                            onDelete: {
                                appModel.deleteBinding(id: binding.id)
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            footer
        }
        .sheet(item: $editorItem) { binding in
            GestureBindingEditorSheet(
                title: isAdding ? "Add Gesture" : "Edit Gesture",
                binding: binding,
                onCancel: { editorItem = nil },
                onSave: { updated in
                    appModel.saveBinding(updated)
                    editorItem = nil
                }
            )
            .frame(width: 460, height: 520)
        }
        .confirmationDialog("Reset all gestures to Magix defaults?", isPresented: $showResetConfirm) {
            Button("Reset to Defaults", role: .destructive) {
                appModel.resetBindingsToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gesture mappings")
                    .font(.headline)
                Text("Add a gesture, pick an action, save. Changes apply immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isAdding = true
                editorItem = GestureBinding(
                    name: "",
                    gestureKind: .twoFingerSwipeLeft,
                    action: .keyboardShortcut,
                    parameters: .empty,
                    requiresModifier: true,
                    requiredModifiers: [.option],
                    enabled: true
                )
            } label: {
                Label("Add Gesture", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.draw")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No gesture mappings yet")
                .font(.title3.weight(.semibold))
            Text("Add a mapping, or restore the Magix defaults (swipe up/down + pinch zoom).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            HStack {
                Button("Add Gesture") {
                    isAdding = true
                    editorItem = GestureBinding(
                        gestureKind: .twoFingerSwipeUp,
                        action: .missionControl
                    )
                }
                .buttonStyle(.borderedProminent)
                Button("Restore Defaults") {
                    appModel.resetBindingsToDefaults()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack {
            Button("Restore Defaults…") { showResetConfirm = true }
            Spacer()
            Toggle("Modifier-gate pinch/zoom templates", isOn: Binding(
                get: { appModel.config.requireModifiersForTemplates },
                set: { value in
                    var next = appModel.config
                    next.requireModifiersForTemplates = value
                    appModel.updateConfig(next)
                }
            ))
            .toggleStyle(.checkbox)
            .help("When on, pinch/scroll-zoom kinds require a modifier (⌥ by default unless overridden).")
        }
        .padding(12)
    }
}

private struct GestureBindingRow: View {
    let binding: GestureBinding
    var onToggle: (Bool) -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: binding.gestureKind.symbolName)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(binding.displayTitle)
                    .font(.body.weight(.medium))
                Text(binding.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { binding.enabled },
                set: onToggle
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Button("Edit", action: onEdit)
                .controlSize(.small)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .help("Delete mapping")
        }
        .padding(.vertical, 4)
    }
}

private struct GestureBindingEditorSheet: View {
    let title: String
    @State private var binding: GestureBinding
    var onCancel: () -> Void
    var onSave: (GestureBinding) -> Void

    @State private var selectedTemplateID: String?

    init(
        title: String,
        binding: GestureBinding,
        onCancel: @escaping () -> Void,
        onSave: @escaping (GestureBinding) -> Void
    ) {
        self.title = title
        self._binding = State(initialValue: binding)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            .padding()

            Form {
                Section("Quick start") {
                    Picker("Template", selection: $selectedTemplateID) {
                        Text("Custom…").tag(String?.none)
                        ForEach(GestureTemplateCatalog.all) { template in
                            Text(template.name).tag(Optional(template.id))
                        }
                    }
                    .onChange(of: selectedTemplateID) { _, newValue in
                        guard let newValue,
                              let template = GestureTemplateCatalog.all.first(where: { $0.id == newValue })
                        else { return }
                        applyTemplate(template)
                    }
                }

                Section("Gesture") {
                    TextField("Name (optional)", text: $binding.name)
                    Picker("Type", selection: $binding.gestureKind) {
                        ForEach(GestureKind.allCases) { kind in
                            Label(kind.displayName, systemImage: kind.symbolName).tag(kind)
                        }
                    }
                    Toggle("Require modifier key", isOn: $binding.requiresModifier)
                    if binding.requiresModifier {
                        ModifierPicker(modifiers: $binding.requiredModifiers)
                    }
                    Toggle("Enabled", isOn: $binding.enabled)
                }

                Section("Action") {
                    Picker("Action", selection: $binding.action) {
                        ForEach(MagixAction.allCases.filter { $0 != .none }) { action in
                            Text(action.displayName).tag(action)
                        }
                    }

                    if binding.action == .keyboardShortcut {
                        keyboardFields
                    }
                    if binding.action == .openApp {
                        openAppFields
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Save") {
                    onSave(normalizedBinding())
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding()
        }
    }

    private var keyboardFields: some View {
        Group {
            Picker("Key", selection: Binding(
                get: { binding.parameters.keyCode ?? 17 },
                set: { code in
                    binding.parameters.keyCode = code
                    binding.parameters.keyCharacter = ShortcutKeyCatalog.items.first(where: { $0.keyCode == code })?.label
                }
            )) {
                ForEach(ShortcutKeyCatalog.items) { item in
                    Text(item.label).tag(item.keyCode)
                }
            }
            ModifierPicker(title: "Shortcut modifiers", modifiers: Binding(
                get: { binding.parameters.keyModifiers },
                set: { binding.parameters.keyModifiers = $0 }
            ))
        }
    }

    private var openAppFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(binding.parameters.appPath?.isEmpty == false
                  ? binding.parameters.appPath!
                  : "No app selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Button("Choose Application…") {
                chooseApp()
            }
        }
    }

    private var canSave: Bool {
        switch binding.action {
        case .keyboardShortcut:
            return binding.parameters.keyCode != nil
        case .openApp:
            return !(binding.parameters.appPath ?? "").isEmpty
        case .none:
            return false
        default:
            return true
        }
    }

    private func applyTemplate(_ template: GestureTemplate) {
        binding.name = template.name
        binding.gestureKind = template.gestureKind
        binding.action = template.suggestedAction
        binding.requiresModifier = template.requiresModifier
        binding.requiredModifiers = template.defaultModifiers
        if template.suggestedAction == .keyboardShortcut, binding.parameters.keyCode == nil {
            binding.parameters.keyCode = 123 // ← as a sensible starter for “Back”
            binding.parameters.keyCharacter = "←"
            binding.parameters.keyModifiers = [.command]
        }
    }

    private func normalizedBinding() -> GestureBinding {
        var next = binding
        if next.requiresModifier, next.requiredModifiers.isEmpty {
            next.requiredModifiers = [.option]
        }
        if next.action == .keyboardShortcut, next.parameters.keyCharacter == nil,
           let code = next.parameters.keyCode {
            next.parameters.keyCharacter = ShortcutKeyCatalog.items.first(where: { $0.keyCode == code })?.label
        }
        return next
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            binding.parameters.appPath = url.path
        }
    }
}

private struct ModifierPicker: View {
    var title: String = "Modifiers"
    @Binding var modifiers: ModifierSet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                toggle("⌃", .control)
                toggle("⌥", .option)
                toggle("⇧", .shift)
                toggle("⌘", .command)
            }
        }
    }

    private func toggle(_ label: String, _ flag: ModifierSet) -> some View {
        Toggle(label, isOn: Binding(
            get: { modifiers.contains(flag) },
            set: { on in
                if on { modifiers.insert(flag) } else { modifiers.remove(flag) }
            }
        ))
        .toggleStyle(.button)
    }
}
