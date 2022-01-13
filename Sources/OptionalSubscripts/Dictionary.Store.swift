//
// github.com/screensailor 2021
//

public extension Dictionary {
	
	typealias Store = DictionaryStore<Key, Value>
}

@MinorActor public class DictionaryStore<Key: Hashable, Value> {
	
	public typealias BatchUpdates = [(Key, Value?)]
	public typealias TransactionLevel = UInt

	public var dictionary: [Key: Value]
	
	typealias ID = UInt
	typealias Subject = [ID: AsyncStream<Value?>.Continuation]

	var count: UInt = 0
	var subscriptions: [Key: Subject] = [:]

	public private(set) var transactionLevel: TransactionLevel = 0
	public private(set) var transactionUpdates: [TransactionLevel: BatchUpdates] = [:]

	nonisolated public init(_ dictionary: [Key: Value] = [:]) {
		self.dictionary = dictionary
	}
}

@MinorActor public extension DictionaryStore {
    
    typealias BufferingPolicy = AsyncStream<Value?>.Continuation.BufferingPolicy

    func stream(_ key: Key, bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AsyncStream<Value?> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.insert(continuation, for: key)
        }
    }

    private func insert(_ continuation: AsyncStream<Value?>.Continuation, for key: Key) {
        continuation.yield(dictionary[key])
        self.count += 1
        let id = self.count
        subscriptions[key, default: [:]][id] = continuation
        continuation.onTermination = { @Sendable [weak self] termination in
            guard let self = self else { return }
            Task {
                await self.remove(continuation: id, for: key)
            }
        }
    }

    private func remove(continuation id: ID, for key: Key) {
        subscriptions[key]?[id] = nil
        if subscriptions[key]?.isEmpty == true {
            subscriptions[key] = nil
        }
    }
}

@MinorActor public extension DictionaryStore {
    
    var isInTransaction: Bool {
        transactionLevel > 0
    }

    func transaction(_ updates: (DictionaryStore) async throws -> ()) async rethrows {
        transactionLevel += 1
        do {
            try await updates(self)
            let levelUpdates = transactionUpdates.removeValue(forKey: transactionLevel) ?? []
            transactionLevel -= 1
            if transactionLevel > 0 {
                transactionUpdates[transactionLevel, default: []].append(contentsOf: levelUpdates)
            } else {
                batch(levelUpdates)
            }
        }
        catch {
            transactionUpdates.removeValue(forKey: transactionLevel)
            transactionLevel -= 1
            throw error
        }
    }
    
    func batch(_ updates: BatchUpdates) {
        var array: [Key] = []
        var set: Set<Key> = []
        for (key, value) in updates {
            dictionary[key] = value
            if set.insert(key).inserted {
                array.append(key)
            }
        }
        for key in array {
            let value = dictionary[key]
            subscriptions[key]?.values.forEach { $0.yield(value) }
        }
    }
}

@MinorActor public extension DictionaryStore {
    
    func get(_ key: Key) throws -> Value {
        guard let o = dictionary[key] else {
            throw Error.nilAt(key: key)
        }
        return o
    }

    func set(_ key: Key, to value: Value?) {
        guard transactionLevel == 0 else {
            return transactionUpdates[transactionLevel, default: []].append((key, value))
        }
        dictionary[key] = value
        subscriptions[key]?.values.forEach { $0.yield(value) }
    }
}

@MinorActor public extension DictionaryStore {
    
    @inlinable subscript<A>(_ key: Key, as a: A.Type = A.self) -> A {
        get throws {
            try get(key)
        }
    }

    func get<A>(_ key: Key, as a: A.Type = A.self) throws -> A {
        guard let any = dictionary[key] else {
            throw Error.nilAt(key: key)
        }
        guard let a = any as? A else {
            throw Error.casting(key: key, from: type(of: any), to: A.self)
        }
        return a
    }
}

public extension DictionaryStore {
    
    enum Error: Swift.Error {
        case nilAt(key: Key)
        case casting(key: Key, from: Any.Type, to: Any.Type)
    }
}
