/**
 * MblMwDataSignal+Async.swift
 * MetaWear
 *
 * Created by Stephen Schiffli on 5/3/18.
 * Copyright 2018 MbientLab Inc. All rights reserved.
 *
 * IMPORTANT: Your use of this Software is limited to those specific rights
 * granted under the terms of a software license agreement between the user who
 * downloaded the software, his/her employer (which must be your employer) and
 * MbientLab Inc, (the "License").  You may not use this Software unless you
 * agree to abide by the terms of the License which can be found at
 * www.mbientlab.com/terms.  The License limits your use, and you acknowledge,
 * that the Software may be modified, copied, and distributed when used in
 * conjunction with an MbientLab Inc, product.  Other than for the foregoing
 * purpose, you may not use, reproduce, copy, prepare derivative works of,
 * modify, distribute, perform, display or sell this Software and/or its
 * documentation for any purpose.
 *
 * YOU FURTHER ACKNOWLEDGE AND AGREE THAT THE SOFTWARE AND DOCUMENTATION ARE
 * PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY, TITLE,
 * NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL
 * MBIENTLAB OR ITS LICENSORS BE LIABLE OR OBLIGATED UNDER CONTRACT, NEGLIGENCE,
 * STRICT LIABILITY, CONTRIBUTION, BREACH OF WARRANTY, OR OTHER LEGAL EQUITABLE
 * THEORY ANY DIRECT OR INDIRECT DAMAGES OR EXPENSES INCLUDING BUT NOT LIMITED
 * TO ANY INCIDENTAL, SPECIAL, INDIRECT, PUNITIVE OR CONSEQUENTIAL DAMAGES, LOST
 * PROFITS OR LOST DATA, COST OF PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY,
 * SERVICES, OR ANY CLAIMS BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY
 * DEFENSE THEREOF), OR OTHER SIMILAR COSTS.
 *
 * Should you have any questions regarding your right to use this Software,
 * contact MbientLab via email: hello@mbientlab.com
 */

import MetaWearCpp
import Combine

public typealias MWDataProcessorSignal = OpaquePointer
public typealias MWBoardOrDataSignal = OpaquePointer

// MARK: - Data Processor C++ Functions

public extension MWBoardOrDataSignal {

    /// Combine interface for `mbl_mw_dataprocessor_accounter_create_count`
    /// Add timer to packet
    ///
    func accounterCreate() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_accounter_create(self, bridgeRetained(obj: subject)) { (context, counter) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let counter = counter {
                _subject.send(counter)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create accounter timer")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }
    
    /// Combine interface for `mbl_mw_dataprocessor_accounter_create_count`
    /// Add counter to packet
    ///
    func accounterCreateCount() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_accounter_create_count(self, bridgeRetained(obj: subject)) { (context, accounter) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let accounter = accounter {
                _subject.send(accounter)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create accounter counter")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }
    
    /// Combine interface for `mbl_mw_dataprocessor_accounter_create`
    /// Continuous sum
    ///
    func accumulatorCreate() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {
        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()

        let code = mbl_mw_dataprocessor_accumulator_create(self, bridgeRetained(obj: subject)) { (context, accumulator) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let accumulator = accumulator {
                _subject.send(accumulator)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create accumulator")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }
    
    /// Combine interface for `mbl_mw_dataprocessor_accumulator_create_size`
    /// Continuous sum
    ///
    func accumulatorCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_accumulator_create_size(self, size, bridgeRetained(obj: subject)) { (context, accumulator) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let accumulator = accumulator {
                _subject.send(accumulator)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create accumulator")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_counter_create`
    /// Counter
    ///
    func counterCreate() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_counter_create(self, bridgeRetained(obj: subject)) { (context, counter) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let counter = counter {
                _subject.send(counter)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create counter")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_counter_create_size`
    /// Counter with size
    func counterCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_accumulator_create_size(self, size, bridgeRetained(obj: subject)) { (context, counter) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let counter = counter {
                _subject.send(counter)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create counter")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_average_create`
    /// Create an averager
    ///
    func averagerCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_average_create(self, size, bridgeRetained(obj: subject)) { (context, averager) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let averager = averager {
                _subject.send(averager)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create averager")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_highpass_create`
    /// Create a high pass filter
    ///
    func highpassFilterCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_average_create(self, size, bridgeRetained(obj: subject)) { (context, highpass) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let highpass = highpass {
                _subject.send(highpass)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create high pass")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_lowpass_create`
    /// Create a low pass filter
    ///
    func lowpassFilterCreate(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_lowpass_create(self, size, bridgeRetained(obj: subject)) { (context, lowpass) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let lowpass = lowpass {
                _subject.send(lowpass)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create low pass")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_buffer_create`
    /// Buffer
    ///
    func bufferCreate() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_buffer_create(self, bridgeRetained(obj: subject)) { (context, buffer) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)
            if let buffer = buffer {
                _subject.send(buffer)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create buffer")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    #warning("THis is a a loggable and streamble datasignal.")
    /// Combine interface for `mbl_mw_dataprocessor_rms_create`
    /// RMS
    ///
    func rmsCreate() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_rms_create(self, bridgeRetained(obj: subject)) { (context, rms) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let rms = rms {
                _subject.send(rms)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create rms")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_rss_create`
    /// RSS
    ///
    func rssCreate() -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_rss_create(self, bridgeRetained(obj: subject)) { (context, rms) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let rms = rms {
                _subject.send(rms)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create rss")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_multi_comparator_create`
    /// Compare
    ///
    func simpleComparatorCreate(op: MblMwComparatorOperation, reference: Float) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_comparator_create(self, op, reference, bridgeRetained(obj: subject)) { (context, comparator) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

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
    func comparatorCreate(op: MblMwComparatorOperation, mode: MblMwComparatorMode, references: [Float]) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal, MetaWearError>()
        var references = references

        mbl_mw_dataprocessor_multi_comparator_create(self, op, mode, &references, UInt8(references.count), bridgeRetained(obj: subject)) { (context, comparator) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let comparator = comparator {
                _subject.send(comparator)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create comparator")))
            }
        }
        return subject.eraseToAnyPublisher()
    }

    /// Combine interface for `mbl_mw_dataprocessor_delta_create`
    /// Change
    ///
    func deltaCreate(mode: MblMwDeltaMode, magnitude: Float) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_delta_create(self, mode, magnitude, bridgeRetained(obj: subject)) { (context, delta) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)
            if let delta = delta {
                _subject.send(delta)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create delta")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_math_create`
    /// Simple math ops
    ///
    func mathCreate(op: MblMwMathOperation, rhs: Float, signed: Bool? = nil) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let handler: MblMwFnDataProcessor = { (context, math) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let math = math {
                _subject.send(math)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create math")))
            }
        }

        let code: Int32
        switch signed {
            case .none:
                code = mbl_mw_dataprocessor_math_create(self, op, rhs, bridgeRetained(obj: subject), handler)
            case .some(true):
                code = mbl_mw_dataprocessor_math_create_signed(self, op, rhs, bridgeRetained(obj: subject), handler)
            case .some(false):
                code = mbl_mw_dataprocessor_math_create_unsigned(self, op, rhs, bridgeRetained(obj: subject), handler)
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_packer_create`
    /// Pack
    ///
    func packerCreate(count: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_packer_create(self, count, bridgeRetained(obj: subject)) { (context, packer) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let packer = packer {
                _subject.send(packer)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create packer")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_passthrough_create`
    /// Passthrough
    ///
    func passthroughCreate(mode: MblMwPassthroughMode, count: UInt16) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_passthrough_create(self, mode, count, bridgeRetained(obj: subject)) { (context, passthrough) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

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
    func pulseCreate(operation: MblMwPulseOutput, threshold: Float, width: UInt16) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_pulse_create(self, operation, threshold, width, bridgeRetained(obj: subject)) { (context, success) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let success = success {
                _subject.send(success)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create pulse")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_sample_create`
    /// Sample
    ///
    func sampleCreate(binSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_sample_create(self, binSize, bridgeRetained(obj: subject)) { (context, sample) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let sample = sample {
                _subject.send(sample)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create sample")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_threshold_create`
    ///
    func thresholdCreate(mode: MblMwThresholdMode, boundary: Float, hysteresis: Float) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        let code = mbl_mw_dataprocessor_threshold_create(self, mode, boundary, hysteresis, bridgeRetained(obj: subject)) { (context, threshold) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let threshold = threshold {
                _subject.send(threshold)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create threshold")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

    /// Combine interface for `mbl_mw_dataprocessor_fuser_create`
    ///
    func fuserCreate(with: OpaquePointer) -> AnyPublisher<MWDataProcessorSignal, MetaWearError> {

        let subject = PassthroughSubject<MWDataProcessorSignal,MetaWearError>()
        var array: [OpaquePointer?] = [with]
        let code = mbl_mw_dataprocessor_fuser_create(self, UnsafeMutablePointer(&array), 1,  bridgeRetained(obj: subject)) { (context, delta) in
            let _subject: PassthroughSubject<MWDataProcessorSignal,MetaWearError> = bridgeTransfer(ptr: context!)

            if let delta = delta {
                _subject.send(delta)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create fuser")))
            }
        }
        return subject.erasedWithDataProcessorError(code: code)
    }

}

// MARK: - Helpers

fileprivate extension PassthroughSubject where Failure == MetaWearError {

    func erasedWithDataProcessorError(code: Int32) -> AnyPublisher<Output,Failure> {
        tryMap { output in
            if let error = Self._errorForCode(Int(code)) {
                throw MetaWearError.operationFailed(error)
            } else {
                return output
            }
        }
        .mapError { error -> MetaWearError in error as! MetaWearError } // Recast tryMap's mandated type erasure
        .eraseToAnyPublisher()
    }

    // Error for MblMwDataSignal
    private static func _errorForCode(_ code: Int) -> String? {
        switch code {
            case STATUS_WARNING_UNEXPECTED_SENSOR_DATA:
                return "Data unexpectedly received from a sensor"
            case STATUS_WARNING_INVALID_PROCESSOR_TYPE:
                return "Invalid processor passed into a dataprocessor function"
            case STATUS_ERROR_UNSUPPORTED_PROCESSOR:
                return "Processor not supported for the data signal"
            case STATUS_WARNING_INVALID_RESPONSE:
                return "Invalid response receieved from the MetaWear notify characteristic"
            case STATUS_ERROR_TIMEOUT:
                return "Timeout occured during an asynchronous operation"
            case STATUS_ERROR_SERIALIZATION_FORMAT:
                return "Cannot restore API state given the input serialization format"
            case STATUS_ERROR_ENABLE_NOTIFY:
                return "Failed to enable notifications"
            default:
                return nil
        }
    }

}
