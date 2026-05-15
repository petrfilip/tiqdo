import SwiftUI

struct FooterView: View {
    var body: some View {
        HStack {
            Text("v1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
            Spacer()
            Text("Ctrl + Q")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}
