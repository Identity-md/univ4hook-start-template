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
 * The setup below is the part worth keeping regardless of what the hook ends up doing: v4 requires
 * a hook to live at an address whose low 14 bits equal its permission flags, so a hook cannot
 * simply be `new`-ed in a test. `deployCodeTo` writes the contract to a chosen address instead,
 * which is how a hook is tested without mining a real salt.
 */
contract HookTest is Test {
    /**
     * @dev Permission flags this hook's address must encode.
     *
     * Zero because {Hook.getHookPermissions} enables nothing. When a permission is turned on, OR in
     * the matching constant from {Hooks} — for example
     * `Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG` — or the constructor will revert with
     * `HookAddressNotValid`.
     */
    uint160 internal constant HOOK_FLAGS = 0;

    /// @dev A high address, so the low 14 bits are free to carry exactly HOOK_FLAGS and nothing else.
    address internal constant HOOK_ADDRESS = address(uint160(0x4444 << 144));

    IPoolManager internal manager;
    Hook internal hook;

    function setUp() public {
        manager = IPoolManager(address(new PoolManager(address(this))));

        address target = address(uint160(HOOK_ADDRESS) | HOOK_FLAGS);
        deployCodeTo("Hook.sol:Hook", abi.encode(manager), target);
        hook = Hook(target);
    }

    function test_DeploysAtAnAddressMatchingItsPermissions() public view {
        // The constructor already enforces this; asserting it here makes the failure obvious when
        // someone changes the permissions and forgets HOOK_FLAGS.
        assertEq(uint160(address(hook)) & Hooks.ALL_HOOK_MASK, HOOK_FLAGS);
    }

    function test_KnowsItsPoolManager() public view {
        assertEq(address(hook.poolManager()), address(manager));
    }

    function test_EnablesNoCallbacks() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();

        // A blank canvas: the pool calls into this hook at no point, so a pool using it behaves
        // exactly as one with no hook at all until a permission is turned on.
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertFalse(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertFalse(permissions.beforeSwap);
        assertFalse(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }

    function test_RejectsCallbacksFromAnyoneButThePoolManager() public {
        // BaseHook enforces this, so an override never has to check msg.sender itself. Worth a test
        // because it is the assumption every future callback will silently rely on.
        PoolKey memory key;

        vm.expectRevert();
        IHooks(address(hook)).beforeInitialize(address(this), key, 0);
    }
}
