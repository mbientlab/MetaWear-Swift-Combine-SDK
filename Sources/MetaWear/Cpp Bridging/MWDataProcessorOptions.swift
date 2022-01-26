import Foundation
import MetaWearCpp

/// Whether to simply emit the throttled value or emit the difference between the current and prior value.
///
/// If you encounter an error while computing the delta between two values, it's possible the data type is not supported by the data processor unit.
///
public enum MWThrottleMutationMode: UInt32, CaseIterable, IdentifiableByRawValue {
    case passthrough = 0, computeDelta

    public var cppValue: MblMwTimeMode {
        switch self {
            case .passthrough: return MBL_MW_TIME_ABSOLUTE
            case .computeDelta: return MBL_MW_TIME_DIFFERENTIAL
        }
    }

}

/// Data processor Comparator options against a given threshold value. If successful, a signal is emitted that a subsequent event can listen for.
///
public enum MWComparatorOption: Int, CaseIterable, IdentifiableByRawValue {
    case equals = 0
    case notEqualTo
    case lessThan
    case lessThanOrEqualTo
    case greaterThan
    case greaterThanOrEqualTo

    public var cppValue: MblMwComparatorOperation {
        switch self {
            case .equals: return MBL_MW_COMPARATOR_OP_EQ
            case .notEqualTo: return MBL_MW_COMPARATOR_OP_NEQ
            case .lessThan: return MBL_MW_COMPARATOR_OP_LT
            case .lessThanOrEqualTo: return MBL_MW_COMPARATOR_OP_LTE
            case .greaterThan: return MBL_MW_COMPARATOR_OP_GT
            case .greaterThanOrEqualTo: return MBL_MW_COMPARATOR_OP_GTE
        }
    }
}
