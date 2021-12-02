// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.


import Foundation
import Combine
import MetaWearCpp

// MARK: - C++ Closure -> MWData

public typealias _MWStatusSubject         = PassthroughSubject<MWStatusCode,MWError>
public typealias _MWDataSubject            = PassthroughSubject<MWData, MWError>
public typealias _MWDataArraySubject       = CurrentValueSubject<[MWData], MWError>
public typealias _MWDataProcessorSubject  = PassthroughSubject<MWDataProcessorSignal, MWError>
public typealias _MWDataProcessorFunction = (OpaquePointer?, UnsafeMutableRawPointer?, MblMwFnDataProcessor?) -> Int32
public typealias _MWDataProcessorFunctionUInt8 = (OpaquePointer?, UInt8, UnsafeMutableRawPointer?, MblMwFnDataProcessor?) -> Int32

public func _datasignal_subscribe(_ signal: OpaquePointer) -> _MWDataSubject {
    let dataStream = _MWDataSubject()
    mbl_mw_datasignal_subscribe(signal, bridge(obj: dataStream)) { context, dataPtr in
        let _subject: _MWDataSubject = bridge(ptr: context!)
        if let data = dataPtr {
            _subject.send(data.pointee.copy())
        } else {
            let error = MWError.operationFailed("Could not subscribe")
            _subject.send(completion: .failure(error))
        }
    }
    return dataStream
}

public func _datasignal_subscribe_accumulate(_ signal: OpaquePointer) -> _MWDataArraySubject {
    let subject = _MWDataArraySubject([])
    mbl_mw_logger_subscribe(signal, bridge(obj: subject)) { _context, dataPtr in
        let _subject: _MWDataArraySubject = bridge(ptr: _context!)
        let datum = dataPtr!.pointee.copy()
        _subject.send(_subject.value + CollectionOfOne(datum))
    }
    return subject
}

public func _datasignal_subscribe_outputOnlyOnce(_ signal: OpaquePointer) -> _MWDataSubject {
    let dataStream = _MWDataSubject()
    mbl_mw_datasignal_subscribe(signal, bridge(obj: dataStream)) { context, dataPtr in
        let _subject: _MWDataSubject = bridge(ptr: context!)
        if let data = dataPtr {
            _subject.send(data.pointee.copy())
            _subject.send(completion: .finished)
        } else {
            let error = MWError.operationFailed("Could not subscribe")
            _subject.send(completion: .failure(error))
        }
    }
    return dataStream
}

public func _dataprocessor(_ dpFunc: _MWDataProcessorFunction,
                           _ signal: OpaquePointer,
                           errorLabel: String = #function
) -> AnyPublisher<MWDataProcessorSignal, MWError> {

    let subject = _MWDataProcessorSubject()
    let code = dpFunc(signal, bridge(obj: subject)) { (context, accumulator) in
        let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

        if let accumulator = accumulator {
            _subject.send(accumulator)
        } else {
            _subject.send(completion: .failure(.operationFailed("could not create data processor")))
        }
    }
    return subject
        .mapError { _ in .operationFailed("could not perform \(errorLabel)") }
        .erasedWithDataProcessorError(code: code)
}

public func _dataprocessor(_ dpFunc: _MWDataProcessorFunctionUInt8,
                           _ signal: OpaquePointer,
                           _ size: UInt8,
                           errorLabel: String = #function
) -> AnyPublisher<MWDataProcessorSignal, MWError> {

    let subject = _MWDataProcessorSubject()
    let code = dpFunc(signal, size, bridge(obj: subject)) { (context, accumulator) in
        let _subject: _MWDataProcessorSubject = bridge(ptr: context!)

        if let accumulator = accumulator {
            _subject.send(accumulator)
        } else {
            _subject.send(completion: .failure(.operationFailed("could not create sized data processor")))
        }
    }
    return subject
        .mapError { _ in .operationFailed("could not perform \(errorLabel)") }
        .erasedWithDataProcessorError(code: code)
}



// MARK: - Downloads

public extension Dictionary where Key == MWLogger, Value == CurrentValueSubject<[MWData], MWError> {
    func latest() -> [MWData.LogDownload] {
        map { key, subject in
            MWData.LogDownload(logger: key, data: subject.value)
        }
    }
}
