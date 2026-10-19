import AppKit
import ApplicationServices

/// Finds the on-screen rectangle of the text cursor in the frontmost app
/// through the Accessibility API, so the panel can appear right under it — like Win+V.
enum CaretLocator {
    /// Caret rectangle in Cocoa screen coordinates (origin at the bottom left).
    static func caretRect() -> NSRect? {
        guard Accessibility.isTrusted else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.15)

        guard let element: AXUIElement = copyAttribute(systemWide, kAXFocusedUIElementAttribute) else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.15)

        guard let range: AXValue = copyAttribute(element, kAXSelectedTextRangeAttribute) else { return nil }

        var boundsValue: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &boundsValue
        )
        guard status == .success, let boundsValue, CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else { return nil }

        // Some apps (Electron, terminals) report an empty rect at the origin.
        guard rect.origin != .zero, rect.width >= 0, rect.height > 0, rect.height < 400 else { return nil }

        // Accessibility uses a top-left origin anchored to the primary screen.
        guard let primary = NSScreen.screens.first else { return nil }
        let flipped = NSRect(
            x: rect.minX,
            y: primary.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        guard NSScreen.screens.contains(where: { $0.frame.intersects(flipped.insetBy(dx: -1, dy: -1)) }) else { return nil }
        return flipped
    }

    private static func copyAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
