//
//  MacVerilogEditor.swift
//  macVerilog
//
//  Created by Ilie-Adrian Avramescu on 11/06/2026.
//
import SwiftUI
import AppKit

struct MacVerilogEditor: NSViewRepresentable {
    @Binding var text: String
    
    // Culori stil Xcode / Dark Mode Premium
    private let keywordColor = NSColor.systemPink
    private let typeColor = NSColor.systemOrange
    private let systemColor = NSColor.systemOrange // $dumpfile, $finish
    private let commentColor = NSColor.systemGreen
    private let textColor = NSColor.labelColor
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        
        // Configurări de bază pentru editor de cod
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // no loops if the code is identic
        if textView.string != text {
            textView.string = text
            applyHighlighting(to: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // --- Syntax highliting ---
    func applyHighlighting(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Reset style
        textStorage.addAttribute(.foregroundColor, value: textColor, range: fullRange)
        textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
        
        let code = textView.string
        
        // 1. Highliting syntax
        let rules: [(regex: String, color: NSColor)] = [
            // keywords
            ("\\b(module|endmodule|initial|always|begin|end|assign|input|output|posedge|negedge|if|else|case|endcase)\\b", keywordColor),
            // data types
            ("\\b(reg|wire|integer|parameter)\\b", typeColor),
            // system functions ($)
            ("\\$[a-zA-Z_0-9]+", systemColor),
            // comments (//...)
            ("//.*", commentColor)
        ]
        
        for rule in rules {
            if let regex = try? NSRegularExpression(pattern: rule.regex, options: []) {
                let matches = regex.matches(in: code, options: [], range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: rule.color, range: match.range)
                    if rule.color == keywordColor {
                        textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), range: match.range)
                    }
                }
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacVerilogEditor
        
        init(_ parent: MacVerilogEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            self.parent.applyHighlighting(to: textView)
        }
    }
}
