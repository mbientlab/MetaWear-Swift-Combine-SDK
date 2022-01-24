class TrainingUseCase: ObservableObject {

    private weak var metawear: MetaWear?
    ...

}

extension TrainingUseCase {

    func easyMacroExampleBeforeRealOne() {
        logSub = metawear?
            .publishWhenConnected()
            .first()
            .command(.macroStartRecording(runOnStartup: true))
            .recordEvents(for: .buttonUp, { recording in
                recording.command(.ledFlash(.Presets.eight.pattern))
            })
            .recordEvents(for: .buttonDown, { recording in
                recording.command(.ledFlash(.Presets.zero.pattern))
            })
            .command(.macroStopRecordingAndGenerateIdentifier)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        metawear?.connect()
    }
}
