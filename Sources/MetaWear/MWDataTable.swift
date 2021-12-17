// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.


import Foundation

public struct MWDataTable {

    /// Maximum decimal places used for string formatting
    public static var stringDecimalDigits = 4
    public let source: MWNamedSignal
    public let headerRow: [String]
    /// Outer: Row. Inner: Data columns, starting with epoch.
    public let rows: [[String]]

    /// Make a CSV with a labeled header row, optionally with other delimiters like a pipe |
    public func makeCSV(delimiter: String = ",") -> String {
        rows.reduce(into: makeRow(row: headerRow)) { csv, row in
            csv.append(makeRow(row: row))
        }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    internal func makeRow(row: [String], delimiter: String = ",") -> String {
        row.joined(separator: delimiter).appending("\n")
    }

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
