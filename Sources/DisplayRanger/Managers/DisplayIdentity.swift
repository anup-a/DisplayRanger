import ColorSync
import CoreGraphics
import Foundation

/// CGDirectDisplayID is *not* stable across reconnects, so profiles key displays
/// by their persistent CoreDisplay UUID. This helper bridges the two.
enum DisplayIdentity {
    /// Stable UUID string for a display, e.g. "37D8832A-2D66-02CA-B9F7-8F30A301B230".
    /// Falls back to a vendor/model/serial composite if the UUID API returns nil.
    static func uuid(for id: CGDirectDisplayID) -> String {
        if let cf = CGDisplayCreateUUIDFromDisplayID(id) {
            let uuid = cf.takeRetainedValue()
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))"
    }

    /// Reverse lookup: find the live display ID currently backing a stored UUID.
    static func currentDisplayID(forUUID target: String, among displays: [DisplayModel]) -> CGDirectDisplayID? {
        displays.first { uuid(for: $0.id) == target }?.id
    }
}
