import Foundation

/// Upstream builds with no patch metadata retain the existing update behavior.
struct DistributionPolicy {
    let patchRevision: String?

    init(info: [String: Any]) {
        let revision = (info["VRPatchRevision"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        patchRevision = revision?.isEmpty == false ? revision : nil
    }

    var allowsOfficialInstaller: Bool { patchRevision == nil }
}
