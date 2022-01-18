class SensorLoggingController: ObservableObject {

    let name:                                 String
    @Published var logGyroscope             = true
    @Published var logAccelerometer         = true

    @Published private(set) var state:        State = .unknown
    @Published private(set) var enableCTAs:   Bool
    private var enableCTAsSub:                AnyCancellable? = nil

    @Published var showFolderExporter       = false
    @Published private(set) var exportable:   Folder? = nil

    init(mac: MACAddress, sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDeviceAndMetadata(mac)!
        self.metawear = device!
        self.name = metadata.name
        self.enableCTAs = device?.connectionState == .connected
    }

    deinit { try? FileManager.default.removeItem(at: Self.tempFolder) }

    private var startDate: Date     = .init()
    private let accelerometerConfig = MWAccelerometer(rate: .hz100, gravity: .g16)
    private let gyroscopeConfig     = MWGyroscope(rate: .hz100, range: .dps2000)

    private unowned let metawear: MetaWear
    private var logSub: AnyCancellable? = nil
    private var downloadSub: AnyCancellable? = nil

    enum State: Equatable {
        case unknown
        case logging
        case downloading(Double)
        case downloaded
        case loggingError(String)
        case downloadError(String)
    }
}

extension SensorLoggingController {

    func onAppear() {
        metawear.connect()

        enableCTAsSub = metawear.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.enableCTAs = $0 == .connected }
    }

    func log() {
        logSub = metawear
            .publishWhenConnected()
            .first()
            .optionallyLog(logGyroscope ? gyroscopeConfig : nil)
            .optionallyLog(logAccelerometer ? accelerometerConfig : nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                    case .failure(let error):
                        self?.state = .loggingError(error.localizedDescription)
                    case .finished: return
                }
            } receiveValue: { [weak self] _ in
                self?.state = .logging
                self?.startDate = .init()
            }

        metawear.connect()
    }

    func download() {
        downloadSub = metawear
            .publishWhenConnected()
            .first()
            .downloadLogs(startDate: startDate)
            .handleEvents(receiveOutput: { [weak self] (_, percentComplete) in
                DispatchQueue.main.async { [weak self] in
                    self?.state = .downloading(percentComplete)
                }
            })
            .drop { $0.percentComplete < 1 }
            .sink { [weak self] completion in
                switch completion {
                    case .failure(let error):
                        DispatchQueue.main.async { [weak self] in
                            self?.state = .downloadError(error.localizedDescription)
                        }
                    case .finished: return
                }
            } receiveValue: { [weak self] (dataTables, percentComplete) in
                self?.prepareExportAndUpdateUI(for: dataTables)
            }

        metawear.connect()
    }

    func export() {
        if exportable != nil { showFolderExporter = true }
    }
}

private extension SensorLoggingController {

    func prepareExportAndUpdateUI(for dataTables: [MWDataTable]) {
        do {
            let exportableFolder = try makeCSVs(from: dataTables)
            DispatchQueue.main.async { [weak self] in
                self?.exportable = exportableFolder
                self?.state = .downloaded
            }
        } catch let error {
            DispatchQueue.main.async { [weak self] in
                self?.state = .exportError(error.localizedDescription)
            }
        }
    }

    func makeCSVs(from tables: [MWDataTable]) throws -> Folder {
        let folderName = [metawear.name, startDate.formatted(date: .abbreviated, time: .shortened)].joined(separator: " ")
        let files = tables.map { table -> (filename: String, csv: String) in
            let filename = [table.source.name, folderName].joined(separator: " ")
            return (filename, table.makeCSV())
        }

        let folderURL = try getTempDirectory(named: folderName)
        for file in files {
            let url = folderURL.appendingPathComponent(file.filename).appendingPathExtension(for: .commaSeparatedText)
            try file.csv.write(to: url, atomically: true, encoding: .utf8)
        }
        return try Folder(url: folderURL, name: folderName)
    }

    ...
}
