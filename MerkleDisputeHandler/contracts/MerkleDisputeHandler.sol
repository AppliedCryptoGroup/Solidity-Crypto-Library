// The MerkleDisputeHandler acts as an adjudicator for disputes about a Merkle
// tree proof.
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

import "./utils/ECDSA.sol";

/**
 * @title The MerkleDisputeHandler
 * @author Philipp-Florens Lehwalder
 * @dev An adjudicator for disputes about a Merkle Tree proof.
 */
abstract contract MerkleDisputeHandler {

  // This struct represents the dispute between two parties on a Merkle tree.
  struct MerkleDispute {
    // The required amount of collateral used for this dispute.
    uint collateral;
    // The time limit in seconds used for this dispute.
    uint timeLimit;
    // The submitted hash from the party with index = lastParty.
    bytes32 hashLastParty;
    // Will only be used to store the leaf hash from the other party that
    // differs between the two parties.
    bytes32 hashOtherParty;
    // The hash of the last node which the two parties agreed on. Is used for
    // the Merkle proof to proof that the predecessor preimage is correct.
    bytes32 lastCommonHash;
    // The hash of the first leaf, both parties have agreed on.
    bytes32 firstLeafHash;
    // The total height of the tree, starting at 1 = root.
    // The max. number of leaves/currentIndex = 2^256-1 -> max. height = 257 ->
    // 16 bits are sufficient.
    uint16 height;
    // The level of the current hash.
    uint16 currentLevel;
    // The level of the last common hash.
    uint16 lastCommonHashLevel;
    // The index of the current hash in the tree.
    uint currentIndex;
    // The index of the last hash on which the parties have agreed on.
    uint lastCommonHashIndex;
    // The timestamp of the last contract interaction from lastParty.
    // Used for the timeLimit.
    uint lastTimestamp;
    // The index of the last party that submitted its hash, 0 or 1, or 2 if no
    // one submitted its hash for the currentIndex yet.
    uint8 lastParty;
    // The dispute status meanings:
    // 0 -> This dispute is not registered yet.
    // 1 -> The first party (0) has registered this dispute.
    // 2 -> The second party (1) has registered this dispute.
    // 3 -> Both parties have registered the dispute and it's ready for
    //      initalization.
    // 4 -> The dispute has been successfully initialized. It is ready for
    //      submitting hashes and the deviating leaf has not been found yet.
    // 5 -> The deviating leaf has been found (the leaf that differs between
    //      the two parties). A party now needs to submit the preimage of the
    //      predecessor of this deviating leaf along with a Merkle proof.
    // 6 -> A party has submitted the correct preimage of the predecessor and
    //      the contract is ready to determine the guiltier.
    // 7 -> Special case where a party cheated by using a different first leaf
    //      than the one they initially agreed on. Is ready to determine the
    //      guiltier.
    uint8 disputeStatus;
    // The preimage from the predecessor leaf of the deviating leaf.
    bytes32 preimage;
  }

  // After both parties have registered the dispute, it can be initialized.
  event ReadyForInitialization(bytes32 disputeId);
  // The dispute is initialized and the parties can submit hashes.
  event ReadyForSubmitting(bytes32 disputeId);
  // Emits the new index of the leaf that the two parties should submit.
  event NewIndexToSubmit(bytes32 disputeId, uint index);
  // The contract has found the index of the leaf that differs between the two
  // parties (index + 1) and now needs the preimage of the predecessor of this
  // leaf to be able to determine the guiltier.
  event ReadyForRevealingPreimage(bytes32 disputeId, uint index);
   // After a party has submitted the correct preimage of the predecessor, the
   // contract is ready to determine the guiltier.
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
    * @notice This modifier checks if the time limit is exceeded and updates
    * the last timestamp if this is not the case.
    * @param otherParty The address of the other party in this dispute.
    */
  modifier withTimeLimit(address otherParty) {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    // Only check the time limit, if the dispute is registered.
    if (merkleDispute.disputeStatus > 0) {
      require(
        merkleDispute.lastTimestamp + merkleDispute.timeLimit
          >= block.timestamp,
        "The time limit is exceeded!"
      );
    }

    _;

    // If the disputeStatus changed to 0, it has been reseted.
    if (merkleDispute.disputeStatus > 0) {
      merkleDispute.lastTimestamp = block.timestamp;
    }
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
   * @notice Registers the dispute by depositing the default collateral.
   * After both parties have registered the dispute, it is ready for
   * initalization.
   * @param otherParty The address of the other party in this dispute.
   */
  function registerDispute(address otherParty)
    external
    payable
  {
    registerDispute(otherParty, defaultCollateral, defaultTimeLimit);
  }

  /**
   * @notice Initializes the dispute with the given parameters.
   * @dev The contract only supports leaves whose number is a power of 2.
   * @param otherParty The address of the other party in this dispute.
   * @param height The height of the Merkle tree, staring at 1 for the root.
   * @param firstLeafHash The hash of the first leaf of the Merkle tree.
   * @param rootCurrentParty The root hash from the current party.
   * @param rootOtherParty The root hash from the other party.
   * @param firstLeafSig The signature of the other party on the first leaf.
   * @param rootOtherPartySig The signature of the other party on the root hash.
   */
  function initDispute(
    address otherParty,
    uint16 height,
    bytes32 firstLeafHash,
    bytes32 rootCurrentParty,
    bytes32 rootOtherParty,
    bytes memory firstLeafSig,
    bytes memory rootOtherPartySig)
   external
   withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(
      merkleDispute.disputeStatus == 3,
      "The contract is not yet registered or has already been initialized."
    );
    require(height > 1, "The height of the tree must be greater than 1.");

    // Check the signatures from otherParty..
    require(
      ECDSA.recover(
        ECDSA.toEthSignedMessageHash(rootOtherParty),
        rootOtherPartySig
       )
        == otherParty,
      "The signature on the root hash from the other party is not valid."
    );
    require(
      ECDSA.recover(ECDSA.toEthSignedMessageHash(firstLeafHash), firstLeafSig)
        == otherParty,
      "The signature on the first leaf hash from the other party is not valid."
    );

    // If the root hashes are equal, both parties get their collateral back.
    if (rootCurrentParty == rootOtherParty) {
      emit DetermindedGuiltier(disputeId, 2);
      resetDispute(disputeId);
      balances[otherParty] += merkleDispute.collateral;
      balances[msg.sender] += merkleDispute.collateral;
    }

    merkleDispute.firstLeafHash = firstLeafHash;
    merkleDispute.height = height;
    merkleDispute.currentLevel = 2; // We directly go one level deeper..
    // ..to the first child of the root which both parties should submit.
    uint indexToSubmit = getChildIndex(
      2**uint(height) - 2,
      height,
      1
    );
    merkleDispute.currentIndex = indexToSubmit;
    merkleDispute.lastParty = 2;
    merkleDispute.disputeStatus = 4;

    emit NewIndexToSubmit(disputeId, indexToSubmit);
  }

  /**
   * @notice Submits a given node represented by its hash and index and sets
   * the new index to submit if both parties have submitted.
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

    require(
      merkleDispute.disputeStatus == 4,
      "Not ready for submitting hashes or deviating leaf already found!"
    );
    require(
      index == merkleDispute.currentIndex,
      "Element with wrong index submitted!"
    );

    uint8 currentParty = msg.sender < otherParty ? 0 : 1;

    require(currentParty != merkleDispute.lastParty,
      "You have already submitted your element!");

    // Both parties needed to submit their nodes.
    if (merkleDispute.lastParty == 2 ) {
      merkleDispute.hashLastParty = hash;
      merkleDispute.lastParty = currentParty;

    } else {
      bytes32 hashLastParty = merkleDispute.hashLastParty;
      uint16 height = merkleDispute.height;
      uint16 currentLevel = merkleDispute.currentLevel;

      // If the current node is a leaf and the hashes are different, the
      // desired leaf is found.
      if (isLeaf(index, height) && hash != hashLastParty) {
        // Need to save this hash for determining the guiltier.
          merkleDispute.hashOtherParty = hash;

          // A party cheated by using a different first leaf. Since the first
          // leaf does not  have a predecessor, the contract is ready to
          // determine the guiltier.
          if (index == 0) {
            merkleDispute.disputeStatus = 7;
            emit ReadyForDetermineGuiltier(disputeId);

          // Otherwise, the contract needs the preimage of the predecessor of
          // the deviating leaf.
          } else {
            merkleDispute.disputeStatus = 5;
            merkleDispute.currentIndex--;
            emit ReadyForRevealingPreimage(disputeId, index-1);
          }

      } else {
        // If it's a node and they're unequal, go to the first child.
        if (hash != hashLastParty) {
         merkleDispute.currentIndex = getChildIndex(
           index,
           height,
           currentLevel
         );
         merkleDispute.currentLevel++; // Go one level deeper.

         // If they are equal and it's the first sibling of two leaves, go to
         // the other leaf.
       } else if (index % 2 == 0 && isLeaf(index, height)) {
         merkleDispute.lastCommonHash = hash;
         merkleDispute.lastCommonHashIndex = index;
         merkleDispute.lastCommonHashLevel = currentLevel;
         merkleDispute.currentIndex++;

         // Otherwise, it is a node and we directly go to the child of the next
         // sibling.
       } else if (!isLeaf(index, height)) {
         merkleDispute.lastCommonHash = hash;
         merkleDispute.lastCommonHashIndex = index;
         merkleDispute.lastCommonHashLevel = currentLevel;
         merkleDispute.currentIndex = getChildIndex(
           index + 1,
           height,
           currentLevel
         );
         merkleDispute.currentLevel++; // Go one level deeper.

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
   * @notice After the deviating leaf has been found, a party need to
   * reveal the preimage of the predecessor of it, so the contract can
   * determine the guilty party by calculating the correct leaf.
   * @param otherParty The address of the other party in this dispute.
   * @param preimage The preimage of the required predecessor leaf.
   * @param merkleProof The Merkle proof for proofing that the last common hash
   * indeed contains this preimage.
   */
  function revealPreimage(
    address otherParty,
    bytes32 preimage,
    bytes32[] memory merkleProof)
   external
   withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];

    require(
      merkleDispute.disputeStatus == 5,
      "Not ready for receiving the preimage or it has already been submitted!"
    );

    require(
      merkleProof.length == merkleDispute.height -
        merkleDispute.lastCommonHashLevel,
      "Incorrect number of hashes for the Merkle proof!"
    );

    // Verify the Merkle proof while the first hash is the hashed preimage.
    bytes32 hashMp = keccak256(abi.encodePacked(preimage));

    for (uint16 i = 0; i < merkleProof.length; i++) {
      hashMp = keccak256(abi.encodePacked(merkleProof[i], hashMp));
    }

    require(hashMp == merkleDispute.lastCommonHash,
      "Merkle proof does not proof that the preimage is included!");

    merkleDispute.preimage = preimage;
    merkleDispute.disputeStatus = 6;
    emit ReadyForDetermineGuiltier(disputeId);
  }

  /**
   * @notice Determines which party cheated and which party calculated the
   * deviating leaf correctly.
   * Updates the balances of the two parties according to the judgement.
   * @param otherParty The address of the other party in this dispute.
   */
  function determineGuiltier(address otherParty)
    external
    withTimeLimit(otherParty)
  {
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    require(merkleDispute.disputeStatus >= 6,
      "Contract is not yet ready to determine the guiltier!");

    uint collateral = merkleDispute.collateral;
    uint8 lastParty = merkleDispute.lastParty;
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    // Setting it initially to 2 meaning that no party is guilty (both parties
    // miscalculated).
    uint8 guiltyParty = 2;

    bytes32 correctLeaf;

    // Even though both parties agreed on the first leaf, a party used a
    // different hash. So, we compare them to the saved first leaf hash.
    if (merkleDispute.disputeStatus == 7) {
      correctLeaf = merkleDispute.firstLeafHash;

    } else {
      // Calculate the correct leaf hash by making one step on its predecessor.
      correctLeaf = makeStep(merkleDispute.preimage);
    }

    // The party that last submitted its hash, is honest.
    if (merkleDispute.hashLastParty == correctLeaf) {
      guiltyParty = lastParty ^ 1;

      // The party that last submitted its hash, cheated.
    } else if (merkleDispute.hashOtherParty == correctLeaf) {
      guiltyParty = lastParty;
    }

    resetDispute(disputeId);

    // In a tie situation, both parties can withdraw the collateral.
    if (guiltyParty == 2) {
      balances[otherParty] += collateral;
      balances[msg.sender] += collateral;

    } else if (guiltyParty == currentParty) {
      balances[otherParty] += collateral * 2;

    } else {
      balances[msg.sender] += collateral * 2;
    }

    emit DetermindedGuiltier(disputeId, guiltyParty);
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
    uint8 disputeStatus = merkleDispute.disputeStatus;
    require(
      disputeStatus > 0,
      "This dispute has not been registered yet!"
    );
    require(
      merkleDispute.lastTimestamp + merkleDispute.timeLimit < block.timestamp,
      "The time limit is not exceeded yet!"
    );


    uint collateral = merkleDispute.collateral;
    uint8 lastParty = merkleDispute.lastParty;
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;
    // The index of the party that did not answer in time or 2 if both failed
    // to do so.
    uint8 guiltyParty;
    // The address of the honest party that gets the compensation.
    address honestParty;


    // Only the first party registered the dispute.
    if (disputeStatus == 1) {
      guiltyParty = 1;

      // Only the second party registered the dispute.
    } else if (disputeStatus == 2) {
      guiltyParty = 0;

      // Both parties registered the dispute, but no one initialized it in time.
      // Or no party revealed the preimage of the predecessor in time.
      // Or no one called the function determineGuiltier in time.
    } else if (
      disputeStatus == 3 ||
      disputeStatus == 5 ||
      disputeStatus == 6)
    {
      guiltyParty = 2;

    } else if (disputeStatus == 4) {

      // None of the two parties has submitted the required hash in time.
      if (lastParty == 2) {
        guiltyParty = 2;

      } else { // Only lastParty has submitted the required hash in time.
        guiltyParty = lastParty ^ 1;
      }

    } else {
      revert("Unknown dispute status!");
    }


    if (guiltyParty == 2) { // Both parties get their collateral back.
      balances[otherParty] += collateral;
      balances[msg.sender] += collateral;

    } else { // Only the honest party gets the compensation.
      honestParty = (guiltyParty ^ 1) == currentParty ? msg.sender : otherParty;

      // Only if both parties registered the dispute, the honest party can get
      // the collateral from both parties.
      if (disputeStatus > 2) {
        balances[honestParty] += collateral * 2;

      } else { // Otherwise, the party can only get its own collateral back.
        balances[honestParty] += collateral;
      }

    }

    emit DetermindedGuiltier(disputeId, guiltyParty);

    resetDispute(disputeId);
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
   * @notice Returns the current dispute status.
   * @param disputeId The identifier of this dispute.
   * @return The current dispute status.
   */
  function getDisputeStatus(bytes32 disputeId) external view returns (uint8) {
    return merkleDisputes[disputeId].disputeStatus;
  }

  /**
   * @notice Returns if the contract has found the index of the leaf that differs
   * from the two parties.
   * @param disputeId The identifier of this dispute.
   * @return True, if the contract has found the index of the leaf that differs
   * from the two parties, otherwise false.
   */
  function leafIsFound(bytes32 disputeId) external view returns (bool) {
    return merkleDisputes[disputeId].disputeStatus >= 5;
  }

  /**
   * @notice Returns the indexes of the nodes that are required for the Merkle
   * proof for revealing the predecessor preimage.
   * @param disputeId The identifier of this dispute.
   * @return The required indexes of the nodes for the Merkle proof.
   */
  function getMerkleProofIndexes(bytes32 disputeId)
    external
    view
    returns (uint[] memory) {
      MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
      require(merkleDispute.disputeStatus == 5,
        "Deviating leaf has not been found or preimage already submitted!");

      uint16 height = merkleDispute.height;
      uint16 currentlevel = merkleDispute.lastCommonHashLevel;
      uint16 numHashes = height - merkleDispute.lastCommonHashLevel;
      uint[] memory mpIndexes = new uint[](numHashes);

      if (numHashes == 0) { // Only the preimage is sufficient.
        return mpIndexes;
      }

      // Add the indexes for the Merkle proof.
      mpIndexes[numHashes-1] = getChildIndex(
        merkleDispute.lastCommonHashIndex,
        height,
        currentlevel++);
      numHashes--;

      while (numHashes > 0) {
        mpIndexes[numHashes-1] = getChildIndex(
          mpIndexes[numHashes] + 1,
          height,
          currentlevel++);
        numHashes--;
      }

      return mpIndexes;
    }

  /**
   * @notice Registers the dispute by depositing a custom collateral.
   * After both parties have registered the dispute with the same values for
   * the collateral and time limit, it is ready for initalization.
   * @param collateral The value for the collateral that should be used.
   * @param timeLimit How many seconds should be used for the time limit.
   */
  function registerDispute(address otherParty, uint collateral, uint timeLimit)
    public
    payable
    withTimeLimit(otherParty)
  {
    require(
      msg.sender != otherParty,
      "The Address of the other party must not be equal to your address."
    );
    require(
      msg.value >= collateral,
      "Please transfer the required collateral with your commit!"
    );
    bytes32 disputeId = getDisputeId(otherParty);
    MerkleDispute storage merkleDispute = merkleDisputes[disputeId];
    // Is zero if the sender's address is lower as the otherParty's address or
    // 1, otherwise.
    uint8 currentParty = msg.sender < otherParty ? 0 : 1;

    // Allowed state transitions of disputeStatus: 0 -r0-> 1 -r1-> 3 and
    // 0 -r1-> 2 -r0-> 3. With ri meaning the registration of party i.
    require(
      merkleDispute.disputeStatus < 3,
      "The dispute has already been registered!"
    );

    // No party has registered the dispute yet.
    if (merkleDispute.disputeStatus == 0) {
      // Changing from 0 -r0-> 1 or 0 -r1-> 2.
      merkleDispute.disputeStatus += currentParty + 1;
      merkleDispute.collateral = collateral;
      merkleDispute.timeLimit = timeLimit;

    } else {
      uint8 partyToRegister = merkleDispute.disputeStatus == 1 ? 1 : 0;
      require(
        currentParty == partyToRegister,
        "You have already registered this dispute!"
      );
      require(
        merkleDispute.collateral == collateral,
        "Both parties need to choose the same collateral!"
      );
      require(
        merkleDispute.timeLimit == timeLimit,
        "Both parties need to choose the same time limit!"
      );

      merkleDispute.disputeStatus = 3;
      emit ReadyForInitialization(disputeId);
    }

    // Send back the change if the party sent too much funds as a collateral.
    if (msg.value > collateral) {
        msg.sender.transfer(msg.value - collateral);
      }
  }

  /**
   * @notice Returns the MerkleDispute identifier from the sender with the given
   * address of the other party.
   * @param otherParty The address of the other party in this dispute.
   * @return The MerkleDispute identifier from the sender with the given
   * address of the other party.
   */
  function getDisputeId(address otherParty) public view returns (bytes32) {
    return msg.sender < otherParty ?
      keccak256(abi.encodePacked(msg.sender, otherParty)) :
      keccak256(abi.encodePacked(otherParty, msg.sender));
  }

  /**
   * @notice Resets the dispute to the default type values.
   * @param disputeId The id for the dispute to reset.
   */
  function resetDispute(bytes32 disputeId) internal {
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
      0,
      0,
      0,
      0,
      0
    );
  }

  /**
   * @notice Computes the next leaf by calculating one step from the given leaf
   * preimage on. This application specific computation needs to be implemented
   * by the inheriting contract.
   * @param leafPreimage The preimage of the leaf that should be used.
   * @return The leaf that follows from the given one.
   * leaf preimage on.
   */
  function makeStep(bytes32 leafPreimage)
    virtual
    internal
    pure
    returns (bytes32)
  {

  }

/**
 * @notice Returns the index of the first child which is represented by the
 * given parameters.
 * @param index The index of the current node in the Merkle tree.
 * @param height The height of the Merkle tree, starting at 1 for the root.
 * @param currentLevel The level of the current node.
 * @return The index of the first child of the given node.
 */
  function getChildIndex(uint index, uint height, uint currentLevel)
    internal
    pure
    returns (uint)
  {
    // Initialized with the root index.
    uint firstIndexOnLevel = 2**height - 2;
    for (uint i = 1; i < currentLevel; i++) {
      // Go lower to currentLevel step by step.
      firstIndexOnLevel = firstIndexOnLevel - 2**i;
    }
    return index - 2**currentLevel + index - firstIndexOnLevel;
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
