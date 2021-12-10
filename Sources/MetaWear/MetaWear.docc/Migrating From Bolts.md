# Migrating from the Bolts SDK

Fast facts for developers who already know the MetaWear iOS SDK.

## Overview

Testing some description here linking to the class ``MetaWear/MetaWear`` not the framework ``MetaWear``. Blah blah write it out.

Bolts | Combine 
--- | ---
`Task` | `Publisher`
Reference semantics | Reference + value semantics
Facebook | Apple
iOS 10 | iOS 13

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
