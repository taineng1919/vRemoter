import Foundation

func check(_ condition: Bool, _ label: String) {
    guard condition else { fatalError(label) }
    print("PASS: \(label)")
}
check(DistributionPolicy(info: [:]).allowsOfficialInstaller, "upstream update behavior preserved")
check(DistributionPolicy(info: ["VRPatchRevision": ""]).allowsOfficialInstaller, "empty revision is not a custom build")
check(!DistributionPolicy(info: ["VRPatchRevision": "9451-test1"]).allowsOfficialInstaller,
      "custom build cannot invoke official installer")
