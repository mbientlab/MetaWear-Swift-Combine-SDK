// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import CoreBluetooth

// MARK: - Read Once

public extension Publisher where Output == MetaWear {

    /// Performs a one-time read of a board signal and returned data type casting.
    ///
    /// - Parameters:
    ///   - readable: Type-safe preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<R: MWReadable>(_ readable: R) -> MWPublisher<Timestamped<R.DataType>> {
        // create an (metawear, signal) tuple
        tryMap { metawear -> (metawear: MetaWear, signal: MWDataSignal) in
            // retrieve the signal on the board from the readable -> MWDataSignal
            print("Attempting to retrieve signal for \(readable.name)")
            guard let signal = try readable.readableSignal(board: metawear.board) // Creates a MWDataSignal
            else { throw MWError.operationFailed("Board unavailable for \(readable.name).") }
            // configures the signal on the board as needed before reading.
            // needs to do peripehral writes
            print("Signal retrieved for \(readable.name). Configuring signal...")
            readable.readConfigure(board: metawear.board)
            // return the tuple
            print("Signal configured for \(readable.name)")
            return (metawear, signal)
        }
        .mapToMWError()
        .flatMap { metawear, signal -> MWPublisher<Timestamped<R.DataType>> in
            signal
                // perform read below
                .read(readable)
                // clean up after reading
                .handleEvents(receiveOutput: { _ in
                    print("Read operation completed for \(readable.name). Cleaning up...")
                    readable.readCleanup(board: metawear.board) })
                // replace any unspecific type casting failure message
                .replaceMWError(.operationFailed("Failed reading \(readable.name)."))
                // runs the read operation on metawear.bleQueue
                .erase(subscribeOn: metawear.bleQueue)
        }
        // converts the pipeline to AnyPublisher
        .eraseToAnyPublisher()
    }

    /// Performs a one-time read of a board signal and casting to the provided type.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<T>(signal: MWDataSignal, as type: T.Type) -> MWPublisher<Timestamped<T>> {
        // converts any potential errors into MWError type
        mapToMWError()
            // extract the MetaWear device
            .flatMap { metawear in
                metawear.board
                    // reads the data and casts it to type `T`
                    .read(as: T.self)
                    // ensures it runs on the correct queue
                    .erase(subscribeOn: metawear.bleQueue)
            }
            .eraseToAnyPublisher()
    }

    /// Performs a one-time read of compound board signals ((e.g., accelerometer + gyroscope) and returned data type casting.
    ///
    /// - Parameters:
    ///   - readable: Type-safe preset for `MetaWear` signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<E:MWReadableMerged>(_ readable: E) -> MWPublisher<E.DataType> {
        // converts any potential errors into MWError type
        mapToMWError()
            // calls `read()` on `readable` to retrieve the data
            .flatMap(readable.read)
            // hides the internal implementation and returns `AnyPublisher`
            .eraseToAnyPublisher()
    }
}

public extension MWDataSignal {

    /// When pointing to a data signal, perform a one-time read. Call clean up or configure methods yourself.
    /// Reads and converts raw BLE data.
    ///
    func read<R: MWReadable>(_ readable: R) -> AnyPublisher<Timestamped<R.DataType>, MWError> {
        // initiates the one-time read operation on the MWDataSignal.
        // returns AnyPublisher<MWData, MWError>
        _read()
            // convert the raw data into a Swift-compatible type, specifically R.DataType
            // from raw MWData -> Timestamped<DataType>
            .map(readable.convertRawToSwift)
            // replace a generic read error (C function pointer cannot form w/ generic)
            .replaceMWError(.operationFailed("Could not read \(R.DataType.self)"))
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, perform a one-time read. Call clean up or configure methods yourself.
    /// Reads and converts raw BLE data.
    ///
    /// Performs:
    ///   - `mbl_mw_datasignal_subscribe`
    ///   - `dataPtr.pointee.copy` -> ensures lifetime extends beyond closure
    ///   - `.valueAs` casts from `MetaWearData`
    ///   - `mbl_mw_datasignal_read`
    ///   - `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func read<T>(as: T.Type) -> AnyPublisher<Timestamped<T>, MWError> {
        _read()
            .map { ($0.timestamp, $0.valueAs() as T) }
            // Replace a generic read error (C function pointer cannot form w/ generic)
            .replaceMWError(.operationFailed("Could not read \(T.self)"))
            .eraseToAnyPublisher()
    }
}

// MARK: - Internal

private extension MWDataSignal {
    
//    func _read() -> AnyPublisher<MWData, MWError> {
//
//        assert(mbl_mw_datasignal_is_readable(self) != 0)
//        let subject = _datasignal_subscribe_outputOnlyOnce(self) // creates PassthroughSubject<MWData, MWError>()
//        mbl_mw_datasignal_read(self) // send bluetooth read
//
//        return subject
//            .handleEvents(receiveCompletion: { completion in
//                mbl_mw_datasignal_unsubscribe(self)
//            }, receiveCancel: {
//                mbl_mw_datasignal_unsubscribe(self)
//            })
//            .eraseToAnyPublisher()
//    }
    
    func _read() -> AnyPublisher<MWData, MWError> {
        guard let board = self.owner,
              let commandCharacteristic = board.commandCharacteristic,
              let peripheral = board.peripheral,
              let metawear = board.owner,
              self.header.isReadable() else {
            return Fail(error: MWError.bluetoothUnsupported).eraseToAnyPublisher()
        }

        let command: [UInt8] = [self.header.moduleID, self.header.registerID, 0]
        let data = Data(command)
        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)

        let subject = PassthroughSubject<Data, MWError>()
        print("Starting _read for signal with header: \(self.header)")

        metawear._readCharacteristicSubjects[board.notificationCharacteristic!, default: []].append(subject)
        peripheral.readValue(for: board.commandCharacteristic!)
        print("Triggered read for characteristic: \(board.commandCharacteristic!.uuid)")
        print(self.header)
        print(self.interpreter)
        
        // TO DO
        return subject
            .map { data in
                print("Data: \(data)")
                print("Data size: \(data.count)")
                return MWData(
                    timestamp: Date(),
                    data: data,
                    typeId: .MBL_MW_DT_ID_STRING
                )
            }
            .eraseToAnyPublisher()
    }
}
