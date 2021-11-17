////Copyright

import Foundation
import Combine

/// Sugar for Just with an Error output.
func _Just<O>(_ output: O) -> AnyPublisher<O,Error> {
    Just(output).setFailureType(to: Error.self).eraseToAnyPublisher()
}

/// Sugar for Just with a MetaWear output.
func _JustMW(_ bool: Bool) -> AnyPublisher<Bool,MetaWearError> {
    Just(bool).setFailureType(to: MetaWearError.self).eraseToAnyPublisher()
}

func _Fail<Output>(_ error: MetaWearError) -> AnyPublisher<Output,Error> {
    Fail(outputType: Output.self, failure: error)
        .eraseToAnyPublisher()
}

internal extension Publisher {

    /// Wraps any preceding error into a `MetaWearError`.
    func mapToMetaWearError() -> AnyPublisher<Output,MetaWearError> {
        mapError { error -> MetaWearError in
            if let mwe = error as? MetaWearError {
                return mwe
            } else {
                return MetaWearError.operationFailed(error.localizedDescription)
            }
        }
        .eraseToAnyPublisher()
    }
}




// DELETION CANDIDATE:

/// Simpler semantics when building futures, such as
/// storing a promise-fulfilling closure for a delegate response.
///
internal typealias PromiseClosure<Output> = (Result<Output, MetaWearError>) -> Void

internal extension MetaWear {

    func BLELazyFuture<O>(closure: @escaping (PromiseClosure<O>) -> Void ) -> MetaPublisher<O> {
        Deferred {
            Future<O, MetaWearError> { promise in
                closure(promise)
            }
        }
        .erase(subscribeOn: self.apiAccessQueue)
    }
}
