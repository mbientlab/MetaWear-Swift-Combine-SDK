// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.


import Foundation

public struct MWDataTable {

    public let source: MWNamedSignal
    public let headerRow: [String]
    /// Outer: Row. Inner: Data columns, starting with epoch.
    public let rows: [[String]]

    public init(download: MWData.LogDownload) {
        self.source = download.logger
        let utilities = download.logger.downloadUtilities
        self.headerRow = utilities.columnHeadings
        self.rows = utilities.convertRawDataToCSVColumns(download.data)
    }

    public init<S: MWStreamable>(streamed: [(time: Date, value: S.DataType)], _ streamable: S) {
        self.source = streamable.signalName
        let utilties = source.downloadUtilities
        self.headerRow = utilties.columnHeadings
        self.rows = streamed.map(streamable.asColumns)
    }

    public init<P: MWPollable>(streamed: [(time: Date, value: P.DataType)], _ streamable: P) {
        self.source = streamable.signalName
        let utilties = source.downloadUtilities
        self.headerRow = utilties.columnHeadings
        self.rows = streamed.map(streamable.asColumns)
    }
}
