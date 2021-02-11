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

import "./utils/AccessRestriction.sol";
import "./MerkleDisputeHandler.sol";

contract ExampleAdjucator is AccessRestriction, MerkleDisputeHandler(1 * 1e17, 3600) {


  function makeStep(bytes32 leafPreimage)
    override
    internal
    pure
    returns (bytes32) {

    // The nonce correponds to the first 31 bytes of a leaf.
    bytes31 nonce = bytes31(leafPreimage);
    // The counter correponds to the last byte of a leaf.
    uint8 counter = uint8(leafPreimage[31]);

    // The new state is the hash of the old one.
    nonce = bytes31(keccak256(abi.encodePacked(nonce)));

    // If the new nonce is divisible by 2, we increase the counter and
    // decrease it, otherwise. We allow a possible overflow/underflow.
    counter = uint248(nonce) % 2 == 0 ? counter + 1 : counter - 1;

    // The new state is the new nonce with the new counter. We use the left
    // shift on the counter to set it as the the last byte of the new state.
    bytes32 state = nonce | bytes32(bytes1(counter)) >> 248;

    // And finally, the new leaf is the hash of the new state.
    return keccak256(abi.encodePacked(state));
  }

  function changeDefaultCollateral(uint collateral) external onlyBy(owner) {
   defaultCollateral = collateral;
  }

  function changeDefaultTimeLimit(uint timeLimit) external onlyBy(owner) {
   defaultTimeLimit = timeLimit;
  }

  function destroy() external onlyBy(owner) {
    selfdestruct(msg.sender);
  }
}
