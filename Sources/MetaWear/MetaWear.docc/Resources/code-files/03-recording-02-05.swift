class DownloadUseCase: ObservableObject {

    private(set) var startDate:         Date
    @Published private(set) var state:  UseCaseState      = .notReady

    init(_ knownDevice: MWKnownDevice, startDate: Date) {
        self.startDate = startDate
        self.metawear = knownDevice.mw
        self.deviceName = knownDevice.meta.name
    }
}

extension DownloadUseCase {

    ...
}

private extension DownloadUseCase {

    func prepareForExport(dataTables: [MWDataTable]) {
        let prefix = startDate.formatted(date: .abbreviated, time: .shortened)

        let csvs = dataTables.map { table -> (String, Data) in
            let filename = [table.source.name, prefix].joined(separator: " ")
            let csv = table.makeCSV(delimiter: ",").data(using: .utf8)!
            return (filename, csv)
        }

        self?.export = ExportUseCase(...)
        ...
    }
}
