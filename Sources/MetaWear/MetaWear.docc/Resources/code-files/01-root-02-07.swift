@main
struct MacApp: App {
    @StateObject private var root = Root()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                DeviceListSidebar(root)
                EmptyView()
            }
            .toolbar { BluetoothStateToolbar(root: root) }
            .onAppear(perform: root.start)
            .environmentObject(root)
        }
    }
}
