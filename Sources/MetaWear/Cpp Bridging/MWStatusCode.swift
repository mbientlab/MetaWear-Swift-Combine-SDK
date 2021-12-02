// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

/// Status codes returned by certain C++ functions
///
public enum MWStatusCode: String, CaseIterable {
    case ok
    case errorUnsupportedProcessor
    case errorTimeout
    case errorEnableNotify
    case errorSerializationFormat
    case warningInvalidProcessorType
    case warningInvalidResponse
    case warningUnexpectedSensorData

    public init?(cpp: Int32) {
        guard let code = Self.allCases.first(where: { $0.cppValue == cpp })
        else { return nil }
        self = code
    }

    public var cppValue: Int {
        switch self {
            case .ok: return STATUS_OK
            case .errorUnsupportedProcessor: return STATUS_ERROR_UNSUPPORTED_PROCESSOR
            case .errorTimeout: return STATUS_ERROR_TIMEOUT
            case .errorEnableNotify: return STATUS_ERROR_ENABLE_NOTIFY
            case .errorSerializationFormat: return STATUS_ERROR_SERIALIZATION_FORMAT
            case .warningInvalidProcessorType: return STATUS_WARNING_INVALID_PROCESSOR_TYPE
            case .warningInvalidResponse: return STATUS_WARNING_INVALID_RESPONSE
            case .warningUnexpectedSensorData: return STATUS_WARNING_UNEXPECTED_SENSOR_DATA
        }
    }

    static func send(to subject: PassthroughSubject<MWStatusCode,MWError>, cpp: Int32, completeOnOK: Bool) {
        guard let code = Self.init(cpp: cpp) else {
            subject.send(completion: .failure(.operationFailed("Unknown status code")))
            return
        }
        guard code == .ok else {
            subject.send(completion: .failure(.operationFailed("Status code: \(code.rawValue)")))
            return
        }
        subject.send(code)
        if completeOnOK { subject.send(completion: .finished) }
    }
}
