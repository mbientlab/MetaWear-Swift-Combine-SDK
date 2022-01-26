import Foundation
import MetaWearCpp

extension MWDataProcessor {

    /// Whether to simply emit the throttled value or emit the difference between the current and prior value.
    ///
    /// If you encounter an error while computing the delta between two values, it's possible the data type is not supported by the data processor unit.
    ///
    public enum ThrottleMutation: UInt32, CaseIterable, IdentifiableByRawValue {
        case passthrough = 0, computeDelta

        public var cppValue: MblMwTimeMode {
            switch self {
                case .passthrough: return MBL_MW_TIME_ABSOLUTE
                case .computeDelta: return MBL_MW_TIME_DIFFERENTIAL
            }
        }

    }

    /// Compares input signal against a given threshold value. If successful, a signal is emitted that a subsequent event can listen for.
    ///
    public enum ComparatorOption: Int, CaseIterable, IdentifiableByRawValue {
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

    public enum DeltaMode: Int, CaseIterable, IdentifiableByRawValue {
        /// Return the data as is
        case absolute = 0
        /// Return the difference between the input and the reference value
        case differential
        /// Return 1 if input > reference, -1 if input < reference
        case binary
        public var cppValue: MblMwDeltaMode {
            switch self {
                case .absolute: return MBL_MW_DELTA_MODE_ABSOLUTE
                case .differential: return MBL_MW_DELTA_MODE_DIFFERENTIAL
                case .binary: return MBL_MW_DELTA_MODE_BINARY
            }
        }
    }

    public enum ComparatorMode: Int, CaseIterable, IdentifiableByRawValue {
        /// Return the data as is
        case absolute = 0
        /// Return the reference value for the satisfied comparison
        case reference
        /// Return the position of the reference value satisfying the comparison, n + 1 for not satisfied
        case zone
        /// Return 1 if any reference values satisfy the comparison, 0 if none do
        case binary

        public var cppValue: MblMwComparatorMode {
            switch self {
                case .absolute: return MBL_MW_COMPARATOR_MODE_ABSOLUTE
                case .reference: return MBL_MW_COMPARATOR_MODE_REFERENCE
                case .zone: return MBL_MW_COMPARATOR_MODE_ZONE
                case .binary: return MBL_MW_COMPARATOR_MODE_BINARY
            }
        }
    }

    public enum MathOperation: Int, CaseIterable, IdentifiableByRawValue {
        /// Computes input + rhs
        case add = 1
        /// Computes input * rhs
        case multiply
        /// Computes input / rhs
        case divide
        /// Computes input % rhs
        case modulus
        /// Computes input ^ rhs
        case exponent
        /// Computes sqrt(input)
        case squareRoot
        /// Computes input << rhs
        case leftShift
        /// Computes input >> rhs
        case rightShift
        /// Computes input - rhs
        case subtract
        /// Computes |input|
        case absoluteValue
        /// Replaces input with rhs
        case constant

        public var cppValue: MblMwMathOperation {
            switch self {
                case .add: return MBL_MW_MATH_OP_ADD
                case .multiply: return MBL_MW_MATH_OP_MULTIPLY
                case .divide: return MBL_MW_MATH_OP_DIVIDE
                case .modulus: return MBL_MW_MATH_OP_MODULUS
                case .exponent: return MBL_MW_MATH_OP_EXPONENT
                case .squareRoot: return MBL_MW_MATH_OP_SQRT
                case .leftShift: return MBL_MW_MATH_OP_LSHIFT
                case .rightShift: return MBL_MW_MATH_OP_RSHIFT
                case .subtract: return MBL_MW_MATH_OP_SUBTRACT
                case .absoluteValue: return MBL_MW_MATH_OP_ABS_VALUE
                case .constant: return MBL_MW_MATH_OP_CONSTANT
            }
        }
    }

    public enum PassthroughMode: Int, CaseIterable, IdentifiableByRawValue {
        /// Allow all data through
        case all = 0
        /// Only allow data through if count > 0
        case conditional
        /// Only allow a fixed number of data samples through
        case count
        public var cppValue: MblMwPassthroughMode {
            switch self {
                case .all: return MBL_MW_PASSTHROUGH_MODE_ALL
                case .conditional: return MBL_MW_PASSTHROUGH_MODE_CONDITIONAL
                case .count: return MBL_MW_PASSTHROUGH_MODE_COUNT
            }
        }
    }

    public enum PulseOutput: Int, CaseIterable, IdentifiableByRawValue {
        /// Return number of samples in the pulse
        case width = 0
        /// Return a sum of all data points in the pulse
        case area
        /// Return the highest value in the pulse
        case peak
        /// Return a 0x01 as soon as a pulse is detected
        case onDetection
        public var cppValue: MblMwPulseOutput {
            switch self {
                case .width: return MBL_MW_PULSE_OUTPUT_WIDTH
                case .area: return MBL_MW_PULSE_OUTPUT_AREA
                case .peak: return MBL_MW_PULSE_OUTPUT_PEAK
                case .onDetection: return MBL_MW_PULSE_OUTPUT_ON_DETECTION
            }
        }
    }

    public enum ThresholdMode: Int, CaseIterable, IdentifiableByRawValue {
        /// Return the data as is
        case absolute = 0
        /// Return 1 if data > bounday, -1 if data < boundary
        case binary
        public var cppValue: MblMwThresholdMode {
            switch self {
                case .absolute: return MBL_MW_THRESHOLD_MODE_ABSOLUTE
                case .binary: return MBL_MW_THRESHOLD_MODE_BINARY
            }
        }
    }
}
