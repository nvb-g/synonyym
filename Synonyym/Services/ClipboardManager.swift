import AppKit

final class ClipboardManager {
    private var savedItems: [[NSPasteboard.PasteboardType: Data]] = []
    private var savedChangeCount: Int = 0

    func save() {
        let pasteboard = NSPasteboard.general
        savedChangeCount = pasteboard.changeCount
        savedItems = []

        guard let items = pasteboard.pasteboardItems else { return }
        for item in items {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            savedItems.append(itemData)
        }
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        for itemData in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }

    func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Returns current pasteboard change count (increments on each clipboard write)
    var changeCount: Int {
        NSPasteboard.general.changeCount
    }

    func writeString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
