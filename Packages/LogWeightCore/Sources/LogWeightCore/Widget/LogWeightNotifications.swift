import Foundation

extension Notification.Name {
    /// Posted after the widget save intent commits a weight through HealthKit in the host app.
    public static let logWeightWidgetDidSave = Notification.Name("logWeightWidgetDidSave")
}
