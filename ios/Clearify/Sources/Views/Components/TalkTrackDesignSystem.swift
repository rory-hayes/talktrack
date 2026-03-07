import SwiftUI

enum TalkTrackTheme {
    static let ink = Color(red: 0.11, green: 0.08, blue: 0.33)
    static let indigo = Color(red: 0.16, green: 0.10, blue: 0.46)
    static let lavender = Color(red: 0.75, green: 0.55, blue: 0.96)
    static let sky = Color(red: 0.36, green: 0.55, blue: 0.98)
    static let blush = Color(red: 0.98, green: 0.86, blue: 0.91)
    static let mist = Color(red: 0.94, green: 0.93, blue: 0.98)
    static let surface = Color.white.opacity(0.94)
    static let muted = Color(red: 0.46, green: 0.46, blue: 0.56)
    static let line = Color.white.opacity(0.7)
    static let accentGreen = Color(red: 0.67, green: 0.92, blue: 0.30)
    static let accentGreenSoft = Color(red: 0.91, green: 0.98, blue: 0.83)
}

struct TalkTrackBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [TalkTrackTheme.mist, Color(red: 0.99, green: 0.96, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(TalkTrackTheme.lavender.opacity(0.12))
                .frame(width: 320, height: 320)
                .offset(x: -120, y: -280)

            Circle()
                .fill(TalkTrackTheme.blush.opacity(0.25))
                .frame(width: 340, height: 340)
                .offset(x: 160, y: 300)
        }
    }
}

extension View {
    func talkTrackCard(radius: CGFloat = 30, opacity: Double = 0.96) -> some View {
        self
            .background(TalkTrackTheme.surface.opacity(opacity), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(TalkTrackTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 24, y: 12)
    }
}

struct TalkTrackSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(TalkTrackTheme.muted)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(TalkTrackTheme.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .talkTrackCard(radius: 22)
    }
}

struct TalkTrackSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(TalkTrackTheme.sky)
            }
        }
    }
}

struct TalkTrackModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : TalkTrackTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(TalkTrackTheme.indigo)
                        } else {
                            Capsule().fill(Color.white.opacity(0.72))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

struct TalkTrackBottomBar: View {
    @Binding var selectedTab: RootTab

    var body: some View {
        HStack(spacing: 18) {
            tabButton(tab: .home, icon: "house", label: "Home")
            tabButton(tab: .progress, icon: "list.bullet.rectangle.portrait", label: "Progress")
            tabButton(tab: .profile, icon: "person.crop.circle", label: "Profile")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(TalkTrackTheme.indigo, in: Capsule())
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    private func tabButton(tab: RootTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selectedTab == tab ? Color.white : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? TalkTrackTheme.indigo : Color.white)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(selectedTab == tab ? 0.96 : 0.68))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct TalkTrackHeroArtwork: View {
    var height: CGFloat = 360

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.63, green: 0.40, blue: 0.95), Color(red: 0.44, green: 0.32, blue: 0.97)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .frame(width: 180, height: 18)
                .offset(y: 18)

            HStack(alignment: .bottom, spacing: 14) {
                heroPillar(width: 64, height: 78, top: Color(red: 0.72, green: 0.69, blue: 0.98), bottom: Color(red: 0.17, green: 0.82, blue: 0.48))
                heroPillar(width: 78, height: 132, top: Color(red: 0.99, green: 0.85, blue: 0.37), bottom: Color(red: 0.92, green: 0.74, blue: 0.25))
                heroPillar(width: 76, height: 186, top: Color(red: 0.98, green: 0.45, blue: 0.72), bottom: Color(red: 0.25, green: 0.52, blue: 0.98))
            }
            .offset(y: -8)
        }
        .frame(height: height)
    }

    private func heroPillar(width: CGFloat, height: CGFloat, top: Color, bottom: Color) -> some View {
        RoundedRectangle(cornerRadius: width / 2, style: .continuous)
            .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
            )
    }
}

struct TalkTrackScenarioArtwork: View {
    let mode: ScenarioMode

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(backgroundGradient)

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 92, height: 92)
                .offset(x: 54, y: -30)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.22))
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(18))
                .offset(x: -40, y: 28)

            Image(systemName: iconName)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(height: 180)
    }

    private var iconName: String {
        switch mode {
        case .interview:
            return "briefcase.fill"
        case .workplace:
            return "bubble.left.and.bubble.right.fill"
        case .customer:
            return "person.2.fill"
        }
    }

    private var backgroundGradient: LinearGradient {
        switch mode {
        case .interview:
            return LinearGradient(colors: [Color(red: 0.89, green: 0.78, blue: 0.98), Color(red: 0.44, green: 0.60, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .workplace:
            return LinearGradient(colors: [Color(red: 0.98, green: 0.79, blue: 0.87), Color(red: 0.54, green: 0.63, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .customer:
            return LinearGradient(colors: [Color(red: 0.99, green: 0.85, blue: 0.88), Color(red: 0.75, green: 0.60, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct TalkTrackWaveView: View {
    var color: Color = TalkTrackTheme.accentGreen

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                wave(in: proxy.size, amplitude: 18, frequency: 1.6, phase: 0)
                    .stroke(color.opacity(0.72), lineWidth: 2)
                wave(in: proxy.size, amplitude: 24, frequency: 1.15, phase: .pi / 2)
                    .stroke(color.opacity(0.38), lineWidth: 2)
                wave(in: proxy.size, amplitude: 14, frequency: 2.2, phase: .pi)
                    .stroke(color.opacity(0.58), lineWidth: 1.5)
            }
        }
    }

    private func wave(in size: CGSize, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat) -> Path {
        Path { path in
            let midY = size.height * 0.55
            path.move(to: CGPoint(x: 0, y: midY))
            for x in stride(from: 0, through: size.width, by: 2) {
                let progress = x / size.width
                let angle = CGFloat(progress) * .pi * 2 * frequency + phase
                let y = midY + sin(angle) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}

struct TalkTrackStatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.muted)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(TalkTrackTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
