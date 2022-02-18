// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.


import Foundation

/// Stringly-expressed data from any sensor, ready to export in CSV format.
///
public struct MWDataTable {

    /// Maximum decimal places used for string formatting
    public static var stringDecimalDigits = 4
    public let source: MWNamedSignal
    public var headerRow: [String]
    /// Outer: Row. Inner: Data columns, starting with epoch.
    public var rows: [[String]]

    /// Make a CSV with a labeled header row, optionally with other delimiters like a pipe |
    public func makeCSV(withHeaderRow: Bool = true, delimiter: String = ",") -> String {
        let header = withHeaderRow ? makeRow(row: headerRow) : ""
        return rows.reduce(into: header) { csv, row in
            csv.append(makeRow(row: row))
        }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    internal func makeRow(row: [String], delimiter: String = ",") -> String {
        row.joined(separator: delimiter).appending("\n")
    }

    /// - Parameter startDate: Time that the logging session started. Used to calculate elapsed time in an output CSV files, potentially synchronized across multiple devices. (A MetaWear ticks time, but lacks a calendar-aware clock.)
    ///
    public init(
        download: MWData.LogDownload,
        startDate: Date,
        dateColumns: [ExtraDateColumns] = ExtraDateColumns.allCases
    ) {
        self.source = download.logger
        let utilities = download.logger.downloadUtilities
        self.headerRow = dateColumns.updatingHeader(utilities.columnHeadings)

        guard dateColumns.isEmpty == false else {
            /// Only includes the epoch column, nothing else
            self.rows = utilities.convertRawDataToCSVColumns(download.data)
            return
        }

        /// Add in date stamp with (custom) formatting and time elapsed optional columns
        self.rows = utilities.convertRawDataToCSVColumns(download.data)
        .compactMap { row -> [String]? in
            guard let first = row.first, let epoch = Double(first) else { return nil }
            let date = Date(timeIntervalSince1970: epoch)
            let extras = dateColumns.makeDateColumns(for: date, startDate: startDate)
            var mutableRow = row
            mutableRow.insert(contentsOf: extras, at: 1)
            return mutableRow
        }
    }

    /// - Parameter startDate: Time that the streaming session started. Used to calculate elapsed time in an output CSV files, potentially synchronized across multiple devices. (A MetaWear ticks time, but lacks a calendar-aware clock.)
    ///
    public init<S: MWStreamable>(
        streamed: [(time: Date, value: S.DataType)],
        _ streamable: S,
        startDate: Date,
        dateColumns: [ExtraDateColumns] = ExtraDateColumns.allCases
    ) {
        self.source = streamable.signalName
        self.headerRow = dateColumns.updatingHeader(source.downloadUtilities.columnHeadings)
        self.rows = streamed.map {
            var columns = streamable.asColumns($0)
            if dateColumns.isEmpty { return columns }
            let extras = dateColumns.makeDateColumns(for: $0.time, startDate: startDate)
            columns.insert(contentsOf: extras, at: 1)
            return columns
        }
    }
    
    /// - Parameter startDate: Time that the streaming session started. Used to calculate elapsed time in an output CSV files, potentially synchronized across multiple devices. (A MetaWear ticks time, but lacks a calendar-aware clock.)
    ///
    public init<P: MWPollable>(
        streamed: [(time: Date, value: P.DataType)],
        _ streamable: P,
        startDate: Date,
        dateColumns: [ExtraDateColumns] = ExtraDateColumns.allCases
    ) {
        self.source = streamable.signalName
        self.headerRow = dateColumns.updatingHeader(source.downloadUtilities.columnHeadings)

        self.rows = streamed.map {
            var columns = streamable.asColumns($0)
            if dateColumns.isEmpty { return columns }
            let extras = dateColumns.makeDateColumns(for: $0.time, startDate: startDate)
            columns.insert(contentsOf: extras, at: 1)
            return columns
        }
    }

    /// For manually manipulating downloaded data
    ///
    public init(
        source: MWNamedSignal,
        startDate: Date,
        dateColumns: [ExtraDateColumns] = ExtraDateColumns.allCases,
        rows: [[String]]
    ) {
        self.source = source
        self.headerRow = dateColumns.updatingHeader(source.downloadUtilities.columnHeadings)
        self.rows = rows
    }
}

// MARK: - Timestamp and Elapsed Time Columns

public extension MWDataTable {

    enum ExtraDateColumns: Int, Equatable, Hashable, CaseIterable {
        case date
        case elapsed

        var header: String {
            switch self {
                case .date:
                    let zone = Self.zoneFormatter.string(from: Date())
                    return "Timestamp (\(zone))"
                case .elapsed: return "Elapsed (s)"
            }
        }

        public func string(date: Date, startdate: Date) -> String {
            switch self {
                case .date:
                    return Self.formatter.string(from: date)
                case .elapsed:
                    let elapsed = startdate.distance(to: date)
                    return String(format: "%.\(Self.timeElapsedDecimals)f", elapsed)
            }
        }

        /// Max is nanoseconds
        public static var timeElapsedDecimals = 3

        public static var zoneFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "Z"
            return f
        }()

        public static var formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH.mm.ss.SSS"
            return f
        }()
    }
}

internal extension Array where Element == MWDataTable.ExtraDateColumns {

    func updatingHeader(_ headerColumns: [String]) -> [String] {
        if isEmpty { return headerColumns }
        var update = headerColumns
        update.insert(contentsOf: self.map(\.header), at: 1)
        return update
    }

    func makeDateColumns(for date: Date, startDate: Date) -> [String] {
        map { column in
            column.string(date: date, startdate: startDate)
        }
    }
}
