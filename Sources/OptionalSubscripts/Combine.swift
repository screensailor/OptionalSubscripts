//
// github.com/screensailor 2021
//

#if canImport(Combine)
import Combine

public extension AsyncSequence {
    
    func publisher() -> AnyPublisher<Element, Never> {
        let o = PassthroughSubject<Element, Never>()
        var task: Task<(), Error>?
        return o.handleEvents(
            receiveCancel: {
                if let o = task {
                    o.cancel()
                    task = nil
                }
            },
            receiveRequest: { _ in
                guard task == nil else {
                    return
                }
                task = Task {
                    for try await element in self {
                        o.send(element)
                    }
                }
            }
        ).eraseToAnyPublisher()
    }
}

public extension Pond {

    @inlinable func publisher(for route: Location..., bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AnyPublisher<Any?, Never> {
        stream(route, bufferingPolicy: bufferingPolicy).publisher()
    }
    
    @inlinable func publisher<Route>(for route: Route, bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AnyPublisher<Any?, Never> where Route: Collection, Route.Index == Int, Route.Element == Location {
        stream(route, bufferingPolicy: bufferingPolicy).publisher()
    }
}

public extension OptionalStore {

    @inlinable func publisher(for route: Location..., bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AnyPublisher<Any?, Never> {
        stream(route, bufferingPolicy: bufferingPolicy).publisher()
    }
    
    @inlinable func publisher<Route>(for route: Route, bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AnyPublisher<Any?, Never> where Route: Collection, Route.Index == Int, Route.Element == Location {
        stream(route, bufferingPolicy: bufferingPolicy).publisher()
    }
}

public extension DictionaryStore {

    @inlinable func publisher(for key: Key, bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> AnyPublisher<Value?, Never> {
        stream(key, bufferingPolicy: bufferingPolicy).publisher()
    }
}

public extension Publisher {
    
    @inlinable func filter<A>(_: A.Type = A.self) -> Publishers.CompactMap<Self, A> {
        compactMap{ $0 as? A }
    }
    
    @inlinable func cast<A>(to: A.Type = A.self) -> Publishers.TryMap<Self, A> {
        tryMap { o in
            guard let a = o as? A else {
                throw CastingError(value: self, to: A.self)
            }
            return a
        }
    }
}
#endif
