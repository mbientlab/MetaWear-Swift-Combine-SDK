@main
struct MacApp: App {

    @NSApplicationDelegateAdaptor private var app: AppDelegate

    var body: some Scene {
        MainWindowScene(factory: .init(root: app.root))
    }
}

@main
struct iOSApp: App {

    @UIApplicationDelegateAdaptor private var app: AppDelegate

    var body: some Scene {
        MainScene(factory: .init(root: app.root))
    }
}
