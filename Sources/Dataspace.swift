// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of HDF5Kit. The full HDF5Kit copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import CHDF5

public class Dataspace {
    var id: Int32

    init(id: Int32) {
        self.id = id
        guard id >= 0 else {
            fatalError("Failed to create Dataspace")
        }
        selectionDims = []
        selectionDims = dims
    }

    deinit {
        let status = H5Sclose(id)
        assert(status >= 0, "Failed to close Dataspace")
    }

    public internal(set) var selectionDims: [Int]

    /// Create a Dataspace
    public init(dims: [Int]) {
        id = H5Screate_simple(Int32(dims.count), ptr(dims), nil)
        guard id >= 0 else {
            fatalError("Failed to create Dataspace")
        }
        selectionDims = dims
    }

    /// Create a Dataspace for use in a chunked Dataset. No component of `maxDims` should be less than the corresponding element of `dims`. Elements of `maxDims` can have a value of -1, those dimension will have an unlimited size.
    public init(dims: [Int], maxDims: [Int]) {
        id = H5Screate_simple(Int32(dims.count), ptr(dims), ptr(maxDims))
        guard id >= 0 else {
            fatalError("Failed to create Dataspace")
        }
        selectionDims = dims
    }

    public convenience init(_ space: Dataspace) {
        self.init(id: H5Scopy(space.id))
    }

    /// The total number of elements in the Dataspace
    public var size: Int {
        let result = H5Sget_simple_extent_npoints(id)
        guard result >= 0 else {
            fatalError("Failed to get Dataspace size")
        }
        return Int(result)
    }

    /// The size of each dimension in the Dataspace
    public var dims: [Int] {
        let rank = Int(H5Sget_simple_extent_ndims(id))
        var dims = [Int](count: rank, repeatedValue: 0)
        guard H5Sget_simple_extent_dims(id, ptr(&dims), nil) >= 0 else {
            fatalError("Coulnd't get the dimensons of the Dataspace")
        }
        return dims
    }

    /// The maximum size of each dimension in the Dataspace
    public var maxDims: [Int] {
        let rank = Int(H5Sget_simple_extent_ndims(id))
        var maxDims = [Int](count: rank, repeatedValue: 0)
        guard H5Sget_simple_extent_dims(id, nil, ptr(&maxDims)) >= 0 else {
            fatalError("Coulnd't get the dimensons of the Dataspace")
        }
        return maxDims
    }

    // MARK: - Selection

    public var hasValidSelection: Bool {
        return H5Sselect_valid(id) > 0
    }

    public var selectionSize: Int {
        return Int(H5Sget_select_npoints(id))
    }

    /// Selects the entire dataspace.
    public func selectAll() {
        H5Sselect_all(id)
        selectionDims = dims
    }

    /// Resets the selection region to include no elements.
    public func selectNone() {
        H5Sselect_none(id)
        for i in 0..<selectionDims.count {
            selectionDims[i] = 0
        }
    }

    /// Select a hyperslab region.
    ///
    /// - parameter start:  Specifies the offset of the starting element of the specified hyperslab.
    /// - parameter stride: Chooses array locations from the dataspace with each value in the stride array determining how many elements to move in each dimension. Stride values of 0 are not allowed. If the stride parameter is `nil`, a contiguous hyperslab is selected (as if each value in the stride array were set to 1).
    /// - parameter count:  Determines how many blocks to select from the dataspace, in each dimension.
    /// - parameter block:  Determines the size of the element block selected from the dataspace. If the block parameter is set to `nil`, the block size defaults to a single element in each dimension (as if each value in the block array were set to 1).
    public func select(start start: [Int], stride: [Int]?, count: [Int]?, block: [Int]?) {
        H5Sselect_hyperslab(id, H5S_SELECT_SET, ptr(start), ptr(stride), ptr(count), ptr(block))
        selectionDims = count ?? dims
    }

    /// Select a hyperslab region.
    public func select(slices: HyperslabIndexType...) {
        select(slices)
    }

    /// Select a hyperslab region.
    public func select(slices: [HyperslabIndexType]) {
        let dims = self.dims
        let rank = dims.count
        var start = [Int](count: rank, repeatedValue: 0)
        var stride = [Int](count: rank, repeatedValue: 1)
        var count = [Int](count: rank, repeatedValue: 0)
        var block = [Int](count: rank, repeatedValue: 1)

        for (index, slice) in slices.enumerate() {
            start[index] = slice.start
            stride[index] = slice.stride
            if slice.blockCount != HyperslabIndex.all {
                count[index] = slice.blockCount
            } else {
                count[index] = dims[index] - slice.start
            }
            block[index] = slice.blockSize
        }

        select(start: start, stride: stride, count: count, block: block)
    }

    /// This function allows the same shaped selection to be moved to different locations within a dataspace without requiring it to be redefined.
    public func offset(offset: [Int]) {
        H5Soffset_simple(id, ptr(offset))
    }
}
