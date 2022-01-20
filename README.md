# MetaWear Swift Combine SDK Beta

Control our wearable sensors using Combine on iOS and macOS devices.

Optional utilities facilitate tracking MetaWears uniquely across 
Apple devices via iCloud sync and conveniences for drag and drop UI.

Detailed documentation, demo apps, and quick start guides are available 
in Xcode-native format. Build it by pressing Control + Shift + Cmd + D.

For license and copyright, see LICENSE.md.

Please email us, open an issue, or post on the MetaWear community 
forum with questions or feedback.


Directories At a Glance
--------------

### SDK Products
##### MetaWear
The root directory contains the core objects and type aliases for typical use of the SDK.
- Combine: Primary Combine operators used to control MetaWear devices
- Cpp Bridging: Swift wrappers around sensors/modules (e.g., gyroscope), commands (e.g., activate iBeacon), and anything else from the C/C++ library
- Helpers: Extensions and utilities

##### MetaWearSync
iCloud synchronization of device identities

##### MetaWearFirmware
Updates device firmware from MetaWear servers

##### MetaWearCpp 
Underlying C/C++ library

### Tests
Run the test host project at Sources/Tests/IntegrationTests/. CoreBluetooth does not work in an iOS Simulator.
