# ``MetaWear``

Do BLE stuff. Lots of 1010101 flying around you.

More information goes here.

```
metawear.militaryMode().kabooom()
```

![MetaMotion S.](metamotion.png)

## Topics

### Getting Started

- <doc:/tutorials/MetaWear>
- <doc:Migrating-From-Bolts>

### Essentials

Ensure all reads of MetaWear properties and calls into the C++ library use the ``MetaWear/apiAccessQueue``. That's handled for you by any ``MetaPublisher``.

- ``MetaWear/MetaWearScanner``
- ``MetaWear/MetaWear``
- ``MetaWear/MetaPublisher``

### Identification

- ``DeviceInformation``
- ``MetaWear/MetaWear/readCharacteristic(_:)``
- ``MWServiceCharacteristic``

### Connecting
- ``MetaWearScanner``
- ``MetaWearScanner/startScan(allowDuplicates:)``
- ``MetaWearScanner/didDiscoverUniqued``
- ``MetaWear/MetaWear/connectPublisher()``

### Stream & Log Sensors

- ``MWSignal``
- ``MetaWearData``
- ``MetaWear/MetaWear/publishIfConnected()``
- ``MetaWear/MetaWear/publishWhenConnected()``
- ``MetaWear/MetaWear/publishWhenDisconnected()``
- ``MetaWear/MetaWear/publish()``
- ``MWDataSignal``
- ``MWLoggerKey``
- ``MWReadableOnce``
- ``MWLoggableStreamable``
- ``Timestamped``
- ``MetaWearBoard``
- <doc:/tutorials/MetaWear/Connecting-To-A-MetaWear>

### Firmware

- ``MetaWearFirmwareServer``
- ``FirmwareBuild``
- ``MetaWearFirmwareServer/fetchRelevantFirmwareUpdate(for:)``
- ``MetaWearFirmwareServer/updateFirmware(on:delegate:build:)``

### Console Logging

- ``ConsoleLogger``
- ``LogLevel``
- ``LogDelegate``

### Errors

- ``MetaWearError``
- ``FirmwareError``

### C++ Bridging

You can use the bridge functions. These enums provide an easy reference to C++ constants. You can use functions too.
+ ``bridge(obj:)``
+ ``bridge(ptr:)``
+ ``bridgeRetained(obj:)``
+ ``bridgeTransfer(ptr:)``

### Accelerometer

- ``MWAccelerometerGravityRange``
- ``MWAccelerometerSampleFrequency``
- ``MWAccelerometerModel``
- ``MODULE_ACC_TYPE_BMI270``
- ``MODULE_ACC_TYPE_BMI160``
- ``MODULE_ACC_TYPE_BMA255``
- ``MODULE_ACC_TYPE_MMA8452Q``
- ``ACC_ACCEL_X_AXIS_INDEX``
- ``ACC_ACCEL_Y_AXIS_INDEX``
- ``ACC_ACCEL_Z_AXIS_INDEX``

### Ambient Light

- ``MWAmbientLightGain``
- ``MWAmbientLightTR329IntegrationTime``
- ``MWAmbientLightTR329MeasurementRate``

### Battery

- ``SETTINGS_BATTERY_CHARGE_INDEX``
- ``SETTINGS_BATTERY_VOLTAGE_INDEX``
- ``SETTINGS_CHARGE_STATUS_UNSUPPORTED``
- ``SETTINGS_POWER_STATUS_UNSUPPORTED``

### Barometer

- ``MWBarometerIIRFilter``
- ``MWBarometerModel``
- ``MWBarometerOversampling``
- ``MWBarometerStandbyTime``
- ``MODULE_BARO_TYPE_BME280``
- ``MODULE_BARO_TYPE_BMP280``

### GPIO

- ``MWGPIOChangeType``
- ``MWGPIOMode``
- ``MWGPIOPin``
- ``MWGPIOPullMode``
- ``GPIO_UNUSED_PIN``

### Gyroscope

- ``MWGyroscopeFrequency``
- ``MWGyroscopeGraphRange``
- ``MODULE_GYRO_TYPE_BMI160``
- ``MODULE_GYRO_TYPE_BMI270``
- ``GYRO_ROTATION_X_AXIS_INDEX``
- ``GYRO_ROTATION_Y_AXIS_INDEX``
- ``GYRO_ROTATION_Z_AXIS_INDEX``

### Hygrometer

- ``MWHumidityOversampling``

### I2C

- ``MWI2CSize``

### LED

- ``MBLColor``
- ``LED_REPEAT_INDEFINITELY``
- ``CD_TCS34725_ADC_RED_INDEX``
- ``CD_TCS34725_ADC_GREEN_INDEX``
- ``CD_TCS34725_ADC_BLUE_INDEX``
- ``CD_TCS34725_ADC_CLEAR_INDEX``

### Magnetometer

- ``MAG_BFIELD_X_AXIS_INDEX``
- ``MAG_BFIELD_Y_AXIS_INDEX``
- ``MAG_BFIELD_Z_AXIS_INDEX``

### Sensor Fusion

- ``MWSensorFusionMode``
- ``MWSensorFusionOutputType``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_HIGH``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_LOW``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_MEDIUM``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_UNRELIABLE``

### Thermometer

- ``MWTemperatureSource``

### Status

- ``STATUS_OK``
- ``STATUS_ERROR_UNSUPPORTED_PROCESSOR``
- ``STATUS_ERROR_TIMEOUT``
- ``STATUS_ERROR_ENABLE_NOTIFY``
- ``STATUS_ERROR_SERIALIZATION_FORMAT``
- ``STATUS_WARNING_INVALID_PROCESSOR_TYPE``
- ``STATUS_WARNING_INVALID_RESPONSE``
- ``STATUS_WARNING_UNEXPECTED_SENSOR_DATA``

### Module Detection
- ``MODULE_TYPE_NA``

### Etc
- ``ADDRESS_TYPE_RANDOM_STATIC``
- ``ADDRESS_TYPE_PUBLIC``
- ``ADDRESS_TYPE_PRIVATE_RESOLVABLE``
- ``ADDRESS_TYPE_PRIVATE_NON_RESOLVABLE``
