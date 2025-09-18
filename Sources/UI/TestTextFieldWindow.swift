import Cocoa

class TestTextFieldWindow: NSWindowController {
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Text Field Test"
        window.center()
        
        let contentView = NSView()
        window.contentView = contentView
        
        // Create a simple text field using the standard approach
        let testField = NSTextField(string: "Test text here")
        testField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(testField)
        
        // Create a label
        let label = NSTextField(labelWithString: "Try copy/paste in this field:")
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            testField.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            testField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            testField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            testField.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
}