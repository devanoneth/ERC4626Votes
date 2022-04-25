# <h1 align="center"> ERC4626Votes </h1>

**ERC4626 extension which allows for voting based on underlying asset in Compound style governance**

![Github Actions](https://github.com/devanonon/ERC4626Votes/workflows/CI/badge.svg)

## Getting Started

Clone this repo.
```
forge install
forge build
forge test
```

## Notes

### OpenZeppelin Draft ERC4626
This repo uses the draft ERC4626 OZ implementation as a submodule. It is not currently in any release. For this reason, you must run `forge install` rather than `forge update`. More details on this WIP ERC4626 below:
 - https://github.com/OpenZeppelin/openzeppelin-contracts/pull/3171
 - https://github.com/Amxx/openzeppelin-contracts/tree/feature/ERC4626

### ¿Porque no [Solmate](https://github.com/Rari-Capital/solmate)?
All my friends ❤️ Solmate. However, here we needed to quickly integrate an ERC4626 token into governance contracts. OZ provides a really easy way to extend their contracts / interfaces to achieve that, especially because they also have all of the governance pieces needed.

## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.
