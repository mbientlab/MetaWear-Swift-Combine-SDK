import Foundation

/// Represents all hardware modules on a MetaWear board.
public enum MWModules: Equatable, Identifiable, Codable, Hashable {

    case humidity
    case illuminance
    case magnetometer
    case sensorFusion
    case mechanicalSwitch
    case led
    case gpio
    case iBeacon
    case haptic
    case i2c
    case thermometer(ThermometerID) // Supports multiple thermometer sources via unique IDs
    
    /// Unique identifier for each module (ignores associated values).
    public var id: ID {
        switch self {
        case .humidity: return .humidity
        case .illuminance: return .illuminance
        case .magnetometer: return .magnetometer
        case .sensorFusion: return .sensorFusion
        case .mechanicalSwitch: return .mechanicalSwitch
        case .led: return .led
        case .gpio: return .gpio
        case .iBeacon: return .iBeacon
        case .haptic: return .haptic
        case .i2c: return .i2c
        case .thermometer(let thermometerID): return .thermometer(thermometerID)
        }
    }

    /// Defines module IDs for dictionary key usage.
    public enum ID: Hashable, Codable {
        case humidity
        case illuminance
        case magnetometer
        case sensorFusion
        case mechanicalSwitch
        case led
        case gpio
        case iBeacon
        case haptic
        case i2c
        case thermometer(ThermometerID) // Each thermometer has a unique ID
        
        /// Manually define all possible cases
       public static var allCases: [MWModules.ID] {
           return [
               .humidity,
               .illuminance,
               .magnetometer,
               .sensorFusion,
               .mechanicalSwitch,
               .led,
               .gpio,
               .iBeacon,
               .haptic,
               .i2c
           ] + ThermometerID.allCases.map { .thermometer($0) }
       }
    }

    /// Unique ID for each thermometer type.
    public enum ThermometerID: String, Hashable, Codable, CaseIterable {
        case onDie = "thermometer.onDie"
        case external = "thermometer.external"
        case bmp280 = "thermometer.bmp280"
        case onboard = "thermometer.onboard"
    }

    /// Detects available modules on the board.
    public static func detect(in board: MWBoard) -> [MWModules.ID: MWModules] {
        var detected = [MWModules.ID: MWModules]()

        // Detect standard modules
        let modulePairs: [(MWModules.ID, MWModules)] = [
            (.magnetometer, .magnetometer),
            (.humidity, .humidity),
            (.illuminance, .illuminance),
            (.sensorFusion, .sensorFusion),
            (.mechanicalSwitch, .mechanicalSwitch),
            (.led, .led),
            (.gpio, .gpio),
            (.iBeacon, .iBeacon),
            (.haptic, .haptic),
            (.i2c, .i2c)
        ]

        for (id, module) in modulePairs {
            if lookup(in: board, id) != nil {
                detected[id] = module
            }
        }

        // Detect thermometer sources and store them separately
        let sources = MWThermometer.Source.availableChannels(on: board)
        for source in sources {
            if let thermometerID = ThermometerID(rawValue: "thermometer.\(source)") {
                detected[.thermometer(thermometerID)] = .thermometer(thermometerID)
            }
        }

        return detected
    }

    /// Looks up if a module is present.
    public static func lookup(in board: MWBoard, _ module: ID) -> Int32? {
        return board.lookupModule(moduleId: module)
    }
}
