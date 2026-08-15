// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Hook} from "../src/Hook.sol";

/**
 * @notice Deployment scaffolding for a v4 hook, and the place to add behavioural tests.
 *
 * A hook cannot simply be `new`-ed: v4 requires it to live at an address whose low 14 bits equal
 * its permission flags, and {BaseHook}'s constructor rejects any other address. `setUp` below reads
 * the permissions off the contract and derives the address from them, so turning a callback on in
 * {Hook} needs no corresponding edit here — this file keeps working whatever the hook grows into.
 */
contract HookTest is Test {
    /// @dev A high address, leaving the low 14 bits free to carry the permission flags.
    uint160 internal constant HOOK_BASE = uint160(0x4444 << 144);

    IPoolManager internal manager;
    Hook internal hook;

    function setUp() public {
        manager = IPoolManager(address(new PoolManager(address(this))));

        address target = address(HOOK_BASE | _declaredFlags());
        deployCodeTo("Hook.sol:Hook", abi.encode(manager), target);
        hook = Hook(target);
    }

    function test_DeploysAtAnAddressEncodingItsPermissions() public view {
        // The constructor enforces this too. Asserting it here turns a confusing deployment revert
        // into a named failure, which is worth one test.
        assertEq(uint160(address(hook)) & Hooks.ALL_HOOK_MASK, _flagsOf(hook.getHookPermissions()));
    }

    function test_KnowsItsPoolManager() public view {
        assertEq(address(hook.poolManager()), address(manager));
    }

    function test_RejectsCallbacksFromAnyoneButThePoolManager() public {
        // BaseHook enforces this, so an override never has to check msg.sender itself. Worth a test
        // because it is the assumption every callback added later silently relies on.
        PoolKey memory key;

        vm.expectRevert();
        IHooks(address(hook)).beforeInitialize(address(this), key, 0);
    }

    /**
     * @dev The flags {Hook} asks for, read without deploying it.
     *
     * `getHookPermissions` is `pure`, so runtime code placed with `vm.etch` can answer it. That is
     * the way around the circularity: the constructor validates the address, so it cannot be run
     * until the address is known, and the address is what the permissions decide.
     */
    function _declaredFlags() private returns (uint160) {
        address probe = address(uint160(uint256(keccak256("hook.permission.probe"))));
        vm.etch(probe, vm.getDeployedCode("Hook.sol:Hook"));
        return _flagsOf(Hook(probe).getHookPermissions());
    }

    function _flagsOf(Hooks.Permissions memory p) private pure returns (uint160 flags) {
        if (p.beforeInitialize) flags |= Hooks.BEFORE_INITIALIZE_FLAG;
        if (p.afterInitialize) flags |= Hooks.AFTER_INITIALIZE_FLAG;
        if (p.beforeAddLiquidity) flags |= Hooks.BEFORE_ADD_LIQUIDITY_FLAG;
        if (p.afterAddLiquidity) flags |= Hooks.AFTER_ADD_LIQUIDITY_FLAG;
        if (p.beforeRemoveLiquidity) flags |= Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
        if (p.afterRemoveLiquidity) flags |= Hooks.AFTER_REMOVE_LIQUIDITY_FLAG;
        if (p.beforeSwap) flags |= Hooks.BEFORE_SWAP_FLAG;
        if (p.afterSwap) flags |= Hooks.AFTER_SWAP_FLAG;
        if (p.beforeDonate) flags |= Hooks.BEFORE_DONATE_FLAG;
        if (p.afterDonate) flags |= Hooks.AFTER_DONATE_FLAG;
        if (p.beforeSwapReturnDelta) flags |= Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;
        if (p.afterSwapReturnDelta) flags |= Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        if (p.afterAddLiquidityReturnDelta) flags |= Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG;
        if (p.afterRemoveLiquidityReturnDelta) flags |= Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
    }
}
