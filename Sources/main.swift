import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set activation policy for a status bar application
app.setActivationPolicy(.accessory)

app.run()
