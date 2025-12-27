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

    public init(
        isMetaBoot: Bool,
        firmwareRevision: String? = nil,
        hardwareRevision: String? = nil,
        modelNumber: String? = nil,
        manufacturerName: String? = nil,
        serialNumber: String? = nil,
        moduleInfo: [UInt8: ModuleInfo] = [:]
    ) {
        self.isMetaBoot = isMetaBoot
        self.firmwareRevision = firmwareRevision
        self.hardwareRevision = hardwareRevision
        self.modelNumber = modelNumber
        self.manufacturerName = manufacturerName
        self.serialNumber = serialNumber
        self.moduleInfo = moduleInfo
    }
}
