import Foundation

/// Shift 키 상태 머신.
/// - 탭: off → once → off
/// - once 상태에서 `doubleTapInterval` 안에 다시 탭: locked(Caps Lock)
/// - locked에서 탭: off
/// - once 상태에서 문자를 입력하면 off로 돌아간다.
public struct ShiftStateMachine: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case off
        case once
        case locked
    }

    public private(set) var state: State
    public let doubleTapInterval: TimeInterval
    private var lastTapTime: TimeInterval?

    public init(state: State = .off, doubleTapInterval: TimeInterval = 0.3) {
        self.state = state
        self.doubleTapInterval = doubleTapInterval
    }

    public var isUppercase: Bool { state != .off }

    /// Shift 키 탭. `time`은 단조 증가 시각(초)이다.
    public mutating func tap(at time: TimeInterval) {
        if state == .once, let last = lastTapTime, time - last <= doubleTapInterval {
            state = .locked
            lastTapTime = nil
            return
        }
        switch state {
        case .off: state = .once
        case .once, .locked: state = .off
        }
        lastTapTime = time
    }

    /// 문자가 입력된 뒤 호출한다. 한 번 Shift는 해제된다.
    public mutating func didInsertCharacter() {
        if state == .once {
            state = .off
        }
    }

    /// 자동 대문자 판단 결과를 반영한다. Caps Lock은 건드리지 않는다.
    public mutating func applyAutoCapitalization(_ shouldCapitalize: Bool) {
        guard state != .locked else { return }
        state = shouldCapitalize ? .once : .off
    }
}
