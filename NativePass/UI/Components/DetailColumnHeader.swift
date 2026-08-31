import SwiftUI

@Observable
final class DetailPaneController {
    var showEditButton = false
    var isEditing = false
    var canSave = false

    func configureHandlers(
        onEdit: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        editHandler = onEdit
        cancelHandler = onCancel
        saveHandler = onSave
    }

    fileprivate var editHandler: () -> Void = {}
    fileprivate var cancelHandler: () -> Void = {}
    fileprivate var saveHandler: () -> Void = {}

    func edit() { editHandler() }
    func cancel() { cancelHandler() }
    func save() { saveHandler() }

    func reset() {
        showEditButton = false
        isEditing = false
        canSave = false
        editHandler = {}
        cancelHandler = {}
        saveHandler = {}
    }
}

struct DetailToolbarActions: View {
    @Bindable var controller: DetailPaneController

    var body: some View {
        if controller.isEditing {
            Button("Cancel") { controller.cancel() }
            Button("Save") { controller.save() }
                .disabled(!controller.canSave)
        } else if controller.showEditButton {
            Button("Edit") { controller.edit() }
        }
    }
}

struct DetailPaneToolbarContent: ToolbarContent {
    @Bindable var controller: DetailPaneController

    private var hasActions: Bool {
        controller.isEditing || controller.showEditButton
    }

    var body: some ToolbarContent {
        if hasActions {
            ToolbarItemGroup(placement: .primaryAction) {
                DetailToolbarActions(controller: controller)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Color.clear
                    .frame(width: 44, height: 1)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
}
