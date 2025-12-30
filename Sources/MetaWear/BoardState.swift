import Foundation

public struct BoardState: Equatable, Sendable {
    public struct ModuleInfo: Equatable, Sendable {
        public var present: Bool
        public var implementation: Int32
        public var revision: UInt8
        public var extra: Data

        public init(present: Bool, implementation: Int32, revision: UInt8, extra: Data) {
            self.present = present
            self.implementation = implementation
            self.revision = revision
            self.extra = extra
#if DEBUG
            print("[BoardState] ModuleInfo init -> present: \(present), impl: \(implementation), rev: \(revision), extraBytes: \(extra.count)")
#endif
        }
    }

    public struct LoggingTimeRef: Equatable, Sendable {
        public var resetUID: UInt32
        public var epochMs: Int64

        public init(resetUID: UInt32, epochMs: Int64) {
            self.resetUID = resetUID
            self.epochMs = epochMs
#if DEBUG
            print("[BoardState] LoggingTimeRef init -> resetUID: \(resetUID), epochMs: \(epochMs)")
#endif
        }
    }

    // Minimal properties we can know during setup without C++
    public var isMetaBoot: Bool

    // DIS fields
    public var firmwareRevision: String?
    public var hardwareRevision: String?
    public var modelNumber: String?
    public var manufacturerName: String?
    public var serialNumber: String?

    // Module info keyed by module id (UInt8)
    public var moduleInfo: [UInt8: ModuleInfo]

    // Optional logging reference time
    public var loggingTime: LoggingTimeRef?

    public init(
        isMetaBoot: Bool,
        firmwareRevision: String? = nil,
        hardwareRevision: String? = nil,
        modelNumber: String? = nil,
        manufacturerName: String? = nil,
        serialNumber: String? = nil,
        moduleInfo: [UInt8: ModuleInfo] = [:],
        loggingTime: LoggingTimeRef? = nil
    ) {
        self.isMetaBoot = isMetaBoot
        self.firmwareRevision = firmwareRevision
        self.hardwareRevision = hardwareRevision
        self.modelNumber = modelNumber
        self.manufacturerName = manufacturerName
        self.serialNumber = serialNumber
        self.moduleInfo = moduleInfo
        self.loggingTime = loggingTime
        #if DEBUG
        print("[BoardState] init -> metaBoot: \(isMetaBoot), fw: \(String(describing: firmwareRevision)), hw: \(String(describing: hardwareRevision)), model: \(String(describing: modelNumber)), mfr: \(String(describing: manufacturerName)), serial: \(String(describing: serialNumber)), modules: \(moduleInfo.count), loggingTime: \(String(describing: loggingTime))")
        #endif
    }
}
