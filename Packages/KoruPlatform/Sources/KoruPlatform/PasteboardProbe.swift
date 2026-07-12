import AppKit
import Foundation
import KoruDomain

public struct PasteboardSnapshot: Sendable, Equatable {
    public var changeCount: Int
    public var itemCount: Int
    public var broadTypes: Set<ContentType>
}

public final class PasteboardProbe: @unchecked Sendable {
    private let pasteboard: NSPasteboard
    public init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }
    public func inspect() -> PasteboardSnapshot {
        var broadTypes = Set<ContentType>()
        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                if type == .string { broadTypes.insert(.plainText) }
                else if type == .rtf || type == .html { broadTypes.insert(.richText) }
                else if type == .URL { broadTypes.insert(.url) }
                else if type == .fileURL { broadTypes.insert(.fileReference) }
                else if type == .png || type == .tiff { broadTypes.insert(.image) }
                else { broadTypes.insert(.unsupported) }
            }
        }
        return .init(changeCount: pasteboard.changeCount, itemCount: pasteboard.pasteboardItems?.count ?? 0, broadTypes: broadTypes)
    }
    public func copyOnly(_ text: String) -> Bool {
        KoruPasteboardOrigin.write(text, to: pasteboard)
    }
}
