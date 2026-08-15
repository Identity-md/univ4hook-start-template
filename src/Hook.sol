// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/**
 * @title Hook
 * @notice A Uniswap v4 hook with no behaviour, meant to be filled in.
 *
 * Every permission below is `false`, so the pool calls into this contract at no point and it
 * behaves exactly as if no hook were attached. That is the intended starting state: turn on the
 * callbacks the feature actually needs and override the matching `_before*` / `_after*` function
 * from {BaseHook}, leaving the rest alone.
 *
 * Two things about v4 that are easy to discover the hard way:
 *
 * - A hook's *address* encodes its permissions. `BaseHook`'s constructor rejects any address whose
 *   low 14 bits disagree with {getHookPermissions}, so enabling a callback here means deploying to
 *   a mined address with the matching flag bits set. `test/Hook.t.sol` shows how, and
 *   `HOOK_FLAGS` in that file is the single place to change when permissions change.
 * - Callbacks are only reachable from the `PoolManager`. {BaseHook} enforces that, so an override
 *   never needs to check `msg.sender` itself.
 */
contract Hook is BaseHook {
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    /**
     * @notice Which pool callbacks this hook receives.
     *
     * @dev Flip a field to `true`, override the matching internal function from {BaseHook}, and
     * update `HOOK_FLAGS` in the test so the deployed address still matches. Leaving a field
     * `false` while overriding its function does nothing: the pool never calls it.
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
