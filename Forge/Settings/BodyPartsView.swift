import SwiftUI
import SwiftData

/// Add, rename and remove custom body parts. Built-ins are listed for
/// reference but can't be changed.
struct BodyPartsView: View {
    @Environment(\.modelContext) private var context

    @State private var custom: [BodyPart] = []
    @State private var draft = ""
    @State private var renaming: BodyPart?
    @State private var renameDraft = ""
    @State private var error: String?

    private let catalog = BodyPartCatalog()

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("New body part", text: $draft)
                    .limitedLength($draft)
                        .textInputAutocapitalization(.words)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                SectionLabel("Custom").textCase(nil)
            } footer: {
                if custom.isEmpty {
                    Text("Body parts you add appear in the exercise editor alongside the built-in ones.")
                }
            }

            if !custom.isEmpty {
                Section {
                    ForEach(custom) { part in
                        HStack {
                            Text(part.displayName)
                            Spacer()
                            let uses = catalog.usageCount(of: part, in: context)
                            if uses > 0 {
                                Text("^[\(uses) exercise](inflect: true)")
                                    .font(ForgeType.meta)
                                    .foregroundStyle(ForgeColor.ink3)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) { remove(part) }
                                .tint(.red)
                            Button("Rename", systemImage: "pencil") {
                                renameDraft = part.displayName
                                renaming = part
                            }
                            .tint(.gray)
                        }
                    }
                }
            }

            Section {
                ForEach(BodyPart.builtIn) { part in
                    Text(part.displayName).foregroundStyle(ForgeColor.ink2)
                }
            } header: {
                SectionLabel("Built in").textCase(nil)
            }
        }
        .forgeForm()
        .navigationTitle("Body parts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { custom = catalog.custom }
        .alert("Rename body part", isPresented: Binding(
            get: { renaming != nil }, set: { if !$0 { renaming = nil } }
        ), presenting: renaming) { part in
            TextField("Name", text: $renameDraft)
            Button("Rename") { rename(part) }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: { part in
            Text("Exercises tagged \(part.displayName) will follow the new name.")
        }
        .alert("Can't do that", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func add() {
        do {
            try catalog.add(draft)
            Haptics.tap()
            draft = ""
            custom = catalog.custom
        } catch {
            self.error = Self.describe(error)
        }
    }

    private func rename(_ part: BodyPart) {
        do {
            try catalog.rename(part, to: renameDraft, in: context)
            Haptics.tap()
            custom = catalog.custom
        } catch {
            self.error = Self.describe(error)
        }
        renaming = nil
    }

    private func remove(_ part: BodyPart) {
        do {
            try catalog.remove(part, in: context)
            Haptics.heavy()
            custom = catalog.custom
        } catch {
            self.error = Self.describe(error)
        }
    }

    private static func describe(_ error: Swift.Error) -> String {
        switch error as? BodyPartCatalog.Error {
        case .emptyName: "Give it a name first."
        case .duplicate: "There's already a body part with that name."
        case let .inUse(count): "^[\(count) exercise](inflect: true) still use it. Retag them first."
        case nil: error.localizedDescription
        }
    }
}
