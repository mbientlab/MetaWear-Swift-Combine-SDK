// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp
import Combine

/// Data processors attach to a sensor signal or to another data processor to transform or gate the output, possibly mutating its output data type.
/// * **Be sure that the output data type will be properly handled on stream or download.**
/// * **Some processors are incompatible with logging.**
///
/// You can apply data processors in the `.log` or `.stream` operators, for example, as they return a closure for chaining processor commands. You can also use `.getLoggerMutablePointer` to start constructing the signal yourself.
///
/// 1.  **Accounter**       Adds additional information to the payload to facilitate packet reconstruction.
/// 3.  **Average**         Computes a running average of the input.
/// 4.  **Buffer**          Captures input data which can be retrieved at a later point in time.
/// 5.  **Comparator**      Only allows data through that satisfies a comparison operation.
/// 6.  **Counter**         Counts the number of times an event was fired.
/// 7.  **Delta**           Only allows data through that is a min distance from a reference value.
/// 8.  **Fuser**           Combine data from multiple data sources into 1 data packet.
/// 9.  **Math**            Performs arithmetic on sensor data.
/// 10. **Packer**          Combines multiple data values into 1 BLE packet.
/// 11. **Passthrough**     Gate that only allows data though based on a user configured internal state.
/// 12. **Pulse**           Detects and quantifies a pulse over the input values.
/// 2.  **Running Sum**     Tallies a running sum of the input.
/// 13. **RMS**             Computes the root mean square of the input.
/// 14. **RSS**             Computes the root sum square of the input.
/// 15. **Sample**          Holds data until a certain amount has been collected.
/// 16. **Threshold**       Allows data through that crosses a boundary.
/// 17. **Throttle**        Periodically allow data through (Timer in C++)
///
public struct MWDataProcessor { private init() {} }

// MARK: - Data Processor Operators

extension Publisher where Output == MWDataSignal {

    /// Not typically used. The accounter processor adds additional information to the BTLE packet to reconstruct the data's timestamp from a counter, typically used with streaming raw accelerometer, gyro, and magnetometer data.
    ///
    /// This processor is designed specifically for streaming, DO NOT use with the logger.
    ///
    func addAccounterForDateReconstruction() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.accounterCreate() }.eraseToAnyPublisher()
    }

    /// Adds a simple counter (1, 2, 3) to the input signal to ensure packets are coming in order. Requires unwrapping the C struct's extra value. Combine SDK version 0.5.0 does not automatically parse this value.
    ///
    func addIterationCountAsExtraValue() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.accounterCreateCount() }.eraseToAnyPublisher()
    }

    /// A delta processor computes the difference between two successive data values and only allows dathrough that creates a difference greater in magnitude than the specified threshold.
    ///
    /// When creating a delta processor, users will also choose how the processor transforms the output whican, in some cases, alter the output data type id.
    ///
    ///  - **Absolute**    Input passed through untouched    Same as input source i.e. float -> float
    ///  - **Differential**    Difference between current and previous    If input is unsigned int, output is signed int
    ///  - **Binary**    1 if difference > 0, -1 if less than 0    Output is always signed int
    ///
    func computeDelta(mode: MWDataProcessor.DeltaMode, magnitude: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.computeDelta(mode: mode, magnitude: magnitude) }.eraseToAnyPublisher()
    }

    /// The averager computes a running average over the over the inputs. It will not produce any output until it has accumulated enough samples to match the specified sample size.
    ///
    /// The output data type id of averager is the same as its input source.
    ///
    func average(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.average(size: size) }.eraseToAnyPublisher()
    }

    /// The buffer processor captures input data which can be read at a later time using mbl_mw_datasignal_read; no output is produced by this processor.
    ///
    /// The data type id of a buffer's state is the same as its input source.
    ///
    func buffer() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.buffer() }.eraseToAnyPublisher()
    }

    /// A counter keeps a tally of how many times it is called. It can be used by MblMwEvent pointers to count the numbers of times a MetaWear event was fired and enable simple events to utilize the full set of firmware features.
    ///
    /// Counter data is only interpreted as an unsigned integer.
    ///
    func counted(size: UInt8?) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { signal -> AnyPublisher<MWDataProcessorSignal, MWError> in
            if let size = size { return signal.counterCreateWithSize(size: size) }
            else { return signal.counterCreate() }
        }.eraseToAnyPublisher()
    }

    /// The comparator removes data that does not satisfy the comparison operation. Callers can force a signed or unsigned comparison, or let the API determine which is appropriate.
    ///
    ///  The output data type id of comparator is the same as its input source.
    ///
    func filter(_ op: MWDataProcessor.ComparatorOption, reference: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.filter(op, reference: reference) }.eraseToAnyPublisher()
    }

    /// Starting from firmware v1.2.3, the comparator can accept multiple reference values to compare against and has additional operation modes that can modify output values and when outputs are produced. The multi-value comparison filter is an extension of the comparison filter implemented on older firmware.
     ///
    func filter(_ op: MWDataProcessor.ComparatorOption, mode: MWDataProcessor.ComparatorMode, references: [Float]) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.filter(op, mode: mode, references: references) }.eraseToAnyPublisher()
    }

    /// The fuser processor combines data from multiple sensors into 1 message. When fusing multiple data sources, ensure that they are sampling at the same frequency, or at the very least, integer multiples of the fastest frequency. Data sources sampling at the lower frequencies will repeat the last received value.
    ///
    /// Unlike the other data sources, fuser data is represented as an MblMwData array, which is indexed based on the order of the data signals passed into mbl_mw_dataprocessor_fuser_create.
    ///
    func fuse(with signal: OpaquePointer?) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.fuse(with: signal) }.eraseToAnyPublisher()
    }

    /// Passes inputs that are **higher** than the running average of the previous N samples. Output from this processor is delayed until the first N samples have been received.
    ///
    func highPass(filterBufferSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.highPass(filterBufferSize: filterBufferSize) }.eraseToAnyPublisher()
    }

    /// Passes inputs that are **lower** than the running average of the previous N samples. Output from this processor is delayed until the first N samples have been received.
    ///
    func lowPass(filterBufferSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.lowPass(filterBufferSize: filterBufferSize) }.eraseToAnyPublisher()
    }

    /// The math processor performs arithmetic or logical operations on the input. Users can force signed or unsigned operation, or allow the API to determine which is appropriate.
    ///
    /// Depending on the operation, the output data type id can change.
    ///   - **Add, Sub, Mult, Div, Mod** If input is unsigned, output is signed
    ///   - **Sqrt, Abs** If input is signed, output is unsigned
    ///   - **Const** Output type id is the same as input type id
    ///   - **Remaining Ops** API cannot infer, up to user to reassemble the bytes
    ///
    func math(_ op: MWDataProcessor.MathOperation, rhs: Float, signed: Bool? = nil) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.math(op: op, rhs: rhs, signed: signed) }.eraseToAnyPublisher()
    }

    /// Prevents data flow given a condition (all, after a tally is above 0, or up until a threshold is reached).
    ///
    func passthrough(mode: MWDataProcessor.PassthroughMode, count: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.passthrough(mode: mode, count: count) }.eraseToAnyPublisher()
    }

    /// The packer processor combines multiple data samples into 1 BLE packet to increase the data throughput. You can pack between 4 to 8 samples per packet depending on the data size.
    ///
    /// Note that if you use the packer processor with raw motion data instead of using their packed data producer variants, you will only be able to combine 2 data samples into a packet instead of 3 samples however, you can chain an accounter processor to associate a timestamp with the packed data.
    ///
    func packerCreate(count: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.packerCreate(count: count) }.eraseToAnyPublisher()
    }

    /// The pulse processor detects and quantifies a pulse over a set of data.
    ///
    /// Pulses are defined as a minimum number of data points that rise above then fall below a threshold and quantified by transforming the collection of data into three different values:
    ///
    func pulse(operation: MWDataProcessor.PulseOutput, threshold: Float, width: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.pulseCreate(operation: operation, threshold: threshold, width: width) }.eraseToAnyPublisher()
    }

    /// The accumulator computes a running sum over the inputs. Users can explicitly specify an output size (1 to 4 bytes) or let the API infer an appropriate size.
    ///
    /// The output data type id of an accumulator is the same as its input source.
    ///
    func runningSum(size: UInt8? = nil) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { signal -> AnyPublisher<MWDataProcessorSignal, MWError> in
            if let size = size { return signal.accumulator(size: size) }
            else { return signal.accumulator() }
        }.eraseToAnyPublisher()
    }

    /// The RMS processor computes the root mean square over multi component data i.e. XYZ values from acceleration data.
    ///
    /// The processor will convert MblMwCartesianFloat inputs into float outputs.
    ///
    func rootMeanSquare() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.rootMeanSquare() }.eraseToAnyPublisher()
    }

    /// Applies a root sum square, a statistical method for dealing with a series of values where each value is squared and then the total sum of these values square rooted. The result is transmission of less data via Bluetooth and less processing on your device.
    ///
    func rootSumSquare() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.rootSumSquare() }.eraseToAnyPublisher()
    }

    /// The sample processor acts like a bucket, only allowing data through once it has collected a set number of samples. It functions as a data historian of sorts providing a way to look at the data values prior to an event.
    ///
    ///  The output data type id of an accumulator is the same as its input source.
    ///
    func sampler(binSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.sampler(binSize: binSize) }.eraseToAnyPublisher()
    }

    /// The threshold processor only allows data through that crosses a boundary, either crossing above or below it. In absolute mode, the input type does not change. In binary mode, the output is always a signed int, with 1 indicating a rising value and -1 a falling value.
    ///
    func threshold(mode: MWDataProcessor.ThresholdMode, boundary: Float, hysteresis: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        mapToMWError().flatMap { $0.threshold(mode: mode, boundary: boundary, hysteresis: hysteresis) }.eraseToAnyPublisher()
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
        mapToMWError()
            .flatMap { $0.throttle(mode: mode, rate: rate) }
            .eraseToAnyPublisher()
    }
}

// MARK: - Swift Wrappers on C Pointer Data Processor Create Methods

// These restate the above publishers, but accessible on the data signal being modified.

// MARK: - (Extra parameters)

public extension MWDataSignal {

    func computeDelta(mode: MWDataProcessor.DeltaMode, magnitude: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {

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

    func fuse(with signal: OpaquePointer?) -> AnyPublisher<MWDataProcessorSignal, MWError> {
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

    func math(op: MWDataProcessor.MathOperation, rhs: Float, signed: Bool? = nil) -> AnyPublisher<MWDataProcessorSignal, MWError> {

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

    func passthrough(mode: MWDataProcessor.PassthroughMode, count: UInt16) -> AnyPublisher<MWDataProcessorSignal, MWError> {
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

    func threshold(mode: MWDataProcessor.ThresholdMode, boundary: Float, hysteresis: Float) -> AnyPublisher<MWDataProcessorSignal, MWError> {

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


// MARK: - (UInt8 or no parameters)

public extension MWDataSignal {

    func accounterCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accounter_create, self)
    }

    func accounterCreateCount() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accounter_create_count, self)
    }

    func accumulator() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accumulator_create, self)
    }

    func accumulator(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_accumulator_create_size, self, size)
    }

    func buffer() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_buffer_create, self)
    }

    func counterCreate() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_counter_create, self)
    }

    func counterCreateWithSize(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_counter_create_size, self, size)
    }

    func average(size: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_average_create, self, size)
    }

    func highPass(filterBufferSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_highpass_create, self, filterBufferSize)
    }

    func lowPass(filterBufferSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_lowpass_create, self, filterBufferSize)
    }

    func packerCreate(count: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_packer_create, self, count)
    }

    func rootMeanSquare() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_rms_create, self)
    }

    func rootSumSquare() -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_rss_create, self)
    }

    func sampler(binSize: UInt8) -> AnyPublisher<MWDataProcessorSignal, MWError> {
        _dataprocessor(mbl_mw_dataprocessor_sample_create, self, binSize)
    }
}
