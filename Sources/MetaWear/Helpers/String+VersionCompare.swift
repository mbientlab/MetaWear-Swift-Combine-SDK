// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

/// String helper functions
extension String {
    /// Inner comparison utility to handle same versions with different length. (Ex: "1.0.0" & "1.0")
    private func compare(toVersion targetVersion: String) -> ComparisonResult {
        let versionDelimiter = "."
        var result: ComparisonResult = .orderedSame
        var versionComponents = components(separatedBy: versionDelimiter)
        var targetComponents = targetVersion.components(separatedBy: versionDelimiter)
        let spareCount = versionComponents.count - targetComponents.count
        
        if spareCount == 0 {
            result = compare(targetVersion, options: .numeric)
        } else {
            let spareZeros = repeatElement("0", count: abs(spareCount))
            if spareCount > 0 {
                targetComponents.append(contentsOf: spareZeros)
            } else {
                versionComponents.append(contentsOf: spareZeros)
            }
            result = versionComponents.joined(separator: versionDelimiter)
                .compare(targetComponents.joined(separator: versionDelimiter), options: .numeric)
        }
        return result
    }
    
    public func isMetaWearVersion(equalTo targetVersion: String) -> Bool {
        compare(toVersion: targetVersion) == .orderedSame
    }

    public func isMetaWearVersion(greaterThan targetVersion: String) -> Bool {
        compare(toVersion: targetVersion) == .orderedDescending
    }

    public func isMetaWearVersion(greaterThanOrEqualTo targetVersion: String) -> Bool {
        compare(toVersion: targetVersion) != .orderedAscending
    }

    public func isMetaWearVersion(lessThan targetVersion: String) -> Bool {
        compare(toVersion: targetVersion) == .orderedAscending
    }

    public func isMetaWearVersion(lessThanOrEqualTo targetVersion: String) -> Bool {
        compare(toVersion: targetVersion) != .orderedDescending
    }
}
