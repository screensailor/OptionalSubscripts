//
// github.com/screensailor 2021
//

final class Location™: Hopes {

    func test() {
        
        var o: Optional<Any>.Location
        
        o = 5

        hope(o) == 5

        o = "👋"

        hope(o) == "👋"
    }
    
    func test_comparable() {
        
        var l: Optional<Any>.Location
        var r: Optional<Any>.Location

        (l, r) = (5, "5")
        hope.true(l < r)

        (l, r) = ("5", 5)
        hope.false(l < r)

        (l, r) = (4, 5)
        hope.true(l < r)

        (l, r) = ("4", "5")
        hope.true(l < r)
    }
    
    func test_comparable_routes() {
        
        let g = Any?.RandomRoutes(
            keys: "abcde".map(String.init),
            indices: Array(1...3),
            keyBias: 0.8,
            length: 0...5,
            seed: 4
        )

        let routes = g.generate(count: 10)
        
        hope(routes.sorted(by: <)) == [
            [],
            [3, "a"],
            [3, "a", "d", "e"],
            ["a"],
            ["a", 2, "d"],
            ["a", "e", 3, "b"],
            ["b", "e", "e"],
            ["c", 3, "d", "e", "d"],
            ["d"],
            ["d", 3],
        ]
    }
}
