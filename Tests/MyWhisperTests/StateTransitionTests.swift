import XCTest
@testable import MyWhisper

/// Exercises the conditional-transition guards that make the `state` writes on
/// `WhisperServerManager` and `WhisperEngine` race-safe. The data race itself
/// can only be provoked by concurrent threads, so these tests instead drive the
/// `transition(to:onlyIf:)` compare-and-set helper directly on a single thread to
/// prove the guard LOGIC holds: a late writer cannot resurrect a stopped engine,
/// and a committed value is what `state` reads back.
///
/// These managers are constructed with throwaway URLs/ports and `start()` is
/// never called, so no process is spawned and no model is loaded.
final class StateTransitionTests: XCTestCase {

    // MARK: WhisperServerManager

    private func makeServerManager() -> WhisperServerManager {
        WhisperServerManager(
            serverBinary: URL(fileURLWithPath: "/nonexistent/whisper-server"),
            modelURL: URL(fileURLWithPath: "/nonexistent/model.bin"),
            port: 65535)
    }

    /// A predicate mirroring pollUntilReady / start()'s queue guard: transition
    /// only if the current state is still `.starting`.
    private func onlyIfStarting(_ current: EngineState) -> Bool {
        if case .starting = current { return true }
        return false
    }

    /// A predicate mirroring the server termination handler: transition only if
    /// the current state is NOT `.stopped`.
    private func unlessStopped(_ current: EngineState) -> Bool {
        if case .stopped = current { return false }
        return true
    }

    func testServerStartingToReadySucceeds() {
        let manager = makeServerManager()
        XCTAssertTrue(manager.transition(to: .starting) { _ in true })
        let promoted = manager.transition(to: .ready, onlyIf: onlyIfStarting)
        XCTAssertTrue(promoted, "starting → ready must succeed")
        guard case .ready = manager.state else {
            return XCTFail("state should be .ready, got \(manager.state)")
        }
    }

    func testServerStoppedStaysStoppedOnLateReady() {
        let manager = makeServerManager()
        // stop() sets .stopped unconditionally.
        XCTAssertTrue(manager.transition(to: .stopped) { _ in true })
        // A poll closure that lost the race tries to promote to .ready.
        let promoted = manager.transition(to: .ready, onlyIf: onlyIfStarting)
        XCTAssertFalse(promoted, "a late .ready must not resurrect a stopped server")
        guard case .stopped = manager.state else {
            return XCTFail("state should remain .stopped, got \(manager.state)")
        }
    }

    func testServerStoppedStaysStoppedOnLateTerminationFailure() {
        let manager = makeServerManager()
        XCTAssertTrue(manager.transition(to: .stopped) { _ in true })
        // The termination handler firing after stop() must not overwrite .stopped.
        let failed = manager.transition(to: .failed("server exited"), onlyIf: unlessStopped)
        XCTAssertFalse(failed, "termination .failed must not overwrite an explicit .stopped")
        guard case .stopped = manager.state else {
            return XCTFail("state should remain .stopped, got \(manager.state)")
        }
    }

    func testServerTerminationFailureAppliesWhenNotStopped() {
        let manager = makeServerManager()
        XCTAssertTrue(manager.transition(to: .starting) { _ in true })
        // A crash while still starting (server never came up) is reported.
        let failed = manager.transition(to: .failed("server exited"), onlyIf: unlessStopped)
        XCTAssertTrue(failed, "a crash before .stopped must be reported as .failed")
        guard case .failed = manager.state else {
            return XCTFail("state should be .failed, got \(manager.state)")
        }
    }

    func testServerPollTimeoutOnlyFailsWhileStarting() {
        let manager = makeServerManager()
        // If the server became ready between the last ping and the deadline, a
        // timeout .failed must not clobber .ready.
        XCTAssertTrue(manager.transition(to: .starting) { _ in true })
        XCTAssertTrue(manager.transition(to: .ready, onlyIf: onlyIfStarting))
        let timedOut = manager.transition(to: .failed("timed out"), onlyIf: onlyIfStarting)
        XCTAssertFalse(timedOut, "timeout .failed must not overwrite .ready")
        guard case .ready = manager.state else {
            return XCTFail("state should remain .ready, got \(manager.state)")
        }
    }

    func testServerStateReadsBackLastCommittedValue() {
        let manager = makeServerManager()
        guard case .stopped = manager.state else {
            return XCTFail("initial state should be .stopped")
        }
        manager.transition(to: .starting) { _ in true }
        guard case .starting = manager.state else {
            return XCTFail("state should be .starting after committing it")
        }
        manager.transition(to: .failed("boom")) { _ in true }
        guard case .failed(let msg) = manager.state, msg == "boom" else {
            return XCTFail("state should carry the last committed payload")
        }
    }

    func testServerOnStateChangeFiresOnCommitAndReadsCommittedValue() {
        let manager = makeServerManager()
        var delivered: [EngineState] = []
        var stateSeenInsideCallback: EngineState?
        manager.onStateChange = { newValue in
            delivered.append(newValue)
            // Reading `state` from inside the callback must not deadlock and must
            // already reflect the committed value (callback fires after unlock).
            stateSeenInsideCallback = manager.state
        }
        XCTAssertTrue(manager.transition(to: .starting) { _ in true })
        XCTAssertEqual(delivered.count, 1)
        guard case .starting = delivered[0] else {
            return XCTFail("callback should receive .starting")
        }
        guard let seen = stateSeenInsideCallback, case .starting = seen else {
            return XCTFail("state read inside callback should be committed .starting")
        }
        // A no-op transition must not fire the callback.
        XCTAssertFalse(manager.transition(to: .ready, onlyIf: { _ in false }))
        XCTAssertEqual(delivered.count, 1, "a rejected transition must not fire onStateChange")
    }

    // MARK: WhisperEngine

    private func makeEngine() -> WhisperEngine {
        WhisperEngine(modelURL: URL(fileURLWithPath: "/nonexistent/model.bin"))
    }

    func testEngineStartingToReadySucceeds() {
        let engine = makeEngine()
        XCTAssertTrue(engine.transition(to: .starting) { _ in true })
        let promoted = engine.transition(to: .ready, onlyIf: onlyIfStarting)
        XCTAssertTrue(promoted, "starting → ready must succeed")
        guard case .ready = engine.state else {
            return XCTFail("state should be .ready, got \(engine.state)")
        }
    }

    func testEngineStoppedStaysStoppedOnLateReady() {
        let engine = makeEngine()
        // stop() flips state to .stopped authoritatively.
        XCTAssertTrue(engine.transition(to: .stopped) { _ in true })
        // The load's queue block finishing after stop() tries to publish .ready.
        let promoted = engine.transition(to: .ready, onlyIf: onlyIfStarting)
        XCTAssertFalse(promoted, "a late .ready must not resurrect a stopped engine")
        guard case .stopped = engine.state else {
            return XCTFail("state should remain .stopped, got \(engine.state)")
        }
    }

    func testEngineStoppedStaysStoppedOnLateLoadFailure() {
        let engine = makeEngine()
        XCTAssertTrue(engine.transition(to: .stopped) { _ in true })
        let failed = engine.transition(to: .failed("could not load model"), onlyIf: onlyIfStarting)
        XCTAssertFalse(failed, "a late load .failed must not overwrite an explicit .stopped")
        guard case .stopped = engine.state else {
            return XCTFail("state should remain .stopped, got \(engine.state)")
        }
    }

    func testEngineLoadFailureAppliesWhileStarting() {
        let engine = makeEngine()
        XCTAssertTrue(engine.transition(to: .starting) { _ in true })
        let failed = engine.transition(to: .failed("could not load model"), onlyIf: onlyIfStarting)
        XCTAssertTrue(failed, "a genuine load failure while starting must be reported")
        guard case .failed = engine.state else {
            return XCTFail("state should be .failed, got \(engine.state)")
        }
    }

    func testEngineStateReadsBackLastCommittedValue() {
        let engine = makeEngine()
        guard case .stopped = engine.state else {
            return XCTFail("initial state should be .stopped")
        }
        engine.transition(to: .starting) { _ in true }
        guard case .starting = engine.state else {
            return XCTFail("state should be .starting after committing it")
        }
        engine.transition(to: .ready) { _ in true }
        guard case .ready = engine.state else {
            return XCTFail("state should read back the last committed value")
        }
    }

    func testEngineOnStateChangeFiresOnCommitOnly() {
        let engine = makeEngine()
        var delivered: [EngineState] = []
        engine.onStateChange = { delivered.append($0) }
        XCTAssertTrue(engine.transition(to: .starting) { _ in true })
        XCTAssertFalse(engine.transition(to: .ready, onlyIf: { _ in false }))
        XCTAssertEqual(delivered.count, 1, "only the committed transition fires the callback")
        guard case .starting = delivered[0] else {
            return XCTFail("callback should receive .starting")
        }
    }
}
