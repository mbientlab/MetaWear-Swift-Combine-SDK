/**
 * MetaWear+Async.swift
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

import Foundation
import MetaWearCpp
import Combine

public typealias MetaWearBoard = OpaquePointer

public extension MetaWearBoard {

    /// When pointing to a board, this stops logging, deletes recorded logs and macros, tears down the board and disconnects.
    ///
    func resetToFactoryDefaults() {
        mbl_mw_logging_stop(self)
        mbl_mw_metawearboard_tear_down(self)
        mbl_mw_logging_clear_entries(self)
        mbl_mw_macro_erase_all(self)
        mbl_mw_debug_reset_after_gc(self) //05
        mbl_mw_debug_disconnect(self) //06
    }

    /// When pointing to a board, ends recording of an `MblMwEvent`. Combine wrapper for `mbl_mw_event_end_record`.
    ///
    func eventEndRecording() -> PassthroughSubject<Void,MetaWearError> {

        let subject = PassthroughSubject<Void,MetaWearError>()

        mbl_mw_event_end_record(self, bridgeRetained(obj: subject)) { (context, event, status) in
            let _subject: PassthroughSubject<Void,MetaWearError> = bridgeTransfer(ptr: context!)

            guard status == 0 else {
                _subject.send(completion: .failure(.operationFailed("Event end record failed: \(status)")))
                return
            }
            _subject.send()
            _subject.send(completion: .finished)
        }

        return subject
    }

    /// When pointing to a board, ends macro recordings. Combine wrapper for `mbl_mw_macro_end_record`.
    ///
    func macroEndRecording() -> PassthroughSubject<Int32,MetaWearError> {

        let subject = PassthroughSubject<Int32,MetaWearError>()

        mbl_mw_macro_end_record(self, bridgeRetained(obj: subject)) { (context, board, value) in
            let _subject: PassthroughSubject<Int32,MetaWearError> = bridgeTransfer(ptr: context!)
            _subject.send(value)
            _subject.send(completion: .finished)
        }

#warning("What is the return value?")
        return subject
    }

    /// When pointing to a board, creates a timer. Combine interface to `mbl_mw_timer_create`.
    ///
    func createTimer(period: UInt32,
                     repetitions: UInt16 = 0xFFFF,
                     immediateFire: Bool = false
    ) -> PassthroughSubject<OpaquePointer, MetaWearError> {

        let subject = PassthroughSubject<OpaquePointer,MetaWearError>()

        mbl_mw_timer_create(self, period, repetitions, immediateFire ? 0 : 1, bridgeRetained(obj: subject)) { (context, timer) in
            let _subject: PassthroughSubject<OpaquePointer, MetaWearError> = bridgeTransfer(ptr: context!)

            if let timer = timer {
                _subject.send(timer)
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not create timer")))
            }
        }

#warning("What are the return value(s)?")
        return subject
    }

    /// When pointing to a board, collects an array of logger signals created before this session. Combine wrapper for `mbl_mw_metawearboard_create_anonymous_datasignals`.
    ///
    func collectAnonymousLoggerSignals() -> PassthroughSubject<[OpaquePointer], MetaWearError> {

        let subject = PassthroughSubject<[OpaquePointer], MetaWearError>()

        mbl_mw_metawearboard_create_anonymous_datasignals(self, bridgeRetained(obj: subject))
        { (context, board, anonymousSignals, size) in
            let _subject: PassthroughSubject<[OpaquePointer], MetaWearError> = bridgeTransfer(ptr: context!)

            guard let signals = anonymousSignals else {
                _subject.send(completion: .failure(.operationFailed("Could not create anonymous data signals (status = \(size)")))
                return
            }
            guard size > 0 else {
                _subject.send(completion: .failure(.operationFailed("Device is not logging any sensor data")))
                return
            }

            let array = (0..<size).map { signals[Int($0)]! }
            _subject.send(array)
            _subject.send(completion: .finished)
        }

        return subject
    }
}
