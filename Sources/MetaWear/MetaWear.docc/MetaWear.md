# ``MetaWear``

Develop Bluetooth Low Energy apps using our sensors and `Combine`

This SDK makes configuring and retrieving data streams from MetaWear devices easy, flexible, and concise by leveraging Apple's `Combine` framework across iOS, macOS, watchOS, and tvOS.

If you're new to Bluetooth and MetaWear, this SDK offers SwiftUI-like presets that entirely abstract any interactions with the C++ library. You can try the <doc:/tutorials/MetaWear> tutorial and examine the source of our MetaBase app for example SDK usage.

For those who want more control, this SDK also exposes publishers convenient for working with `OpaquePointer` chains and your own C++ commands. See <doc:Migrating-From-Bolts>.

![MetaMotion S.](metamotion.png)

## Basics

You can build an asynchronous `Combine` pipeline by combining:
1. a start condition — e.g., upon disconnection (to perhaps auto-reconnect)
2. an action — e.g., `read`, `stream`, `log`, `downloadLog`, `command`
3. a sensor configuration suggested by code completion
4. any of the many `Combine` operators for manipulating streams of data or events

###### Example 1: Wait until first connection, stream accelerometer vectors, process, update UI on main ######
```swift
metawear
   .publishWhenConnected()
   .first()
   .stream(.accelerometer(rate: .hz100, range: .g2)
   .map { myProcessingFunction($0) }
   .receive(on: DispatchQueue.main)
```

If you're unfamiliar with `Combine`, see <doc:/tutorials/MetaWear/Renaming-Devices>. The above block is a "recipe" that you can pass around for further specialization. Execution begins only when you subscribe, which the tutorial explains.

To discover nearby MetaWears, use ``MetaWearScanner``.

###### Example 2: Scan for nearby devices, add only unique discoveries to table view ######
```swift
let scanner = MetaWearScanner.sharedRestore()
scanner.didDiscoverDeviceUniqued
       .recieve(on: DispatchQueue.main)
       .sink { [weak self] device in 
           self?.devices.append(device)
       }
       .store(in: &subs)
scanner.startScan(allowDuplicates: true)
```


## Topics

### Getting Started

- <doc:/tutorials/MetaWear>
- <doc:Migrating-From-Bolts>

### Essentials

Using any ``MWPublisher`` ensures calls into the C++ library and reads of any properties occur on the ``MetaWear/apiAccessQueue``.

- ``MetaWear/MetaWearScanner``
- ``MetaWear/MetaWear``
- ``MWError``
- ``MetaWear/MWPublisher``

### Interact

- <doc:Interacting-with-MetaWears>
- ``MWCommand``
- ``MWLoggable``
- ``MWReadable``
- ``MWPollable``
- ``MWStreamable``
- ``MWFrequency``
- ``MWLogger``

### Data Output

Streaming data arrives in Swift formats. Logged data downloads in a string-based `MWDataTable` that can output a .csv file.

- ``MWDataTable``
- ``MWData``
- ``MWDataConvertible``
- ``Download``
- ``Timestamped``

### Modules

- ``MWModules``
- ``MWAccelerometer``
- ``MWAmbientLight``
- ``MWBarometer``
- ``MWGyroscope``
- ``MWHumidity``
- ``MWThermometer``
- ``MWColorDetector``
- ``MWLED``
- ``MWMagnetometer``
- ``MWOrientationSensor``
- ``MWProximity``
- ``MWSensorFusion``
- ``MWStepCounter``
- ``MWStepDetector``

### Misc Signals

- ``MWBatteryLevel``
- ``MWLogLength``
- ``MWMACAddress``
- ``MWLastResetTime``

### Utilities
- ``MWFirmwareServer``
- ``MWConsoleLogger``
- ``MWConsoleLoggerDelegate``

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
