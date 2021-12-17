# Migrating from the Bolts SDK

Comparison of frameworks and namespacing changes

## Overview

While the basics of working with MetaWear is similar, some changes would require some (hopefully streamlining) adaptations.

Many operations using Combine require less code and less nesting. Not all operations possible in C have defined Swift methods. You may still use C mixed in Combine operators. Most interactions will start with a ``MetaWear/MetaWear/publishWhenConnected()`` or ``MetaWear/MetaWear/publishIfConnected()`` command on the target MetaWear. 


## Sample Changes

State changes are observed not through delegates, but publishers on the objects themselves. Gone are `ScannerModel` and `ScannerModelItems`. Now the ``MetaWearScanner`` publishes diffs of its own device map or individual discoveries. The `connect()` command is relocated to the ``MetaWear/MetaWear`` itself.

To replicate the prior behavior of flashes upon connection, add a pipeline to the observing view model or controller as below. You can also use the ``MWLED/Flash/Pattern/Emulator`` to depict the same event in your UI.

```
let pattern: MWLED.FlashPattern = ...
metawear
    .whenConnected()
    .command(.ledFlash(pattern))
    .sink { _ in }
    .store(in: &subs)
```

#### Other namespacing changes

Most properties remain similar. Minor objects have been shortened with MW prefixes or placed one level deeper in a hierarchy. Some examples are:
- ``MetaWear/MetaWear/DeviceInformation`` includes ``MACAddress``
- ``MWFirmwareServer``
- `metaWear.` ``MetaWear/MetaWear/publish()`` `.command(.resetFactoryDefaults)`
- ``MetaWearScanner/discoveredDevices``
- ``MWData``
- ``MWError``

An edge case difference: this SDK has a public ``MetaWear/MetaWear/init(peripheral:scanner:mac:)`` for MetaWears so that you may roll your own ``MetaWearScanner``.

## Comparing Async Frameworks

Aspect | Bolts | Combine 
--- | --- | ---
Objects      | `Task` | `Publisher<Output, Failure>` pipelines, retained by an `AnyCancellable` token
Semantics   | Reference | Reference + value
Requirement | iOS 10 | iOS 13
Distribution | Cocoapods | Enables Swift Package Manager

#### Quick tips

* Most publishers are value types, but `CurrentValueSubject` and `PassthroughSubject` are reference types. You can progressively build and pass around "unconnected" publisher pipelines. Execution starts upon subscription, which often is when you create and store an `AnyCancellable` token.

* To consume one type and output another asynchronously, use `flatMap`.
```swift
.flatMap { [weak self] output -> AnyPublisher<Output,Failure> in 
    // Calculations
    return <new publisher>.eraseToAnyPublisher()
}
```

* To perform side effects, use `.handleEvents()`.

* To cancel one or more pipelines, call .cancel() on a stored `AnyCancellable` token or use the `prefix(untilOutputFrom:)` operator.

* If the compiler says `.flatMap()` is unavailable or is inexplicably upset, the culprit may be a discreptant `Failure` types. For example, `.tryMap()` erases custom error types. You can use `.mapToMWError()` or your own `.mapError()` operator to keep the party going.


## Philosophies
Philosophy | Prior SDK | Combine SDK
--- | --- | ---
Purpose | Thin C wrapper | Beginner-friendly, extendable, browsable source
Outputs | Some C structs | SIMD or other native types
Communication | Delegate-observer | Unlimited state subscriptions
Namespacing | Wider | More hierarchical (not quite 1:1)
Persistence | Many keys, fixed UserDefaults suite | One or two keys, specified suite, migration


## Resources

Aspect | Prior SDK | Combine SDK
--- | --- | ---
UI Assist | Imperative ScannerModel/Item | Publishers or cloud-synced metadata store `MetaWearSync` and ``MWLED/Flash/Pattern/Emulator``
Demo Apps | UIKit + SwiftUI | Bare test host, basic tutorial, MetaBase (all SwiftUI)
Install Base | Wider | New, but same [community forum](https://mbientlab.com/community/)
