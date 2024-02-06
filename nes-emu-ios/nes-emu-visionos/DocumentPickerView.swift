import UniformTypeIdentifiers
import SwiftUI

extension UTType {
    static var nesRom: UTType {
        UTType(filenameExtension: "nes", conformingTo: .data)!
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {

    @Binding var console: Console
    
    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(console: $console)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.nesRom])
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {

    }
}

class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    @Binding var console: Console
    
    init(console: Binding<Console>) {
        _console = console
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
        var c = Console(withCartridge: Cartridge(fromData: fileData), sampleRate: ._22050Hz, audioFiltersEnabled: false, state: nil)
        c.reset()
        console = c
    }
}
