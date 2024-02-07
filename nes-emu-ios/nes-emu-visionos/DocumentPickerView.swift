import UniformTypeIdentifiers
import SwiftUI

extension UTType {
    static var nesRom: UTType {
        UTType(filenameExtension: "nes", conformingTo: .data)!
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {

    @Binding var console: Console
    @Binding var tabSelection: Int
    
    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(console: $console, tabSelection: $tabSelection)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.nesRom])
        p.allowsMultipleSelection = false
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {

    }
}

class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    @Binding var console: Console
    @Binding var tabSelection: Int
    
    init(console: Binding<Console>, tabSelection: Binding<Int>) {
        _console = console
        _tabSelection = tabSelection
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first,
              url.startAccessingSecurityScopedResource() == true
        else {
            return
        }
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
            url.stopAccessingSecurityScopedResource()
        } catch {
            fileData = Data()
            print(error.localizedDescription)
        }
        var c = Console(withCartridge: Cartridge(fromData: fileData), sampleRate: ._44100Hz, audioFiltersEnabled: true, state: nil)
        c.reset()
        console = c
        tabSelection = 0
    }
}
