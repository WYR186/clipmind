import SwiftUI
import AppKit

// MARK: - Single-line text input

struct MacTextInputField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    var characterLimit: Int? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.isBezeled = true
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .default
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // ✅ 唯一安全策略：updateNSView 完全不碰 stringValue。
        // 文字内容只由用户输入 → delegate → @Binding 单向流动。
        // 仅更新 placeholder（纯展示属性，不影响编辑状态）。
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextInputField
        init(_ parent: MacTextInputField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            var value = field.stringValue
            if let limit = parent.characterLimit, value.count > limit {
                value = String(value.prefix(limit))
                field.stringValue = value
            }
            parent.text = value
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

// MARK: - Secure single-line input (for API keys / passwords)

struct MacSecureInputField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.isBezeled = true
        field.isEditable = true
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacSecureInputField
        init(_ parent: MacSecureInputField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
        }
    }
}

// MARK: - Multiline text input

struct MacMultilineTextInputField: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.backgroundColor = .textBackgroundColor
        tv.drawsBackground = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.heightTracksTextView = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.string = text

        scrollView.documentView = tv
        context.coordinator.textView = tv
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // ✅ 同上：updateNSView 完全不碰 string 内容，避免重绘时覆盖用户输入。
        if let tv = nsView.documentView as? NSTextView {
            tv.isEditable = isEditable
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMultilineTextInputField
        weak var textView: NSTextView?
        init(_ parent: MacMultilineTextInputField) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

// MARK: - Convenience: text field with character count indicator

struct LimitedTextInputField: View {
    let placeholder: String
    @Binding var text: String
    let limit: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            MacTextInputField(placeholder: placeholder, text: $text, characterLimit: limit)
            Text("\(text.count)/\(limit)")
                .font(.caption2)
                .foregroundStyle(text.count >= limit ? .red : .secondary)
        }
    }
}
