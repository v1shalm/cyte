import Foundation
import Testing
@testable import Cyte

struct SearchRankingTests {
    private func save(title: String, note: String = "", ocr: String? = nil) -> Save {
        var save = Save(kind: .image, title: title)
        save.note = note
        save.ocrText = ocr
        return save
    }

    @Test func `a match in the why ranks above a match in image text`() {
        let screenshot = save(title: "Dashboard", ocr: "pricing page layout")
        let reason = save(title: "Stripe page", note: "pricing idea for the TIST deck")
        let ranked = SearchEngine.ranked([screenshot, reason], words: ["pricing"])
        #expect(ranked.map(\.id) == [reason.id, screenshot.id])
    }

    @Test func `equal scores keep the incoming order`() {
        let newer = save(title: "Motion study")
        let older = save(title: "Motion reference")
        let ranked = SearchEngine.ranked([newer, older], words: ["motion"])
        #expect(ranked.map(\.id) == [newer.id, older.id])
    }

    @Test func `every word adds the weight of its best field`() {
        let both = save(title: "Onboarding", note: "falling tiles")
        #expect(SearchEngine.score(both, words: ["onboarding", "tiles"]) == 11)
        #expect(SearchEngine.score(both, words: ["missing"]) == 0)
    }

    @Test func `a smart folder rule matches a hex colour and part of a site`() {
        var link = Save(kind: .link, url: URL(string: "https://www.dribbble.com/shots/1"))
        link.palette = ["#2563EB"]
        var rule = SmartRule()
        rule.host = "dribbble"
        rule.color = "#2563eb"
        #expect(rule.matches(link))
        rule.color = "#d7263d"
        #expect(!rule.matches(link))
    }
}
