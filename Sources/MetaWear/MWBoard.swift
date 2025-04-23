//
//  MetaWearBoard.swift
//  MetaWear
//
//  Created by Laura Kassovic on 9/29/24.
//

import Foundation
import CoreBluetooth
import Combine
import OSLog

@available(macOS 11.0, *)
let logger = Logger.init(subsystem: "com.mbientlab.sdk", category: "board")

// MARK: - ModuleInfo
struct ModuleInfo {
    var id: UInt8
    var present: Bool
    var implementation: UInt8
    var revision: UInt8
    var extra: [UInt8]

    init(response: [UInt8], size: UInt8) {
        self.id = response[0]
        self.present = size > 2

        if present {
            self.implementation = response[2]
            self.revision = response[3]
        } else {
            self.implementation = 0xff
            self.revision = 0xff
        }

        if size > 4 {
            self.extra = Array(response[4..<Int(size)])
        } else {
            self.extra = []
        }
    }
    
    // Serialize the struct into an array of bytes
    func serialize() -> [UInt8] {
        var state = [id, present ? 1 : 0]
        state.append(contentsOf: extra)
        state.append(implementation)
        state.append(revision)
        return state
    }
}

// MARK: - MetaWearBoard Class
open class MWBoard: NSObject {
    
    weak var owner: MetaWear?
    
    // BLE communication
    var peripheral: CBPeripheral?
    var commandCharacteristic: CBCharacteristic?
    var notificationCharacteristic: CBCharacteristic?
    
    // Asynchronous read/write callbacks
    var _onReadCallbacks: [CBCharacteristic: (Data) -> Void] = [:]
    var _onDataCallbacks: [CBCharacteristic: (Data) -> Void] = [:]
    var _subscribeCompleteCallbacks: [CBCharacteristic: (MWBoard, Bool) -> Void] = [:]
    var _onDisconnectCallback: ((MWBoard, Int) -> Void)? = nil

    // Device state
    var initialized: Bool = false
    var detectedModule: [MWModules.ID: ModuleInfo] = [:]
    
    // Publishers & subscriptions
    var cancellables = Set<AnyCancellable>()
    let moduleInfoBoardPublisher = PassthroughSubject<Data, Never>()
    
    // Integer properties
    var timePerResponse: Int64 = 0
    var moduleDiscoveryIndex: Int = 0
    var devInfoIndex: Int8 = 0
    
    // Module discovery
    var moduleEvents: [ResponseHeader: MWDataSignal] = [:]
    var moduleConfig: [UInt8: Any] = [:]
    
    // Firmware and other string information
    var firmwareRevision: String = ""
    var modelNumber: String = ""
    var hardwareRevision: String = ""
    var manufacturer: String = ""
    var serialNumber: String = ""
    
    // Modules
    var switchInstance: MWSwitch?

    // DFU operations (replace with equivalent Swift type for handling DFU)
    //var operations: DfuOperations?
    
    // Filename as a C string equivalent in Swift
    //var filename: String?
    
    // Reset or clear states for example purposes
    func resetBoardState() {
        // Placeholder for reset logic, like clearing state or configurations
    }
    
    // Init MetaWearBoard
    // mbl_mw_metawearboard_create
    init(peripheral: CBPeripheral, owner: MetaWear) {
        self.owner = owner
        self.peripheral = peripheral
    }
    
    // Initialize the board
    // mbl_mw_metawearboard_initialize
    func initialize() {
        print("INIT")
    }
    
    // MARK: - Public API
    
    /// Performs an actual BLE read and returns `Data`
    private func readValue() -> AnyPublisher<Data, MWError> {
        guard let characteristic = commandCharacteristic,
              let peripheral = peripheral else {
            return Fail(error: MWError.operationFailed("Command characteristic unavailable"))
                .eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<Data, MWError>()

        _onReadCallbacks[characteristic] = { data in
            subject.send(data)
            subject.send(completion: .finished)
        }

        peripheral.readValue(for: characteristic)

        return subject.eraseToAnyPublisher()
    }
    
    /// Reads data as a specified type
    func read<T>(as type: T.Type) -> AnyPublisher<Timestamped<T>, MWError> {
        readValue()
            .map { _ in ( Timestamped(value:0 as! T, time:Date())) }
            .mapToMWError()
            .eraseToAnyPublisher()
    }
    
    /// Writes data to the board
    func writeValue(_ data: Data) {
        guard let characteristic = commandCharacteristic else {
            logger.error("Command characteristic not found")
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withoutResponse)
    }
    
    /// Subscribes to continuous data notifications
    func enableNotifications(onData: @escaping (Data) -> Void, completion: ((MWBoard, Bool) -> Void)? = nil) {
        guard let characteristic = commandCharacteristic else {
            completion?(self, false)
            return
        }
        
        _onDataCallbacks[characteristic] = onData
        _subscribeCompleteCallbacks[characteristic] = completion
        
        peripheral?.setNotifyValue(true, for: characteristic)
    }
    
    /// Unsubscribes from notifications
    func disableNotifications() {
        guard let characteristic = commandCharacteristic else { return }
        peripheral?.setNotifyValue(false, for: characteristic)
        _onDataCallbacks.removeValue(forKey: characteristic)
    }
    
}

extension MWBoard {

    func moduleDiscoveryWorker() -> AnyPublisher<Data, MWError> {
        let subject = PassthroughSubject<Data, MWError>()
        
        // Check if the index is within bounds
        guard moduleDiscoveryIndex < MODULE_DISCOVERY_CMDS.count else {
            subject.send(completion: .finished)
            return subject.eraseToAnyPublisher()
        }
        
        let bytes: [UInt8] = MODULE_DISCOVERY_CMDS[moduleDiscoveryIndex]
        let data = Data(bytes)
        print("Get next module \(moduleDiscoveryIndex)")
        
        print("\(commandCharacteristic!.uuid)")
        // Set up the callback to capture the response
        _onReadCallbacks[notificationCharacteristic!] = { responseData in
            print("TO PROCESS DATA \(responseData)")
            subject.send(responseData)
            subject.send(completion: .finished)
        }
        
        writeValue(data)
        
        return subject.eraseToAnyPublisher()
    }
    
    func detectModules() -> Future<Void, Never> {
        Future<Void, Never> { promise in
            func processNextModule() {
                self.moduleDiscoveryWorker()
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            logger.error("Module discovery failed: \(error.localizedDescription)")
                            promise(.success(())) // End discovery on failure
                        }
                    }, receiveValue: { data in
                        // Process the received data
                        logger.info("Received data: \(String(describing: data.first))")
                        self.processDiscoveryData(value: data)
                        self.moduleDiscoveryIndex += 1
                        
                        if self.moduleDiscoveryIndex < MODULE_DISCOVERY_CMDS.count {
                            processNextModule() // Continue with the next module
                        } else {
                            promise(.success(())) // All modules discovered
                        }
                    })
                    .store(in: &self.cancellables)
            }
            
            logger.info("Starting module discovery")
            processNextModule()
        }
    }
    
    func processDiscoveryData(value: Data) {
        switch value[0] {
        case Module.button.byte:
            self.initSwitch(value: value)
            print("Switch TODO")
        case Module.led.byte:
            //self.initLed(value: value)
            print("LED TODO")
        case Module.accelerometer.byte:
            //self.initAccelerometer(value: value)
            print("Acc TODO")
        case Module.temperature.byte:
            print("TEMPERATURE INIT")
            //self.initTemperature(value: value)
        case Module.gpio.byte:
            //self.initGpio(value: value)
            print("GPIO TODO")
        case Module.neoPixel.byte:
            print("NEO")
        case Module.ibeacon.byte:
            //self.initIBeacon(value: value)
            print("IBEACON TO DO")
        case Module.haptic.byte:
            //self.initHaptic(value: value)
            print("HAPTIC TO DO")
        case Module.dataProcessor.byte, Module.event.byte, Module.logging.byte,
             Module.timer.byte, Module.macro.byte, Module.conductance.byte,
             Module.settings.byte, Module.ambientLight.byte, Module.humidity.byte,
             Module.colorDetector.byte, Module.proximity.byte, Module.sensorFusion.byte:
            print("OTHERS")
        case Module.i2c.byte:
            print("I2C")
            //self.initI2C(value: value)
        case Module.barometer.byte:
            print("BARO")
            //self.initBarometer(value: value)
        case Module.gyro.byte:
            print("GYRO")
            //self.initGyro(value: value)
        case Module.magnetometer.byte:
            print("MAG")
            //self.initMag(value: value)
        case Module.debug.byte:
            logger.debug("DONE")
            self.moduleDiscoveryIndex+=1
        default:
            logger.debug("Default hit, module discovery index \(self.moduleDiscoveryIndex)")
        }
    }

    // mbl_mw_metawearboard_lookup_module
    func lookupModule(moduleId: MWModules.ID) -> Int32 {
        guard let moduleInfo = detectedModule[moduleId] else {
            return -1 // ❌ Module not found
        }
        return Int32(moduleInfo.implementation) // ✅ Return implementation for found module
    }
    
    // Sets response time
    // mbl_mw_metawearboard_set_time_for_response
    func setTimeForResponse(_ timeMs: UInt16) {
        timePerResponse = Int64(min(timeMs, MAX_TIME_PER_RESPONSE))
    }
    
    // Gets the model
    // mbl_mw_metawearboard_get_model(board)
    func getModel() -> String {
        return self.modelNumber
    }
    
}

enum MultiChannelTempRegister: UInt8 {
    case temperature = 1
    case mode = 2
}

extension MWBoard {

    func initSwitch(value: Data) {
        let modData = value.dropFirst(2)
        let modInfo = ModuleInfo(response: [UInt8](modData), size: UInt8(modData.count))
        detectedModule[.mechanicalSwitch] = modInfo
        print("Mechanical switch module detected with ID: \(modInfo)")
        switchInstance = MWSwitch.init()
    }
    
    func initTemperature(value: Data) {
        let start = 4
        let end = min(value.count - 1, 7)

        for val in value[start...end] {
            let thermometerID: MWModules.ThermometerID?

            switch val {
            case 0x0:
                print("on die")
                thermometerID = .onDie
            case 0x1:
                print("external")
                thermometerID = .external
            case 0x2:
                print("bmp280")
                thermometerID = .bmp280
            case 0x3:
                print("on board")
                thermometerID = .onboard
            default:
                print("Unknown temperature sensor")
                continue
            }

            guard let thermometer = thermometerID else { continue }
            let modinfo = ModuleInfo(response: [UInt8](value), size: UInt8(value.count))

            // ✅ Store each thermometer separately by unique ID
            detectedModule[.thermometer(thermometer)] = modinfo
        }

        // Proceed with the next module discovery step
        //moduleDiscoveryWorker(index: moduleDiscoveryIndex)
    }
    
    // mbl_mw_multi_chnl_temp_get_temperature_data_signal
    func getTemperatureDataSignal(channel: Int) -> MWDataSignal {
        let tempResponseHeader = ResponseHeader(moduleID: Module.temperature.byte, registerID: READ_REGISTER(MultiChannelTempRegister.temperature.rawValue), dataID: UInt8(channel))
        let dataSignal = MWDataSignal(header: tempResponseHeader, owner: self, interpreter: DataInterpreter.TEMPERATURE)
        moduleEvents[tempResponseHeader] = dataSignal
        return dataSignal
    }
    
    // mbl_mw_multi_chnl_temp_get_num_channels
    func getNumChannels() -> Int {
        let thermometerCount = detectedModule.keys.filter { key in
            if case .thermometer = key {
                return true
            }
            return false
        }.count

        print("Number of channels found \(thermometerCount)")
        return thermometerCount
    }
    
    // mbl_mw_multi_chnl_temp_get_source
    func tempGetSource(channel: Int) -> Int {
        // hardcoded for now since we only support new boards
        switch channel {
        case 0:
            return 0 //Channel 0 is nRF On-Die Temp with driver id 0
        case 1:
            return 3 //Channel 1 is Thermistor: On-board with driver id 3
        case 2:
            return 1 //Channel 2 is Thermistor: External with driver id 1
        case 3:
            return 2 //Channel 3 is BMP280 with driver id 2
        default:
            return -1
        }
    }
    
    // mbl_mw_multi_chnl_temp_configure_ext_thermistor
    func configureExtThermistor() {
        
    }
    
    // mbl_mw_baro_bosch_start
    func baroBoschStart() {
        
    }
    
    // mbl_mw_baro_bosch_stop
    func baroBoschStop() {
        
    }
}
