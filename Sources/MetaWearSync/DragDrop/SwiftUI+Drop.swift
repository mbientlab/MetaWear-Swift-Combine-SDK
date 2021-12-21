// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import SwiftUI
import MetaWear

/// For lists of MetaWear devices that support grouping,
/// this provides a default implementation of `DropDelegate`.
///
@available(iOS 14.0, macOS 11, *)
public protocol MWDropTargetVM: AnyObject, DropDelegate {

    /// Outcome of the proposed drop to reflect in your UI
    ///
    var dropOutcome: DraggableMetaWear.DropOutcome { get }

    /// Background queue used with a DispatchGroup during drop decoding
    ///
    var dropQueue: DispatchQueue { get }

    /// Called on the main queue in response to drop validation (likely with a populated array)
    /// and after a drop exit (always with an empty array).
    ///
    func updateDropOutcome(for drop: [DraggableMetaWear.Item])

    /// Called on the `dropQueue` for allowed, non-empty drops (i.e., `dropOutcome` != `noDrop`)
    ///
    func receiveDrop(_ drop: [DraggableMetaWear.Item], intent: DraggableMetaWear.DropOutcome)

}

public extension DraggableMetaWear {

    enum DropOutcome {
        case addToGroup
        case deleteFromGroup
        case newGroup
        case noDrop
    }

}

// MARK: - SwiftUI Drop Delegate Convenience Implementation

@available(iOS 14.0, macOS 11, *)
public extension MWDropTargetVM {

    /// Once at drop kickoff, asynchronously parses the drop's contents
    /// and calls `updateDropOutcome(for:)` to update state for this proposed drop
    ///
    func validateDrop(info: DropInfo) -> Bool {
        dropQueue.async { [weak self] in
            let draggables = info.loadMetaWears() ?? []
            DispatchQueue.main.async { [weak self] in
                self?.updateDropOutcome(for: draggables.map(\.item))
            }
        }
        return info.willLoadMetaWears()
    }

    /// Called repeatedly as the mouse moves, this checks the current `dropOutcome`
    /// and updates the mouse cursor's icon representing this drop operation
    ///
    func dropUpdated(info: DropInfo) -> DropProposal? {
        var op: DropOperation = .move
        switch dropOutcome {
            case .noDrop: op = .cancel
            case .deleteFromGroup: op = .move
            case .addToGroup: op = .copy
            case .newGroup: op = .copy
        }
        return .init(operation: op)
    }

    /// Called upon mouse exit or drop completion. Send an
    /// empty array to `updateDropOutcome(for:)` with the
    /// expectation that `dropOutcome` will be set to `noDrop`.
    ///
    func dropExited(info: DropInfo) {
        self.updateDropOutcome(for: [])
    }

    /// Called once when the user releases the mouse.
    /// Accepts or reject the proposed drop based on current `.dropOutcome` state.
    ///
    func performDrop(info: DropInfo) -> Bool {
        let cachedOutcome = dropOutcome
        let allowDrop = cachedOutcome != .noDrop
        if allowDrop {
            dropQueue.async { [weak self] in
                guard let metawears = info.loadMetaWears() else { return }
                self?.receiveDrop(metawears.map(\.item), intent: cachedOutcome)
            }
        }
        return allowDrop
    }

}

// MARK: - SwiftUI Drop Delegate Helpers
@available(iOS 14.0, macOS 11, *)
public extension DropInfo {

    func willLoadMetaWears() -> Bool {
#if os(macOS)
        let type = DraggableMetaWear.pasteboardType.rawValue
#else
        let type = DraggableMetaWear.identifierString
#endif
        return hasItemsConforming(to: [type])
    }

    /// Call on a background queue!
    ///
    func loadMetaWears() -> [DraggableMetaWear]? {
#if os(macOS)
        let type = DraggableMetaWear.pasteboardType.rawValue
#else
        let type = DraggableMetaWear.identifierString
#endif
        guard hasItemsConforming(to: [type]) else { return nil }
        let providers = itemProviders(for: [type])
        let group = DispatchGroup()
        var items: [DraggableMetaWear] = []
        providers.forEach {
            group.enter()
            $0.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                do {
                    guard let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: data ?? Data())
                    else { group.leave(); return }
                    items.append(item)
                } catch { print(error: error) }
                group.leave()
            }
        }
        group.wait()
        return items
    }
}

public extension Array where Element == DraggableMetaWear.Item {

    /// Extracts remembered devices, preserving order
    func rememberedDevices(excluding: Set<MACAddress> = []) -> [(metadata: MetaWear.Metadata, localID: CBPeripheralIdentifier?)] {
        reduce(into: [(metadata: MetaWear.Metadata, localID: CBPeripheralIdentifier?)](), { result, item in
            guard case .remembered(meta: let meta, localID: let id) = item,
                  excluding.contains(meta.mac) == false
            else { return }
            result.append((meta, id))
        })
    }

    /// Extracts groups, preserving order
    func groups() -> [MetaWear.Group] {
        reduce(into: [MetaWear.Group](), { result, item in
            guard case .group(let group) = item else { return }
            result.append(group)
        })
    }

    /// Extracts unknown devices, preserving order
    func unknownDevices() -> [CBPeripheralIdentifier] {
        reduce(into: [CBPeripheralIdentifier](), { result, item in
            guard case .unknown(let id) = item else { return }
            result.append(id)
        })
    }
}

// MARK: - SwiftUI Drop w/ Binding

extension Array where Element == NSItemProvider {

    /// Call on a background queue!
    ///
    public func loadMetaWears() -> [DraggableMetaWear]? {
        guard self.isEmpty == false else { return nil }

        let group = DispatchGroup()
        var draggables: [DraggableMetaWear] = []

        forEach {
            group.enter()
            $0.loadItem(forTypeIdentifier: DraggableMetaWear.identifierString, options: nil) { coding, error in
                do {
                    let data = coding as? Data ?? Data()
                    let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: data)
                    if let item = item { draggables.append(item) }
                    group.leave()
                } catch { group.leave(); print(error: error) }
            }
        }
        group.wait()
        return draggables.isEmpty ? nil : draggables
    }
}
