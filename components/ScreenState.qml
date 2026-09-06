import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool appstore

    // launcher and appstore share the same bottom-center region, so opening one closes the other
    onLauncherChanged: if (launcher) appstore = false
    onAppstoreChanged: if (appstore) launcher = false

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
