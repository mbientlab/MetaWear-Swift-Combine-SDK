@main
struct MacApp: App {
    @StateObject private var root = Root()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                DeviceListSidebar(root)
                EmptyView()
            }
            .onAppear(perform: root.start)
            .environmentObject(root)
        }
    }
}
