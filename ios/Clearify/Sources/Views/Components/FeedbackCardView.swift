import SwiftUI

struct FeedbackCardView: View {
    let response: AnalyzeRepResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Score \(response.workClarityScore)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.ink)
                    Text(response.strength)
                        .font(.subheadline)
                        .foregroundStyle(TalkTrackTheme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(response.pacingBand.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(TalkTrackTheme.indigo)
                    Text("\(response.speechMetrics.wpm) WPM")
                        .font(.footnote)
                        .foregroundStyle(TalkTrackTheme.muted)
                }
            }

            HStack(spacing: 10) {
                pillarScore(title: "Structure", value: response.breakdown.structure)
                pillarScore(title: "Clarity", value: response.breakdown.clarity)
                pillarScore(title: "Concise", value: response.breakdown.conciseness)
                pillarScore(title: "Delivery", value: response.breakdown.delivery)
            }

            feedbackSection(title: "Main fix", body: response.primaryImprovement)
            feedbackSection(title: "Use this structure", body: response.suggestedStructure)

            if let deliveryNote {
                feedbackSection(title: "Delivery note", body: deliveryNote)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Example response")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(response.rewrittenExample)
                    .foregroundStyle(TalkTrackTheme.ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Next try")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.ink)
                Text(response.retryInstruction)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(TalkTrackTheme.indigo)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(22)
        .talkTrackCard(radius: 30)
    }

    private func feedbackSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(body)
                .font(.callout)
                .foregroundStyle(TalkTrackTheme.ink)
        }
    }

    private func pillarScore(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(TalkTrackTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var deliveryNote: String? {
        var parts: [String] = [response.fillerHotspot, response.pacingBand.guidance]

        if response.openingOverlong {
            parts.append("Your opening ran long before the main point landed.")
        }
        if response.weakConclusion {
            parts.append("The ending needs a firmer result or next step.")
        }

        let trimmed = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return trimmed.isEmpty ? nil : trimmed.joined(separator: " ")
    }
}
