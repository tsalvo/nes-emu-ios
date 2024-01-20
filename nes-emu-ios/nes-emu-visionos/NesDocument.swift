import SwiftUI
import UniformTypeIdentifiers

extension UTType {
	static var nesType: UTType {
		UTType(filenameExtension: "nes", conformingTo: .data)!
	}
}

public struct NesDocument: FileDocument {
	public let romData: Data

    public init() {
        self.romData = Data()
    }
    
    public static var readableContentTypes: [UTType] { [.nesType] }
    public static var writableContentTypes: [UTType] { [] }

    public init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		
		self.romData = data
	}
	
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = self.romData
		return .init(regularFileWithContents: data)
	}
}
