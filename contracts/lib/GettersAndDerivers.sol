// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    OrderParameters
} from "../seaport-types/src/lib/ConsiderationStructs.sol";

import { ConsiderationBase } from "./ConsiderationBase.sol";

import {
    Create2AddressDerivation_length,
    Create2AddressDerivation_ptr,
    EIP_712_PREFIX,
    EIP712_ConsiderationItem_size,
    EIP712_DigestPayload_size,
    EIP712_DomainSeparator_offset,
    EIP712_OfferItem_size,
    EIP712_Order_size,
    EIP712_OrderHash_offset,
    FreeMemoryPointerSlot,
    information_conduitController_offset,
    information_domainSeparator_offset,
    information_length,
    information_version_cd_offset,
    information_version_offset,
    information_versionLengthPtr,
    information_versionWithLength,
    MaskOverByteTwelve,
    MaskOverLastTwentyBytes,
    OneWord,
    OneWordShift,
    OrderParameters_consideration_head_offset,
    OrderParameters_counter_offset,
    OrderParameters_offer_head_offset,
    TwoWords
} from "../seaport-types/src/lib/ConsiderationConstants.sol";

/**
 * @title GettersAndDerivers
 * @author 0age
 * @notice ConsiderationInternal contains pure and internal view functions
 *         related to getting or deriving various values.
 */
contract GettersAndDerivers is ConsiderationBase {
    /**
     * @dev Derive and set hashes, reference chainId, and associated domain
     *      separator during deployment.
     *
     * @param conduitController A contract that deploys conduits, or proxies
     *                          that may optionally be used to transfer approved
     *                          ERC20/721/1155 tokens.
     */
    constructor(
        address conduitController
    ) ConsiderationBase(conduitController) {}

    /**
     * @dev Internal view function to derive the order hash for a given order.
     *      Note that only the original consideration items are included in the
     *      order hash, as additional consideration items may be supplied by the
     *      caller.
     *
     * @param orderParameters The parameters of the order to hash.
     * @param counter         The counter of the order to hash.
     *
     * @return orderHash The hash.
     */
    function _deriveOrderHash(
        OrderParameters memory orderParameters,
        uint256 counter
    ) internal view returns (bytes32 orderHash) {
        // Get length of original consideration array and place it on the stack.
        uint256 originalConsiderationLength = (
            orderParameters.totalOriginalConsiderationItems
        );

        /*
         * Memory layout for an array of structs (dynamic or not) is similar
         * to ABI encoding of dynamic types, with a head segment followed by
         * a data segment. The main difference is that the head of an element
         * is a memory pointer rather than an offset.
         */

        // Declare a variable for the derived hash of the offer array.
        bytes32 offerHash;

        // Read offer item EIP-712 typehash from runtime code & place on stack.
        // OfferItem 结构体的 EIP-712 类型哈希值
        bytes32 typeHash = _OFFER_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(FreeMemoryPointerSlot)

            // Get the pointer to the offers array.
            // 指针偏移0x40获取offers数组的指针
            let offerArrPtr := mload(
                add(orderParameters, OrderParameters_offer_head_offset)
            )

            // Load the length.
            // 读取offers数组的长度
            let offerLength := mload(offerArrPtr)

            // Set the pointer to the first offer's head.
            // 偏移一个字，获取offers数组的第一个元素的指针
            offerArrPtr := add(offerArrPtr, OneWord)

            // Iterate over the offer items.
            for {
                let i := 0
            } lt(i, offerLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the offer data and subtract one word
                // to get typeHash pointer.
                // mload(offerArrPtr)读取offers数组的元素的指针，不是数据
                // sub(mload(offerArrPtr), OneWord)获取offer数据的指针的前一个字节
                let ptr := sub(mload(offerArrPtr), OneWord)

                // Read the current value before the offer data.
                // 保存offer数据的前一个字节的值
                let value := mload(ptr)

                // Write the type hash to the previous word.
                // 将offer数据的前一个字节的值设置为typeHash
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                // 计算offer数据的哈希值，并存储到hashArrPtr
                // 即将_OFFER_ITEM_TYPEHASH OrderParameters中offer~endtime的数据进行哈希
                mstore(hashArrPtr, keccak256(ptr, EIP712_OfferItem_size))

                // Restore the previous word.
                // 恢复offer数据的前一个字节的值
                mstore(ptr, value)

                // Increment the array pointers by one word.
                // offerArrPtr指针偏移一个字，指向下一个offerItem 指针
                offerArrPtr := add(offerArrPtr, OneWord)
                // hashArrPtr指针偏移一个字，相当于hashArrPtr新增一个元素
                hashArrPtr := add(hashArrPtr, OneWord)
            }

            // Derive the offer hash using the hashes of each item.
            // 计算hashArrPtr数组的hash
            offerHash := keccak256(
                mload(FreeMemoryPointerSlot),
                shl(OneWordShift, offerLength)
            )
        }

        // Declare a variable for the derived hash of the consideration array.
        bytes32 considerationHash;

        // Read consideration item typehash from runtime code & place on stack.
        typeHash = _CONSIDERATION_ITEM_TYPEHASH;

        // Utilize assembly so that memory regions can be reused across hashes.
        assembly {
            // Retrieve the free memory pointer and place on the stack.
            let hashArrPtr := mload(FreeMemoryPointerSlot)

            // Get the pointer to the consideration array.
            let considerationArrPtr := add(
                mload(
                    add(
                        orderParameters,
                        OrderParameters_consideration_head_offset
                    )
                ),
                OneWord
            )

            // Iterate over the consideration items (not including tips).
            for {
                let i := 0
            } lt(i, originalConsiderationLength) {
                i := add(i, 1)
            } {
                // Read the pointer to the consideration data and subtract one
                // word to get typeHash pointer.
                let ptr := sub(mload(considerationArrPtr), OneWord)

                // Read the current value before the consideration data.
                let value := mload(ptr)

                // Write the type hash to the previous word.
                mstore(ptr, typeHash)

                // Take the EIP712 hash and store it in the hash array.
                mstore(
                    hashArrPtr,
                    keccak256(ptr, EIP712_ConsiderationItem_size)
                )

                // Restore the previous word.
                mstore(ptr, value)

                // Increment the array pointers by one word.
                considerationArrPtr := add(considerationArrPtr, OneWord)
                hashArrPtr := add(hashArrPtr, OneWord)
            }

            // Derive the consideration hash using the hashes of each item.
            considerationHash := keccak256(
                mload(FreeMemoryPointerSlot),
                shl(OneWordShift, originalConsiderationLength)
            )
        }

        // Read order item EIP-712 typehash from runtime code & place on stack.
        typeHash = _ORDER_TYPEHASH;

        // Utilize assembly to access derived hashes & other arguments directly.
        assembly {
            // Retrieve pointer to the region located just behind parameters.
            let typeHashPtr := sub(orderParameters, OneWord)

            // Store the value at that pointer location to restore later.
            let previousValue := mload(typeHashPtr)

            // Store the order item EIP-712 typehash at the typehash location.
            mstore(typeHashPtr, typeHash)

            // Retrieve the pointer for the offer array head.
            let offerHeadPtr := add(
                orderParameters,
                OrderParameters_offer_head_offset
            )

            // Retrieve the data pointer referenced by the offer head.
            let offerDataPtr := mload(offerHeadPtr)

            // Store the offer hash at the retrieved memory location.
            // 将之前计算好的 offerHash 写入 offerHeadPtr 位置，覆盖原始的 offer 数组数据指针
            mstore(offerHeadPtr, offerHash)

            // Retrieve the pointer for the consideration array head.
            let considerationHeadPtr := add(
                orderParameters,
                OrderParameters_consideration_head_offset
            )

            // Retrieve the data pointer referenced by the consideration head.
            let considerationDataPtr := mload(considerationHeadPtr)

            // Store the consideration hash at the retrieved memory location.
            // 将之前计算好的 considerationHash 写入 considerationHeadPtr 位置，覆盖原始的 consideration 数组数据指针。
            mstore(considerationHeadPtr, considerationHash)

            // Retrieve the pointer for the counter.
            // uint256 totalOriginalConsiderationItems; // 0x140
            let counterPtr := add(
                orderParameters,
                OrderParameters_counter_offset  // 0x140
            )

            // Store the counter at the retrieved memory location.
            // 将 counter 写入 counterPtr 位置，覆盖原始的 counter
            mstore(counterPtr, counter)

            // Derive the order hash using the full range of order parameters.
            orderHash := keccak256(typeHashPtr, EIP712_Order_size)

            // Restore the value previously held at typehash pointer location.
            // 恢复 typeHashPtr 位置的原始值
            mstore(typeHashPtr, previousValue)

            // Restore offer data pointer at the offer head pointer location.
            // 恢复 offerHeadPtr 位置的原始值,还原 offer 数组数据指针
            mstore(offerHeadPtr, offerDataPtr)

            // Restore consideration data pointer at the consideration head ptr.
            // 恢复 considerationHeadPtr 位置的原始值，还原 consideration 数组数据指针
            mstore(considerationHeadPtr, considerationDataPtr)

            // Restore consideration item length at the counter pointer.
            // 恢复 counterPtr 位置的原始值，还原 counter
            mstore(counterPtr, originalConsiderationLength)
        }
    }

    /**
     * @dev Internal view function to derive the address of a given conduit
     *      using a corresponding conduit key.
     *
     * @param conduitKey A bytes32 value indicating what corresponding conduit,
     *                   if any, to source token approvals from. This value is
     *                   the "salt" parameter supplied by the deployer (i.e. the
     *                   conduit controller) when deploying the given conduit.
     *
     * @return conduit The address of the conduit associated with the given
     *                 conduit key.
     */
    function _deriveConduit(
        bytes32 conduitKey
    ) internal view returns (address conduit) {
        // Read conduit controller address from runtime and place on the stack.
        address conduitController = address(_CONDUIT_CONTROLLER);

        // Read conduit creation code hash from runtime and place on the stack.
        bytes32 conduitCreationCodeHash = _CONDUIT_CREATION_CODE_HASH;

        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Retrieve the free memory pointer; it will be replaced afterwards.
            let freeMemoryPointer := mload(FreeMemoryPointerSlot)

            // Place the control character and the conduit controller in scratch
            // space; note that eleven bytes at the beginning are left unused.
            mstore(0, or(MaskOverByteTwelve, conduitController))

            // Place the conduit key in the next region of scratch space.
            mstore(OneWord, conduitKey)

            // Place conduit creation code hash in free memory pointer location.
            mstore(TwoWords, conduitCreationCodeHash)

            // Derive conduit by hashing and applying a mask over last 20 bytes.
            conduit := and(
                // Hash the relevant region.
                keccak256(
                    // The region starts at memory pointer 11.
                    Create2AddressDerivation_ptr,
                    // The region is 85 bytes long (1 + 20 + 32 + 32).
                    Create2AddressDerivation_length
                ),
                // The address equals the last twenty bytes of the hash.
                MaskOverLastTwentyBytes
            )

            // Restore the free memory pointer.
            mstore(FreeMemoryPointerSlot, freeMemoryPointer)
        }
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     *
     * @return The domain separator.
     */
    function _domainSeparator() internal view returns (bytes32) {
        return
            block.chainid == _CHAIN_ID
                ? _DOMAIN_SEPARATOR
                : _deriveDomainSeparator();
    }

    /**
     * @dev Internal view function to retrieve configuration information for
     *      this contract.
     *
     * @return The contract version.
     * @return The domain separator for this contract.
     * @return The conduit Controller set for this contract.
     */
    function _information()
        internal
        view
        returns (
            string memory /* version */,
            bytes32 /* domainSeparator */,
            address /* conduitController */
        )
    {
        // Derive the domain separator.
        bytes32 domainSeparator = _domainSeparator();

        // Declare variable as immutables cannot be accessed within assembly.
        address conduitController = address(_CONDUIT_CONTROLLER);

        // Return the version, domain separator, and conduit controller.
        assembly {
            mstore(information_version_offset, information_version_cd_offset)
            mstore(information_domainSeparator_offset, domainSeparator)
            mstore(information_conduitController_offset, conduitController)
            mstore(information_versionLengthPtr, information_versionWithLength)
            return(information_version_offset, information_length)
        }
    }

    /**
     * @dev Internal pure function to efficiently derive an digest to sign for
     *      an order in accordance with EIP-712.
     *
     * @param domainSeparator The domain separator.
     * @param orderHash       The order hash.
     *
     * @return value The hash.
     */
    function _deriveEIP712Digest(
        bytes32 domainSeparator,
        bytes32 orderHash
    ) internal pure returns (bytes32 value) {
        // Leverage scratch space to perform an efficient hash.
        assembly {
            // Place the EIP-712 prefix at the start of scratch space.
            mstore(0, EIP_712_PREFIX)

            // Place the domain separator in the next region of scratch space.
            mstore(EIP712_DomainSeparator_offset, domainSeparator)

            // Place the order hash in scratch space, spilling into the first
            // two bytes of the free memory pointer — this should never be set
            // as memory cannot be expanded to that size, and will be zeroed out
            // after the hash is performed.
            mstore(EIP712_OrderHash_offset, orderHash)

            // Hash the relevant region (65 bytes).
            value := keccak256(0, EIP712_DigestPayload_size)

            // Clear out the dirtied bits in the memory pointer.
            mstore(EIP712_OrderHash_offset, 0)
        }
    }
}
