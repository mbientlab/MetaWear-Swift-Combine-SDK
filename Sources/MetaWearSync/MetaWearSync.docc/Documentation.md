# ``MetaWearSync``

Identify MetaWears across users' devices

## Overview

The ``MetaWearSyncStore`` facilitates recognizing individual and grouped MetaWear devices uniquely across macOS and iOS devices using iCloud key value storage. 

This library also includes conveniences for drag-and-drop operations in AppKit, UIKit, and SwiftUI.

## Topics

### Essentials

- ``MetaWearSync/MetaWearSyncStore``
- ``MetaWearMetadata``
- ``MetaWearGroup``
- ``MWKnownDevice``

### Drag and Drop
- ``DraggableMetaWear``
- ``MWDropTargetVM``

### Persistence
Versioned containers ensure continuity of persisted data across SDK updates.

- ``MetaWeariCloudSyncLoader``
- ``MWCloudKeyValueDataLoader``
- ``MWLoader``
- ``MWKnownDevicesContainer``
- ``MWKnownDevicesLoadable``
- ``MWVersioningContainer``
- ``VersionedContainerLoadable``
