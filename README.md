# Uniswap v4 Hook — Launch Pool Starter

An empty Uniswap v4 hook on OpenZeppelin's `BaseHook`, and a test harness that hands it a real
launch pool: native ETH paired with a fresh one-billion-supply token, the entire supply already
seeded as liquidity.

The hook does nothing yet. That is the point — the awkward parts of starting a v4 hook are already
solved, so a new idea starts at the behaviour rather than at the scaffolding:

- **The address/permission coupling.** A v4 hook must live at an address encoding its own
  permissions. The harness derives that address from the contract, so enabling a callback needs no
  edit to the test setup.
- **A pool to act on.** Tokens, an initialized pool, liquidity in range, and routers to swap
  through — the environment every hook needs before a single assertion can be written.
- **Remappings** across three nested dependency trees.

## Getting started

```bash
git clone https://github.com/Identity-md/univ4hook-start-template
cd univ4hook-start-template
forge build
forge test
```

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation). No submodule step and
no `forge install`: dependencies are committed under `lib/`, so a plain clone builds offline.

That is not only convenience. This template is built to be handed to an automated contributor whose
work is re-run by a verifier in a container with **no network at all** — submodules there resolve to
empty directories and every build fails. Committed dependencies are what make the template usable by
the network it exists for.

## Starting a new hook

The starter contract is `src/Hook.sol` and its tests are `test/Hook.t.sol`. A real hook is named
after its idea, and lives in its own pair of files:

```solidity
// test/FeeSplitHook.t.sol
contract FeeSplitHookTest is BaseHookTest {
    function hookArtifact() internal view virtual override returns (string memory) {
        return "FeeSplitHook.sol:FeeSplitHook";
    }
}
```

That one override is the whole integration: the harness deploys your contract at an address encoding
*its* permissions, installs it on the launch pool, and every inherited test keeps applying. Override
`hookConstructorArgs()` too if the constructor takes more than the pool manager.

Nothing else needs editing — and under the contributor network, nothing else *may* be: a job for
`FeeSplitHook` is granted write access to `src/FeeSplitHook.sol` and `test/FeeSplitHook.t.sol` and
no other path.

## The launch pool

`BaseHookTest` builds this in `setUp`, so every test inherits it:

```
currency0  native ETH
currency1  LaunchToken — 1,000,000,000e18, minted once, no mint function afterwards
price      starts at tick 138000, ≈ 984k token per ETH (~1,016 ETH fully diluted)
liquidity  the entire supply, in a single position below the starting price
```

All liquidity sits *below* the starting tick, so seeding it costs **no ETH** — the position is pure
token. Buyers swap ETH in, which walks the pool price down through the range and hands out token;
the token's price *in ETH* therefore rises as it is bought. The pool accumulates the ETH. That is
the launch curve, and it is why the pool can open with nothing but the token in it.

Native ETH rather than a mock WETH is deliberate: ETH settles differently from an ERC20, and that
difference is where hooks most often break.

A test usually needs no setup of its own:

```solidity
function test_MyHookTakesItsCut() public {
    swap(key, true, -1 ether, ZERO_BYTES);   // buy with 1 ETH
    assertGt(token.balanceOf(address(hook)), 0);
}
```

Inherited and ready to use: `manager`, `key`, `hook`, `token`, `swapRouter`,
`modifyLiquidityRouter`, `donateRouter`, `ZERO_BYTES`, `tickLower` / `tickUpper`, and
`swap(key, zeroForOne, amountSpecified, hookData)` — a negative amount is exact-input.

## The one thing to understand about v4 hooks

**A hook's address encodes its permissions.** The low 14 bits of the contract's address are the
permission flags. `PoolManager` reads them from the address rather than calling the contract, so it
knows which callbacks to fire without an external call — and a hook cannot change what it is
permitted to do after deployment.

In production you mine a CREATE2 salt whose resulting address carries the right bits (`HookMiner`
in `v4-periphery` does this). In tests, `deployCodeTo` writes the contract to an address you choose,
and `BaseHookTest` reads the permissions off the contract to work out which address that is.
**Enabling a callback therefore needs no edit to the test scaffolding.** It adapts.

Two related rules that produce confusing reverts:

- A hook with **no** flags cannot be installed on a static-fee pool at all — v4 requires "at least 1
  flag set, or a dynamic fee". That is why the starter pool opens dynamic-fee and becomes an
  ordinary 0.30% pool the moment the hook enables anything. See `BaseHookTest.poolFee`.
- A `*ReturnDelta` flag is separate from its action flag. Returning a delta from `_afterSwap`
  without `afterSwapReturnDelta: true` is silently ignored.

## Adding a callback

One file changes. Flip the permission and override the callback. `BaseHook` declares the internal
`_before*` / `_after*` methods; override those, not the external ones, and the `onlyPoolManager`
check stays in place.

```solidity
function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
    return Hooks.Permissions({ ..., afterSwap: true, afterSwapReturnDelta: true, ... });
}

function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
    internal
    override
    returns (bytes4, int128)
{
    return (this.afterSwap.selector, 0);
}
```

Keep the constructor as `constructor(IPoolManager)`. Needing an owner is not a reason to add a
parameter — `Ownable(msg.sender)` works and leaves the harness able to deploy the hook unchanged.
If a hook genuinely needs more constructor arguments, override `BaseHookTest.deployHook`.

## Layout

```
src/Hook.sol           the hook — all permissions off, nothing overridden
src/LaunchToken.sol    ERC20, one billion supply, fixed at construction
test/BaseHookTest.sol  the launch pool: harness, address derivation, seeding
test/Hook.t.sol        your assertions
foundry.toml           solc 0.8.26, cancun, no ffi
remappings.txt         forge-std, uniswap-hooks, v4-core, v4-periphery, openzeppelin, solmate
lib/forge-std
lib/uniswap-hooks      brings v4-core, v4-periphery, openzeppelin-contracts and solmate nested
```

Dependencies come from [OpenZeppelin/uniswap-hooks](https://github.com/OpenZeppelin/uniswap-hooks),
which pins its own v4-core and v4-periphery. That is one version to keep current instead of three
that can disagree with each other.

## Notes

`ffi` is off in `foundry.toml` and should stay off — it lets a Solidity test run arbitrary shell
commands, so anything that compiles an untrusted fork of this template would be executing that
fork's author's code.

`evm_version` is `cancun` because v4 uses transient storage (`TSTORE`/`TLOAD`). Older EVM versions
will not compile it.

Seeding a position from `totalSupply()` rounds down to a whole number of liquidity units, so a few
hundred wei stay with the deployer. `test_PoolHoldsTheEntireSupply` asserts that bound rather than
an exact equality, because the exact equality is not achievable.

## License

MIT
