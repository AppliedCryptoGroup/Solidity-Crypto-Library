# Merkle Dispute Handler
This contract acts as an adjudicator for disputes about a Merkle tree proof, where two parties have different root hashes caused by a party miscalculated a leaf. \
The Merkle Dispute Handler is then able to find the index of that deviating leaf and to determine who cheated.


# Usage

### 1. Setup

#### 1.1 Create a Merkle tree
First of all, you can create a Merkle tree by using `createMerkleTree` from _MerkleTree.js_, please note that the contract currently **only supports  leaves whose number is a power of 2.**
If the number of leaves isn't a power of 2, please extend them with leaves with value 0 until it is.

#### 1.2 Inheriting the contract
Since the _MerkleDisputeHandler.sol_ contract is abstract, you have to create a contract that inherits from it and implements the `makeStep` method depending on your use case.
Additionally, the constructor expects a value for the collateral and the time limit. For an example, you can see _ExampleAdjuticator.sol_.

### 2. Initialization phase

#### 2.1 Registering the dispute
To register the dispute, both parties need to call `registerDispute` by depositing a collateral and providing the address of the other party. They can use the default collateral and time-limit or provide custom values as parameters. \
Note that it is always necessary to provide the address of the other party for all different phases of dispute-interactions with the contract for the identification of the current party and of the dispute. To get general information about the dispute, e.g., which party needs to submit a hash, the disputeId is sufficient, which you can get by calling `getDisputeId`.


#### 2.2 Initializing the dispute
Note that the time limit is active immediately after registration, so any of the parties need to initialize the dispute in time. To do so, a party has to send its root hash, the first leaf hash and signatures of both to the other party. This party can then call `initDispute` with the tree height, which starts at 1 for the root, the first leaf on which they agreed on, the root hash from the other party and of himself, and both signatures from the other party.

### 3. Submit phase

#### 3.1 Submitting nodes
Then, the two parties need to alternately submit the hash of their tree with the required index using `submitHash`. \
By calling `partyToSubmit` the contract returns the index of the party that has to submit its hash, and with `indexToSubmit` the index of the hash to submit. \
To figure out which index you have in this dispute, you can call `getOwnPartyIndex`. \
The contract will emit events for every new index to submit and an event if it found the index of the different leaf.

### 4. Guilty verdict
To check if the deviating leaf has been found, you can call the method `leafIsFound`.

#### 4.1 Reveal phase
Before the contract is then able to determine the guiltier (the party that miscalculated this leaf), one of the two parties needs to reveal the preimage of the predecessor of the deviating leaf; the method `getIndexToSubmit` will return the index of this predecessor. To do so, a party needs to call the method `revealPreimage` with the preimage and a Merkle proof which proofs that this preimage is correct or rather is included in the last common hash of the two parties. The indexes for the required hashes for the Merkle proof can be obtained by calling `getMerkleProofIndexes`, where the first element is the index of the left sibling of the predecessor. If the last common hash is the predecessor, the Merkle proof is just an empty list.

#### 4.2 Determining the guiltier
Finally, any of the two parties can call `determineGuiltier`; the contract will then emit an event to tell which party has cheated, increase the balance of the honest party, and reset this dispute. \
However, if any of the parties or both did not interact with the contract in any of the different phases (including this one) before the deadline, the method `reportExceededTimeLimit` should be called.
The contract will then determine who did not respond in time and, depending on the current state, update the balances accordingly. \
To check the current deadline, which corresponds to the timestamp of the last interaction plus the time limit, you can use the method `getDeadline`.

#### 4.3 Withdrawal
For every account, that interacted with the adjudicator, the total balance, resulting of finished disputes, is saved and can be withdrawn by calling `withdrawFunds`. \
During the finalization of a dispute, the balance of the honest party will be increased by the doubled amount of the collateral (the own collateral and the one from the other party). If the contract could not determine who cheated or both parties did not respond before the time limit, both parties get their collateral back.

# Testing

We use [Truffle](https://truffleframework.com/) for testing.

```
$ truffle test

Compiling your contracts...
===========================
> Compiling .\contracts\ExampleAdjucator.sol
> Compiling .\contracts\MerkleDisputeHandler.sol
> Compiling .\contracts\Migrations.sol
> Compiling .\contracts\V1\MerkleDisputeHandler.sol
> Compiling .\contracts\utils\AccessRestriction.sol
> Compiling .\contracts\utils\ECDSA.sol

Contract: MerkleDisputeHandler
  √ Finds the index of the deviating leaf of two parties (3972ms)
  √ Determines the guilty party correctly (316ms)
  Total gas used for 2048 leaves: 1629939 resulting in 0.0032598780000000003 ETH.
  √ The honest party can withdraw the compensation (162ms)
  √ Determines a cheating party (1039ms)
  √ The non-responding party is convicted (4623ms)


5 passing (10s)
```

# TODO

- [x] Add a JS function for creating Merkle trees
- [x] Add testing
- [x] Implement the functionality of checking which party cheated
- [x] Send back change if a party sent more money as a collateral as required
- [x] Implement the time-limit feature
- [x] Adapt code according to the style guide
- [x] Requires a Merkle proof for revealing the predecessor preimage
- [ ] Support for a number of leaves that isn't a power of two?
