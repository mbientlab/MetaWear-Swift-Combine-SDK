# ``MetaWear/MetaWear``

## Topics

### Actions

Reading sensor data and issuing many commands to a MetaWear are asynchronous operations. Publishers below start a `Combine` pipeline that offers operators like `read`, `stream`, `log`, `downloadLogs`, `optionallyLog`, `command`, and `macro`.

- ``publishWhenConnected()``
- ``publishWhenDisconnected()``
- ``publishIfConnected()``
- ``publish()``
- ``connectPublisher()``
- ``MWPublisher``

### Identity

- ``info``
- ``localBluetoothID``
- ``name``
- ``isNameValid(_:)``
- ``defaultName``
- ``DeviceInformation``
- ``Model``

### Connect

- ``connectionState``
- ``connectionStatePublisher``
- ``connect()``
- ``connectPublisher()``
- ``disconnect()``

### Signal Strength

- ``rssi``
- ``rssiPublisher``
- ``rssiMovingAveragePublisher``
- ``updateRSSI()``

### Bluetooth

- ``forget()``
- ``remember()``
- ``bleQueue``
- ``peripheral``
- ``scanner``

### Logging

- ``logDelegate``
- ``MWConsoleLogger``

### Restoring State

A device's state, including all sensor configurations, loggers, and active downloads, can be stored for restoration in the event of a disconnection.

- ``stateSerialize()``
- ``stateLoadFromUniqueURL()``
- ``uniqueURL()``

### Infrequently Used APIs

- ``describeModules()``
- ``advertisementDataPublisher``
- ``advertisementData``
- ``board``
- ``isMetaBoot``
- ``init(peripheral:scanner:mac:)``
- ``Characteristic``
- ``Service``
