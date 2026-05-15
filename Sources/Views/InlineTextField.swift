import AppKit
import SwiftUI

struct InlineTextField: NSViewRepresentable {
    @Binding var text: String
    var clickScreenPoint: NSPoint
    var onCommit: () -> Void
    var onCancel: (() -> Void)?

    func makeNSView(context: Context) -> CursorTextField {
        let field = CursorTextField()
        field.delegate = context.coordinator
        field.stringValue = text
        field.isBordered = false
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 13)
        field.focusRingType = .none
        field.drawsBackground = false
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.pendingClickScreen = clickScreenPoint
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: CursorTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: InlineTextField

        init(_ parent: InlineTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel?()
                return true
            }
            return false
        }
    }
}

final class NoSelectCell: NSTextFieldCell {
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: rect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: 0)
    }
}

final class CursorTextField: NSTextField {
    var pendingClickScreen: NSPoint?

    override class var cellClass: AnyClass? {
        get { NoSelectCell.self }
        set {}
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let clickPoint = pendingClickScreen {
            pendingClickScreen = nil
            DispatchQueue.main.async { [weak self] in
                self?.placeCursor(atScreenPoint: clickPoint)
            }
        }
        return result
    }

    private func placeCursor(atScreenPoint screenPoint: NSPoint) {
        guard let window = window,
              let editor = currentEditor() as? NSTextView else { return }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let editorPoint = editor.convert(windowPoint, from: nil)
        let index = editor.characterIndexForInsertion(at: editorPoint)
        if index != NSNotFound {
            editor.setSelectedRange(NSRange(location: min(index, editor.string.count), length: 0))
        }
    }
}
