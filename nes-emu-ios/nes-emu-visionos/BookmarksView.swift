import SwiftUI

struct BookmarksView: View {
    @Binding var showBookmarks: Bool
    var body: some View {
        VStack {
            Button.init("", systemImage: "xmark") {
                showBookmarks = false
            }
            Text("Bookmarks")
        }
    }
}
