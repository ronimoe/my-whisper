import XCTest
@testable import MyWhisper

final class HistoryStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
        tempURL = dir.appendingPathComponent("history-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        tempURL = nil
        super.tearDown()
    }

    func testAppendThenLoadRoundTrips() {
        let store = HistoryStore(fileURL: tempURL)
        store.append(text: "hello world", language: "en")

        let entries = store.load()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].text, "hello world")
        XCTAssertEqual(entries[0].language, "en")
        XCTAssertEqual(entries[0].date.timeIntervalSinceNow, 0, accuracy: 5)
    }

    func testTwoAppendsPreserveOrderNewestLast() {
        let store = HistoryStore(fileURL: tempURL)
        store.append(text: "first", language: "en")
        store.append(text: "second", language: "en")

        let entries = store.load()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].text, "first")
        XCTAssertEqual(entries[1].text, "second")
    }

    func testCapsStorageAt200DroppingOldest() {
        let store = HistoryStore(fileURL: tempURL)
        for i in 0..<205 {
            store.append(text: "entry \(i)", language: "en")
        }

        let entries = store.load()
        XCTAssertEqual(entries.count, 200)
        XCTAssertEqual(entries.first?.text, "entry 5")
        XCTAssertEqual(entries.last?.text, "entry 204")
        for i in 0..<5 {
            XCTAssertFalse(entries.contains { $0.text == "entry \(i)" })
        }
    }

    func testClearEmptiesStore() {
        let store = HistoryStore(fileURL: tempURL)
        store.append(text: "hello", language: "en")
        store.clear()

        XCTAssertEqual(store.load(), [])
    }

    func testLoadWithNoFileReturnsEmpty() {
        let store = HistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.load(), [])
    }

    func testLoadWithGarbageBytesReturnsEmpty() {
        try? "not valid json at all".data(using: .utf8)?.write(to: tempURL)
        let store = HistoryStore(fileURL: tempURL)
        XCTAssertEqual(store.load(), [])
    }

    func testSecondInstanceSeesDataWrittenByFirst() {
        let store1 = HistoryStore(fileURL: tempURL)
        store1.append(text: "persisted", language: "id")

        let store2 = HistoryStore(fileURL: tempURL)
        let entries = store2.load()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].text, "persisted")
        XCTAssertEqual(entries[0].language, "id")
    }
}
