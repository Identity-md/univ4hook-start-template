# Uniswap v4 Hook — Starter Template

A deliberately empty Uniswap v4 hook, built on OpenZeppelin's `BaseHook`, with the deployment
scaffolding a hook needs already working. Fork it, turn on the callbacks you want, write the
behaviour.

Nothing here does anything yet. That is the point: the awkward parts of starting a v4 hook — the
address/permission coupling, the remappings across three nested dependency trees, a test that can
actually deploy the thing — are solved, and the contract itself is a blank canvas.

## Getting started

```bash
git clone --recurse-submodules https://github.com/Identity-md/univ4hook-start-template
cd univ4hook-start-template
forge build
forge test
```

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation). If you cloned without
`--recurse-submodules`, run `git submodule update --init --recursive`.

## The one thing to understand about v4 hooks

**A hook's address encodes its permissions.** The low 14 bits of the contract's address are the
permission flags. `PoolManager` reads them from the address itself rather than calling the contract,
so it knows which callbacks to fire without an external call — and so a hook cannot change what it
is permitted to do after deployment.

The practical consequence: enabling a callback is a two-part change, and doing only half of it
fails.

1. Return `true` for it in `getHookPermissions()`.
2. Deploy to an address whose low 14 bits match.

`BaseHook`'s constructor calls `_validateHookAddress(this)`, so a mismatch reverts at deployment
rather than producing a hook that silently never gets called.

In tests, `deployCodeTo` writes the contract to an address you choose, which is why `HookTest` does
not mine a salt. In production you mine a CREATE2 salt whose resulting address carries the right
bits (`HookMiner` in `v4-periphery` does this).

## Adding a callback

To add `beforeSwap`, say — three edits:

**`src/Hook.sol`** — flip the permission and override the callback. `BaseHook` declares the
internal `_before*`/`_after*` methods; override those, not the external ones, and the
`onlyPoolManager` check stays in place.

```solidity
function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
    return Hooks.Permissions({ ..., beforeSwap: true, ... });
}

function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
    internal
    override
    returns (bytes4, BeforeSwapDelta, uint24)
{
    return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
}
```

**`test/Hook.t.sol`** — update the flags constant so the test deploys to a matching address:

```solidity
uint160 internal constant HOOK_FLAGS = uint160(Hooks.BEFORE_SWAP_FLAG);
```

Forgetting this second edit is the most common way a first hook fails, and the revert
(`HookAddressNotValid`) does not say so.

## Layout

```
src/Hook.sol        the hook — all permissions off, nothing overridden
test/Hook.t.sol     deployment scaffolding + permission assertions
foundry.toml        solc 0.8.26, cancun, no ffi
remappings.txt      forge-std, uniswap-hooks, v4-core, v4-periphery, openzeppelin-contracts
lib/forge-std
lib/uniswap-hooks   brings v4-core, v4-periphery and openzeppelin-contracts nested
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

## License

MIT
