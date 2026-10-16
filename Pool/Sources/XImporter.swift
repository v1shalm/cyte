import AppKit
import Foundation
import Observation
import WebKit

@Observable
final class XImporter: NSObject, WKNavigationDelegate {
    enum Failure: Equatable { case limited, noPage, noLogin }

    enum Phase: Equatable {
        case idle, intro, loading, importing
        case done(Int)
        case failed(Failure)
    }

    var phase: Phase = .idle
    var found = 0
    var added = 0
    var connected = false
    var browserName: String?
    var lastSync: Date? = UserDefaults.standard.object(forKey: "pool.x.lastSync") as? Date {
        didSet { UserDefaults.standard.set(lastSync, forKey: "pool.x.lastSync") }
    }

    var isShown: Bool { phase != .idle }
    var isBusy: Bool { phase == .loading || phase == .importing }

    private(set) var webView: WKWebView?
    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private let ingestor: Ingestor
    @ObservationIgnored private var known: Set<String> = []
    @ObservationIgnored private var seen: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "pool.x.seen") ?? [])
    @ObservationIgnored private var incremental = false
    @ObservationIgnored private var queue: [Data] = []
    @ObservationIgnored private var draining = false
    @ObservationIgnored private var pageFinished = false
    @ObservationIgnored private var triedScroll = false
    @ObservationIgnored private var running = false
    @ObservationIgnored private var runStart = Date()
    @ObservationIgnored private var order = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var watchdog: Task<Void, Never>?

    private static let bookmarks = URL(string: "https://x.com/i/bookmarks")!
    private static let agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    init(store: LibraryStore, ingestor: Ingestor) {
        self.store = store
        self.ingestor = ingestor
        super.init()
        Task { await refreshConnection() }
    }

    var importedCount: Int { store.saves.reduce(0) { $0 + ($1.source == "x" ? 1 : 0) } }

    func open() {
        guard !isShown else { return }
        if connected {
            begin()
            return
        }
        phase = .intro
        Task {
            browserName = await Self.detect()
            if browserName == nil, phase == .intro { phase = .failed(.noLogin) }
        }
    }

    @concurrent
    private static func detect() async -> String? {
        BrowserLogin.find()?.browser.name
    }

    @concurrent
    private static func readLogin() async -> BrowserLogin? {
        BrowserLogin.load()
    }

    func begin() {
        guard connected else {
            phase = .loading
            Task {
                guard let login = await Self.readLogin() else {
                    fail(.noLogin)
                    return
                }
                let cookies = WKWebsiteDataStore.default().httpCookieStore
                for cookie in login.cookies { await cookies.setCookie(cookie) }
                await refreshConnection()
                if connected { begin() } else { fail(.noLogin) }
            }
            return
        }
        generation += 1
        found = 0
        added = 0
        order = 0
        queue = []
        pageFinished = false
        triedScroll = false
        running = false
        runStart = Date()
        known = seen.union(store.saves.compactMap { $0.source == "x" ? XTweet.id(in: $0.url) : nil })
        incremental = !known.isEmpty
        phase = .loading
        load(Self.bookmarks)
        armWatchdog()
    }

    func stop() {
        guard isBusy else { close(); return }
        webView?.evaluateJavaScript("window.__pool && (window.__pool.stop = true)")
        queue = []
        finish()
    }

    func close() {
        generation += 1
        queue = []
        teardown()
        phase = .idle
    }

    func disconnect() {
        close()
        seen = []
        remember()
        let store = WKWebsiteDataStore.default()
        Task {
            let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
            let matches = records.filter { $0.displayName.contains("x.com") || $0.displayName.contains("twitter.com") }
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: matches)
            connected = false
        }
    }

    func refreshConnection() async {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        connected = cookies.contains { cookie in
            cookie.name == "auth_token" && (cookie.domain.hasSuffix("x.com") || cookie.domain.hasSuffix("twitter.com"))
        }
    }

    private func load(_ url: URL) {
        let view = webView ?? makeWebView()
        webView = view
        view.load(URLRequest(url: url))
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .page))
        controller.add(MessageRelay(owner: self), contentWorld: .page, name: "pool")
        configuration.userContentController = controller
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 460, height: 640), configuration: configuration)
        view.customUserAgent = Self.agent
        view.navigationDelegate = self
        return view
    }

    private func teardown() {
        watchdog?.cancel()
        webView?.stopLoading()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView?.navigationDelegate = nil
        webView = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        guard let url = webView.url else { return }
        Task {
            await refreshConnection()
            if !connected || Self.isLogin(url) {
                connected = false
                fail(.noLogin)
            } else if url.path().hasPrefix("/i/bookmarks"), !running, phase == .loading {
                running = true
                phase = .importing
                _ = try? await webView.evaluateJavaScript("(window.__poolRun && window.__poolRun(), 0)")
            }
        }
    }

    private static func isLogin(_ url: URL) -> Bool {
        let path = url.path()
        return path.hasPrefix("/i/flow/login") || path.hasPrefix("/login") || path.hasPrefix("/i/flow/signup") || path == "/"
    }

    private func armWatchdog() {
        watchdog?.cancel()
        let current = generation
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(40))
            guard let self, !Task.isCancelled, current == self.generation, self.phase == .loading || (self.phase == .importing && self.found == 0) else { return }
            self.fail(.noPage)
        }
    }

    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String, isBusy else { return }
        switch type {
        case "page":
            guard let text = message["body"] as? String, let data = text.data(using: .utf8) else { return }
            if phase == .loading { phase = .importing }
            queue.append(data)
            drain()
        case "done":
            let reason = message["reason"] as? String ?? "end"
            switch reason {
            case "limited":
                if added > 0 { pageFinished = true; drainOrFinish() } else { fail(.limited) }
            case "error", "norequest":
                if !triedScroll {
                    triedScroll = true
                    webView?.evaluateJavaScript("window.__poolScroll && window.__poolScroll()")
                } else if found > 0 {
                    pageFinished = true
                    drainOrFinish()
                } else {
                    fail(.noPage)
                }
            default:
                pageFinished = true
                drainOrFinish()
            }
        default:
            break
        }
    }

    private func drainOrFinish() {
        if queue.isEmpty && !draining { finish() }
    }

    private func drain() {
        guard !draining else { return }
        draining = true
        let current = generation
        Task {
            while current == generation, !queue.isEmpty {
                let data = queue.removeFirst()
                let tweets = await Self.parse(data)
                var fresh = 0
                for tweet in tweets {
                    guard current == generation else { break }
                    found += 1
                    guard !known.contains(tweet.id) else { continue }
                    known.insert(tweet.id)
                    seen.insert(tweet.id)
                    fresh += 1
                    guard !tweet.media.isEmpty else { continue }
                    order += 1
                    if await ingestor.importTweet(tweet, at: runStart.addingTimeInterval(-Double(order))) > 0 {
                        added += 1
                    }
                }
                if incremental, fresh == 0, !tweets.isEmpty {
                    _ = try? await webView?.evaluateJavaScript("window.__pool && (window.__pool.stop = true)")
                }
            }
            draining = false
            if current == generation, pageFinished { finish() }
        }
    }

    @concurrent
    private static func parse(_ data: Data) async -> [XTweet] {
        XParser.tweets(in: data)
    }

    private func remember() {
        UserDefaults.standard.set(Array(seen), forKey: "pool.x.seen")
    }

    private func finish() {
        guard isBusy else { return }
        remember()
        generation += 1
        lastSync = Date()
        teardown()
        phase = .done(added)
        if added > 0 { SoundEngine.shared.play(.chime, volume: 0.7) }
    }

    private func fail(_ failure: Failure) {
        remember()
        generation += 1
        teardown()
        phase = .failed(failure)
    }

    private static let script = #"""
    (() => {
      if (window.__pool) return;
      const pool = window.__pool = { template: null, stop: false, replaying: false, pages: 0, cursor: null, last: -1 };
      const post = (m) => { try { window.webkit.messageHandlers.pool.postMessage(m); } catch (e) {} };
      const isBookmarks = (u) => /\/graphql\/[^/]+\/Bookmarks(\?|$)/.test(String(u || ''));
      const wait = (ms) => new Promise((r) => setTimeout(r, ms));
      const scan = (json) => {
        let cursor = null, tweets = 0;
        const walk = (o) => {
          if (!o || typeof o !== 'object') return;
          if (Array.isArray(o)) { for (const v of o) walk(v); return; }
          if (typeof o.entryId === 'string') {
            if (o.entryId.startsWith('tweet-')) tweets++;
            if (o.entryId.startsWith('cursor-bottom') && o.content && o.content.value) cursor = o.content.value;
          }
          for (const k in o) walk(o[k]);
        };
        walk(json);
        return { cursor, tweets };
      };
      const deliver = (text) => {
        pool.pages++;
        try { const r = scan(JSON.parse(text)); pool.last = r.tweets; if (r.cursor) pool.cursor = r.cursor; } catch (e) { pool.last = 0; }
        post({ type: 'page', body: text });
      };
      const plain = (h) => {
        const out = {};
        if (!h) return out;
        if (Array.isArray(h)) h.forEach(([k, v]) => { out[k] = v; });
        else if (typeof h.forEach === 'function') h.forEach((v, k) => { out[k] = v; });
        else Object.assign(out, h);
        return out;
      };
      const originalFetch = window.fetch.bind(window);
      window.fetch = function (input, init) {
        const url = typeof input === 'string' ? input : (input && input.url) || '';
        const promise = originalFetch(input, init);
        if (isBookmarks(url) && !pool.replaying) {
          pool.template = { url: String(url), headers: Object.assign(plain(input && input.headers), plain(init && init.headers)) };
          promise.then((res) => res.ok ? res.clone().text() : Promise.reject()).then(deliver).catch(() => {});
        }
        return promise;
      };
      const open = XMLHttpRequest.prototype.open, setHeader = XMLHttpRequest.prototype.setRequestHeader, send = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function (method, url) { this.__poolURL = String(url); this.__poolHeaders = {}; return open.apply(this, arguments); };
      XMLHttpRequest.prototype.setRequestHeader = function (k, v) { if (this.__poolHeaders) this.__poolHeaders[k] = v; return setHeader.apply(this, arguments); };
      XMLHttpRequest.prototype.send = function () {
        if (isBookmarks(this.__poolURL) && !pool.replaying) {
          pool.template = { url: this.__poolURL, headers: this.__poolHeaders };
          this.addEventListener('load', () => { if (this.status === 200) deliver(this.responseText); });
        }
        return send.apply(this, arguments);
      };
      window.__poolRun = async () => {
        for (let i = 0; i < 100 && !pool.template; i++) await wait(200);
        if (!pool.template) return post({ type: 'done', reason: 'norequest' });
        for (let i = 0; i < 50 && pool.pages === 0; i++) await wait(200);
        pool.replaying = true;
        let used = null;
        while (!pool.stop && pool.cursor && pool.cursor !== used && pool.last !== 0) {
          await wait(450);
          used = pool.cursor;
          const u = new URL(pool.template.url, location.origin);
          const vars = JSON.parse(u.searchParams.get('variables') || '{}');
          vars.cursor = used;
          u.searchParams.set('variables', JSON.stringify(vars));
          let res;
          try { res = await originalFetch(u.toString(), { headers: pool.template.headers, credentials: 'include' }); }
          catch (e) { pool.replaying = false; return post({ type: 'done', reason: 'error' }); }
          if (res.status === 429) { pool.replaying = false; return post({ type: 'done', reason: 'limited' }); }
          if (!res.ok) { pool.replaying = false; return post({ type: 'done', reason: 'error' }); }
          deliver(await res.text());
        }
        pool.replaying = false;
        post({ type: 'done', reason: pool.stop ? 'stopped' : 'end' });
      };
      window.__poolScroll = async () => {
        pool.replaying = false;
        let idle = 0, seen = pool.pages;
        while (!pool.stop && idle < 8 && pool.last !== 0) {
          window.scrollTo(0, document.documentElement.scrollHeight);
          await wait(1500);
          if (pool.pages === seen) idle++; else { idle = 0; seen = pool.pages; }
        }
        post({ type: 'done', reason: pool.stop ? 'stopped' : 'end' });
      };
    })();
    """#
}

private final class MessageRelay: NSObject, WKScriptMessageHandler {
    weak var owner: XImporter?

    init(owner: XImporter) {
        self.owner = owner
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.receive(message.body)
    }
}
