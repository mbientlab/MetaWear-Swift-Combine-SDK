// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

/// An optional MetaWear reference (e.g, never seen locally by CoreBluetooth)
/// and mandatory Metadata (is cloud persisted)
///
public typealias MWKnownDevice = (mw: MetaWear?, meta: MetaWearMetadata)

/// An guaranteed MetaWear reference (e.g., seen locally by CoreBluetooth this session)
/// and optional Metadata (likely nil, but possibly not if a user "forgot" this device during this app session)
///
public typealias MWNearbyUnknownDevice = (metawear: MetaWear, metadata: MetaWearMetadata?)
