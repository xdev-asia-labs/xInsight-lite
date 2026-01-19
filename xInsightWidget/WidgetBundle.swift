import WidgetKit
import SwiftUI

@main
struct xInsightWidgetBundle: WidgetBundle {
    var body: some Widget {
        CPUWidget()
        MemoryWidget()
        SystemOverviewWidget()
    }
}
