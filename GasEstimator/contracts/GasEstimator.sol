// The GasEstimator estimates the gas usage for functions using the setLastGas
// modifier.
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


contract GasEstimator {
  uint lastGas;
  // The hashes for getLastGas(), getFunctionHashIndex()
  // and getFunctionHash(string).
  // Alternatively, the inherited contract could also provide the complete and
  // ordered functionHashes array, making the constructor unnecessary.
  bytes4[] functionHashes = [
    bytes4(0x55c451b2),
    bytes4(0x828bf210),
    bytes4(0x8bc25426)
  ];

  // The parameters for a function that uses the setEstimatedGas modifier and
  // which is currently running.
  bytes32[] functionParams;


  /**
   * @notice The modifier which sets the lastGas variable to the estimated gas for
   * the current execution.
   * @param functionHashIndex The index of the hashed function signature in
   * functionHashes.
   * @param returnType If 0 = uint256 or int256, 1 = uintX<256 or bool,
   * 2 = intX<256, 3 = bytes32, 4 = bytesX<32
   */
   modifier setEstimatedGas(uint functionHashIndex, uint returnType) {
        uint gasUsed = gasleft();
        require(functionHashIndex < functionHashes.length,
         "functionHashIndex has to be smaller than the length of functionHashes");
        // Calculate the gas costs for the function signature hash
        bytes4 funSigHash = functionHashes[functionHashIndex];
        for (uint b = 0; b < 4; b++) {
            // Gtxdatanonzero was reduced from 68 to 16 with EIP 2028
            // (Remix uses 68).
            gasUsed += funSigHash[b] == 0 ? 4 : 16;
        }

     // Adding 21000 for Gtransaction and 22 Gas depending on the position in
     // functionHashes.
     gasUsed = gasUsed + 21000 + functionHashIndex * 22;

     _; // Execute the function which uses the modifier.

     // Corresponds to Gsset (20000) or Gsreset (5000).
     gasUsed += lastGas == 0 ? 20000 : 5000;

     if (functionParams.length > 0) {
         // Calculating the gas cost for the number of parameters.
        gasUsed += (87 + (functionParams.length-1) * 29);

        // Calculating the gas costs for every single parameter.
        for (uint p = 0; p < functionParams.length; p++) {

            for (uint pb = 0; pb < 32; pb++) {
                // Gtxdatanonzero was reduced from 68 to 16 with EIP 2028
                // (Remix uses 68).
                gasUsed += functionParams[p][pb] == 0 ? 4 : 16;
            }
        }
        // Adapt to tested measurments.
        gasUsed -= 19203 + functionParams.length * 19200;
        delete functionParams; // Resetting the functionParams array.
     }

     // Corresponds to uint256 or int256.
     if (returnType == 0) {
          gasUsed += 5;

      // Corresponds to uintX with X < 256 (includes bool = uint8).
      } else if (returnType == 1) {
        gasUsed += 17;

      // Corresponds to intX with X < 256.
      } else if (returnType == 2) {
        gasUsed +=  21;

      // Corresponds to bytes32.
      } else if (returnType == 3) {
        gasUsed += 5;

      // Corresponds to bytesX with X < 32.
      } else {
        gasUsed += 23;
      }

     // The gas costs differ for functions with more than 6 functions in total
     // (including those from GasEstimator).
      uint diffFromSix = functionHashes.length > 6 ?
        functionHashes.length - 6 : 0;

       if (diffFromSix  > 0) {
           if (functionHashIndex >= 2 + diffFromSix) {
               gasUsed -= diffFromSix*22 + 20;
           } else {
               gasUsed += 25;
           }
       }

     gasUsed = gasUsed + 1856 - gasleft();
     if (gasUsed == lastGas)
            gasUsed += 14;
     lastGas = gasUsed;
  }

  /**
   * @notice The constructor adds the function hashes of the inherited contract
   * into functionHashes with respect to its order.
   * @param _functionHashes The function signature hashes of the inherited
   * contract which can be generated using getFunctionHash below.
   */
  constructor(bytes4[] memory _functionHashes) internal {
    bytes4 toBeInserted;
    bytes4 tmp;
    for (uint i = 0; i < _functionHashes.length; i++) {
      toBeInserted = _functionHashes[i];
      for (uint j = 0; j < functionHashes.length; j++) {
        if (toBeInserted < functionHashes[j]) {
          tmp = functionHashes[j];
          functionHashes[j] = toBeInserted;
          toBeInserted = tmp;
        }
      }
      functionHashes.push(toBeInserted);
    }
  }

     /**
      * @notice Getter for the lastGas variable.
      * @return The estimated gas of the last function call that used the modifier
      * setEstimatedGas.
     */
    function getLastGas() external view returns (uint) {
        return lastGas;
    }

  /**
   * @notice Returns the index of a given function Hash in functionHashes.
   * @param functionHash The hash of a function signature.
   * @return The index of the functionHash inside functionHashes or 0 as a
   * default.
   */
  function getFunctionHashIndex(bytes4 functionHash) public view returns (uint) {
    for (uint i = 0; i < functionHashes.length; i++) {
      if (functionHashes[i] == functionHash) {
        return i;
      }
    }
    return 0;
  }

  /**
   * @notice A helper function for calculating the hash of a given function
   * signature.
   * @param funSig The signature of a function.
   * @return The bytes4 hash of the function signature.
   */
  function getFunctionHash(string memory funSig) public pure returns (bytes4) {
      return bytes4(keccak256(abi.encodePacked(funSig)));
  }
}
