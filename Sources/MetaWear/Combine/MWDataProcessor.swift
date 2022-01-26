// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp
import Combine
import SwiftUI

// MARK: - Data Processor C++ Functions

extension Publisher where Output == MWDataSignal {

    /// Downsample a signal to a lower throughput rate.
    ///
    /// - Parameters:
    ///   - mode: Either passthrough (no changes) or delta (compute difference between last value)
    ///   - rate: One value will emit per period
    ///
    /// - Returns: Processed data signal
    ///
    func throttle(mode: MWDataProcessor.ThrottleMutation = .passthrough, rate: MWFrequency) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError()
            .flatMap { $0.throttle(mode: mode, rate: rate) }
            .eraseToAnyPublisher()
    }

    func accounterCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.accounterCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_accounter_create_count`
    /// Add counter to packet
    ///
    func accounterCreateCount() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.accounterCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_accounter_create`
    /// Continuous sum
    ///
    func accumulatorCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.accounterCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_accumulator_create_size`
    /// Continuous sum
    ///
    func accumulatorCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.accumulatorCreateWithSize(size: size) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_buffer_create`
    /// Buffer
    ///
    func bufferCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.bufferCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_counter_create`
    /// Counter
    ///
    func counterCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.counterCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_counter_create_size`
    /// Counter with size
    func counterCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.counterCreateWithSize(size: size) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_average_create`
    /// Create an averager
    ///
    func averagerCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.averagerCreate(size: size) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_highpass_create`
    /// Create a high pass filter
    ///
    func highpassFilterCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.highpassFilterCreate(size: size) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_lowpass_create`
    /// Create a low pass filter
    ///
    func lowpassFilterCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.lowpassFilterCreate(size: size) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_packer_create`
    /// Pack
    ///
    func packerCreate(count: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.packerCreate(count: count) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_rms_create`
    /// RMS
    ///
    func rmsCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.rmsCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_rss_create`
    /// RSS
    ///
    func rssCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.rssCreate() }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_sample_create`
    /// Sample
    ///
    func sampleCreate(binSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.sampleCreate(binSize: binSize) }.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_delta_create`
    /// Change
    ///
    func deltaCreate(mode: MWDataProcessor.DeltaMode, magnitude: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.deltaCreate(mode: mode, magnitude: magnitude) }.eraseToAnyPublisher()
    }

    func filter(_ op: MWDataProcessor.ComparatorOption, reference: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.filter(op, reference: reference) }.eraseToAnyPublisher()
    }

    func filter(_ op: MWDataProcessor.ComparatorOption, mode: MWDataProcessor.ComparatorMode, references: [Float]) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.filter(op, mode: mode, references: references) }.eraseToAnyPublisher()
    }

    func fuserCreate(with signal: OpaquePointer?) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.fuserCreate(with: signal) }.eraseToAnyPublisher()
    }

    func mathCreate(op: MWDataProcessor.MathOperation, rhs: Float, signed: Bool? = nil) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.mathCreate(op: op, rhs: rhs, signed: signed) }.eraseToAnyPublisher()
    }

    func passthroughCreate(mode: MWDataProcessor.PassthroughMode, count: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.passthroughCreate(mode: mode, count: count) }.eraseToAnyPublisher()
    }

    func pulseCreate(operation: MWDataProcessor.PulseOutput, threshold: Float, width: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.pulseCreate(operation: operation, threshold: threshold, width: width) }.eraseToAnyPublisher()
    }

    func thresholdCreate(mode: MWDataProcessor.ThresholdMode, boundary: Float, hysteresis: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.thresholdCreate(mode: mode, boundary: boundary, hysteresis: hysteresis) }.eraseToAnyPublisher()
    }
}

// MARK: - Methods with UInt8 or no parameters

public extension MWDataSignal {

    /// Combine interface for `mbl_mw_dataprocessor_accounter_create_count`
    /// Add timer to packet
    ///
    func accounterCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accounter_create, self)
    }
    
    /// Combine interface for `mbl_mw_dataprocessor_accounter_create_count`
    /// Add counter to packet
    ///
    func accounterCreateCount() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accounter_create_count, self)
    }
    
    /// Combine interface for `mbl_mw_dataprocessor_accounter_create`
    /// Continuous sum
    ///
    func accumulatorCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accumulator_create, self)
    }
    
    /// Combine interface for `mbl_mw_dataprocessor_accumulator_create_size`
    /// Continuous sum
    ///
    func accumulatorCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accumulator_create_size, self, size)
    }

    /// Combine interface for `mbl_mw_dataprocessor_buffer_create`
    /// Buffer
    ///
    func bufferCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_buffer_create, self)
    }

    /// Combine interface for `mbl_mw_dataprocessor_counter_create`
    /// Counter
    ///
    func counterCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_counter_create, self)
    }

    /// Combine interface for `mbl_mw_dataprocessor_counter_create_size`
    /// Counter with size
    func counterCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accumulator_create_size, self, size)
    }

    /// Combine interface for `mbl_mw_dataprocessor_average_create`
    /// Create an averager
    ///
    func averagerCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_average_create, self, size)
    }

    /// Combine interface for `mbl_mw_dataprocessor_highpass_create`
    /// Create a high pass filter
    ///
    func highpassFilterCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_average_create, self, size)
    }

    /// Combine interface for `mbl_mw_dataprocessor_lowpass_create`
    /// Create a low pass filter
    ///
    func lowpassFilterCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_lowpass_create, self, size)
    }

    /// Combine interface for `mbl_mw_dataprocessor_packer_create`
    /// Pack
    ///
    func packerCreate(count: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_packer_create, self, count)
    }

    /// Combine interface for `mbl_mw_dataprocessor_rms_create`
    /// RMS
    ///
    func rmsCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_rms_create, self)
    }

    /// Combine interface for `mbl_mw_dataprocessor_rss_create`
    /// RSS
    ///
    func rssCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_rss_create, self)
    }

    /// Combine interface for `mbl_mw_dataprocessor_sample_create`
    /// Sample
    ///
    func sampleCreate(binSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_sample_create, self, binSize)
    }
}

// MARK: - Methods with extra parameters

public extension MWDataSignal {

    /// Combine interface for `mbl_mw_dataprocessor_delta_create`
    /// Change
    ///
    func deltaCreate(mode: MWDataProcessor.DeltaMode, magnitude: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {

        let subject = _MWDataProcessorSubject()
        let code = mbl_mw_dataprocessor_delta_create(self, mode.cppValue, magnitude, bridge(obj: subject)) { (context, delta) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)
            if let delta = delta {
                _subject.send(delta)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create delta")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// A Swifty wrapper for `mbl_mw_dataprocessor_comparator_create`, which creates an on-board data processor that emits a value only when the comparison is satisfied.
    ///
    func filter(_ op: MWDataProcessor.ComparatorOption, reference: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {

        let subject = _MWDataProcessorSubject()
        let code = mbl_mw_dataprocessor_comparator_create(self, op.cppValue, reference, bridge(obj: subject)) { (context, comparator) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let comparator = comparator {
                _subject.send(comparator)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create comparator")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_multi_comparator_create`
    /// Compare
    ///
    func filter(_ op: MWDataProcessor.ComparatorOption, mode: MWDataProcessor.ComparatorMode, references: [Float]) -> AnyPublisher<MWDataProcessorSignal, MWError> {

        let subject = _MWDataProcessorSubject()
        var references = references

        mbl_mw_dataprocessor_multi_comparator_create(self, op.cppValue, mode.cppValue, &references, UInt8(references.count), bridge(obj: subject)) { (context, comparator) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let comparator = comparator {
                _subject.send(comparator)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create comparator")))
            }
        }
        return subject.eraseToAnyPublisher()
    }

    func fuserCreate(with signal: OpaquePointer?) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        withUnsafePointer(to: signal) { sig in
            let mutable = UnsafeMutablePointer<OpaquePointer?>(mutating: sig)
            let subject = _MWDataProcessorSubject()

            let code = mbl_mw_dataprocessor_fuser_create(self, mutable, 1,  bridge(obj: subject)) { (context, delta) in
                let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

                if let delta = delta {
                    _subject.send(delta)
                } else {
                    _subject.send(completion: .failure(.operationFailed("could not create fuser")))
                }
            }
            return subject.erasedWithDataProcessorError(code: code)
        }
    }

    /// Combine interface for `mbl_mw_dataprocessor_math_create`
    /// Simple math ops
    ///
    func mathCreate(op: MWDataProcessor.MathOperation, rhs: Float, signed: Bool? = nil) -> AnyPublisher<MWDataProcessorSignal, MWError> {

        let subject = _MWDataProcessorSubject()
        let handler: MblMwFnDataProcessor = { (context, math) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let math = math {
                _subject.send(math)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create math")))
            }
        }

        let code: Int32
        switch signed {
            case .none:
                code = mbl_mw_dataprocessor_math_create(self, op.cppValue, rhs, bridge(obj: subject), handler)
            case .some(true):
                code = mbl_mw_dataprocessor_math_create_signed(self, op.cppValue, rhs, bridge(obj: subject), handler)
            case .some(false):
                code = mbl_mw_dataprocessor_math_create_unsigned(self, op.cppValue, rhs, bridge(obj: subject), handler)
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_passthrough_create`
    /// Passthrough
    ///
    func passthroughCreate(mode: MWDataProcessor.PassthroughMode, count: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        let subject = _MWDataProcessorSubject()
        let code = mbl_mw_dataprocessor_passthrough_create(self, mode.cppValue, count, bridge(obj: subject)) { (context, passthrough) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let passthrough = passthrough {
                _subject.send(passthrough)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create passthrough")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_pulse_create`
    /// Pulse detector
    ///
    func pulseCreate(operation: MWDataProcessor.PulseOutput, threshold: Float, width: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {

        let subject = _MWDataProcessorSubject()
        let code = mbl_mw_dataprocessor_pulse_create(self, operation.cppValue, threshold, width, bridge(obj: subject)) { (context, success) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let success = success {
                _subject.send(success)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create pulse")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_threshold_create`
    ///
    func thresholdCreate(mode: MWDataProcessor.ThresholdMode, boundary: Float, hysteresis: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {

        let subject = _MWDataProcessorSubject()
        let code = mbl_mw_dataprocessor_threshold_create(self, mode.cppValue, boundary, hysteresis, bridge(obj: subject)) { (context, threshold) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let threshold = threshold {
                _subject.send(threshold)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create threshold")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Downsample a signal to a lower throughput rate.
    ///
    /// - Parameters:
    ///   - mode: Either passthrough (no changes) or delta (compute difference between last value)
    ///   - rate: One value will emit per period
    ///
    /// - Returns: Processed data signal
    ///
    func throttle(mode: MWDataProcessor.ThrottleMutation = .passthrough, rate: MWFrequency) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        let period = UInt32(rate.periodMs)
        let subject = _MWDataProcessorSubject()
        let code = mbl_mw_dataprocessor_time_create(self, mode.cppValue, period, bridge(obj: subject)) { (context, threshold) in
            let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

            if let threshold = threshold {
                _subject.send(threshold)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create throttle processor")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }
}

// MARK: - Helpers

public extension Publisher where Output == MWDataProcessorSignal, Failure == MWError {

    func erasedWithDataProcessorError(code: Int32) -> AnyPublisher<Output,Failure> {
        tryMap { output in
            if let error = Self._errorForCode(Int(code)) {
                throw MWError.operationFailed(error)
            } else {
                return output
            }
        }
        .mapToMWError()
        .eraseToAnyPublisher()
    }

    // Error for MblMwDataSignal
    private static func _errorForCode(_ code: Int) -> String? {
        switch code {
            case MBL_MW_STATUS_WARNING_UNEXPECTED_SENSOR_DATA:
                return "Data unexpectedly received from a sensor"
            case MBL_MW_STATUS_WARNING_INVALID_PROCESSOR_TYPE:
                return "Invalid processor passed into a dataprocessor function"
            case MBL_MW_STATUS_ERROR_UNSUPPORTED_PROCESSOR:
                return "Processor not supported for the data signal"
            case MBL_MW_STATUS_WARNING_INVALID_RESPONSE:
                return "Invalid response receieved from the MetaWear notify characteristic"
            case MBL_MW_STATUS_ERROR_TIMEOUT:
                return "Timeout occured during an asynchronous operation"
            case MBL_MW_STATUS_ERROR_SERIALIZATION_FORMAT:
                return "Cannot restore API state given the input serialization format"
            case MBL_MW_STATUS_ERROR_ENABLE_NOTIFY:
                return "Failed to enable notifications"
            default:
                return nil
        }
    }

}
