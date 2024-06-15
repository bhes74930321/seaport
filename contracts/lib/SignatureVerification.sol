// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    SignatureVerificationErrors
} from "../seaport-types/src/interfaces/SignatureVerificationErrors.sol";

import { LowLevelHelpers } from "./LowLevelHelpers.sol";

import {
    ECDSA_MaxLength,
    ECDSA_signature_s_offset,
    ECDSA_signature_v_offset,
    ECDSA_twentySeventhAndTwentyEighthBytesSet,
    Ecrecover_args_size,
    Ecrecover_precompile,
    EIP1271_isValidSignature_calldata_baseLength,
    EIP1271_isValidSignature_digest_negativeOffset,
    EIP1271_isValidSignature_selector_negativeOffset,
    EIP1271_isValidSignature_selector,
    EIP1271_isValidSignature_signature_head_offset,
    EIP2098_allButHighestBitMask,
    MaxUint8,
    OneWord,
    Signature_lower_v
} from "../seaport-types/src/lib/ConsiderationConstants.sol";

import {
    BadContractSignature_error_length,
    BadContractSignature_error_selector,
    BadSignatureV_error_length,
    BadSignatureV_error_selector,
    BadSignatureV_error_v_ptr,
    Error_selector_offset,
    InvalidSignature_error_length,
    InvalidSignature_error_selector,
    InvalidSigner_error_length,
    InvalidSigner_error_selector
} from "../seaport-types/src/lib/ConsiderationErrorConstants.sol";

/**
 * @title SignatureVerification
 * @author 0age
 * @notice SignatureVerification contains logic for verifying signatures.
 */
contract SignatureVerification is SignatureVerificationErrors, LowLevelHelpers {
    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 64 or 65 bytes or if the recovered signer does not match the
     *      supplied signer.
     *
     * @param signer                  The signer for the order.
     * @param digest                  The digest to verify signature against.
     * @param originalDigest          The original digest to verify signature
     *                                against.
     * @param originalSignatureLength The original signature length.
     * @param signature               A signature from the signer indicating
     *                                that the order has been approved.
     */
    function _assertValidSignature(
        address signer,
        bytes32 digest,
        bytes32 originalDigest,
        uint256 originalSignatureLength,
        bytes memory signature
    ) internal view {
        // Declare value for ecrecover equality or 1271 call success status.
        bool success;

        // Utilize assembly to perform optimized signature verification check.
        assembly {
            // Ensure that first word of scratch space is empty.
            mstore(0, 0)

            // Get the length of the signature.
            let signatureLength := mload(signature)

            // Get the pointer to the value preceding the signature length.
            // This will be used for temporary memory overrides - either the
            // signature head for isValidSignature or the digest for ecrecover.
            // 获取指向签名长度之前的值的指针。
            let wordBeforeSignaturePtr := sub(signature, OneWord)

            // Cache the current value behind the signature to restore it later.
            // 缓存签名后面的当前值，以便稍后恢复它。
            let cachedWordBeforeSignature := mload(wordBeforeSignaturePtr)

            // Declare lenDiff + recoveredSigner scope to manage stack pressure.
            {
                // Take the difference between the max ECDSA signature length
                // and the actual signature length. Overflow desired for any
                // values > 65. If the diff is not 0 or 1, it is not a valid
                // ECDSA signature - move on to EIP1271 check.
                // 计算ECDSA 签名长度与实际签名长度差值
                let lenDiff := sub(ECDSA_MaxLength, signatureLength)

                // Declare variable for recovered signer.
                let recoveredSigner

                // If diff is 0 or 1, it may be an ECDSA signature.
                // Try to recover signer.
                // 如果差异为 0 或 1，则它可能是 ECDSA 签名。
                if iszero(gt(lenDiff, 1)) {
                    // Read the signature `s` value.
                    // 读取签名 `s` 值。
                    let originalSignatureS := mload(
                        add(signature, ECDSA_signature_s_offset)
                    )

                    // Read the first byte of the word after `s`. If the
                    // signature is 65 bytes, this will be the real `v` value.
                    // If not, it will need to be modified - doing it this way
                    // saves an extra condition.
                    // 读取v值
                    let v := byte(
                        0,
                        mload(add(signature, ECDSA_signature_v_offset))
                    )

                    // If lenDiff is 1, parse 64-byte signature as ECDSA.
                    // 如果 lenDiff 为 1，则将 64 字节签名解析为 ECDSA。
                    if lenDiff {
                        // Extract yParity from highest bit of vs and add 27 to
                        // get v.
                        // 从 vs 的最高位提取 yParity 并添加 27 以获得 v。
                        v := add(
                            shr(MaxUint8, originalSignatureS),
                            Signature_lower_v
                        )

                        // Extract canonical s from vs, all but the highest bit.
                        // Temporarily overwrite the original `s` value in the
                        // signature.
                        // 从 vs 中提取规范的 s，除了最高位之外的所有位。
                        // 临时覆盖签名中的原始 `s` 值。
                        mstore(
                            add(signature, ECDSA_signature_s_offset),
                            and(
                                originalSignatureS,
                                EIP2098_allButHighestBitMask
                            )
                        )
                    }
                    // Temporarily overwrite the signature length with `v` to
                    // conform to the expected input for ecrecover.
                    // 用 `v` 临时覆盖签名长度，以符合 ecrecover 的预期输入。
                    mstore(signature, v)

                    // Temporarily overwrite the word before the length with
                    // `digest` to conform to the expected input for ecrecover.
                    // 用 `digest` 临时覆盖长度之前的字，以符合 ecrecover 的预期输入。
                    mstore(wordBeforeSignaturePtr, digest)

                    // Attempt to recover the signer for the given signature. Do
                    // not check the call status as ecrecover will return a null
                    // address if the signature is invalid.
                    // 尝试恢复给定签名的签名者。
                    // 不要检查调用状态，因为如果签名无效，ecrecover 将返回一个空地址。
                    pop(
                        staticcall(
                            gas(),
                            Ecrecover_precompile, // Call ecrecover precompile. 调用 ecrecover 预编译合约。
                            wordBeforeSignaturePtr, // Use data memory location. 使用数据内存位置。
                            Ecrecover_args_size, // Size of digest, v, r, and s. 摘要、v、r 和 s 的大小。
                            0, // Write result to scratch space. 将结果写入暂存空间。
                            OneWord // Provide size of returned result. 提供返回结果的大小。
                        )
                    )

                    // Restore cached word before signature.
                    // 恢复缓存的签名之前的字。
                    mstore(wordBeforeSignaturePtr, cachedWordBeforeSignature)

                    // Restore cached signature length.
                    // 恢复缓存的签名长度。
                    mstore(signature, signatureLength)

                    // Restore cached signature `s` value.
                    // 恢复缓存的签名 `s` 值。
                    mstore(
                        add(signature, ECDSA_signature_s_offset),
                        originalSignatureS
                    )

                    // Read the recovered signer from the buffer given as return
                    // space for ecrecover.
                    // 从作为 ecrecover 返回空间提供的缓冲区中读取恢复的签名者。
                    recoveredSigner := mload(0)
                }

                // Set success to true if the signature provided was a valid
                // ECDSA signature and the signer is not the null address. Use
                // gt instead of direct as success is used outside of assembly.
                // 如果使用 ecrecover 验证了签名，并且签名者不是空地址，则将 success 设置为 true。
                // 使用 gt 而不是直接比较，因为 success 在程序集之外使用。
                success := and(eq(signer, recoveredSigner), gt(signer, 0))
            }

            // If the signature was not verified with ecrecover, try EIP1271.
            // 如果未通过 ecrecover 验证签名，请尝试 EIP1271。
            if iszero(success) {
                // Reset the original signature length.
                // 重置原始签名长度。
                mstore(signature, originalSignatureLength)

                // Temporarily overwrite the word before the signature length
                // and use it as the head of the signature input to
                // `isValidSignature`, which has a value of 64.
                // 临时覆盖签名长度之前的字，并将其用作 `isValidSignature` 的签名输入头，其值为 64。
                mstore(
                    wordBeforeSignaturePtr,
                    EIP1271_isValidSignature_signature_head_offset
                )

                // Get pointer to use for the selector of `isValidSignature`.
                // 获取用于 `isValidSignature` 选择器的指针。
                let selectorPtr := sub(
                    signature,
                    EIP1271_isValidSignature_selector_negativeOffset
                )

                // Cache the value currently stored at the selector pointer.
                // 缓存当前存储在`isValidSignature`选择器指针处的值。
                let cachedWordOverwrittenBySelector := mload(selectorPtr)

                // Cache the value currently stored at the digest pointer.
                // 缓存当前存储在摘要指针处的值。
                let cachedWordOverwrittenByDigest := mload(
                    sub(
                        signature,
                        EIP1271_isValidSignature_digest_negativeOffset
                    )
                )

                // Write the selector first, since it overlaps the digest.
                // 首先写入选择器，因为它与摘要重叠。
                mstore(selectorPtr, EIP1271_isValidSignature_selector)

                // Next, write the original digest.
                // 接下来，写入原始摘要。
                mstore(
                    sub(
                        signature,
                        EIP1271_isValidSignature_digest_negativeOffset
                    ),
                    originalDigest
                )

                // Call signer with `isValidSignature` to validate signature.
                // 使用 `isValidSignature` 调用签名者以验证签名。
                success := staticcall(
                    gas(),
                    signer,
                    selectorPtr,
                    add(
                        originalSignatureLength,
                        EIP1271_isValidSignature_calldata_baseLength
                    ),
                    0,
                    OneWord
                )

                // Determine if the signature is valid on successful calls.
                // 确定在成功调用时签名是否有效。
                if success {
                    // If first word of scratch space does not contain EIP-1271
                    // signature selector, revert.
                    // 如果暂存空间的第一个字不包含 EIP-1271 签名选择器，则回退。
                    if iszero(eq(mload(0), EIP1271_isValidSignature_selector)) {
                        // Revert with bad 1271 signature if signer has code.
                        // 如果签名者有代码，则使用错误的 1271 签名回退。
                        if extcodesize(signer) {
                            // Bad contract signature.
                            // Store left-padded selector with push4, mem[28:32]
                            // 错误的合约签名。
                            // 使用 push4 存储左对齐的选择器，mem[28:32]
                            mstore(0, BadContractSignature_error_selector)

                            // revert(abi.encodeWithSignature(
                            //     "BadContractSignature()"
                            // ))
                            revert(
                                Error_selector_offset,
                                BadContractSignature_error_length
                            )
                        }

                        // Check if signature length was invalid.
                        // 检查签名长度是否无效。
                        if gt(sub(ECDSA_MaxLength, signatureLength), 1) {
                            // Revert with generic invalid signature error.
                            // Store left-padded selector with push4, mem[28:32]
                            // 使用通用的无效签名错误回退。
                            // 使用 push4 存储左对齐的选择器，mem[28:32]
                            mstore(0, InvalidSignature_error_selector)

                            // revert(abi.encodeWithSignature(
                            //     "InvalidSignature()"
                            // ))
                            revert(
                                Error_selector_offset,
                                InvalidSignature_error_length
                            )
                        }

                        // Check if v was invalid.
                        // 检查 v 是否无效。
                        if and(
                            eq(signatureLength, ECDSA_MaxLength),
                            iszero(
                                byte(
                                    byte(
                                        0,
                                        mload(
                                            add(
                                                signature,
                                                ECDSA_signature_v_offset
                                            )
                                        )
                                    ),
                                    ECDSA_twentySeventhAndTwentyEighthBytesSet
                                )
                            )
                        ) {
                            // Revert with invalid v value.
                            // Store left-padded selector with push4, mem[28:32]
                            // 使用无效的 v 值回退。
                            // 使用 push4 存储左对齐的选择器，mem[28:32]
                            mstore(0, BadSignatureV_error_selector)
                            mstore(
                                BadSignatureV_error_v_ptr,
                                byte(
                                    0,
                                    mload(
                                        add(signature, ECDSA_signature_v_offset)
                                    )
                                )
                            )

                            // revert(abi.encodeWithSignature(
                            //     "BadSignatureV(uint8)", v
                            // ))
                            revert(
                                Error_selector_offset,
                                BadSignatureV_error_length
                            )
                        }

                        // Revert with generic invalid signer error message.
                        // Store left-padded selector with push4, mem[28:32]
                        // 使用通用的无效签名者错误消息回退。
                        // 使用 push4 存储左对齐的选择器，mem[28:32]
                        mstore(0, InvalidSigner_error_selector)

                        // revert(abi.encodeWithSignature("InvalidSigner()"))
                        revert(
                            Error_selector_offset,
                            InvalidSigner_error_length
                        )
                    }
                }

                // Restore the cached values overwritten by selector, digest and
                // signature head.
                // 恢复被选择器、摘要和签名头覆盖的缓存值。
                mstore(wordBeforeSignaturePtr, cachedWordBeforeSignature)
                mstore(selectorPtr, cachedWordOverwrittenBySelector)
                mstore(
                    sub(
                        signature,
                        EIP1271_isValidSignature_digest_negativeOffset
                    ),
                    cachedWordOverwrittenByDigest
                )
            }
        }

        // If the call failed...
        // 如果调用失败...
        if (!success) {
            // 如果返回了原因，则回退并传递原因。
            // Revert and pass reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with error indicating bad contract signature.
            // 否则，回退并指示错误的合约签名。
            assembly {
                // Store left-padded selector with push4, mem[28:32] = selector
                // 使用 push4 存储左对齐的选择器，mem[28:32] = selector
                mstore(0, BadContractSignature_error_selector)
                // revert(abi.encodeWithSignature("BadContractSignature()"))
                revert(Error_selector_offset, BadContractSignature_error_length)
            }
        }
    }
}
