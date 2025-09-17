import Cocoa

extension NSImage {
    static func menuBarIcon() -> NSImage? {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        
        // First priority: Try generated PNG icons (best for menu bars)
        let pngPaths = [
            "\(currentDirectory)/icon/generated/MenuBarIcon_16@2x.png",
            "\(currentDirectory)/icon/generated/MenuBarIcon_16.png",
            "icon/generated/MenuBarIcon_16@2x.png",
            "icon/generated/MenuBarIcon_16.png",
            "./icon/generated/MenuBarIcon_16@2x.png",
            "./icon/generated/MenuBarIcon_16.png"
        ]
        
        for path in pngPaths {
            if fileManager.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path) {
                return configureMenuBarImage(image)
            }
        }
        
        // Second priority: Try ICNS files
        let icnsPaths = [
            "\(currentDirectory)/icon/AltanMon.icns",
            "icon/AltanMon.icns",
            "./icon/AltanMon.icns"
        ]
        
        for path in icnsPaths {
            if fileManager.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path) {
                return configureMenuBarImage(image)
            }
        }
        
        // Third priority: Try bundled resources
        if let resourceURL = Bundle.main.url(forResource: "AltanMon", withExtension: "icns"),
           let image = NSImage(contentsOf: resourceURL) {
            return configureMenuBarImage(image)
        }
        
        if let bundlePath = Bundle.main.path(forResource: "AltanMon", ofType: "icns"),
           let image = NSImage(contentsOfFile: bundlePath) {
            return configureMenuBarImage(image)
        }
        
        // Final fallback: create a simple icon programmatically
        return createFallbackMenuBarIcon()
    }
    
    private static func configureMenuBarImage(_ image: NSImage) -> NSImage {
        // Create a new image to avoid modifying the original
        let menuBarImage = NSImage(size: NSSize(width: 16, height: 16))
        menuBarImage.lockFocus()
        defer { menuBarImage.unlockFocus() }
        
        // Clear background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: NSSize(width: 16, height: 16)).fill()
        
        // Draw the original image scaled to fit
        image.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
        
        // Use template mode for proper macOS menu bar integration
        menuBarImage.isTemplate = true
        return menuBarImage
    }
    
    private static func createFallbackMenuBarIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        // Create a path similar to the logo design but simplified for menu bar
        let path = NSBezierPath()
        path.lineWidth = 1.0
        
        // Based on the SVG logo, create a simplified geometric shape
        // Main rectangular server shape
        let mainRect = NSRect(x: 2, y: 4, width: 12, height: 8)
        path.appendRect(mainRect)
        
        // Server indicator lines
        path.move(to: NSPoint(x: 4, y: 6))
        path.line(to: NSPoint(x: 12, y: 6))
        path.move(to: NSPoint(x: 4, y: 8))
        path.line(to: NSPoint(x: 12, y: 8))
        path.move(to: NSPoint(x: 4, y: 10))
        path.line(to: NSPoint(x: 12, y: 10))
        
        // Small indicator dots for activity
        let dot1 = NSRect(x: 13, y: 5, width: 1, height: 1)
        let dot2 = NSRect(x: 13, y: 7, width: 1, height: 1)
        path.appendRect(dot1)
        path.appendRect(dot2)
        
        NSColor.black.setStroke()
        NSColor.black.setFill()
        path.stroke()
        
        image.isTemplate = true
        return image
    }
}