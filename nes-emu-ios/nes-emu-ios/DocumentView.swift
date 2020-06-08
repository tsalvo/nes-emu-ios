//
//  NesRomView.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import SwiftUI

struct ScreenView: View {
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
            .padding(.all)
            .frame(width: 256, height: 224)
            .foregroundColor(.gray)
            Spacer()
        }
    }
}

struct HeaderInfoView: View {
    @Binding var document: NesRomDocument
    var body: some View {
        VStack {
            Text("Mapper").font(.system(size: 10))
            Text("\(document.nesRom?.data.count ?? 0) bytes").font(.system(size: 10))
            Text("\(document.nesRom?.numPrgBlocks ?? 0)x PRG").font(.system(size: 10))
            Text("\(document.nesRom?.numChrBlocks ?? 0)x CHR").font(.system(size: 10))
        }
    }
}

struct ControlsView: View {
    var body: some View {
        HStack {
            HStack {
                Button("lt", action: {})
                VStack {
                    Button("up", action: {})
                    Spacer()
                    Button("dn", action: {})
                }
                Button("rt", action: {})
            }
            .frame(width: 100.0)
            Spacer()
            HStack {
                Button("sl", action: {})
                    .frame(width: 30.0)
                Button("st", action: {})
            }
            .frame(width: 60.0)
            Spacer()
            HStack {
                Button("b", action: {})
                    .frame(width: 30.0)
                Button("a", action: {})
                    .frame(width: 30.0)
            }
            .frame(width: 60.0)
        }
        .padding(.all)
        .frame(height: 100.0)
        
    }
}

struct NesRomView: View {
    @State var document: NesRomDocument
    var dismiss: () -> Void

    var body: some View {
        
        VStack(alignment: .leading) {
            
            HStack {
                Spacer()
                Text(document.fileURL.lastPathComponent)
                    .lineLimit(1)
                    .padding(.horizontal)
                Spacer()
                Button("Done", action: dismiss)
                    .padding(.horizontal)
            }
            .frame(height: 60.0)
            .navigationBarTitle("Navigation")
            
            Spacer()
            
            HeaderInfoView(document: $document)
            
            Spacer()
            
            ScreenView()
            
            Spacer()
            
            ControlsView()
        }
    }
}


struct DocumentView_Previews: PreviewProvider {
    static var previews: some View {
        NesRomView(document: NesRomDocument(fileURL: URL.init(fileURLWithPath: "test-rom.nes"))) {
            
        }
        .padding()
    }
}
