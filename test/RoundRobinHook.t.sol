// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {RoundRobinHook} from "../src/RoundRobinHook.sol";
import {IGrindurusPositionsNFT} from "../src/RoundRobinHook.sol";
import {IPoolManager, PoolKey} from "v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {HookMiner} from "test/utils/HookMiner.sol";

contract MockGrindurusPositionsNFT is IGrindurusPositionsNFT {
    uint256 public override totalPositions;
    uint256 public executedPosition;

    constructor() {}

    function execute(uint256 positionId) external override {
        executedPosition = positionId;
    }

    function mint() external {
        totalPositions++;
    }
}

contract RoundRobinHookTest is Test {
    RoundRobinHook public hook;
    IGrindurusPositionsNFT public mockPositionsNFT;
    IPoolManager public mockPoolManager;

    function setUp() public {
        // Set up mock contracts and initial state
        mockPositionsNFT = new MockGrindurusPositionsNFT();
        mockPoolManager = IPoolManager(address(this)); // mock pool manager, can use address(this) for simplicity

        mockPositionsNFT.mint();
        mockPositionsNFT.mint();
        mockPositionsNFT.mint();
        mockPositionsNFT.mint();
        mockPositionsNFT.mint();
        
        uint160 flags = uint160(Hooks.ALL_HOOK_MASK);
        address deployer = address(this);
        (address hookAddress, bytes32 salt) = HookMiner.find(deployer, flags, type(RoundRobinHook).creationCode, abi.encode(address(mockPoolManager), address(mockPositionsNFT)));
        hook = new RoundRobinHook{salt: salt}(mockPoolManager, mockPositionsNFT);
        require(address(hook) == hookAddress, "CounterTest: hook address mismatch");
    }

    function testRoundRobinExecution() public {
        // Test roundRobin function execution
        hook.roundRobin();
        assertEq(mockPositionsNFT.executedPosition(), 1, "Position 1 should be executed");

        hook.roundRobin();
        assertEq(mockPositionsNFT.executedPosition(), 2, "Position 2 should be executed");

        // Test wrapping around after reaching total positions
        hook.roundRobin();
        hook.roundRobin();
        hook.roundRobin();
        assertEq(mockPositionsNFT.executedPosition(), 0, "Should wrap around to position 0 after the last position");
    }

    function testBeforeAddLiquidity() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(0x0000000000000000000000000000000000000001), // Example address for currency0
            currency1: Currency.wrap(0x0000000000000000000000000000000000000002), // Example address for currency1
            fee: 3000, // Example fee, can be changed
            tickSpacing: 60, // Example tick spacing, can be changed
            hooks: IHooks(address(0)) // Set to a valid hooks address or address(0) if no hooks are used
        });
        IPoolManager.ModifyLiquidityParams memory params;

        bytes4 result = hook.beforeAddLiquidity(address(this), key, params, "");
        assertEq(result, hook.beforeAddLiquidity.selector, "beforeAddLiquidity selector should match");
        assertEq(mockPositionsNFT.executedPosition(), 1, "RoundRobin should execute the next position");
    }

    function testAfterAddLiquidity() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(0x0000000000000000000000000000000000000001), // Example address for currency0
            currency1: Currency.wrap(0x0000000000000000000000000000000000000002), // Example address for currency1
            fee: 3000, // Example fee, can be changed
            tickSpacing: 60, // Example tick spacing, can be changed
            hooks: IHooks(address(0)) // Set to a valid hooks address or address(0) if no hooks are used
        });
        BalanceDelta delta;
        BalanceDelta feesAccrued;
        IPoolManager.ModifyLiquidityParams memory params;

        (bytes4 selector, BalanceDelta returnedDelta) = hook.afterAddLiquidity(
            address(this),
            key,
            params,
            delta,
            feesAccrued,
            ""
        );
        assertEq(selector, hook.afterAddLiquidity.selector, "afterAddLiquidity selector should match");
        assertEq(mockPositionsNFT.executedPosition(), 1, "RoundRobin should execute the next position");
    }

    function testBeforeSwap() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(0x0000000000000000000000000000000000000001), // Example address for currency0
            currency1: Currency.wrap(0x0000000000000000000000000000000000000002), // Example address for currency1
            fee: 3000, // Example fee, can be changed
            tickSpacing: 60, // Example tick spacing, can be changed
            hooks: IHooks(address(0)) // Set to a valid hooks address or address(0) if no hooks are used
        });
        IPoolManager.SwapParams memory params;

        (bytes4 selector, BeforeSwapDelta delta, ) = hook.beforeSwap(address(this), key, params, "");
        assertEq(selector, hook.beforeSwap.selector, "beforeSwap selector should match");
        
        // Use BeforeSwapDeltaLibrary to extract specified and unspecified deltas
        int128 specifiedDelta = BeforeSwapDeltaLibrary.getSpecifiedDelta(delta);
        int128 unspecifiedDelta = BeforeSwapDeltaLibrary.getUnspecifiedDelta(delta);

        // Compare the extracted values (assuming both should be 0 for this test)
        assertEq(specifiedDelta, 0, "Specified delta should be 0");
        assertEq(unspecifiedDelta, 0, "Unspecified delta should be 0");
    }

    function testAfterSwap() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(0x0000000000000000000000000000000000000001), // Example address for currency0
            currency1: Currency.wrap(0x0000000000000000000000000000000000000002), // Example address for currency1
            fee: 3000, // Example fee, can be changed
            tickSpacing: 60, // Example tick spacing, can be changed
            hooks: IHooks(address(0)) // Set to a valid hooks address or address(0) if no hooks are used
        });
        BalanceDelta delta;
        IPoolManager.SwapParams memory params;

        (bytes4 selector, ) = hook.afterSwap(address(this), key, params, delta, "");
        assertEq(selector, hook.afterSwap.selector, "afterSwap selector should match");
        assertEq(mockPositionsNFT.executedPosition(), 1, "RoundRobin should execute the next position");
    }

    function testBeforeDonate() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(0x0000000000000000000000000000000000000001), // Example address for currency0
            currency1: Currency.wrap(0x0000000000000000000000000000000000000002), // Example address for currency1
            fee: 3000, // Example fee, can be changed
            tickSpacing: 60, // Example tick spacing, can be changed
            hooks: IHooks(address(0)) // Set to a valid hooks address or address(0) if no hooks are used
        });

        bytes4 result = hook.beforeDonate(address(this), key, 100, 200, "");
        assertEq(result, hook.beforeDonate.selector, "beforeDonate selector should match");
        assertEq(mockPositionsNFT.executedPosition(), 1, "RoundRobin should execute the next position");
    }

    function testAfterDonate() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(0x0000000000000000000000000000000000000001), // Example address for currency0
            currency1: Currency.wrap(0x0000000000000000000000000000000000000002), // Example address for currency1
            fee: 3000, // Example fee, can be changed
            tickSpacing: 60, // Example tick spacing, can be changed
            hooks: IHooks(address(0)) // Set to a valid hooks address or address(0) if no hooks are used
        });

        bytes4 result = hook.afterDonate(address(this), key, 100, 200, "");
        assertEq(result, hook.afterDonate.selector, "afterDonate selector should match");
        assertEq(mockPositionsNFT.executedPosition(), 1, "RoundRobin should execute the next position");
    }
}