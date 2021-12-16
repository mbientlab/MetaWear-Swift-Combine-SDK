# Migrating from the Bolts SDK

Fast facts for developers who already know the MetaWear iOS SDK.

## Overview

Testing some description here linking to the class ``MetaWear/MetaWear`` not the framework ``MetaWear``. Blah blah write it out.

**Quick Comparison**
Aspect | Bolts | Combine 
--- | --- | ---
Future      | `Task` | `Publisher<Output, Failure>`
Future Semantics   | Reference | Reference + value
Requirement | iOS 10 | iOS 13
Distribution | Cocoapods | Swift Package Manager
UserDefaults | Many keys, fixed suite | One or two keys, chosen suite, can migrate
Demo Apps | UIKit + SwiftUI | SwiftUI only (works w/ UIKit too)
Install Base | Wider | New

**Approach**
Philosophy | Bolts | Combine 
--- | --- | ---
Purpose | Thin C wrapper | Beginner-friendly, extendable, browsable source
Typing | Exposed C structs | Strongly typed
Namespacing | Wider | Hierarchical (not quite 1:1)
UI Assist | Imperative ScannerModel | Publishers or cloud-synced metadata store

**Example namespacing changes**
- ``MetaWear/MetaWear/DeviceInformation`` includes ``MACAddress``
- ``MWFirmwareServer``
- ``MWError``
- ``MWData``, ``MWDataTable``, ``Timestamped``
- `metaWear.` ``MetaWear/MetaWear/publish()`` `.command(.factoryReset)`
- ``MetaWearScanner/discoveredDevices``

An edge case difference: this SDK has a public ``MetaWear/MetaWear/init(peripheral:scanner:mac:)`` for MetaWears so that you may roll your own ``MetaWearScanner``.

## Some topic

Tasks vs. publishers.



## Topics

### Essentials

- ``MetaWearScanner/``
- ``MetaWearScanner/startScan(higherPerformanceMode:)``
- ``MetaWear/MetaWear``
- ``MetaWear/MetaWear/connectPublisher()``

### Identifying MetaWears

- ``MetaWear/MetaWear/mac``
- ``MetaWear/MetaWear/read(_:)``
- ``MetaWear/MetaWear/DeviceInformation``

### Logging & Streaming

- ``MetaWear/MetaWear/publishIfConnected()``
- ``MetaWear/MWPublisher``
- ``MWDataSignal``

### Firmware Updates

- ``MWFirmwareServer``
- ``MWFirmwareServer/fetchRelevantFirmwareUpdate(for:)``
- ``MWFirmwareServer/updateFirmware(on:delegate:build:)``
