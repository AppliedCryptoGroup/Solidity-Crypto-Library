# Solidity Crypto Library

Collection of cryptographic primitives usable in Solidity smart contracts.

**Currently implemented:**
- Binary Search in Solidity
- Merkle Dispute Handler
- Gas Estimator (works for contracts with less than 7 functions)

## Existing libraries

### BLS signature verification:
* [solidity-bls](https://github.com/kfichter/solidity-bls) transformed [BLSExample.sol](https://gist.github.com/BjornvdLaan/ca6dd4e3993e1ef392f363ec27fe74c4) to a library.

### Post Quantum:

* [EnQlave](https://www.enqlave.io/) (in development) is a quantum-resistant wallet built using smart contracts and relies on the eXtended Merkle Signature Scheme (XMSS).

### Zero Knowledge Proofs:
* [ZoKrates](https://github.com/Zokrates/ZoKrates) the zk-SNARKS implementation for Ethereum. One can generate a proofing and verification key off-chain and use this proofing key to generate a proof, which can then be verified by a pre-compiled smart contract.
* [Zero-Knowledge Range Proof](https://www.ingwb.com/media/2122048/zero-knowledge-range-proof-whitepaper.pdf) enable a more efficient range proof than using generic zk-SNARK.
* [ZSL](https://github.com/jpmorganchase/quorum/wiki/ZSL) uses zk-SNARKS to enable private transfers of “z-tokens” using private and public smart-contracts.
* [EY Nightfall](https://github.com/EYBlockchain/nightfall) uses the ZoKrates toolkit to enable private ERC-20 and ERC-721 transactions.
* [Phantom](https://eprint.iacr.org/2020/156.pdf) is an improvement of ZSL and Nightfall, which uses Shrub Merkle trees, among other changes, to enable more efficient zkps on Ethereum.


### Other libraries that implement cryptographic primitives:
* [OpenZeppelin Cryptography](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/cryptography) includes an ECDSA- and a MerkleProof library.
* [solCrypto](https://github.com/HarryR/solcrypto) implements Schnorr proof of knowledge, AOS ring signatures, Linkable AOS ring signatures, Packed ECDSA signatures, Merkle tree proof, AOS ring signatures.
* [solGrined](https://github.com/18dew/solGrined) implements Pedersen Commitment.
* [solRsaVerify](https://github.com/adria0/SolRsaVerify) verifies RSA signatures.
* [Ether-Schnoor-Verification](https://github.com/DucaturFw/ether-schnorr-verification) implements Schnorr multi-signature verification.
* [elliptic-curve-solidity](https://github.com/witnet/elliptic-curve-solidity) supports the following operations: Modular: inverse, exponentiation. Jacobian: addition, double, multiplication. Affine: inverse, addition, subtraction, multiplication. Auxiliary: convert to affine, derive coordinate Y, point on curve
* [eth-random](https://github.com/axiomzen/eth-random) returns a "random" value by specifying which block in the future will be used for extracting this "random" value out of the hash.
