// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import SwiftUI

// MARK: - SwiftUI Item Provider

public extension NSItemProvider {

    /// Create an `NSItemProvider` for SwiftUI, AppKit, and UIKit
    /// based on the MetaWear metadata you provide
    /// (or an empty non-initiating container if you pass nil)
    ///
    /// - Parameters:
    ///   - metawear: Representation of a MetaWear (grouped, known, unknown)
    ///   - itemVisibility: Ability to drop MetaWear metadata into another MetaWear-aware app
    ///   - plainTextVisibility: Ability to drop plain text-formatted MetaWear metadata into other apps
    ///
    convenience init(metawear: DraggableMetaWear.Item?,
                     visibility: NSItemProviderRepresentationVisibility = .ownProcess,
                     plainTextVisibility: NSItemProviderRepresentationVisibility = .all) {
        self.init()
        guard let item = metawear else { return }
        let draggable = DraggableMetaWear(item: item)

        registerObject(draggable, visibility: visibility)
        registerObject(NSString(string: draggable.plainText), visibility: plainTextVisibility)

        registerDataRepresentation(forTypeIdentifier: "public.data", visibility: plainTextVisibility) { block in
            draggable.loadData(
                withTypeIdentifier: DraggableMetaWear.identifierString,
                forItemProviderCompletionHandler: block
            )
        }
    }
}
