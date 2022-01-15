// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

extension DispatchQueue {

    @discardableResult public static func isOnBleQueue() -> Bool {
        DispatchQueue.getSpecific(key: bleQueueKey) == bleQueueValue
    }

    public static func warnIfNotOnBleQueue() {
        guard DispatchQueue.isOnBleQueue() == false else { return }
        NSLog("A MetaWear library interaction was not performed on the BLE queue. Undefined behavior may occur.")
    }

    fileprivate static let bleQueueKey = DispatchSpecificKey<Int>()
    fileprivate static let bleQueueValue = 1111
    fileprivate static var scannerCount = 0

    internal static func makeScannerQueue() -> DispatchQueue {
        let queue = DispatchQueue(label: "com.mbientlab.bleQueue\(scannerCount)")
        scannerCount += 1
        queue.setSpecific(key: bleQueueKey, value: bleQueueValue)
        return queue
    }

    internal static func onBleQueue(_ queue: DispatchQueue,
                                  _ block: @escaping () -> Void) {
        if DispatchQueue.isOnBleQueue() { block() }
        else { queue.async { block() } }
    }
}
