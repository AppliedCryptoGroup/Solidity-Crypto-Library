// BinarySearch provides an implementation of the binary search for Solidity.
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


abstract contract AbstractBinarySearch {

    /**
     * @notice Searches the given value inside the given array using the binary search algorithmn.
     * @param array A bytes32 array, which is sorted according to the gateIsBigger comparator.
     * @param val The bytes32 value the function should search for.
     * @return The index of the given value inside the array or -1 if it is not included.
     */
    function findIndex(bytes32[] memory array, bytes32 val) public pure returns (int) {

        uint left = 0;
        uint right = array.length - 1;
        uint mid;

        while (left <= right) {
          mid = left + ((right - left) / 2);

          if (gateEquals(array[mid], val)) {
            return int(mid);
          } else if (gateIsBigger(array[mid], val)) {
            right = mid - 1;
          } else {
            left = mid + 1;
          }
        }
        return -1;
    }

    /**
     * @notice Abstract function, which should check if the two given values are equal.
     * @param a The first bytes32 value.
     * @param b The second bytes32 value.
     * @return The index of the given value inside the array or -1 if it is not included.
     */
    function gateEquals(bytes32 a, bytes32 b) internal virtual pure returns (bool);


    /**
     * @notice Abstract function, which should check if the first given value is bigger as the second one.
     * @param a The first bytes32 value.
     * @param b The second bytes32 value.
     * @return True, if the first value is bigger than the second, otherwise False.
     */
    function gateIsBigger(bytes32 a, bytes32 b) internal virtual pure returns (bool);


}


contract BinarySearch is AbstractBinarySearch {

  function gateEquals(bytes32 a, bytes32 b) internal override pure returns (bool) {
    return a == b;
  }


  function gateIsBigger(bytes32 a, bytes32 b) internal override pure returns (bool) {
    return a > b;
  }


}
