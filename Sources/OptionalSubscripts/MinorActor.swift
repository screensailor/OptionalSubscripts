//
// github.com/screensailor 2022
//

/// This global actor makes it easier to adopt the stores in this module and
/// isolate code using the same actor as the stores are using. This convenience
/// will likely not be needed in the future as there are plans that would make
/// isolated code easier to reuse and extend
/// (see for example: https://github.com/apple/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md#isolated-protocol-conformances).
@globalActor public actor MinorActor {
	public static let shared = MinorActor()
}
