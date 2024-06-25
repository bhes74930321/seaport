// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    CostPerWord,
    ExtraGasBuffer,
    FreeMemoryPointerSlot,
    MemoryExpansionCoefficientShift,
    OneWord,
    OneWordShift,
    ThirtyOneBytes
} from "../seaport-types/src/lib/ConsiderationConstants.sol";

import {
    MemoryPointer,
    MemoryPointerLib
} from "../seaport-types/src/helpers/PointerLibraries.sol";

import {
    AdvancedOrder,
    Execution
} from "../seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @title LowLevelHelpers
 * @author 0age
 * @notice LowLevelHelpers contains logic for performing various low-level
 *         operations.
 */
contract LowLevelHelpers {
    /**
     * @dev Internal view function to revert and pass along the revert reason if
     *      data was returned by the last call and that the size of that data
     *      does not exceed the currently allocated memory size.
     */
     //如果上一次调用返回了数据，并且该数据的大小不超过当前分配的内存大小，则回退并传递回退原因。这是一种通用的错误处理机制，用于将底层调用的错误信息传递给上层调用者
    function _revertWithReasonIfOneIsReturned() internal view {
        assembly {
            // If it returned a message, bubble it up as long as sufficient gas
            // remains to do so:
            if returndatasize() {
                // Ensure that sufficient gas is available to copy returndata
                // while expanding memory where necessary. Start by computing
                // the word size of returndata and allocated memory.
                let returnDataWords := shr(
                    OneWordShift,
                    add(returndatasize(), ThirtyOneBytes)
                )

                // Note: use the free memory pointer in place of msize() to work
                // around a Yul warning that prevents accessing msize directly
                // when the IR pipeline is activated.
                let msizeWords := shr(
                    OneWordShift,
                    mload(FreeMemoryPointerSlot)
                )

                // Next, compute the cost of the returndatacopy.
                let cost := mul(CostPerWord, returnDataWords)

                // Then, compute cost of new memory allocation.
                if gt(returnDataWords, msizeWords) {
                    cost := add(
                        cost,
                        add(
                            mul(sub(returnDataWords, msizeWords), CostPerWord),
                            shr(
                                MemoryExpansionCoefficientShift,
                                sub(
                                    mul(returnDataWords, returnDataWords),
                                    mul(msizeWords, msizeWords)
                                )
                            )
                        )
                    )
                }

                // Finally, add a small constant and compare to gas remaining;
                // bubble up the revert data if enough gas is still available.
                if lt(add(cost, ExtraGasBuffer), gas()) {
                    // Copy returndata to memory; overwrite existing memory.
                    returndatacopy(0, 0, returndatasize())

                    // Revert, specifying memory region with copied returndata.
                    revert(0, returndatasize())
                }
            }
        }
    }

    /**
     * @dev Internal view function to branchlessly select either the caller (if
     *      a supplied recipient is equal to zero) or the supplied recipient (if
     *      that recipient is a nonzero value).
     *
     * @param recipient The supplied recipient.
     *
     * @return updatedRecipient The updated recipient.
     */
     //如果提供的接收者地址为零，则使用调用者地址代替；否则使用提供的接收者地址。这通常用于处理订单中没有明确指定接收者的对价项目
    function _substituteCallerForEmptyRecipient(
        address recipient
    ) internal view returns (address updatedRecipient) {
        // Utilize assembly to perform a branchless operation on the recipient.
        assembly {
            // Add caller to recipient if recipient equals 0; otherwise add 0.
            updatedRecipient := add(recipient, mul(iszero(recipient), caller()))
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
     //将布尔值 (bool) 转换为无符号整数 (uint256)
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    /**
     * @dev Internal pure function to cast the `pptrOffset` function from
     *      `MemoryPointerLib` to a function that takes a memory array of
     *      `AdvancedOrder` and an offset in memory and returns the
     *      `AdvancedOrder` whose pointer is stored at that offset from the
     *      array length.
     */
    //将 MemoryPointerLib.pptrOffset 函数转换为一个新的函数，该函数接受一个 AdvancedOrder 内存数组和一个内存
    function _getReadAdvancedOrderByOffset()
        internal
        pure
        returns (
            function(AdvancedOrder[] memory, uint256)
                internal
                pure
                returns (AdvancedOrder memory) fn2
        )
    {
        function(MemoryPointer, uint256)
            internal
            pure
            returns (MemoryPointer) fn1 = MemoryPointerLib.pptrOffset;

        assembly {
            fn2 := fn1
        }
    }

    /**
     * @dev Internal pure function to cast the `pptrOffset` function from
     *      `MemoryPointerLib` to a function that takes a memory array of
     *      `Execution` and an offset in memory and returns the
     *      `Execution` whose pointer is stored at that offset from the
     *      array length.
     */
    function _getReadExecutionByOffset()
        internal
        pure
        returns (
            function(Execution[] memory, uint256)
                internal
                pure
                returns (Execution memory) fn2
        )
    {
        function(MemoryPointer, uint256)
            internal
            pure
            returns (MemoryPointer) fn1 = MemoryPointerLib.pptrOffset;

        assembly {
            fn2 := fn1
        }
    }

    /**
     * @dev Internal pure function to return a `true` value that solc
     *      will not recognize as a compile time constant.
     *
     *      This function is used to bypass function specialization for
     *      functions which take a constant boolean as an input parameter.
     *
     *      This should only be used in cases where specialization has a
     *      negligible impact on the gas cost of the function.
     *
     *      Note: assumes the calldatasize is non-zero.
     */
     //返回一个 true 值，但 Solidity 编译器不会将其识别为编译时常量。这用于绕过 Solidity 函数特化机制，该机制会根据输入参数的常量值生成不同的函数版本，导致合约大小增加
    function _runTimeConstantTrue() internal pure returns (bool) {
        return msg.data.length > 0;
    }

    /**
     * @dev Internal pure function to return a `false` value that solc
     *      will not recognize as a compile time constant.
     *
     *      This function is used to bypass function specialization for
     *      functions which take a constant boolean as an input parameter.
     *
     *      This should only be used in cases where specialization has a
     *      negligible impact on the gas cost of the function.
     *
     *      Note: assumes the calldatasize is non-zero.
     */
    function _runTimeConstantFalse() internal pure returns (bool) {
        return msg.data.length == 0;
    }
}
