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
- ``MetaWearScanner/startScan(allowDuplicates:)``
- ``MetaWear/MetaWear``
- ``MetaWear/MetaWear/connectPublisher()``

### Identifying MetaWears

- ``MetaWear/MetaWear/mac``
- ``MetaWear/MetaWear/readCharacteristic(_:)``
- ``DeviceInformation``

### Logging & Streaming

- ``MetaWear/MetaWear/publishIfConnected()``
- ``MetaWear/MetaPublisher``
- ``MWSignal``

### Firmware Updates

- ``MetaWearFirmwareServer``
- ``MetaWearFirmwareServer/fetchRelevantFirmwareUpdate(for:)``
- ``MetaWearFirmwareServer/updateFirmware(on:delegate:build:)``

- ``MWAccelerometerGravityRange``
- ``MWAccelerometerSampleFrequency``
- ``MWAccelerometerModel``
