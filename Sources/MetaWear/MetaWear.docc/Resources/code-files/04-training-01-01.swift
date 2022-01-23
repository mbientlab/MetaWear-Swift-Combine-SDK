class TrainingUseCase: ObservableObject {

    private weak var metawear: MetaWear?
    ...

}

extension TrainingUseCase {

    func easyMacroExampleBeforeRealOne() {
        logSub = metawear?
            .publishWhenConnected()
            .first()
            .macro(executeOnBoot: true, actions: { macro in
                macro
                    .recordEventsOnButtonUp   { $0.command(.ledFlash(.Presets.eight.pattern)) }
                    .recordEventsOnButtonDown { $0.command(.ledFlash(.Presets.zero.pattern))  }
            })
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        metawear?.connect()
    }
}
