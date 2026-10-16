import SwiftUI

struct SettingsView: View {
    private let store = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.Appearance.title)
                .font(Theme.serif(28))
                .foregroundStyle(Theme.ink)
            Text(L.Appearance.body)
                .font(Theme.ui(13))
                .foregroundStyle(Theme.secondary)
                .padding(.top, 6)
            HStack(spacing: 18) {
                ForEach(ThemeKind.allCases) { kind in
                    ThemeCard(kind: kind, selected: store.kind == kind) { store.set(kind) }
                }
            }
            .padding(.top, 24)
        }
        .padding(30)
        .frame(width: 780)
        .background(Theme.surface)
        .preferredColorScheme(.light)
    }
}

private struct ThemeCard: View {
    let kind: ThemeKind
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 12) {
                ThemePreview(kind: kind)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected ? Theme.ink : (hovering ? Theme.ink.opacity(0.15) : .clear), lineWidth: 2)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Theme.ink))
                                .offset(x: 6, y: -6)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.name)
                        .font(Theme.ui(14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(L.Appearance.description(kind))
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: selected)
        .accessibilityLabel(kind.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ThemePreview: View {
    let kind: ThemeKind

    private var bold: Bool { kind != .white }
    private var canvas: Color { Theme.accent(for: kind) }
    private var control: Color { bold ? Theme.ink(for: kind) : .white }
    private var side: Color { bold ? Theme.ink(for: kind) : .white }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let sideWidth: CGFloat = 46
            let gridX = sideWidth + 16
            let gridWidth = width - gridX - 10
            let column = (gridWidth - 12) / 3
            ZStack(alignment: .topLeading) {
                canvas
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(side)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(bold ? .clear : Theme.hairline))
                    .frame(width: sideWidth, height: proxy.size.height - 12)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Capsule().fill(bold ? Color.white.opacity(0.3) : Theme.ink.opacity(0.15)).frame(width: 18, height: 3)
                            RoundedRectangle(cornerRadius: 3).fill(bold ? canvas : .white).frame(width: 34, height: 8)
                                .shadow(color: .black.opacity(bold ? 0 : 0.08), radius: 2, y: 1)
                            Capsule().fill(bold ? Color.white.opacity(0.3) : Theme.ink.opacity(0.15)).frame(width: 24, height: 3)
                        }
                        .padding(.top, 18)
                        .padding(.leading, 6)
                    }
                    .offset(x: 6, y: 6)

                Capsule().fill(control).overlay(Capsule().strokeBorder(bold ? .clear : Theme.hairline)).frame(width: gridWidth * 0.5, height: 9)
                    .offset(x: gridX + gridWidth * 0.25, y: 10)
                HStack(spacing: 2) {
                    Capsule().fill(bold ? canvas : .white).frame(width: 16, height: 5)
                        .shadow(color: .black.opacity(bold ? 0 : 0.1), radius: 1)
                    Capsule().fill(bold ? Color.white.opacity(0.35) : Theme.ink.opacity(0.2)).frame(width: 10, height: 3)
                    Capsule().fill(bold ? Color.white.opacity(0.35) : Theme.ink.opacity(0.2)).frame(width: 10, height: 3)
                }
                .padding(2)
                .background(Capsule().fill(control).overlay(Capsule().strokeBorder(bold ? .clear : Theme.hairline)))
                .offset(x: gridX + gridWidth * 0.5 - 22, y: 24)
                Capsule().fill(Theme.ink(for: kind)).frame(width: 22, height: 9)
                    .offset(x: width - 32, y: 10)

                HStack(alignment: .top, spacing: 6) {
                    tiles([46, 30, 40], width: column, shade: 0)
                    tiles([30, 52, 26], width: column, shade: 1)
                    tiles([38, 34, 44], width: column, shade: 2)
                }
                .offset(x: gridX, y: 40)
            }
        }
    }

    private func tiles(_ heights: [CGFloat], width: CGFloat, shade: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tone(shade + index))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.hairline))
                    .frame(width: width, height: height)
            }
        }
    }

    private func tone(_ index: Int) -> Color {
        let tones: [Color] = [
            Color(white: 0.2), .white, Color(red: 0.78, green: 0.8, blue: 0.86),
            Color(red: 0.86, green: 0.82, blue: 0.76), .white, Color(white: 0.35),
        ]
        return tones[index % tones.count]
    }
}
