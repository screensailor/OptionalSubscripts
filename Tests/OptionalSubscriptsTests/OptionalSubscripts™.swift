//
// github.com/screensailor 2022
//

@_exported import Hope
@_exported import Combine
@_exported import OptionalSubscripts

final class OptionalSubscripts™: Hopes {
	
	private var bag: Set<AnyCancellable> = []
	
	func test_some_thoughts_about_data_races() async throws {
		
		let a = await A()
		let n = Counter()
		let N = 1_00_000
		
		DispatchQueue.concurrentPerform(iterations: N) { [a] i in
			Task.detached {
				await a.increment()
				await n.increment()
			}
		}
		
		let promise = expectation()
		
		await n.$count.sink{ n in
			if n == N {
				promise.fulfill()
			}
		}.store(in: &bag)
		
		wait(for: promise, timeout: 10)
		
		await print("✅", a.x)
	}
}

@G class A {
	
	private let _a = _A()
	
	@inlinable var x: Int { _a.x }
	
	@inlinable func increment() {
		_a.increment()
	}
}

class _A {
	
	var x = 0
	
	func increment() {
		x += 1
	}
}

@globalActor enum G {
	actor Actor {}
	static let shared = Actor()
}

actor Counter {
	@Published var count = 0
	func increment() {
		count += 1
	}
}
