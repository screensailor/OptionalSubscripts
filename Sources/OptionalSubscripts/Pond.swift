//
// github.com/screensailor 2021
//

import Dispatch // TODO: #if canImport

public extension Optional where Wrapped == Any {

	typealias Pond = OptionalSubscripts.Pond
}

public extension Pond {
	
	typealias Route = Optional<Any>.Route
	typealias Location = Optional<Any>.Location
	
	typealias Stream = AsyncFlatMapSequence<AsyncStream<AsyncStream<Any?>>, AsyncStream<Any?>>
	typealias BufferingPolicy = AsyncStream<Any?>.Continuation.BufferingPolicy
}

@MinorActor public class Pond<Source> where Source: Geyser {
	
	public let source: Source
	public let store: Optional<Any>.Store
	
	public private(set) var cancellingGracePeriodInNanoseconds: UInt64 = 0
	public private(set) var sourceIDs: [Route: Source.GushID] = [:]
	public private(set) var gushSources: [Source.GushID: GushSource] = [:]
	
	public class GushSource {
		
		public fileprivate(set) var pendingContinuations: [PendingContinuation]?
		public fileprivate(set) var cancelTimestamp: DispatchTime?
		public fileprivate(set) var referenceCount: UInt = 0
		
		let task: Task<(), Error>
		
		init(task: Task<(), Error>, pending: PendingContinuation) {
			self.task = task
			self.pendingContinuations = [pending]
		}
	}
	
	public struct PendingContinuation {
		
		public let route: Route
		public let limit: BufferingPolicy
		
		let continuation: Continuation
	}
	
	public typealias Continuation = AsyncStream<AsyncStream<Any?>>.Continuation
	
	nonisolated public init(source: Source, store: Optional<Any>.Store = .init()) {
		self.source = source
		self.store = store
	}
}

@MinorActor public extension Pond {
    
    func setCancellingGracePeriod(to seconds: Double) {
        cancellingGracePeriodInNanoseconds = UInt64(max(0, seconds * 1_000_000_000))
    }

    @inlinable nonisolated func stream(_ route: Location..., bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> Stream {
        stream(route, bufferingPolicy: bufferingPolicy)
    }
    
    nonisolated func stream<Route>(_ route: Route, bufferingPolicy: BufferingPolicy = .bufferingNewest(1)) -> Stream where Route: Collection, Route.Index == Int, Route.Element == Location {
        AsyncStream { continuation in
            Task {
                try await stream(route, to: continuation, limit: bufferingPolicy)
            }
        }.flatMap{ $0 }
    }
}

private extension Pond {
    
    func stream<Route>(_ route: Route, to continuation: Continuation, limit: BufferingPolicy) async throws where Route: Collection, Route.Index == Int, Route.Element == Location {
        
        for try await src in await source.source(of: route) {
            
            guard let src = src else {
                return // TODO: error handling?
            }
            
            switch sourceIDs[src.route] {
                
            case let id? where id == src.id:
                guard let gushSource = gushSources[src.id] else {
                    assertionFailure("Missing gush source \(src.id)")
                    return
                }
                if gushSource.pendingContinuations == nil {
                    yield(route, to: continuation, limit: limit, with: src.id)
                } else {
                    gushSource.pendingContinuations?.append(
                        PendingContinuation(route: Array(route), limit: limit, continuation: continuation)
                    )
                }
                
            case let id?: // where id != src.id:
                cancel(task: id) // TODO: route counting?
                fallthrough
                
            default:
                let task = Task {
                    for try await gush in await source.stream(src.id) {
                        store.set(src.route, to: gush)
                        guard let gushSource = gushSources[src.id] else {
                            assertionFailure("Missing gush source \(src.id)")
                            return
                        }
                        if let pending = gushSource.pendingContinuations {
                            gushSource.pendingContinuations = nil
                            for o in pending {
                                yield(o.route, to: o.continuation, limit: o.limit, with: src.id)
                            }
                        }
                    }
                }
                sourceIDs[src.route] = src.id
                gushSources[src.id] = GushSource(
                    task: task,
                    pending: PendingContinuation(route: Array(route), limit: limit, continuation: continuation)
                )
            }
        }
    }
    
    func yield<Route>(_ route: Route, to continuation: Continuation, limit: BufferingPolicy, with source: Source.GushID) where Route: Collection, Route.Index == Int, Route.Element == Location {
        let stream = AsyncStream<Any?>{ continuation in
            count(for: source, of: +1)
            let task = Task {
                for await o in store.stream(route, bufferingPolicy: limit) {
                    continuation.yield(o)
                }
            }
            continuation.onTermination = { @Sendable [weak self] _ in
                task.cancel()
                Task { [weak self] in
                    await self?.count(for: source, of: -1)
                }
            }
        }
        continuation.yield(stream)
    }
    
    func count(for id: Source.GushID, of change: Int) {
        guard let o = gushSources[id] else {
            assertionFailure("😱 Reference counting (\(change)) of non existant sourece '\(id)'")
            return
        }
        let result = Int(o.referenceCount) + change
        if result > 0 {
            o.referenceCount = UInt(result)
            o.cancelTimestamp = nil
        }
        else if cancellingGracePeriodInNanoseconds > 0 {
            o.cancelTimestamp = .now()
            Task { [t = o.cancelTimestamp, sleep = cancellingGracePeriodInNanoseconds] in
                try await Task.sleep(nanoseconds: sleep)
                guard o.cancelTimestamp == t else {
                    return
                }
                cancel(task: id)
            }
        }
        else {
            cancel(task: id)
        }
    }
    
    func cancel(task id: Source.GushID) {
        gushSources.removeValue(forKey: id)?.task.cancel()
    }
}


