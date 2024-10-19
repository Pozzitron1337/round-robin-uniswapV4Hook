// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

interface IGrindurusPositionsNFT {
    /// execute iteration of strategy
    function execute(uint256 positionId) external;

    function executedPosition() external view returns (uint256);

    /// @dev positions are enumerated from 0 to totalPositions - 1
    function totalPositions() external view returns (uint256);

    function mint() external;
}

contract RoundRobinHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    /// @notice address of strategies NFT
    IGrindurusPositionsNFT public grindurusPositionsNFT;

    /// @notice the positionId of last executed strategy with `positionId`
    /// @dev the value from 0 to totalPositions - 1
    uint256 public lastExecutedPositionId;

    constructor(IPoolManager _poolManager,IGrindurusPositionsNFT _grindurusPositionsNFT) BaseHook(_poolManager) {
        grindurusPositionsNFT = IGrindurusPositionsNFT(_grindurusPositionsNFT);
        lastExecutedPositionId = 0;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: true,
            afterRemoveLiquidityReturnDelta: true
        });
    }

    /// @dev iterates positions in `grindurusPositionsNFT`
    function roundRobin() public {
        uint256 totalPositions = grindurusPositionsNFT.totalPositions();
        if (totalPositions == 0) return;

        lastExecutedPositionId = (lastExecutedPositionId + 1) % totalPositions;

        try grindurusPositionsNFT.execute(lastExecutedPositionId) {
        
        } catch {

        }
    }

    /// @inheritdoc IHooks
    function beforeInitialize(address, PoolKey calldata, uint160) external override returns (bytes4) {
        roundRobin();
        return BaseHook.beforeInitialize.selector;
    }

    /// @inheritdoc IHooks
    function afterInitialize(address, PoolKey calldata, uint160, int24) external override returns (bytes4) {
        roundRobin();
        return BaseHook.beforeInitialize.selector;
    }

    /// @inheritdoc IHooks
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        roundRobin();
        return BaseHook.beforeAddLiquidity.selector;
    }

    /// @inheritdoc IHooks
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        roundRobin();
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    /// @inheritdoc IHooks
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        roundRobin();
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    /// @inheritdoc IHooks
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        roundRobin();
        return (BaseHook.afterRemoveLiquidity.selector, delta);
    }
    
    /// @inheritdoc IHooks
    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        roundRobin();
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @inheritdoc IHooks
    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        roundRobin();
        return (BaseHook.afterSwap.selector, 0);
    }

    /// @inheritdoc IHooks
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external override returns (bytes4) {
        roundRobin();
        return BaseHook.beforeDonate.selector;
    }

    /// @inheritdoc IHooks
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external override returns (bytes4) {
        roundRobin();
        return BaseHook.afterDonate.selector;
    }
}