// This file is part of the GasEstimator.
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

pragma solidity ^0.6.6;

import "./GasEstimator.sol";

contract SampleContract is GasEstimator {

  uint someFunctionIndex;
  uint functionBoolIndex;
  uint funcWithParamsIndex;

  constructor(bytes4[] memory _functionHashes) GasEstimator(_functionHashes) public {
    someFunctionIndex = getFunctionHashIndex(_functionHashes[0]);
    functionBoolIndex = getFunctionHashIndex(_functionHashes[1]);
    funcWithParamsIndex = getFunctionHashIndex(_functionHashes[2]);
  }

  // Just a test function which does some "expensive" operations and uses the modifier setEstimatedGas.
  function someFunction() public setEstimatedGas(someFunctionIndex, 0) returns (uint) {
    uint tmp;
    for (uint i = 0; i < 25; i++) {
      tmp = tmp * i + i**2;
    }
    return tmp;
  }

  function functionBool() public setEstimatedGas(functionBoolIndex, 1) returns (bool) {
    uint tmp;
    for (uint i = 0; i < 10; i++) {
      tmp = tmp * i + i**2;
    }
    return true;
  }

  function funcWithParams(uint x, uint y, uint z) public setEstimatedGas(funcWithParamsIndex, 3) returns (bytes32) {
    uint tmp = x + y + z;
    for (uint i = 0; i < 15; i++) {
      tmp = tmp * i + i**3 + 6;
    }

    // It is required to set the functionParams before returning (or changing
    // those values).
    functionParams = [bytes32(x), bytes32(y), bytes32(z)];
    return bytes32(tmp);
  }
}
