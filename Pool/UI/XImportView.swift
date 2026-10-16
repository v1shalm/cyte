import SwiftUI
import WebKit

struct XImportView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let importer = model.xImport
        card
            .onKeyPress(.escape) {
            importer.stop()
            return .handled
        }
    }

    private var card: some View {
        let importer = model.xImport
        return VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.ink))
                .contentTransition(.symbolEffect(.replace))
                .padding(.bottom, 22)

            switch importer.phase {
            case .intro:
                title(L.X.introTitle)
                paragraph(L.X.introBody(importer.browserName))
                Text(L.X.introPrivacy)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 10)
                actions {
                    Button(L.X.cancel) { importer.close() }.poolSecondary(.first)
                    Button(L.X.start) { importer.begin() }
                        .poolPrimary(.last)
                        .disabled(importer.browserName == nil)
                }
            case .loading, .importing:
                title(importer.phase == .loading ? L.X.loading : L.X.importing)
                Text("\(importer.added)")
                    .font(Theme.serif(64, light: true))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(importer.added)))
                    .animation(.snappy(duration: 0.25), value: importer.added)
                    .padding(.top, 14)
                paragraph(L.X.progress(found: importer.found, added: importer.added))
                Text(L.X.keepOpen)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 6)
                actions {
                    Button(L.X.stop) { importer.stop() }.poolSecondary()
                }
            case .done(let count):
                title(L.X.doneTitle(count))
                if count > 0 { paragraph(L.X.doneBody) }
                actions {
                    Button(L.X.done) { importer.close() }.modifier(DoneStyle(prominent: count == 0, segment: count > 0 ? .first : .alone))
                    if count > 0 {
                        Button(L.X.showThem) {
                            importer.close()
                            model.folderID = nil
                            model.kind = nil
                            model.query = ""
                            model.bookmarksOnly = true
                        }
                        .poolPrimary(.last)
                    }
                }
            case .failed(let failure):
                title(failure == .noLogin ? L.X.noLoginTitle : L.X.failedTitle)
                paragraph(failure == .noLogin ? L.X.noLogin : failure == .limited ? L.X.failedLimited : L.X.failedNoPage)
                actions {
                    Button(L.X.close) { importer.close() }.poolSecondary(.first)
                    Button(L.X.tryAgain) { importer.begin() }.poolPrimary(.last)
                }
            case .idle:
                EmptyView()
            }
        }
        .padding(28)
        .frame(width: 420, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
        .borderBeam(size: .line, strength: 0.5, active: importer.isBusy, cornerRadius: 22, duration: 1.6)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.12), radius: 40, y: 20)
        .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.25), value: importer.phase)
    }

    private var symbol: String {
        switch model.xImport.phase {
        case .done: "checkmark"
        case .failed: "exclamationmark"
        case .loading, .importing: "arrow.down"
        default: "bookmark.fill"
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Theme.serif(26))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Theme.ui(13.5))
            .lineSpacing(3)
            .foregroundStyle(Theme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
    }

    private func actions<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) {
            Spacer()
            content()
        }
        .padding(.top, 26)
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

struct WebHost: NSViewRepresentable {
    let view: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if view.superview !== container { attach(to: container) }
    }

    private func attach(to container: NSView) {
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}

private struct DoneStyle: ViewModifier {
    let prominent: Bool
    var segment: Segment = .alone

    @ViewBuilder func body(content: Content) -> some View {
        if prominent { content.poolPrimary(segment) } else { content.poolSecondary(segment) }
    }
}
