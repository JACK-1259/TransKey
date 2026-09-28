import Foundation

/// 최근 사용 순서를 유지하는 고정 크기 캐시. 호출자가 격리(예: MainActor)를 책임진다.
public struct LRUCache<Key: Hashable, Value> {
    public let capacity: Int
    private var storage: [Key: Value] = [:]
    /// 앞쪽이 가장 오래된 항목.
    private var order: [Key] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public var count: Int { storage.count }

    public mutating func value(for key: Key) -> Value? {
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    public mutating func set(_ value: Value, for key: Key) {
        if storage.updateValue(value, forKey: key) != nil {
            touch(key)
            return
        }
        order.append(key)
        if order.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    public mutating func removeAll() {
        storage.removeAll()
        order.removeAll()
    }

    private mutating func touch(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
    }
}

/// 번역 캐시 키: (원문, 원문 언어, 대상 언어).
public struct TranslationCacheKey: Hashable, Sendable {
    public let text: String
    public let source: Language
    public let target: Language

    public init(text: String, source: Language, target: Language) {
        self.text = text
        self.source = source
        self.target = target
    }
}
