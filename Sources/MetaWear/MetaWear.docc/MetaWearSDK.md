# ``MetaWear``

Develop Bluetooth Low Energy apps using our sensors and `Combine`

This SDK abstracts `CoreBluetooth` and our MetaWear C/C++ API using concise `Combine` publishers and presets. It offers two optional imports:

* `MetaWearSync`  —  track groups of MetaWears across Apple devices using iCloud key-value storage
* `MetaWearCpp`  —  mix our C/C++ API with `Combine` publishers for additional flexibility

![MetaMotion S.](metamotion.png)


## Getting Started

Beyond this guide, you can ramp up with an interactive <doc:/tutorials/MetaWear> tutorial to build a simple app, similar to our barebones [integration test host app](https://github.com/mbientlab/MetaWear-SDK-Swift-Combine-TestHost).  Existing MetaWear developers can orient with <doc:Migrating-From-Bolts>. You can also examine the [source code of our cross-platform MetaBase app](https://github.com/mbientlab/MetaBase).

#### 1. Entitlements
For each target in your project, go to the **Signing & Capabilities** tab. For macOS, go to *App Sandbox* and check **Bluetooth**. For iOS, add *Background Modes* and check **Uses Bluetooth LE accessories**. 

Optionally, for `MetaWearSync`, add *iCloud* and check **Key value storage**. If your plan to update MetaWear firmware in your app, for macOS in *App Sandbox* check **Outgoing Connections**.


For all platforms, go to the **Info** tab and add and provide a message for:
- Privacy - Bluetooth Always Usage Description
- Privacy - Bluetooth Peripheral Usage Description


#### 2. Find nearby MetaWears
Create a ``MetaWearScanner`` instance or use the ``MetaWearScanner/sharedRestore`` singleton.

Goal | API
--- | ---
Search | ``MetaWearScanner/startScan(higherPerformanceMode:)``
Stop searching | ``MetaWearScanner/stopScan()``
Individual discovery events | ``MetaWearScanner/didDiscover``
Refreshing dictionary of devices | ``MetaWearScanner/discoveredDevicesPublisher``
Bluetooth power and authorization | ``MetaWearScanner/bluetoothState``

A restored device may not be nearby right now, but was connected in a previous session. As with all MetaWear interactions, you'll receive updates on that scanner's ``MetaWearScanner/bleQueue``. 


#### 3. Interact

First, to connect to a MetaWear, call ``MetaWear/MetaWear/connect()`` or ``MetaWear/MetaWear/connectPublisher()``. You can observe connection state via the ``MetaWear/MetaWear/connectionStatePublisher``.

Since nearly every MetaWear interaction is an asynchronous call and response over a potentially low strength Bluetooth connection, this SDK reasons about these events and streams of data through Apple's `Combine` framework. If unfamiliar with Combine, the  <doc:/tutorials/MetaWear> tutorial has some basics. A good reference is [Joseph Heck's Using Combine](https://heckj.github.io/swiftui-notes/).

Most of this SDK's functions extend Combine publishers that emit a ``MetaWear``.

Fires | API
--- | ---
On every connection | ``MetaWear/MetaWear/publishWhenConnected()``
First connection only | ``MetaWear/MetaWear/publishWhenConnected()`` `.first()`
On every disconnection | ``MetaWear/MetaWear/publishWhenDisconnected()``
Now, failing if not connected | ``MetaWear/MetaWear/publishIfConnected()``
Now | ``MetaWear/MetaWear/publish()``

From those publishers, autocompletion will reveal MetaWear operators.

Operator | Example
--- | ---
`.command()` | ``MWCommand/rename(advertisingName:)``
`.read()` | ``MWReadable/batteryLevel``
`.stream()` | ``MWStreamable/sensorFusionQuaternion(mode:)``
`.log()` | ``MWLoggable/gyroscope(range:freq:)``
`.downloadLogs()` | Returns ``MWDataTable`` array and percent progress


###### Example: Wait until first connection, stream accelerometer vectors, update UI on main ######
```swift
metawear
   .publishWhenConnected()
   .first()
   .stream(.accelerometer(rate: .hz100, range: .g2)
   .map { makePrettyDataPoint($0) }
   .receive(on: DispatchQueue.main)
   .sink { [weak self] data in 
       self?.pretty.append(data)
   }
   .store(in: &subs)

metawear.connect()
```

###### Performing multiple interactions at once
To chain logging or other commands, you can use `.optionallyLog()` and/or `.macro(executeOnBoot:actions:)`.

To stream an arbitrary number of sensors, you can setup individual pipelines, perhaps coordinated by `prefix(untilOutputFrom:)`. You could also convert the myriad ``MWStreamable`` outputs to the same type, such as ``MWDataTable``, and form an array of publishers consumable by Combine's `MergeMany`. 

Beware that Bluetooth Low Energy usually can't deliver above 100 Hz without dropping some data. Also, the `prefix(untilOutputFrom:)` operator must output on the ``MetaWear/MetaWear/bleQueue`` to avoid undefined behavior.

###### Using onboard timers
For logging, you can program a MetaWear to fire an onboard timer to poll a signal (direct from sensor or after some data processing) or fire an event after some trigger.

Operator | Output Reference Pointer | Input
--- | --- | ---
`.createPollingTimer()` | Data signal embedded in the timer | Publisher<(MetaWear, MWDataSignal)>
`.createTimer()` | Timer | Publisher<(MetaWear, MWDataSignal)>
`.createTimedEvent()` | Event timer | Publisher<MetaWear> and a closure of commands to execute upon firing

An ``MWDataSignal`` is a type alias for `OpaquePointer`, which is simply a reference to a C type not exposed to Swift.


##### 4. Debugging
Bytes transmitted over Bluetooth and other MetaWear actions can be viewed using the ``MWConsoleLogger``. Just assign a reference to that logger to a MetaWear's ``MetaWear/MetaWear/logDelegate`` property.

Sometimes an incomplete or incorrect command can put a MetaWear in a bad state, which will crash when you reconnect. If reseting the device via unit test our apps fails, manually reset by connecting the MetaWear to power at the same time as pressing the mechanical button for 10 seconds.


##### 5. Testing

Unit test targets can call on a host app that exposes a MetaWearScanner, but XCTest cannot instantiate its own MetaWearScanner with Bluetooth permission on its own. 

UI test targets may also improperly parse Swift Package Manager dependencies. (If encountered, please file feedback with Apple.)



## Topics

### Getting Started

- <doc:/tutorials/MetaWear>
- <doc:Migrating-From-Bolts>

### Essentials

Using any ``MWPublisher`` ensures calls into the C++ library and reads of any properties occur on the ``MetaWear/MetaWear/bleQueue``.

- ``MetaWear/MetaWearScanner``
- ``MetaWear/MetaWear``
- ``MWError``
- ``MetaWear/MWPublisher``

### Interact

The `.command()`, `.log()`, `.read()`, and `.stream()` operators accept value types conforming to these protocols, which describe communication methods with the MetaWear.

- ``MWCommand``
- ``MWCommandWithResponse``
- ``MWLoggable``
- ``MWPollable``
- ``MWReadable``
- ``MWReadableMerged``
- ``MWStreamable``
- ``MWFrequency``

### Data Output

Streaming data arrives in Swift types, such as `SIMD3<Float>`. Logs download in a string-based ``MWDataTable`` that can output a .csv file.

- ``MWDataTable``
- ``MWData``
- ``MWDataConvertible``
- ``Download``
- ``Timestamped``

### Modules

- ``MWAccelerometer``
- ``MWAmbientLight``
- ``MWBarometer``
- ``MWBuzzer``
- ``MWGyroscope``
- ``MWHapticMotor``
- ``MWHumidity``
- ``MWiBeacon``
- ``MWThermometer``
- ``MWLED``
- ``MWMagnetometer``
- ``MWMechanicalButton``
- ``MWMotion``
- ``MWOrientationSensor``
- ``MWSensorFusion``
- ``MWStepCounter``
- ``MWStepDetector``
- ``MWModules``

### Misc Signals & Commands

- ``MWBatteryLevel``
- ``MWChargingStatus``
- ``MWChangeAdvertisingName``
- ``MWLastResetTime``
- ``MWLogLength``
- ``MWMACAddress``
- ``MWMacro``
- ``MWNamedSignal``

### Reset or Restart Commands

- ``MWFactoryReset``
- ``MWActivitiesReset``
- ``MWRestart``

### Utilities
- ``MWFirmwareServer``
- ``MWConsoleLogger``
- ``MWConsoleLoggerDelegate``

### Identifiers

Each machine assigns a MetaWear a unique local UUID, but once connected ``MetaWear/MetaWear/info`` contains a stable MAC address.

- ``CBPeripheralIdentifier``
- ``MACAddress``

### C++ Bridging

When interacting with the C++ library, use these functions to reference Swift objects.

+ ``bridge(obj:)``
+ ``bridge(ptr:)``
+ ``bridgeRetained(obj:)``
+ ``bridgeTransfer(ptr:)``

### Opaque Pointer & C++ Aliases

When interacting with the C++ library or forming your own publishers, these type aliases hint at the identity of an `OpaquePointer` or an integer identifier.

- ``MWBoard``
- ``MWDataSignal``
- ``MWDataSignalOrBoard``
- ``MWDataProcessorSignal``
- ``MWLoggerSignal``
- ``MWMacroIdentifier``

### C++ Library Status Code

Useful only when interacting with the C++ library.

- ``MWStatusCode``
- ``STATUS_OK``
- ``STATUS_ERROR_UNSUPPORTED_PROCESSOR``
- ``STATUS_ERROR_TIMEOUT``
- ``STATUS_ERROR_ENABLE_NOTIFY``
- ``STATUS_ERROR_SERIALIZATION_FORMAT``
- ``STATUS_WARNING_INVALID_PROCESSOR_TYPE``
- ``STATUS_WARNING_INVALID_RESPONSE``
- ``STATUS_WARNING_UNEXPECTED_SENSOR_DATA``

### C++ Constants

Useful only when interacting with the C++ library.

- ``MODULE_ACC_TYPE_BMI270``
- ``MODULE_ACC_TYPE_BMI160``
- ``MODULE_ACC_TYPE_BMA255``
- ``MODULE_ACC_TYPE_MMA8452Q``
- ``MODULE_BARO_TYPE_BME280``
- ``MODULE_BARO_TYPE_BMP280``
- ``MODULE_GYRO_TYPE_BMI160``
- ``MODULE_GYRO_TYPE_BMI270``
- ``MODULE_TYPE_NA``
- ``LED_REPEAT_INDEFINITELY``
- ``GPIO_UNUSED_PIN``
- ``SETTINGS_BATTERY_CHARGE_INDEX``
- ``SETTINGS_BATTERY_VOLTAGE_INDEX``
- ``SETTINGS_CHARGE_STATUS_UNSUPPORTED``
- ``SETTINGS_POWER_STATUS_UNSUPPORTED``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_HIGH``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_LOW``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_MEDIUM``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_UNRELIABLE``
- ``ADDRESS_TYPE_RANDOM_STATIC``
- ``ADDRESS_TYPE_PUBLIC``
- ``ADDRESS_TYPE_PRIVATE_RESOLVABLE``
- ``ADDRESS_TYPE_PRIVATE_NON_RESOLVABLE``
- ``ACC_ACCEL_X_AXIS_INDEX``
- ``ACC_ACCEL_Y_AXIS_INDEX``
- ``ACC_ACCEL_Z_AXIS_INDEX``
- ``CD_TCS34725_ADC_RED_INDEX``
- ``CD_TCS34725_ADC_GREEN_INDEX``
- ``CD_TCS34725_ADC_BLUE_INDEX``
- ``CD_TCS34725_ADC_CLEAR_INDEX``
- ``GYRO_ROTATION_X_AXIS_INDEX``
- ``GYRO_ROTATION_Y_AXIS_INDEX``
- ``GYRO_ROTATION_Z_AXIS_INDEX``
- ``MAG_BFIELD_X_AXIS_INDEX``
- ``MAG_BFIELD_Y_AXIS_INDEX``
- ``MAG_BFIELD_Z_AXIS_INDEX``