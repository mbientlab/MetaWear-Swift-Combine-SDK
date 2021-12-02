// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

/// Convert to void* without ownership, only use when lifetime
/// of object is guaranteed elsewhere
public func bridge<T: AnyObject>(obj: T) -> UnsafeMutableRawPointer {
    return Unmanaged.passUnretained(obj).toOpaque()
}
/// Convert from void* without ownership, only use when lifetime
/// of object is guaranteed elsewhere
public func bridge<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

/// Convert to void* with ownership, make sure these are always
/// called in matching pairs with bridgeTransfer
public func bridgeRetained<T: AnyObject>(obj: T) -> UnsafeMutableRawPointer {
    return Unmanaged.passRetained(obj).toOpaque()
}
/// Convert from void* with ownership, make sure these are always
/// called in matching pairs with bridgeRetained
public func bridgeTransfer<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}
