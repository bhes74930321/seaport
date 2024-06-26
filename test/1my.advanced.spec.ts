import { PANIC_CODES } from "@nomicfoundation/hardhat-chai-matchers/panic";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber, constants } from "ethers";
import { ethers, network } from "hardhat";

import { deployContract } from "./utils/contracts";
import { merkleTree } from "./utils/criteria";
import {
  buildOrderStatus,
  buildResolver,
  defaultAcceptOfferMirrorFulfillment,
  defaultBuyNowMirrorFulfillment,
  getItemETH,
  random128,
  randomBN,
  randomHex,
  toBN,
  toFulfillment,
  toFulfillmentComponents,
  toKey,
} from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { seaportFixture } from "./utils/fixtures";
import {
  VERSION,
  minRandom,
  simulateAdvancedMatchOrders,
  simulateMatchOrders,
} from "./utils/helpers";

import type {
  ConduitControllerInterface,
  ConduitInterface,
  ConsiderationInterface,
  // TestERC1155,
  // TestERC20,
  // TestERC721,
  // TestZone,
} from "../typechain-types";
import type { SeaportFixtures } from "./utils/fixtures";
import type { AdvancedOrder, ConsiderationItem } from "./utils/types";
import type { Wallet } from "ethers";

const { parseEther } = ethers.utils;

describe(`Advanced orders (Seaport v${VERSION})`, function () {
  const { provider } = ethers;
  const owner = new ethers.Wallet(randomHex(32), provider);

  let conduitController: ConduitControllerInterface;

  let conduitKeyOne: string;
  let conduitOne: ConduitInterface;
  let marketplaceContract: ConsiderationInterface;
  // let testERC1155: TestERC1155;
  // let testERC1155Two: TestERC1155;
  // let testERC20: TestERC20;
  // let testERC721: TestERC721;
  // let stubZone: TestZone;
  let checkExpectedEvents: SeaportFixtures["checkExpectedEvents"];
  let createMirrorAcceptOfferOrder: SeaportFixtures["createMirrorAcceptOfferOrder"];
  let createMirrorBuyNowOrder: SeaportFixtures["createMirrorBuyNowOrder"];
  let createOrder: SeaportFixtures["createOrder"];
  let getTestItem1155: SeaportFixtures["getTestItem1155"];
  let getTestItem1155WithCriteria: SeaportFixtures["getTestItem1155WithCriteria"];
  let getTestItem20: SeaportFixtures["getTestItem20"];
  let getTestItem721: SeaportFixtures["getTestItem721"];
  let getTestItem721WithCriteria: SeaportFixtures["getTestItem721WithCriteria"];
  let mint1155: SeaportFixtures["mint1155"];
  let mint721: SeaportFixtures["mint721"];
  let mint721s: SeaportFixtures["mint721s"];
  let mintAndApprove1155: SeaportFixtures["mintAndApprove1155"];
  let mintAndApprove721: SeaportFixtures["mintAndApprove721"];
  let mintAndApproveERC20: SeaportFixtures["mintAndApproveERC20"];
  let set1155ApprovalForAll: SeaportFixtures["set1155ApprovalForAll"];
  let set721ApprovalForAll: SeaportFixtures["set721ApprovalForAll"];
  let signOrder: SeaportFixtures["signOrder"];
  let withBalanceChecks: SeaportFixtures["withBalanceChecks"];
  let invalidContractOfferer: SeaportFixtures["invalidContractOfferer"];
  let invalidContractOffererRatifyOrder: SeaportFixtures["invalidContractOffererRatifyOrder"];
  let deployNewConduit: SeaportFixtures["deployNewConduit"];

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });
  before(async () => {
    await faucet(owner.address, provider);
    ({
      conduitController,
      checkExpectedEvents,
      conduitKeyOne,
      conduitOne,
      createMirrorAcceptOfferOrder,
      createMirrorBuyNowOrder,
      createOrder,
      getTestItem1155,
      getTestItem1155WithCriteria,
      getTestItem20,
      getTestItem721,
      getTestItem721WithCriteria,
      marketplaceContract,
      mint1155,
      mint721,
      mint721s,
      mintAndApprove1155,
      mintAndApprove721,
      mintAndApproveERC20,
      set1155ApprovalForAll,
      set721ApprovalForAll,
      signOrder,
      // testERC1155,
      // testERC1155Two,
      // testERC20,
      // testERC721,
      withBalanceChecks,
      invalidContractOfferer,
      invalidContractOffererRatifyOrder,
      // stubZone,
      deployNewConduit,
    } = await seaportFixture(owner));
  });
  let seller: Wallet;
  let buyer: Wallet;
  let zone: Wallet;

  let tempConduit: ConduitInterface;

  async function setupFixture() {
    // Setup basic buyer/seller wallets with ETH
    const seller = new ethers.Wallet(randomHex(32), provider);
    const buyer = new ethers.Wallet(randomHex(32), provider);
    const zone = new ethers.Wallet(randomHex(32), provider);
    for (const wallet of [seller, buyer, zone]) {
      await faucet(wallet.address, provider);
    }

    // Deploy a new conduit
    //const tempConduit = await deployNewConduit(owner);

    console.log("owner:", owner.address);
    console.log("seller:", seller.address);
    console.log("buyer:", buyer.address);
    console.log("zone:", zone.address);
    return { seller, buyer, zone, tempConduit };
  }
  beforeEach(async () => {
    ({ seller, buyer, zone, tempConduit } = await loadFixture(setupFixture));
  });
  describe("Contract Orders", async () => {
    it("Contract Orders (standard)", async () => {
      return;
      // Seller mints nft
      const { nftId, amount } = await mintAndApprove1155(
        seller,
        marketplaceContract.address,
        10000,  //精度 小数点后几个零
        1, //初始id
        1000 //amount
      );
      console.log("nftId", nftId);
      console.log("amount", amount);

      // seller deploys offererContract and approves it for 1155 token
      const offererContract = await deployContract(
        "TestContractOfferer",
        owner,
        marketplaceContract.address
      );
      console.log("offererContract", offererContract.address);

      await set1155ApprovalForAll(seller, offererContract.address, true);

      const offer = [
        getTestItem1155(nftId, amount.mul(10), amount.mul(10)) as any,
      ];

      const consideration = [
        getItemETH(
          amount.mul(1000),
          amount.mul(1000),
          offererContract.address
        ) as any,
      ];

      offer[0].identifier = offer[0].identifierOrCriteria;
      offer[0].amount = offer[0].endAmount;
      console.log("2=====offer:", offer);

      consideration[0].identifier = consideration[0].identifierOrCriteria;
      consideration[0].amount = consideration[0].endAmount;
      console.log("2=====consideration:", consideration);

      //
      await offererContract
        .connect(seller)
        .activate(offer[0], consideration[0]);

      const { order, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        4 // CONTRACT
      );

      const contractOffererNonce =
        await marketplaceContract.getContractOffererNonce(
          offererContract.address
        );

      const orderHash =
        offererContract.address.toLowerCase() +
        contractOffererNonce.toHexString().slice(2).padStart(24, "0");

      const orderStatus = await marketplaceContract.getOrderStatus(orderHash);

      expect({ ...orderStatus }).to.deep.equal(
        buildOrderStatus(false, false, 0, 0)
      );

      console.log("order1:", order);
      order.parameters.offerer = offererContract.address;
      order.numerator = 1;
      order.denominator = 1;
      order.signature = "0x";//删除签名
      console.log("order2:", order);

      await withBalanceChecks([order], 0, [], async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAdvancedOrder(
            order,  //advancedOrder: AdvancedOrderStruct
            [],  // criteriaResolvers: CriteriaResolverStruct[]
            toKey(0), //fulfillerConduitKey: PromiseOrValue<BytesLike>
            ethers.constants.AddressZero, //PromiseOrValue<string>
            {
              value, //    overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: buyer.address,
              fulfillerConduitKey: toKey(0),
            },
          ],
          undefined,
          []
        );

        return receipt;
      });
    });

    it("Contract Orders (with conduit)", async () => {
      return;
      const tempConduitKey = owner.address + "ff00000000000000000000f1";
      const { conduit: tempConduitAddress, exists: isConduitExist } = await conduitController.getConduit(
        tempConduitKey
      );
      //输出 tempConduitAddress和isConduitExist
      console.log(`tempConduitAddress: ${tempConduitAddress}, isConduitExist: ${isConduitExist}`);

      await conduitController
      .connect(owner)
      .createConduit(tempConduitKey, owner.address);
      const { conduit: tempConduitAddress1, exists: isConduitExist1 } = await conduitController.getConduit(
        tempConduitKey
      );
      //console.log(`tempConduitAddress1: ${tempConduitAddress1}, isConduitExist1: ${isConduitExist1}`);

      // Seller mints first nft
      // const mint1155 = async (
      //   signer: Wallet,
      //   multiplier = 1,  精度 mint数量=amt*multiplier
      //   token = testERC1155,  token地址
      //   id?: BigNumberish,  初始id
      //   amt?: BigNumberish  初始数量
      // )
      const { nftId, amount } = await mint1155(seller, undefined, undefined, 1, 1000);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } =
        await mintAndApprove1155(seller, conduitOne.address, 1, 1, 1000);
      
      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
      ];
      console.log("offer:", offer);

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];
      //console.log("consideration:", consideration);

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        null,
        seller,
        ethers.constants.HashZero,
        conduitKeyOne
      );
      // console.log("----------------------------------");
      // console.log(JSON.stringify(order, null, 2));
      // console.log("----------------------------------");


      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );
      // console.log(JSON.stringify(mirrorOrder, null, 2));
      // console.log("----------------------------------");

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );
      // 打印完整对象结构
      // console.log("fulfillments:", JSON.stringify(fulfillments, null, 2));

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );
      console.log("executions:", executions);

      expect(executions.length).to.equal(5);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
        const receipt = await (await tx).wait();
        await checkExpectedEvents(
          tx,
          receipt,
          [
            {
              order,
              orderHash,
              fulfiller: owner.address,
            },
            {
              order: mirrorOrder,
              orderHash: mirrorOrderHash,
              fulfiller: owner.address,
            },
          ],
          executions
        );
        return receipt;

    });

    it("Criteria-based offer item ERC1155 (match)", async () => {
      return
      // Seller mints nfts
      const { nftId } = await mint1155(seller, undefined, undefined, 1, 1000);
  
      // Seller approves marketplace contract to transfer NFTs
      await set1155ApprovalForAll(seller, marketplaceContract.address, true);
  
      const { root, proofs } = merkleTree([nftId]);
  
      const offer = [getTestItem1155WithCriteria(root, toBN(1), toBN(1))];
      console.log("---------------offer-------------------")
      console.log(JSON.stringify(offer, null, 2));
  
      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];
      console.log("---------------consideration-------------------")
      console.log(JSON.stringify(consideration, null, 2));
      
  
      const criteriaResolvers = [
        buildResolver(0, 0, 0, nftId, proofs[nftId.toString()]),
      ];
      console.log("----------------criteriaResolvers------------------")
      console.log(JSON.stringify(criteriaResolvers, null, 2));
  
      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        criteriaResolvers
      );
      console.log("----------------order------------------")
      console.log(JSON.stringify(order, null, 2));
      console.log("----------------orderHash------------------")
      console.log(JSON.stringify(orderHash, null, 2));
      console.log("----------------value------------------")
      console.log(JSON.stringify(value, null, 2));
  
      const { mirrorOrder, mirrorOrderHash } =
        await createMirrorAcceptOfferOrder(
          buyer,
          zone,
          order,
          criteriaResolvers
        );
      console.log("----------------mirrorOrder------------------")
      console.log(JSON.stringify(mirrorOrder, null, 2));
  
      //[[[offerOrderIndex, offerItemIndex]], [[considerationOrderIndex, considerationItemIndex]]]
      // [[[1, 0]], [[0, 0]]], // 镜像订单的第0项报价 (10 ETH) 与 订单的第0项对价 (ERC1155 代币) 匹配
      // [[[0, 0]], [[1, 0]]], // 订单的第0项报价 (ERC1155 代币) 与 镜像订单的第0项对价 (10 ETH) 匹配
      // [[[1, 1]], [[0, 1]]], // 镜像订单的第1项报价 (1 ETH) 与 订单的第1项对价 (1 ETH) 匹配
      // [[[1, 2]], [[0, 2]]], // 镜像订单的第2项报价 (1 ETH) 与 订单的第2项对价 (1 ETH) 匹配
      const fulfillments = [
        [[[1, 0]], [[0, 0]]],
        [[[0, 0]], [[1, 0]]],
        [[[1, 1]], [[0, 1]]],
        [[[1, 2]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );
  
      const executions = await simulateAdvancedMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        criteriaResolvers,
        fulfillments,
        owner,
        value
      );
  
      expect(executions.length).to.equal(4);
  
      const tx = marketplaceContract
        .connect(owner)
        .matchAdvancedOrders(
          [order, mirrorOrder],
          criteriaResolvers,
          fulfillments,
          ethers.constants.AddressZero,
          {
            value,
          }
        );
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions,
        criteriaResolvers
      );
      return receipt;
    });

    it("ERC1155 <=> ETH (match via conduit)", async () => {
      return;
      // Seller mints first nft
      const { nftId, amount } = await mint1155(seller);

      // Seller mints second nft
      const { nftId: secondNftId, amount: secondAmount } =
        await mintAndApprove1155(seller, conduitOne.address);

      const offer = [
        getTestItem1155(nftId, amount, amount, undefined),
        getTestItem1155(secondNftId, secondAmount, secondAmount),
      ];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0, // FULL_OPEN
        [],
        null,
        seller,
        ethers.constants.HashZero,
        conduitKeyOne
      );
      console.log("conduitKeyOne:", conduitKeyOne);
      //return;

      const { mirrorOrder, mirrorOrderHash } = await createMirrorBuyNowOrder(
        buyer,
        zone,
        order
      );

      const fulfillments = [
        [[[0, 0]], [[1, 0]]],
        [[[0, 1]], [[1, 1]]],
        [[[1, 0]], [[0, 0]]],
        [[[1, 0]], [[0, 1]]],
        [[[1, 0]], [[0, 2]]],
      ].map(([offerArr, considerationArr]) =>
        toFulfillment(offerArr, considerationArr)
      );

      const executions = await simulateMatchOrders(
        marketplaceContract,
        [order, mirrorOrder],
        fulfillments,
        owner,
        value
      );

      expect(executions.length).to.equal(5);

      const tx = marketplaceContract
        .connect(owner)
        .matchOrders([order, mirrorOrder], fulfillments, {
          value,
        });
      const receipt = await (await tx).wait();
      await checkExpectedEvents(
        tx,
        receipt,
        [
          {
            order,
            orderHash,
            fulfiller: owner.address,
          },
          {
            order: mirrorOrder,
            orderHash: mirrorOrderHash,
            fulfiller: owner.address,
          },
        ],
        executions
      );
      return receipt;
    });

    it("Can fulfill a single order via fulfillAvailableAdvancedOrders", async () => {
      // Seller mints nft
      const nftId = await mintAndApprove721(
        seller,
        marketplaceContract.address,
        11
      );

      const offer = [getTestItem721(nftId)];

      const consideration = [
        getItemETH(parseEther("10"), parseEther("10"), seller.address),
        getItemETH(parseEther("1"), parseEther("1"), zone.address),
        getItemETH(parseEther("1"), parseEther("1"), owner.address),
      ];

      const { order, orderHash, value } = await createOrder(
        seller,
        zone,
        offer,
        consideration,
        0 // FULL_OPEN
      );

      // orders[0].parameters.offerer[0]
      const offerComponents = [[{ orderIndex: 0, itemIndex: 0 }]];
      // orders[0].parameters.consideration[0]
      // orders[0].parameters.consideration[1]
      // orders[0].parameters.consideration[2]
      const considerationComponents = [
        [{ orderIndex: 0, itemIndex: 0 }],
        [{ orderIndex: 0, itemIndex: 1 }],
        [{ orderIndex: 0, itemIndex: 2 }],
      ];

      await withBalanceChecks([order], 0, undefined, async () => {
        const tx = marketplaceContract
          .connect(buyer)
          .fulfillAvailableAdvancedOrders(
            [order],
            [],
            offerComponents,
            considerationComponents,
            toKey(0),
            ethers.constants.AddressZero,
            100,
            {
              value,
            }
          );
        const receipt = await (await tx).wait();
        await checkExpectedEvents(tx, receipt, [
          {
            order,
            orderHash,
            fulfiller: buyer.address,
          },
        ]);

        return receipt;
      });
    });
  });
});

// enum ItemType {
//   // 0: ETH on mainnet, MATIC on polygon, etc.
//   NATIVE,
//   // 1: ERC20 items (ERC777 and ERC20 analogues could also technically work)
//   ERC20,
//   // 2: ERC721 items
//   ERC721,
//   // 3: ERC1155 items
//   ERC1155,
//   // 4: ERC721 items where a number of tokenIds are supported
//   ERC721_WITH_CRITERIA,
//   // 5: ERC1155 items where a number of ids are supported
//   ERC1155_WITH_CRITERIA
// }