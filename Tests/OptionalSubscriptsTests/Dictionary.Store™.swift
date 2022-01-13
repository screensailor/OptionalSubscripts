//
// github.com/screensailor 2021
//

import Combine

final class DictionaryStore™: Hopes {
    
	@MinorActor
    func test_stream() async throws {
        
        let o = [String: String].Store(["heart": "?"])
        
    forloop:
        for await heart in o.stream("heart") {
            switch heart
            {
            case "?":
                o.set("heart", to: "❤️")
                
            case "❤️":
                o.set("heart", to: "💛")
                
            case "💛":
                o.set("fart",  to: "😱")
                o.set("heart", to: "💚")
                
            case "💚":
                break forloop
                
            default:
                hope.less("Unexpected: '\(heart as Any)'")
                break forloop
            }
        }
		
		try hope(that: o.get("heart")) == "💚"
		try hope(that: o.get("fart")) == "😱"

		hope(that: o.dictionary.count) == 2
    }
    
    func test_publisher() async throws {
        
        let o = [String: String].Store()
        var bag: Set<AnyCancellable> = []
        let promise = expectation()
        
        await o.publisher(for: "heart").sink { heart in
            Task {
                switch heart
                {
                case nil:
                    await o.set("heart", to: "❤️")
                    
                case "❤️":
                    await o.set("heart", to: "💛")
                    
                case "💛":
                    await o.set("fart",  to: "😱")
                    await o.set("heart", to: "💚")
                    
                case "💚":
                    promise.fulfill()
                    
                default:
                    hope.less("Unexpected: '\(heart as Any)'")
                }
            }
        }.store(in: &bag)
        
        wait(for: promise, timeout: 1)
        
        await hope(that: o.dictionary) == [
            "heart": "💚",
            "fart": "😱"
        ]
    }

    func test_batch() async throws {

        let o = [String: Int].Store()
        var bag: Set<AnyCancellable> = []
        let promise = expectation()
        
        await o.publisher(for: "x", bufferingPolicy: .unbounded).prefix(2).collect().sink { callbacks in
            hope(callbacks) == [nil, 3]
            promise.fulfill()
        }.store(in: &bag)
        
        var batch = [String: Int].Store.BatchUpdates()

        batch.set("x", to: 1)
        batch.set("y", to: 1)
        batch.set("x", to: 2)
        batch.set("y", to: 2)
        batch.set("x", to: 3)
        batch.set("y", to: 3)

        try hope(batch.get("x")) == 3

        await o.batch(batch)
        
        wait(for: promise, timeout: 1)

        await hope(that: o.dictionary) == [
            "x": 3,
            "y": 3
        ]
    }

    func test_transaction() async throws {

        let o = [String: Int].Store()
        
        let promise = expectation()
        var bag: Set<AnyCancellable> = []
        
        await o.publisher(for: "x", bufferingPolicy: .unbounded).prefix(2).collect().sink { o in
            hope(o) == [nil, 3]
            promise.fulfill()
        }.store(in: &bag)

        await o.transaction { store in
            
            await o.set("x", to: 1)
            await o.set("y", to: 1)

            await o.transaction { store in
                
                await o.set("x", to: 2)
                await o.set("y", to: 2)

                do {
                    try await o.transaction { store in
                        
                        await o.set("z", to: 3)
                        throw [String: Int].Store.Error.nilAt(key: "x")
                    }
                } catch {}
                
                await o.transaction { store in
                    
                    await o.set("x", to: 3)
                    await o.set("y", to: 3)
                }
            }
        }
        
        wait(for: promise, timeout: 1)
        
        await hope(that: o.dictionary) == ["x": 3, "y": 3]
    }
    
    func test_transaction_level() async throws {
        
        let o = [String: Int].Store()

        await o.transaction { store in
            
            await hope(that: o.transactionLevel) == 1

            await o.transaction { store in

                await hope(that: o.transactionLevel) == 2

                do {
                    try await o.transaction { store in
                        
                        await hope(that: o.transactionLevel) == 3
                        
                        throw [String: Int].Store.Error.nilAt(key: "x")
                    }
                } catch {}
                
                await o.transaction { store in
                    
                    await hope(that: o.transactionLevel) == 3
                }
            }
        }
    }
}
