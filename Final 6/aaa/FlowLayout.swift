import SwiftUI

struct FlowLayout<Data, ID, ItemView: View>: View where Data: RandomAccessCollection, ID: Hashable {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    let spacing: CGFloat
    let itemView: (Data.Element) -> ItemView

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(height: 1)
                .readSize { size in
                    availableWidth = size.width
                }

            let rows = computeRows()
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<rows.count, id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(rows[rowIndex], id: id) { element in
                            itemView(element)
                        }
                    }
                }
            }
        }
    }

    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = []
        var currentRow: [Data.Element] = []
        var currentWidth: CGFloat = 0
        let itemSpacing = self.spacing

        for element in data {
            let elementWidth = self.width(for: element)

            if currentWidth + elementWidth + (currentRow.isEmpty ? 0 : itemSpacing) > availableWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0
            }

            currentRow.append(element)
            currentWidth += elementWidth + (currentRow.count == 1 ? 0 : itemSpacing)
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }
    
    private func width(for element: Data.Element) -> CGFloat {
        let view = itemView(element)
        let hostingController = UIHostingController(rootView: view)
        let size = hostingController.sizeThatFits(in: UIScreen.main.bounds.size)
        return size.width
    }
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}   
