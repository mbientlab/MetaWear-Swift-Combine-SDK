// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.


import Foundation

public struct MWDataTable {

    public let source: MWLogger
    public let headerRow: [String]
    /// Outer: Row. Inner: Data columns, starting with epoch.
    public let rows: [[String]]

    public init(download: MWData.LogDownload) {
        self.source = download.logger
        let utilities = download.logger.downloadUtilities
        self.headerRow = utilities.columnHeadings
        self.rows = utilities.convertRawDataToCSVColumns(download.data)
    }


}
