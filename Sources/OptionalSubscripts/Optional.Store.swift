//
// github.com/screensailor 2021
//

public extension Optional where Wrapped == Any {
    
    actor Store {
        
        public typealias BatchUpdates = [(Route, Any?)]
        public typealias TransactionLevel = UInt
        
        public var data: Any?
        
        public private(set) var transactionLevel: TransactionLevel = 0
        public private(set) var transactionUpdates: [TransactionLevel: BatchUpdates] = [:]

        typealias ID = UInt
        typealias Subject = [ID: AsyncStream<Any?>.Continuation]
        
        var count: UInt = 0
        var subscriptions = Tree<Location, Subject>()
        
        public init(_ data: Any? = nil) {
            self.data = data
        }
    }
}

public extension Optional.Store where Wrapped == Any {
    
    typealias BufferingPolicy = AsyncStream<Any?>.Continuation.BufferingPolicy

    @inlinable func stream(_ route: Location..., bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AsyncStream<Any?> {
        stream(route, bufferingPolicy: bufferingPolicy)
    }

    func stream<Route>(_ route: Route, bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AsyncStream<Any?> where Route: Collection, Route.Index == Int, Route.Element == Location {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            self.insert(continuation, for: route)
        }
    }

    private func insert<Route>(_ continuation: AsyncStream<Any?>.Continuation, for route: Route) where Route: Collection, Route.Index == Int, Route.Element == Location {
        continuation.yield(data[route])
        self.count += 1
        let id = self.count
        subscriptions[route, inserting: Subject()][id] = continuation
        continuation.onTermination = { @Sendable [weak self] termination in
            guard let self = self else { return }
            Task {
                await self.remove(continuation: id, for: route)
            }
        }
    }

    private func remove<Route>(continuation id: ID, for route: Route) where Route: Collection, Route.Index == Int, Route.Element == Location {
        subscriptions[route]?[id] = nil
        if subscriptions[route]?.isEmpty == true {
            subscriptions[route] = Subject?.none
        }
    }
}

public extension Optional.Store where Wrapped == Any {

    var isInTransaction: Bool {
        transactionLevel > 0
    }
    
    func transaction(_ updates: (Optional<Any>.Store) async throws -> ()) async rethrows { // TODO: add a sync version
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
        var routes: Set<Route> = []
        for (route, value) in updates {
            data[route] = value
            routes.formUnion(
                subscriptions
                    .routes(affectedByChanging: route)
                    .filter{ subscriptions[$0] as Subject? != nil }
            )
        }
        for route in routes.sorted(by: <) {
            guard let subject: Subject = subscriptions[route] else { continue }
            let value = data[route]
            subject.values.forEach { $0.yield(value) }
        }
    }
}

public extension Optional.Store where Wrapped == Any {

    @inlinable func set(_ route: Location..., to value: Any?) {
        set(route, to: value)
    }
    
    func set<Route>(_ route: Route, to value: Any?) where Route: Collection, Route.Index == Int, Route.Element == Location {
        guard transactionLevel == 0 else {
            return transactionUpdates[transactionLevel, default: []].append((Array(route), value))
        }
        data[route] = value
        didSet(route, to: value)
    }
}

extension Optional.Store where Wrapped == Any {
    
    func didSet<Route>(_ route: Route, to value: Any?) where Route: Collection, Route.Index == Int, Route.Element == Location {
        for route in route.lineage.reversed() {
            guard let subject: Subject = subscriptions[route] else {
                continue
            }
            let data = data[route]
            subject.values.forEach { $0.yield(data) }
        }
        subscriptions[route]?.traverse { subroute, subject in
            guard let subject = subject else {
                return
            }
            let data = value[subroute]
            subject.values.forEach { $0.yield(data) }
        }
    }
}

public extension Optional.Store where Wrapped == Any {
    
    typealias Route = Optional<Any>.Route
    typealias Location = Optional<Any>.Location
    typealias KeyPath = Optional<Any>.KeyPath
    
    @inlinable subscript<A>(_ route: Location..., as type: A.Type = A.self) -> A {
        get throws {
            try get(route)
        }
    }
    
    @inlinable subscript<A, Route>(_ route: Route, as a: A.Type = A.self) -> A where Route: Collection, Route.Index == Int, Route.Element == Location {
        get throws {
            try get(route)
        }
    }

    @inlinable func get<A>(_ route: Location..., as type: A.Type = A.self) throws -> A {
        try get(route)
    }

    func get<A, Route>(_ route: Route, as a: A.Type = A.self) throws -> A where Route: Collection, Route.Index == Int, Route.Element == Location {
        guard let any = data[route] else {
            throw Error.nilAt(route: Array(route))
        }
        guard let a = try? Optional(any).cast(to: A.self) else {
            throw Error.casting(route: Array(route), from: type(of: any), to: A.self)
        }
        return a
    }
}

public extension Optional.Store where Wrapped == Any {
    
    enum Error: Swift.Error {
        case nilAt(route: Route)
        case casting(route: Route, from: Any.Type, to: Any.Type)
    }
}
