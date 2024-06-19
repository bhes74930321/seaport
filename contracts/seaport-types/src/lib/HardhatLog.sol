pragma solidity ^0.8.24;

import "./ConsiderationStructs.sol";
import "hardhat/console.sol";

library HardhatLog {

// struct OfferItem {
//     ItemType itemType;
//     address token;
//     uint256 identifierOrCriteria;
//     uint256 startAmount;
//     uint256 endAmount;
// }

// struct ConsiderationItem {
//     ItemType itemType;
//     address token;
//     uint256 identifierOrCriteria;
//     uint256 startAmount;
//     uint256 endAmount;
//     address payable recipient;
// }

// struct AdvancedOrder {
//     OrderParameters parameters;
//     uint120 numerator;
//     uint120 denominator;
//     bytes signature;
//     bytes extraData;
// }

// struct OrderParameters {
//     address offerer; // 0x00
//     address zone; // 0x20
//     OfferItem[] offer; // 0x40
//     ConsiderationItem[] consideration; // 0x60
//     OrderType orderType; // 0x80
//     uint256 startTime; // 0xa0
//     uint256 endTime; // 0xc0
//     bytes32 zoneHash; // 0xe0
//     uint256 salt; // 0x100
//     bytes32 conduitKey; // 0x120
//     uint256 totalOriginalConsiderationItems; // 0x140
//     // offer.length                          // 0x160
// }

    function logAdvancedOrders(AdvancedOrder[] memory advancedOrders) internal view {
        console.log("=====advancedOrders.length: ", advancedOrders.length);
        for (uint i = 0; i < advancedOrders.length; i++) {
            logAdvancedOrder(advancedOrders[i]);
        }
    }

    function logAdvancedOrder(AdvancedOrder memory advancedOrder) internal view {
        console.log("-----------logAdvancedOrder---------------");
        logOrderParameters(advancedOrder.parameters);
        console.log("numerator: ", advancedOrder.numerator);
        console.log("denominator: ", advancedOrder.denominator);
        logBytes("signature: ", advancedOrder.signature);
        logBytes("extraData: ", advancedOrder.extraData);
        console.log("------------------------------");
    }

    function logOrderParameters(OrderParameters memory orderParameters) internal view {
        console.log("offerer: ", orderParameters.offerer);
        console.log("zone: ", orderParameters.zone);
        logOrderType("", orderParameters.orderType);
        console.log("startTime: ", orderParameters.startTime);
        console.log("endTime: ", orderParameters.endTime);
        logBytes32("zoneHash: ", orderParameters.zoneHash);
        console.log("salt: ", orderParameters.salt);
        logBytes32("conduitKey: ", orderParameters.conduitKey);
        console.log("totalOriginalConsiderationItems: ", orderParameters.totalOriginalConsiderationItems);
        console.log("offer.length: ", orderParameters.offer.length);
        for (uint i = 0; i < orderParameters.offer.length; i++) {
            OfferItem memory offerItem = orderParameters.offer[i];
            logOfferItem(offerItem);
        }
        console.log("consideration.length: ", orderParameters.consideration.length);
        for (uint i = 0; i < orderParameters.consideration.length; i++) {
            ConsiderationItem memory considerationItem = orderParameters.consideration[i];
            logConsiderationItem(considerationItem);
        }
    }

    function logBytes32(string memory prefix, bytes32 value) internal view {
        console.log(prefix);
        console.logBytes32(value);
    }
    function logBytes(string memory prefix, bytes memory value) internal view {
        console.log(prefix);
        console.logBytes(value);
    }

    function logOfferItem(OfferItem memory offerItem) internal view {
        console.log("+++++logOfferItem:");
        logItemType("itemType: ", offerItem.itemType);
        console.log("token: ", offerItem.token);
        console.log("identifierOrCriteria: ", offerItem.identifierOrCriteria);
        console.log("startAmount: ", offerItem.startAmount);
        console.log("endAmount: ", offerItem.endAmount);
    }

    function logConsiderationItem(ConsiderationItem memory considerationItem) internal view {
        console.log("+++++logConsiderationItem:");
        logItemType("itemType: ", considerationItem.itemType);
        console.log("token: ", considerationItem.token);
        console.log("identifierOrCriteria: ", considerationItem.identifierOrCriteria);
        console.log("startAmount: ", considerationItem.startAmount);
        console.log("endAmount: ", considerationItem.endAmount);
        console.log("recipient: ", considerationItem.recipient);
    }

    function logOrderType(string memory prefix, OrderType orderType) internal view {
        if (orderType == OrderType.FULL_OPEN) {
            console.log(prefix, " OrderType FULL_OPEN");
        } else if (orderType == OrderType.PARTIAL_OPEN) {
            console.log(prefix, " OrderType PARTIAL_OPEN");
        } else if (orderType == OrderType.FULL_RESTRICTED) {
            console.log(prefix, " OrderType FULL_RESTRICTED");
        } else if (orderType == OrderType.PARTIAL_RESTRICTED) {
            console.log(prefix, " OrderType PARTIAL_RESTRICTED");
        } else if (orderType == OrderType.CONTRACT) {
            console.log(prefix, " OrderType CONTRACT");
        }
    }

    function logItemType(string memory prefix, ItemType itemType) internal view {
        if (itemType == ItemType.NATIVE) {
            console.log(prefix, " ItemType NATIVE");
        } else if (itemType == ItemType.ERC20) {
            console.log(prefix, " ItemType ERC20");
        } else if (itemType == ItemType.ERC721) {
            console.log(prefix, " ItemType ERC721");
        } else if (itemType == ItemType.ERC1155) {
            console.log(prefix, " ItemType ERC1155");
        } else if (itemType == ItemType.ERC721_WITH_CRITERIA) {
            console.log(prefix, " ItemType ERC721_WITH_CRITERIA");
        } else if (itemType == ItemType.ERC1155_WITH_CRITERIA) {
            console.log(prefix, " ItemType ERC1155_WITH_CRITERIA");
        }
    }

    function logSide(string memory prefix, Side side) internal view {
        if (side == Side.OFFER) {
            console.log(prefix, " Side OFFER");
        } else if (side == Side.CONSIDERATION) {
            console.log(prefix, " Side CONSIDERATION");
        }
    }

    // struct CriteriaResolver {
    //     uint256 orderIndex;
    //     Side side;
    //     uint256 index;
    //     uint256 identifier;
    //     bytes32[] criteriaProof;
    // }
    function logCriteriaResolver(CriteriaResolver memory criteriaResolver) internal view {
        console.log("-----------logCriteriaResolver---------------");
        console.log("orderIndex: ", criteriaResolver.orderIndex);
        logSide("side: ", criteriaResolver.side);
        console.log("index: ", criteriaResolver.index);
        console.log("identifier: ", criteriaResolver.identifier);
        console.log("criteriaProof.length: ", criteriaResolver.criteriaProof.length);
        for (uint i = 0; i < criteriaResolver.criteriaProof.length; i++) {
            logBytes32("criteriaProof:", criteriaResolver.criteriaProof[i]);
        }
        console.log("----------------------------------");
    }
    function logCriteriaResolvers(CriteriaResolver[] memory criteriaResolvers) internal view {
        console.log("============= CriteriaResolvers =============");
        console.log("criteriaResolvers.length: ", criteriaResolvers.length);
        for (uint i = 0; i < criteriaResolvers.length; i++) {
            logCriteriaResolver(criteriaResolvers[i]);
        }
        console.log("============================================");
    }

    // struct FulfillmentComponent {
    //     uint256 orderIndex;
    //     uint256 itemIndex;
    // }
    // struct Fulfillment {
    //     FulfillmentComponent[] offerComponents;
    //     FulfillmentComponent[] considerationComponents;
    // }
    function logFulfillmentComponent(FulfillmentComponent memory fulfillmentComponent) internal view {
        console.log("orderIndex: ", fulfillmentComponent.orderIndex);
        console.log("itemIndex: ", fulfillmentComponent.itemIndex);
    }
    function logFulfillment(Fulfillment memory fulfillment) internal view {
        console.log("----------------- Fulfillment -----------------");
        console.log("offerComponents:");
        for (uint i = 0; i < fulfillment.offerComponents.length; i++) {
            logFulfillmentComponent(fulfillment.offerComponents[i]);
        }
        console.log("considerationComponents:");
        for (uint i = 0; i < fulfillment.considerationComponents.length; i++) {
            logFulfillmentComponent(fulfillment.considerationComponents[i]);
        }
        console.log("------------------------------------------");
    }
    function logFulfillments(Fulfillment[] memory fulfillments) internal view {
        console.log("================== Fulfillments ==================");
        console.log("fulfillments.length: ", fulfillments.length);
        for (uint i = 0; i < fulfillments.length; i++) {
            logFulfillment(fulfillments[i]);
        }
        console.log("=================================================");
    }

    // struct OrderStatus {
    //     bool isValidated;
    //     bool isCancelled;
    //     uint120 numerator;
    //     uint120 denominator;
    // }
    function logOrderStatus(OrderStatus memory orderStatus) internal view {
        console.log("================logOrderStatus===============");
        console.log("isValidated: ", orderStatus.isValidated);
        console.log("isCancelled: ", orderStatus.isCancelled);
        console.log("numerator: ", orderStatus.numerator);
        console.log("denominator: ", orderStatus.denominator);
        console.log("=================================================");
    }

    // struct ReceivedItem {
    //     ItemType itemType;
    //     address token;
    //     uint256 identifier;
    //     uint256 amount;
    //     address payable recipient;
    // }
    // struct Execution {
    //     ReceivedItem item;
    //     address offerer;
    //     bytes32 conduitKey;
    // }
    function logReceivedItem(ReceivedItem memory receivedItem) internal view {
        console.log("-------------------logReceivedItem:------------------");
        logItemType("itemType: ", receivedItem.itemType);
        console.log("token: ", receivedItem.token);
        console.log("identifier: ", receivedItem.identifier);
        console.log("amount: ", receivedItem.amount);
        console.log("recipient: ", receivedItem.recipient);
        console.log("-------------------  ------------------");
    }
    function logExecution(Execution memory execution) internal view {
        console.log("===================logExecution===================");
        logReceivedItem(execution.item);
        console.log("offerer: ", execution.offerer);
        logBytes32("conduitKey: ", execution.conduitKey);
        console.log("===========================================");
    }
    function logExecutions(Execution[] memory executions) internal view {
        console.log("===================logExecutions===================");
        console.log("executions.length: ", executions.length);
        for (uint i = 0; i < executions.length; i++) {
            logExecution(executions[i]);
        }
    }
}


