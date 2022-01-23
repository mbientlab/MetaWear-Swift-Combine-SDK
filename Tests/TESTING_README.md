#  Setup Required

Our integration tests examine capabilities that are specific to certain MetaWear models. Many methods must constrain to specific devices.

Add your local machine's MetaWears to `TestDevices.swift`. Tip: If you don't have your MetaWear's local UUID memorized, run the test host app and tap on the MetaWear to copy its UUID and MAC address to the clipboard.

If a MetaWear ends up with bad state at some point, `ResetUtility.swift` is will perform CPR.
