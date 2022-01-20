# Migrating from the Bolts SDK

Overview of changes

## Overview

While the C/C++ library remains exposed as before, most Swift APIs have streamlined, but familiar namespacing. All asynchronous interactions and value streams use Apple's Combine framework (which reads similar to React). If new to Combine, check out [Joseph Heck's guide](https://heckj.github.io/swiftui-notes/).

Most activities kick off with a publisher, such as ``MetaWear/MetaWear/publishWhenConnected()`` or ``MetaWear/MetaWear/publishIfConnected()``. Next, an operator like `.stream`, `.log`, `.command`, `.read`, or `.optionallyLog` will consume a sensor configuration struct or code-completing preset.

A new iCloud metadata sync utility, `MetaWearSyncStore`, and drag-and-drop conveniences are in the `MetaWearSync` product.

## Sample Changes

State changes are observed not through delegates, but publishers on the objects themselves. Gone are `ScannerModel` and `ScannerModelItems`. Now the ``MetaWearScanner`` publishes diffs of its own device map or individual discoveries. The `connect()` command is relocated to the ``MetaWear/MetaWear`` itself.

The scanner no longer mandates LED flashes upon connection. If you liked this, just use:
```
let pattern: MWLED.FlashPattern = ...
metawear
   .whenConnected()
   .command(.ledFlash(pattern))
   .sink { _ in }
   .store(in: &subs)
```
You can also use the new ``MWLED/Flash/Pattern/Emulator`` to depict the same event in your UI.

#### Other namespacing changes

Most properties remain similar. Minor objects have been shortened with MW prefixes or placed one level deeper in a hierarchy. Some examples are:
- ``MetaWear/MetaWear/DeviceInformation`` includes ``MACAddress``
- `MWFirmwareServer`
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
    return <new publisher>.eraseToAnyPublisher()
}
```

* To perform side effects, use `.handleEvents()`.

* To cancel one or more pipelines, call `.cancel()` on a stored `AnyCancellable` token or use the `prefix(untilOutputFrom:)` operator.

* If the compiler says `.flatMap()` is unavailable or is inexplicably upset, the culprit may be discrepant `Failure` types. For example, `.tryMap()` erases custom error types. You can use `.mapToMWError()` or your own `.mapError()` operator to keep the party going.


## Philosophies
Philosophy | Prior SDK | Combine SDK
--- | --- | ---
Purpose | Thin C wrapper | Beginner-friendly, extendable
Outputs | Some C structs | Only SIMD or other native types
Communication | Delegate-observer | Unlimited state subscriptions
Namespacing | Wider | More hierarchical (not quite 1:1)
Persistence | Many keys, fixed UserDefaults suite | One or two keys, customizable suite, migration


## Resources

Aspect | Prior SDK | Combine SDK
--- | --- | ---
UI Assist | Imperative ScannerModel/Item | Publishers or cloud-synced metadata store `MetaWearSyncStore` and ``MWLED/Flash/Pattern/Emulator``
Demo Apps | UIKit + SwiftUI | Bare test host, basic tutorial, MetaBase (all SwiftUI)
Install Base | Wider | New, but same [community forum](https://mbientlab.com/community/)
