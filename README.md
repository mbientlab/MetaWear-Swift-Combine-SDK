# MetaWear Swift Combine SDK Beta

### Control our wearable sensors on iOS and macOS devices using Combine.

💪 Inexperienced with CoreBluetooth or C/C++ in Swift? No problem.

📚 Interactive Xcode [DocC documentation](https://mbientlab.netlify.app/documentation/MetaWear) and [tutorials](https://mbientlab.netlify.app/tutorials/metawear)

☁️ New iCloud-sync recognition of MetaWears across Apple devices

✋ Optional drag-and-drop UI conveniences

<br /><br />![metawear](https://user-images.githubusercontent.com/78187398/150276856-d2c75a0f-d8a0-48a9-b877-d4f8dbb0c52c.png)<br /><br />


Getting Started
--------------
- For detailed documentation and comparison to our Bolts SDK, press Control Shift Cmd + D in Xcode. Or use a [web version of the docs](https://mbientlab.netlify.app/documentation/MetaWear) and [interactive tutorial](https://mbientlab.netlify.app/tutorials/metawear).
- For sample apps, see [Streamy](https://github.com/mbientlab/Streamy) (in documentation tutorials) or [MetaBase](https://github.com/mbientlab/MetaWear-MetaBase-iOS-macOS-App/tree/combine-sdk-macos).
- For license and copyright, see LICENSE.md.

Please [email us](mailto:hello@mbientlab.com), open an issue, or post on the MetaWear community forum with questions or feedback.

<br />

Directories At a Glance
--------------

#### 📂 MetaWear
The root directory contains the core objects and type aliases for typical use of the SDK.
- 📁 **Combine** — Primary Combine operators used to control MetaWear devices
- 📁 **Cpp Bridging** — Swift wrappers around sensors/modules (e.g., gyroscope), commands (e.g., activate iBeacon), and anything else from the C/C++ library
- 📁 **Helpers** — Extensions and utilities

📂 **MetaWearSync** — iCloud synchronization of device identities

📂 **MetaWearFirmware** — Updates device firmware from MetaWear servers

📂 **MetaWearCpp** — Underlying C/C++ submodule

📂 **Tests** — Run the test host project at 📂 Sources/Tests/IntegrationTests/. CoreBluetooth does not work in an iOS Simulator.
