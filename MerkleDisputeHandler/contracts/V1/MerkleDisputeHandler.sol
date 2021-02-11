// This file is part of the MerkleDisputeHandler.
// Copyright (C) 2020 Chair of Applied Cryptography, Technische Universität
// Darmstadt, Germany.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>

pragma solidity ^0.7.0;

/**
 * @title The MerkleDisputeHandler
 * @author Philipp-Florens Lehwalder
 * @dev An adjudicator for disputes about a Merkle tree proof.
 */
abstract contract MerkleDisputeHandler {

  // This struct represents the dispute between two parties on a Merkle tree.
  struct MerkleDispute {
    // The required amount of collateral used for this dispute.
    uint collateral;
    // The time limit in seconds used for this dispute.
    uint timeLimit;
    // The current hash to be compared.
    bytes32 hash;
    // Will only be used to store the first leaf's hash from the other party
    // that differs between the two parties.
    bytes32 hashOtherParty;
    // The total height of the tree, starting at 1 = root.
    // The max. number of leaves/currentIndex = 2^256-1 -> max. height = 257 ->
    // 16 bits are sufficient.
    uint16 height;
    // The height of the current hash.
    uint16 currentHeight;
    // The index of the hash in the tree.
    uint currentIndex;
    // The index of the last party that submitted its hash, 0 or 1, or 2 if no
    // one submitted its hash for the currentIndex yet.
    uint8 lastParty;
    // The timestamp of the last contract interaction from lastParty.
    // Used for the timeLimit.
    uint lastTimestamp;
    // The dispute status meanings:
    // 0 -> Deviating leaf has not yet been found (the leaf that differs from
    //       the two parties).
    // 1 -> Deviating leaf has been found.
    // 2 -> The first party (0) has revealed its commit of the first leaf.
    // 3 -> The second party (1) has revealed its commit of the first leaf.
    // 4 -> Both parties have revealed their commits and the contract is ready
    //       to determine the guiltier.
    uint8 disputeStatus;
    // The commits of the two parties for the first leaf. Will be set to the
    // actual first leaf when the parties reval their first leaf.
    bytes32[2] commits;
  }

  // After both parties have commited their first leaf, submitHash can be called.
  event ReadyForSubmitting(bytes32 disputeId);
  // Emits the new index of the leaf that the two parties should submit.
  event NewIndexToSubmit(bytes32 disputeId, uint index);
  // Emits the index of the leaf that differs from the two parties.
  event FoundDeviatingLeafIndex(bytes32 disputeId, uint index);
   // After the deviating leaf has been found and both parties revealed their
   // commits, the contract is ready to determine the guiltier.
  event ReadyForDetermineGuiltier(bytes32 disputeId);
  // The contract has determined the guiltier with partyIndex = 0 or 1, or 2 if
  // it could not determine the guiltier.
  event DetermindedGuiltier(bytes32 disputeId, uint8 partyIndex);


  // The MerkleDispute struct for two parties, who are identified by the hash
  // of their sorted concatenated addresses.
  mapping (bytes32 => MerkleDispute) merkleDisputes;

  // The balances of addresses involed in disputes.
  mapping (address => uint) balances;

  // The default collateral each party has to submit before the contract will
  // begin to solve the dispute.
  uint public defaultCollateral;
  // The default time limit in seconds each party has to reply after a previous
  // interaction with the adjudicator. If a party does not reply in time, it
  // looses its collateral to the honest party, if both did not answer, both
  // get their collateral back. WARNING: Please don't use a too low timeLimit
  // since miners have some influence on choosing the timestamp.
  uint public defaultTimeLimit;



  /**
    * @notice This modifier checks if the time limit is exceeded and updates the
    * last timestamp if this is not the case.
    * @param otherParty The address of the other party in this dispute.
    */
  modifier withTimeLimit(address otherParty) {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(merkleDispute.height > 0,
       "This dispute has not been registered yet!");
    require(
      merkleDispute.lastTimestamp + merkleDispute.timeLimit >= block.timestamp,
       "The time limit is exceeded!");
    _;
    merkleDispute.lastTimestamp = block.timestamp;
  }

  /**
   * @notice The constructor which sets the collateral and the timeLimit.
   * @dev Do not use a time limit that is too short, since a miner has some
   * tolerated influence on setting the timestamp of a block.
   * @param collateral The collateral each party has to submit before the
   * contract will begin so solve the dispute.
   * @param timeLimit The maximum time in seconds each party has to reply
   * before the other party can withdraw the collateral of the dispute.
   */
  constructor(uint collateral, uint timeLimit) {
    defaultCollateral = collateral;
    defaultTimeLimit = timeLimit;
  }

  /**
   * @notice Registers a new dispute with the default collateral and time limit.
   * @dev The contract only supports leaves whose number is a power of 2.
   * @param otherParty The address of the other party in this dispute.
   * @param rootHash The hash of the Merkle root.
   * @param height The height of the Merkle tree, staring at 1 for the root.
   */
  function registerDispute(address otherParty, bytes32 rootHash, uint16 height)
   external
  {
    createMerkleDispute(
      otherParty,
      rootHash,
      height,
      defaultCollateral,
      defaultTimeLimit
    );
  }

  /**
   * @notice Registers a new dispute with a custom collateral and time limit.
   * @dev The contract only supports leaves whose number is a power of 2.
   * @param otherParty The address of the other party in this dispute.
   * @param rootHash The hash of the Merkle root.
   * @param height The height of the Merkle tree, staring at 1 for the root.
   * @param collateral The value for the collateral that should be used.
   * @param timeLimit How many seconds should be used for the time limit.
   */
  function registerDispute(
    address otherParty,
    bytes32 rootHash,
    uint16 height,
    uint collateral,
    uint timeLimit)
   external
  {
    createMerkleDispute(
      otherParty,
      rootHash,
      height,
      collateral,
      timeLimit
    );
  }

  /**
   * @notice Commits the first leaf of a Merkle tree, which is required before the
   * actual dispute settlement.
   * Requires to send the specified collateral with it, which the honest party
   * will receive or both in an tie situation.
   * @param otherParty The address of the other party in this dispute.
   * @param commit The commit of the first leaf with a random nonce.
   */
  function commitFirstLeaf(address otherParty, bytes32 commit)
    external
    payable
    withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(merkleDispute.commits[currentParty] == 0,
       "You have already commited your first leaf!");
    uint collateral = merkleDispute.collateral;
    require(msg.value >= collateral,
      "Please transfer the required collateral with your commit!");
    // Prevents that a party just commits the same hash as the other party
    // after seeing it on the blockchain.
    require(merkleDispute.commits[currentParty ^ 1] != commit,
      "Please choose a different nonce!");
    merkleDispute.commits[currentParty] = commit;
    // It is not necessary to set lastParty since the contract will use the
    // commits to determine who commited and who didn't.

    if (merkleDispute.commits[0] & merkleDispute.commits[1] != 0) {
      emit ReadyForSubmitting(disputeId);
    }

    // Send back the change if the party sent too much funds as a collateral.
    if (msg.value > collateral) {
        msg.sender.transfer(msg.value - collateral);
      }
  }

  /**
   * @notice Is used for revealing the commits of the first leaf after the
   * contract has found the deviating leaf.
   * Then, the contract is able to determine who cheated by calculating the
   * deviating leaf own its own.
   * @param otherParty The address of the other party in this dispute.
   * @param firstLeaf The hash of the first leaf in the Merkle tree.
   * @param nonce A random nonce which was appended to the leaf hash before
   * hashing it.
   */
  function revealFirstLeaf(address otherParty, bytes32 firstLeaf, bytes32 nonce)
    external
    withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];

    // Allowed state transitions of disputeStatus: 1 -r0-> 2 -r1-> 4 and
    // 1 -r1-> 3 -r0-> 4. With ri meaning the reveal of party i.
    require(merkleDispute.disputeStatus >= 1,
      "The deviating leaf has not been found yet!");
    require(merkleDispute.disputeStatus < 4,
      "Both parties have realved their commits already!");

    if (merkleDispute.disputeStatus == 1) {
      // 1 -> 2 or 1 -> 3 depending on currentParty.
      merkleDispute.disputeStatus += currentParty + 1;

    } else {
      uint8 partyToReveal = merkleDispute.disputeStatus == 2 ? 1 : 0;
      require(currentParty == partyToReveal,
        "You have already revealed your commit!");
      merkleDispute.disputeStatus = 4;
      emit ReadyForDetermineGuiltier(disputeId);
    }
    // Check if the hash of the first leaf with the appended nonce equals to
    // the previously saved commit.
    require(
      keccak256(abi.encodePacked(firstLeaf, nonce)) ==
        merkleDispute.commits[currentParty],
    "Invalid opening of commit!"
    );

    merkleDispute.commits[currentParty] = firstLeaf;
  }

  /**
   * @notice Submits a given node represented by its hash and index and sets the
   * new index to submit if both parties have submitted.
   * @param otherParty The address of the other party in this dispute.
   * @param hash The hash of the node with the given index.
   * @param index The index of the current node in the Merkle tree.
   */
  function submitHash(address otherParty, bytes32 hash, uint index)
    external
    withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(merkleDispute.commits[0] & merkleDispute.commits[1] != 0,
      "At least one party has not commited its first leaf yet!");
    require(merkleDispute.disputeStatus == 0, "Deviating leaf already found!");
    require(index == merkleDispute.currentIndex,
      "Element with wrong index submitted!");
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    require(currentParty != merkleDispute.lastParty,
      "You have already submitted your element!");

    // Both parties needed to submit their nodes.
    if (merkleDispute.lastParty == 2 ) {
      merkleDispute.hash = hash;
      merkleDispute.lastParty = currentParty;

    } else {
      bytes32 hashOtherParty = merkleDispute.hash;
      uint height = merkleDispute.height;

      // If the current node is a leaf and the hashes are different, the
      // desired leaf is found.
      if (isLeaf(index, height) && hash != hashOtherParty) {
        // Need to save this hash for determining the guiltier.
          merkleDispute.hashOtherParty = hash;
          emit FoundDeviatingLeafIndex(disputeId, index);
          merkleDispute.disputeStatus = 1;

      } else {
        // If it's a node and their unequal, go to the first ancestor.
        if (hash != hashOtherParty) {
         merkleDispute.currentIndex = getAncestorIndex(
           index,
           height,
           merkleDispute.currentHeight
         );
         merkleDispute.currentHeight++; // Go one level deeper.

         // If they are equal and it's the root.
       } else if (index == 2**height - 2) {
         revert("Root hashes are equal!");

         // If they are equal and it's the first sibling, go to the other one.
       } else if (index % 2 == 0) {
         merkleDispute.currentIndex++;

         // If none of those cases applied, the parent node has to be
         // calculated incorrectly.
       } else {
         revert("Parent node has been calculated incorrectly!");
       }

       // Since a new index to submit is set, both parties need to submit their
       // corresponding nodes.
       merkleDispute.lastParty = 2;
       emit NewIndexToSubmit(disputeId, merkleDispute.currentIndex);
      }
    }
  }


  /**
   * @notice Determines which party cheated and which party calculated the leaf
   * correctly.
   * Updates the balances of the two parties according to the judgement.
   * @param otherParty The address of the other party in this dispute.
   */
  function determineGuiltier(address otherParty)
    external
    withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(merkleDispute.disputeStatus == 4,
      "Contract is not yet ready to determine the guiltier!");

    uint collateral = merkleDispute.collateral;
    uint8 lastParty = merkleDispute.lastParty;
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    // Setting it initially to 2 meaning that no party is guilty.
    uint8 guiltyParty = 2;

    // If the hashes of the leaf nodes aren't equal, the contract can't
    // determine who is right.
    if (merkleDispute.commits[0] == merkleDispute.commits[1]) {
      // Calculate the correct hash of the deviating leaf by starting from the
      // first one.
      bytes32 correctLeaf = makeSteps(
        merkleDispute.commits[0],
        merkleDispute.currentIndex
      );

      // The party that last submitted its hash, is honest.
      if (merkleDispute.hash == correctLeaf) {
        guiltyParty = lastParty ^ 1;
        emit DetermindedGuiltier(disputeId, lastParty ^ 1);

        // The party that last submitted its hash, cheated.
      } else if (merkleDispute.hashOtherParty == correctLeaf) {
        guiltyParty = lastParty;
        emit DetermindedGuiltier(disputeId, lastParty);

        // Both parties miscalculated/cheated.
      } else {
        emit DetermindedGuiltier(disputeId, 2);
      }
    }

    // Reset the dispute.
    merkleDisputes[disputeId] = MerkleDispute(
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      [bytes32(0), 0]
    );

    // In a tie situation, both parties can withdraw the collateral.
    if (guiltyParty == 2) {
      balances[msg.sender] += collateral;
      balances[otherParty] += collateral;

    } else if (guiltyParty == currentParty) {
      balances[otherParty] += collateral * 2;

    } else {
      balances[msg.sender] += collateral * 2;
    }
  }

  /**
   * @notice Sends the whole balance of the sender back to the sender.
   */
  function withdrawFunds() external {
    uint funds = balances[msg.sender];
    balances[msg.sender] = 0;
    msg.sender.transfer(funds);
  }


  /**
   * @notice Can be called if the time limit of a dispute is exceeded.
   * The party, that did not answer in time, will loose its collateral to the
   * honest party.
   * Or both get their collaterals back, if both did not answer in time.
   * @param otherParty The address of the other party in this dispute.
   */
  function reportExceededTimeLimit(address otherParty) external {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(merkleDispute.height > 0,
       "This dispute has not been registered yet!");
    require(merkleDispute.lastTimestamp + merkleDispute.timeLimit < block.timestamp,
      "The time limit is not exceeded yet!");

    uint collateral = merkleDispute.collateral;
    uint8 lastParty = merkleDispute.lastParty;
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    // The index of the party that did not answer in time or 2 if both failed
    // to do so.
    uint8 guiltyParty;
    // The address of the honest party that gets the compensation.
    address honestParty;


    if (merkleDispute.disputeStatus == 0) {
      // Both parties have not commited their first leaf.
      if (merkleDispute.commits[0] & merkleDispute.commits[1] == 0) {
        guiltyParty = 2;

        // The first party has not commited.
      } else if (merkleDispute.commits[0] == 0) {
        guiltyParty = 0;

        // The second party has not commited.
      } else if (merkleDispute.commits[1] == 0) {
        guiltyParty = 1;

        // Both parties have commited their leaves and are in the process of
        // submitting hashes.
      } else {

        // None of the two parties has commited the required hash in time.
        if (lastParty == 2) {
          guiltyParty = 2;

        } else { // Only lastParty has commited the required hash in time.
          guiltyParty = lastParty ^ 1;
        }
      }

      // None of the two parties have revealed their commits in time.
    } else if (merkleDispute.disputeStatus == 1) {
      guiltyParty = 2;

      // Only the first party has revealed its commit.
    } else if (merkleDispute.disputeStatus == 2) {
      guiltyParty = 1;

      // Only the second party has revealed its commit.
    } else if (merkleDispute.disputeStatus == 3) {
      guiltyParty = 0;

      // Both parties revealed their commits but no one called determineGuiltier.
    } else if (merkleDispute.disputeStatus == 4) {
      guiltyParty = 2;

    } else {
      revert("Unknown dispute status!");
    }

    if (guiltyParty == 2) { // Both parties get their collateral back.

      // If any of the commits would be zero, then none of them has deposited
      // the collateral.
      if (merkleDispute.commits[0] & merkleDispute.commits[1] != 0) {
        balances[otherParty] += collateral;
        balances[msg.sender] += collateral;
      }

    } else { // Only the honest party gets the compensation.
      honestParty = (guiltyParty ^ 1) == currentParty ? msg.sender : otherParty;

      // Only if both parties commited, the honest party can get the collateral
      // of both.
      if (merkleDispute.commits[0] & merkleDispute.commits[1] != 0) {
        balances[honestParty] += collateral * 2;
      } else { // Otherwise, the party can only get its own collateral back.
        balances[honestParty] += collateral;
      }

    }

    emit DetermindedGuiltier(disputeId, guiltyParty);
    // Reset the dispute.
    merkleDisputes[disputeId] = MerkleDispute(
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      [bytes32(0), 0]
    );
  }

  /**
   * @notice Returns the index of the other party in this dispute.
   * @param otherParty The address of the other party in this dispute.
   * @return The index of the other party in this dispute.
   */
    function getOwnPartyIndex(address otherParty) external view returns (uint8) {
        return msg.sender < otherParty ? 0 : 1;
      }

  /**
   * @notice Returns the index of the party that needs to submit its node.
   * @param disputeId The identifier of this dispute.
   * @return The index of the party that needs to submit its node or 2 if both
   * parties need to submit their nodes.
   */
    function partyToSubmit(bytes32 disputeId) external view returns (uint8) {
      MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
      // If lastParty = 0 -> returns 0, if lastParty = 1 -> returns 1
      return merkleDispute.lastParty > 1 ? 2 : merkleDispute.lastParty ^ 1;
    }


  /**
   * @notice Returns the index of the node which needs to be submitted by the
   * parties.
   * @param disputeId The identifier of this dispute.
   * @return The index of the node which needs to be submitted by the parties.
   */
  function getIndexToSubmit(bytes32 disputeId) external view returns (uint) {
    return merkleDisputes[disputeId].currentIndex;
  }

  /**
   * @notice Returns the deadline for the next interaction with the adjudicator.
   * Depending on the current state, either one party or both parties need
   * to commit, reveal, submit a hash or need to call determineGuiltier before
   * the deadline.
   * @param disputeId The identifier of this dispute.
   * @return The deadline for the next required interaction with the contract.
   */
  function getDeadline(bytes32 disputeId) external view returns (uint) {
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    return merkleDispute.lastTimestamp + merkleDispute.timeLimit;
  }

  /**
   * @notice Returns the required collateral used for this dispute.
   * @param disputeId The identifier of this dispute.
   * @return The amount of collateral used for this commit.
   */
  function getCollateral(bytes32 disputeId) external view returns (uint) {
    return merkleDisputes[disputeId].collateral;
  }

  /**
   * @notice Returns if the contract has found the index of the leaf that differs
   * from the two parties.
   * @param disputeId The identifier of this dispute.
   * @return True, if the contract has found the index of the leaf that differs
   * from the two parties, otherwise false.
   */
  function leafIsFound(bytes32 disputeId) external view returns (bool) {
    return merkleDisputes[disputeId].disputeStatus >= 1;
  }

  /**
   * @notice Returns the MerkleDispute identifier from the sender with the given
   * address of the other party.
   * @param otherParty The address of the other party in this dispute.
   * @return The MerkleDispute identifier from the sender with the given
   * address of the other party.
   */
  function getDisputeId(address otherParty) public view returns (bytes32) {
    // The dispute Id is the hash of the concatenated addresses involved in the
    // dispute. The address that has the smaller value is first.
    return msg.sender < otherParty ?
      keccak256(abi.encodePacked(msg.sender, otherParty)) :
      keccak256(abi.encodePacked(otherParty, msg.sender));
  }

  /**
   * @notice Creates a new MerkleDispute element in merkleDisputes.
   * @param otherParty The address of the other party in this dispute.
   * @param rootHash The hash of the Merkle root.
   * @param height The height of the Merkle tree, staring at 1 for the root.
   * @param collateral The custom value for the collateral that should be
   * used for this dispute.
   * @param timeLimit The custom value for the time limit that should be
   * used for this dispute.
   */
  function createMerkleDispute(
    address otherParty,
    bytes32 rootHash,
    uint16 height,
    uint collateral,
    uint timeLimit)
   internal
  {
    require(height > 0, "The height of the tree must be bigger than 0.");
    require(msg.sender != otherParty,
       "Address of other party must not be equal to your address.");

    // Is zero if the sender's address is lower as the otherParty's address or
    // 1, otherwise.
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    bytes32 disputeId = getDisputeId(otherParty);

    // Check if this dispute has already been registered.
    if (merkleDisputes[disputeId].height > 0) {
      revert("This dispute has already been registered!");
    }

    merkleDisputes[disputeId] = MerkleDispute(
      collateral,
      timeLimit,
      rootHash,
       0,
       height,
       1,
       2**uint(height) - 2,
       currentParty,
       block.timestamp,
       0,
       [bytes32(0), 0]
     );
  }

  /**
   * @notice Computes the given number of steps on the first leaf.
   * This application specific computation needs to be implemented by the
   * inheriting contract.
   * @param firstLeaf The first leaf of the tree.
   * @param steps The number of steps it should compute.
   * @return The result of computing the given amount of steps from firstLeaf on.
   */
  function makeSteps(bytes32 firstLeaf, uint steps)
    virtual
    internal
    pure
    returns (bytes32)
  {

  }

/**
 * @notice Returns the index of the ancestor which is represented by the given
 * parameters.
 * @param index The index of the current node in the Merkle tree.
 * @param height The height of the Merkle tree, staring at 1 for the root.
 * @param currentHeight The height of the current node.
 * @return The index of the first ancestor of the given node.
 */
  function getAncestorIndex(uint index, uint height, uint currentHeight)
    internal
    pure
    returns (uint)
  {
    uint firstNodeOnLevel = 2**height - 2; // Initialized with the root index.
    for (uint i = 1; i < currentHeight; i++) {
      // Go lower to currentHeight step by step.
      firstNodeOnLevel = firstNodeOnLevel - 2**i;
    }
    return index - 2**currentHeight + index - firstNodeOnLevel;
  }


/**
 * @notice Returns true or false if the current node is a leaf or not.
 * @param index The index of the current node in the Merkle tree.
 * @param height The height of the Merkle tree, staring at 1 for the root.
 * @return true if the current node is a leaf and false, otherwise.
 */
  function isLeaf(uint index, uint height) internal pure returns (bool) {
    if (height == 1) {
      return true;
    } else {
      uint maxLeafIndex = 2**(height - 1) - 1;
      return index >= 0 && index <= maxLeafIndex;
    }
  }

}
