// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test, Vm } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { DeployPermit2 } from "@uniswap/permit2/test/utils/DeployPermit2.sol";
import { ISignatureTransfer } from "@uniswap/permit2/src/interfaces/ISignatureTransfer.sol";
import { IEIP712 } from "@uniswap/permit2/src/interfaces/IEIP712.sol";
import { TypeCasts } from "@hyperlane-xyz/libs/TypeCasts.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import {
    GaslessCrossChainOrder,
    OnchainCrossChainOrder,
    ResolvedCrossChainOrder,
    Output,
    FillInstruction
} from "../src/ERC7683/IERC7683.sol";
import { Base7683 } from "../src/Base7683.sol";

event Open(bytes32 indexed orderId, ResolvedCrossChainOrder resolvedOrder);

event Filled(bytes32 orderId, bytes originData, bytes fillerData);

contract Base7683ForTest is Base7683, StdCheats {
    bytes32 public counterpart;

    uint32 internal _origin;
    uint32 internal _destination;
    address internal inputToken;
    address internal outputToken;

    bytes32 public filledId;
    bytes public filledOriginData;
    bytes public filledFillerData;

    bytes32[] public settledOrderIds;
    bytes[] public settledOrdersFillerData;

    constructor(
      address _permit2,
      uint32 _local,
      uint32 _remote,
      address _inputToken,
      address _outputToken
    ) Base7683(_permit2) {
        _origin = _local;
        _destination = _remote;
        inputToken = _inputToken;
        outputToken = _outputToken;
    }

    function setCounterpart(bytes32 _counterpart) public {
        counterpart = _counterpart;
    }

    function _resolveOrder(GaslessCrossChainOrder memory order)
        internal
        view
        override
        returns (ResolvedCrossChainOrder memory, bytes32 orderId, uint256 nonce)
    {
        return _resolvedOrder(
            order.user,
            order.openDeadline,
            order.fillDeadline,
            order.orderData
        );
    }

    function _resolveOrder(OnchainCrossChainOrder memory order)
        internal
        view
        override
        returns (ResolvedCrossChainOrder memory, bytes32 orderId, uint256 nonce)
    {
        return _resolvedOrder(
            msg.sender,
            type(uint32).max,
            order.fillDeadline,
            order.orderData
        );
    }

    function _resolvedOrder(
        address _sender,
        uint32 _openDeadline,
        uint32 _fillDeadline,
        bytes memory _orderData
    )
        internal
        view
        returns (ResolvedCrossChainOrder memory resolvedOrder, bytes32 orderId, uint256 nonce)
    {
        // this can be used by the filler to approve the tokens to be spent on destination
        Output[] memory maxSpent = new Output[](1);
        maxSpent[0] = Output({
            token: TypeCasts.addressToBytes32(outputToken),
            amount: 100,
            recipient: counterpart,
            chainId: _destination
        });

        // this can be used by the filler know how much it can expect to receive
        Output[] memory minReceived = new Output[](1);
        minReceived[0] = Output({
            token: TypeCasts.addressToBytes32(inputToken),
            amount: 100,
            recipient: bytes32(0),
            chainId: _origin
        });

        // this can be user by the filler to know how to fill the order
        FillInstruction[] memory fillInstructions = new FillInstruction[](1);
        fillInstructions[0] = FillInstruction({
            destinationChainId: _destination,
            destinationSettler: counterpart,
            originData: _orderData
        });

        resolvedOrder = ResolvedCrossChainOrder({
            user: _sender,
            originChainId: _origin,
            openDeadline: _openDeadline,
            fillDeadline: _fillDeadline,
            minReceived: minReceived,
            maxSpent: maxSpent,
            fillInstructions: fillInstructions
        });

        orderId = keccak256("someId");
        nonce = 1;
    }

    function _fillOrder(bytes32 _orderId, bytes calldata _originData, bytes calldata _fillerData) internal override {
        filledId = _orderId;
        filledOriginData = _originData;
        filledFillerData = _fillerData;
    }

    function _settleOrders(bytes32[] calldata _orderIds, bytes[] memory _ordersFillerData) internal override {
        settledOrderIds = _orderIds;
        settledOrdersFillerData = _ordersFillerData;
    }

    function _localDomain() internal view override returns (uint32) {
        return _origin;
    }

    function localDomain() public view returns (uint32) {
        return _localDomain();
    }
}

contract Base7683Test is Test, DeployPermit2 {
    Base7683ForTest internal base;
    // address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address permit2;
    ERC20 internal inputToken;
    ERC20 internal outputToken;

    address internal kakaroto;
    uint256 internal kakarotoPK;
    address internal karpincho;
    uint256 internal karpinchoPK;
    address internal vegeta;
    uint256 internal vegetaPK;
    address internal counterpart = makeAddr("counterpart");

    uint32 internal origin = 1;
    uint32 internal destination = 2;
    uint256 internal amount = 100;

    bytes32 DOMAIN_SEPARATOR;
    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 constant FULL_WITNESS_TYPEHASH = keccak256(
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,ResolvedCrossChainOrder witness)ResolvedCrossChainOrder(address user, uint64 originChainId, uint32 openDeadline, uint32 fillDeadline, Output[] maxSpent, Output[] minReceived, FillInstruction[] fillInstructions)Output(bytes32 token, uint256 amount, bytes32 recipient, uint64 chainId)FillInstruction(uint64 destinationChainId, bytes32 destinationSettler, bytes originData)"
    );

    bytes32 constant FULL_WITNESS_BATCH_TYPEHASH = keccak256(
        "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,ResolvedCrossChainOrder witness)ResolvedCrossChainOrder(address user, uint64 originChainId, uint32 openDeadline, uint32 fillDeadline, Output[] maxSpent, Output[] minReceived, FillInstruction[] fillInstructions)Output(bytes32 token, uint256 amount, bytes32 recipient, uint64 chainId)FillInstruction(uint64 destinationChainId, bytes32 destinationSettler, bytes originData)TokenPermissions(address token,uint256 amount)"
    );

    uint256 internal forkId;

    mapping(address => uint256) internal balanceId;

    function setUp() public {
        // forkId = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 15986407);

        (kakaroto, kakarotoPK) = makeAddrAndKey("kakaroto");
        (karpincho, karpinchoPK) = makeAddrAndKey("karpincho");
        (vegeta, vegetaPK) = makeAddrAndKey("vegeta");

        inputToken = new ERC20("Input Token", "IN");
        outputToken = new ERC20("Output Token", "OUT");

        permit2 = deployPermit2();
        DOMAIN_SEPARATOR = IEIP712(permit2).DOMAIN_SEPARATOR();

        base = new Base7683ForTest(permit2, origin, destination, address(inputToken), address(outputToken));
        base.setCounterpart(TypeCasts.addressToBytes32(counterpart));

        deal(address(inputToken), kakaroto, 1_000_000, true);
        deal(address(inputToken), karpincho, 1_000_000, true);
        deal(address(inputToken), vegeta, 1_000_000, true);
        deal(address(outputToken), kakaroto, 1_000_000, true);
        deal(address(outputToken), karpincho, 1_000_000, true);
        deal(address(outputToken), vegeta, 1_000_000, true);

        balanceId[kakaroto] = 0;
        balanceId[karpincho] = 1;
        balanceId[vegeta] = 2;
        balanceId[counterpart] = 3;
        balanceId[address(base)] = 4;
    }

    function prepareOnchainOrder(
        bytes memory orderData,
        uint32 fillDeadline
    )
        internal
        pure
        returns (OnchainCrossChainOrder memory)
    {
        return OnchainCrossChainOrder({
            fillDeadline: fillDeadline,
            orderDataType: "someOrderType",
            orderData: orderData
        });
    }

    function prepareGaslessOrder(
        bytes memory orderData,
        uint256 permitNonce,
        uint32 openDeadline,
        uint32 fillDeadline
    )
        internal
        view
        returns (GaslessCrossChainOrder memory)
    {
        return GaslessCrossChainOrder({
            originSettler: address(base),
            user: kakaroto,
            nonce: permitNonce,
            originChainId: uint64(origin),
            openDeadline: openDeadline,
            fillDeadline: fillDeadline,
            orderDataType: "someOrderType",
            orderData: orderData
        });
    }

    function assertResolvedOrder(
        ResolvedCrossChainOrder memory resolvedOrder,
        bytes memory orderData,
        address _user,
        uint32 _fillDeadline,
        uint32 _openDeadline
    )
        internal
        view
    {
        assertEq(resolvedOrder.maxSpent.length, 1);
        assertEq(resolvedOrder.maxSpent[0].token, TypeCasts.addressToBytes32(address(outputToken)));
        assertEq(resolvedOrder.maxSpent[0].amount, amount);
        assertEq(resolvedOrder.maxSpent[0].recipient, base.counterpart());
        assertEq(resolvedOrder.maxSpent[0].chainId, destination);

        assertEq(resolvedOrder.minReceived.length, 1);
        assertEq(resolvedOrder.minReceived[0].token, TypeCasts.addressToBytes32(address(inputToken)));
        assertEq(resolvedOrder.minReceived[0].amount, amount);
        assertEq(resolvedOrder.minReceived[0].recipient, bytes32(0));
        assertEq(resolvedOrder.minReceived[0].chainId, origin);

        assertEq(resolvedOrder.fillInstructions.length, 1);
        assertEq(resolvedOrder.fillInstructions[0].destinationChainId, destination);
        assertEq(resolvedOrder.fillInstructions[0].destinationSettler, base.counterpart());

        assertEq(resolvedOrder.fillInstructions[0].originData, orderData);

        assertEq(resolvedOrder.user, _user);
        assertEq(resolvedOrder.originChainId, base.localDomain());
        assertEq(resolvedOrder.openDeadline, _openDeadline);
        assertEq(resolvedOrder.fillDeadline, _fillDeadline);
    }

    function getOrderIDFromLogs() internal returns (bytes32, ResolvedCrossChainOrder memory) {
        Vm.Log[] memory _logs = vm.getRecordedLogs();

        ResolvedCrossChainOrder memory resolvedOrder;
        bytes32 orderID;

        for (uint256 i = 0; i < _logs.length; i++) {
            Vm.Log memory _log = _logs[i];
            // // Open(bytes32 indexed orderId, ResolvedCrossChainOrder resolvedOrder)

            if (_log.topics[0] != Open.selector) {
                continue;
            }
            orderID = _log.topics[1];

            (resolvedOrder) = abi.decode(_log.data, (ResolvedCrossChainOrder));
        }
        return (orderID, resolvedOrder);
    }

    function balances(ERC20 token) internal view returns (uint256[] memory) {
        uint256[] memory _balances = new uint256[](5);
        _balances[0] = token.balanceOf(kakaroto);
        _balances[1] = token.balanceOf(karpincho);
        _balances[2] = token.balanceOf(vegeta);
        _balances[3] = token.balanceOf(counterpart);
        _balances[4] = token.balanceOf(address(base));

        return _balances;
    }

    function orderDataById(bytes32 orderId) internal view returns (bytes memory orderData) {
        (ResolvedCrossChainOrder memory resolvedOrder) = abi.decode(base.orders(orderId), (ResolvedCrossChainOrder));
        orderData = resolvedOrder.fillInstructions[0].originData;
    }

    function assertOrder(
        bytes32 orderId,
        bytes memory orderData,
        uint256[] memory balancesBefore,
        ERC20 token,
        address sender,
        address receiver,
        bytes32 expectedStatus
    )
        internal
        view
    {
        bytes memory savedOrderData = orderDataById(orderId);
        bytes32 status = base.orderStatus(orderId);

        assertEq(savedOrderData, orderData);
        assertTrue(status == expectedStatus);

        uint256[] memory balancesAfter = balances(token);
        assertEq(balancesBefore[balanceId[sender]] - amount, balancesAfter[balanceId[sender]]);
        assertEq(balancesBefore[balanceId[receiver]] + amount, balancesAfter[balanceId[receiver]]);
    }

    function assertOpenOrder(
        bytes32 orderId,
        address sender,
        bytes memory orderData,
        uint256[] memory balancesBefore,
        address user
    )
        internal
        view
    {
        bytes memory savedOrderData = orderDataById(orderId);

        assertFalse(base.isValidNonce(sender, 1));
        assertEq(savedOrderData, orderData);
        assertOrder(orderId, orderData, balancesBefore, inputToken, user, address(base), base.OPENED());
    }

    // open
    function test_open_works(uint32 _fillDeadline) public {
        bytes memory orderData = abi.encode("some order data");
        OnchainCrossChainOrder memory order =
            prepareOnchainOrder(orderData, _fillDeadline);

        vm.startPrank(kakaroto);
        inputToken.approve(address(base), amount);

        assertTrue(base.isValidNonce(kakaroto, 1));
        uint256[] memory balancesBefore = balances(inputToken);

        vm.recordLogs();
        base.open(order);

        (bytes32 orderId, ResolvedCrossChainOrder memory resolvedOrder) = getOrderIDFromLogs();

        assertResolvedOrder(resolvedOrder, orderData, kakaroto, _fillDeadline, type(uint32).max);

        assertOpenOrder(orderId, kakaroto, orderData, balancesBefore, kakaroto);

        vm.stopPrank();
    }

    function getPermitBatchWitnessSignature(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        uint256 privateKey,
        bytes32 typeHash,
        bytes32 witness,
        bytes32 domainSeparator
    )
        internal
        view
        returns (bytes memory sig)
    {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        typeHash,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        address(base),
                        permit.nonce,
                        permit.deadline,
                        witness
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function defaultERC20PermitMultiple(
        address[] memory tokens,
        uint256 nonce,
        uint256 _amount,
        uint32 _deadline
    )
        internal
        pure
        returns (ISignatureTransfer.PermitBatchTransferFrom memory)
    {
        ISignatureTransfer.TokenPermissions[] memory permitted =
            new ISignatureTransfer.TokenPermissions[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            permitted[i] = ISignatureTransfer.TokenPermissions({ token: tokens[i], amount: _amount });
        }
        return ISignatureTransfer.PermitBatchTransferFrom({ permitted: permitted, nonce: nonce, deadline: _deadline });
    }

    function getSignature(
        GaslessCrossChainOrder memory order,
        uint256 permitNonce,
        uint256 _amount,
        uint32 _deadline
    )
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 witness = base.witnessHash(base.resolveFor(order, new bytes(0)));
        address[] memory tokens = new address[](1);
        tokens[0] = address(inputToken);
        ISignatureTransfer.PermitBatchTransferFrom memory permit =
            defaultERC20PermitMultiple(tokens, permitNonce, _amount, _deadline);

        return
            getPermitBatchWitnessSignature(permit, kakarotoPK, FULL_WITNESS_BATCH_TYPEHASH, witness, DOMAIN_SEPARATOR);
    }

    // TODO test_open_InvalidNonce

    // openFor
    function test_openFor_works(uint32 _fillDeadline, uint32 _openDeadline) public {
        vm.assume(_openDeadline > block.timestamp);
        vm.prank(kakaroto);
        inputToken.approve(permit2, type(uint256).max);

        uint256 permitNonce = 0;
        bytes memory orderData = abi.encode("some order data");
        GaslessCrossChainOrder memory order =
            prepareGaslessOrder(orderData, permitNonce, _openDeadline, _fillDeadline);

        bytes memory sig = getSignature(order, permitNonce, amount, _openDeadline);

        vm.startPrank(karpincho);
        inputToken.approve(address(base), amount);

        assertTrue(base.isValidNonce(kakaroto, 1));
        uint256[] memory balancesBefore = balances(inputToken);

        vm.recordLogs();
        base.openFor(order, sig, new bytes(0));

        (bytes32 orderId, ResolvedCrossChainOrder memory resolvedOrder) = getOrderIDFromLogs();

        assertResolvedOrder(resolvedOrder, orderData, kakaroto, _fillDeadline, _openDeadline);

        assertOpenOrder(orderId, kakaroto, orderData, balancesBefore, kakaroto);

        vm.stopPrank();
    }

    // TODO test_openFor_OrderOpenExpired
    // TODO test_openFor_InvalidGaslessOrderSettler
    // TODO test_openFor_InvalidGaslessOrderOriginChain
    // TODO test_openFor_InvalidNonce

    // resolve
    function test_resolve_works(uint32 _fillDeadline) public {
        bytes memory orderData = abi.encode("some order data");
        OnchainCrossChainOrder memory order =
            prepareOnchainOrder(orderData, _fillDeadline);

        vm.prank(kakaroto);
        ResolvedCrossChainOrder memory resolvedOrder = base.resolve(order);

        assertResolvedOrder(resolvedOrder, orderData, kakaroto, _fillDeadline, type(uint32).max);
    }

    // resolveFor
    function test_resolveFor_works(uint32 _fillDeadline, uint32 _openDeadline) public {
        bytes memory orderData = abi.encode("some order data");
        GaslessCrossChainOrder memory order =
            prepareGaslessOrder(orderData, 0, _openDeadline, _fillDeadline);

        vm.prank(karpincho);
        ResolvedCrossChainOrder memory resolvedOrder = base.resolveFor(order, new bytes(0));

        assertResolvedOrder(resolvedOrder, orderData, kakaroto, _fillDeadline, _openDeadline);
    }

    // fill
    function test_fill_works() public {
        bytes memory orderData = abi.encode("some order data");
        bytes32 orderId = "someOrderId";

        vm.startPrank(vegeta);

        bytes memory fillerData = abi.encode(TypeCasts.addressToBytes32(vegeta));

        vm.expectEmit(false, false, false, true);
        emit Filled(orderId, orderData, fillerData);

        base.fill(orderId, orderData, fillerData);

        assertEq(base.orderStatus(orderId), base.FILLED());
        assertEq(base.filledOrders(orderId), orderData);
        assertEq(base.orderFillerData(orderId), fillerData);

        assertEq(base.filledId(), orderId);
        assertEq(base.filledOriginData(), orderData);
        assertEq(base.filledFillerData(), fillerData);

        vm.stopPrank();
    }

    // TODO test_fill_InvalidOrderStatus
}
