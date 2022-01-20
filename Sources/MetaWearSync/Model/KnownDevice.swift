// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

/// An optional MetaWear reference (e.g., never seen locally by CoreBluetooth)
/// and mandatory Metadata (is cloud persisted)
///
public typealias MWKnownDevice = (mw: MetaWear?, meta: MetaWearMetadata)
