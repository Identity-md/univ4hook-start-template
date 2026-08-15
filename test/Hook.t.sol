// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BaseHookTest} from "./BaseHookTest.sol";

/**
 * @notice Tests for {Hook}. Write the behavioural ones here.
 *
 * {BaseHookTest} has already built the launch pool: ETH paired with the full one billion
 * {LaunchToken}, the hook installed, and ETH in hand to buy with. Most tests need no setup of their
 * own — `swap(key, true, -1 ether, ZERO_BYTES)` buys, then assert on what the hook did.
 *
 * The tests below hold for a hook with any permissions, so they keep passing as this one grows.
 */
contract HookTest is BaseHookTest {
    function test_DeploysAtAnAddressEncodingItsPermissions() public view {
        // The constructor enforces this too. Asserting it here turns a confusing deployment revert
        // into a named failure, which is worth one test.
        assertEq(uint160(address(hook)) & Hooks.ALL_HOOK_MASK, flagsOf(hook.getHookPermissions()));
    }

    function test_KnowsItsPoolManager() public view {
        assertEq(address(hook.poolManager()), address(manager));
    }

    function test_IsInstalledOnThePool() public view {
        assertEq(address(key.hooks), address(hook));
    }

    function test_RejectsCallbacksFromAnyoneButThePoolManager() public {
        // BaseHook enforces this, so an override never has to check msg.sender itself. Worth a test
        // because it is the assumption every callback added later silently relies on.
        PoolKey memory empty;

        vm.expectRevert();
        IHooks(address(hook)).beforeInitialize(address(this), empty, 0);
    }

    /**
     * @dev The whole supply is in the pool.
     *
     * Not exactly every wei: liquidity is quantised, so sizing a position from the supply rounds
     * down and leaves a few hundred wei behind. The bound is asserted rather than the equality,
     * because the equality is not achievable and a test that pretends otherwise would be wrong.
     */
    function test_PoolHoldsTheEntireSupply() public view {
        uint256 pooled = token.balanceOf(address(manager));
        uint256 dust = token.totalSupply() - pooled;

        assertEq(token.balanceOf(address(this)), dust, "the deployer keeps only the rounding dust");
        assertLt(dust, 1 gwei, "and that dust is negligible against a 1e27 supply");
    }

    /// @dev Seeding cost no ETH: the position is entirely token, below the starting price.
    function test_LaunchPoolIsSeededWithoutEth() public view {
        assertEq(address(manager).balance, 0, "no ETH needed to open the pool");
    }

    /// @dev A buy: ETH in, token out. Proves the harness is a working pool, not a stub.
    function test_BuyingWithEthReturnsToken() public {
        BalanceDelta delta = swap(key, true, -1 ether, ZERO_BYTES);

        assertEq(delta.amount0(), -1 ether, "spent exactly the ETH offered");
        assertGt(token.balanceOf(address(this)), 0, "received token");
        assertEq(address(manager).balance, 1 ether, "pool took the ETH");
    }

    /// @dev Buying raises the token's price in ETH, so a second identical buy gets less.
    function test_BuyingRaisesThePrice() public {
        swap(key, true, -1 ether, ZERO_BYTES);
        uint256 first = token.balanceOf(address(this));

        swap(key, true, -1 ether, ZERO_BYTES);
        uint256 second = token.balanceOf(address(this)) - first;

        assertLt(second, first, "the same ETH buys less the second time");
    }
}
