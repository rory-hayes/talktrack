import SwiftUI

struct SparklineChart: View {
    let values: [Double]
    let lineColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let points = normalizedPoints(width: width, height: height)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.001))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)

        return values.enumerated().map { index, value in
            let x = values.count == 1 ? width / 2 : CGFloat(index) / CGFloat(values.count - 1) * width
            let normalized = (value - minValue) / range
            let y = height - (CGFloat(normalized) * max(height - 8, 1)) - 4
            return CGPoint(x: x, y: y)
        }
    }
}
