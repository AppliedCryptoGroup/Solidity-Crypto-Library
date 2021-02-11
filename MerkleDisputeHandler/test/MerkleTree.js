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

const web3 = require('web3');


/***
 * Returns a Merkle tree starting with the given leaves.
 * @param leaves The sha3 hashes with which the Merkle tree is created (should
 * start with '0x..').
 * @returns The Merkle tree as an array that begins with the leaves and ends
 * with the root.
 */
function createMerkleTree(leaves) {
  if (leaves.length < 2) {
    return leaves;
  }

  let merkleTree = [];
  let nodes = leaves;

  merkleTree = merkleTree.concat(nodes);

  while (nodes.length > 1) {
    let parents = [];

    // If the length of the nodes is odd, duplicate the last one.
    if (nodes.length % 2 == 1) {
      nodes.push(nodes[nodes.length-1]);
    }

    for (let i = 0; i < nodes.length-1; i++) {
      if (i % 2 == 0) {
        parents.push(getParentHash(nodes[i], nodes[i+1]));
      }
    }
    nodes = parents;
    merkleTree = merkleTree.concat(nodes);
  }
  return merkleTree;
}

  /***
  * Returns the hash of the two concatination of the two given hashes (without '0x' twice).
  * @param hash1 The first hash.
  * @param hash2 The second hash.
  * @returns The hash of the two concatination of the two given hashes.
  */
  function getParentHash(hash1, hash2) {
    // Removing the '0x' from the second hash, concatinating them and then hashing the result.
    return web3.utils.sha3(hash1 + hash2.substring(2));
  }

  /***
  * Returns a map with two random Merkle trees that (start) differ at one specific leaf.
  * @param numberLeaves The number of leaves the tree should have.
  * @param onlySingleDiffLeaf If true, the leaves differ only at deviatingIndex,
  * if false, every leaf after the deviating leaf will be different, too.
  * @returns A map of two Merkle trees that differ at one specific leaf at index = deviatingIndex.
  */
  function getTwoDifferentTrees(numberLeaves, onlySingleDiffLeaf) {
    let leafPreimages = [];

    leafPreimages[0] = (web3.utils.sha3(web3.utils.randomHex(32)));
    leafPreimages[0] = leafPreimages[0].substring(0, 64) + '00';

    for (let i = 1; i < numberLeaves; i++) {
      leafPreimages.push(getNextState(leafPreimages[i-1]));
    }

    // A leaf is the hash of the preimage.
    let leaves1 = leafPreimages.map(lp => web3.utils.sha3(lp));

    let deviatingIndex = getRandomInt(1, numberLeaves);
    let leaves2;

    if (onlySingleDiffLeaf) {
      // Create a second leaf array that differs at one index.
      leaves2 = [];
      leaves2 = leaves2.concat(leaves1);
      leaves2[deviatingIndex] = web3.utils.sha3('I made a mistake');

    } else {

      let leafPreimages2 = [];
      leafPreimages2 = leafPreimages2.concat(leafPreimages);
      leafPreimages2 = leafPreimages2.slice(0, deviatingIndex);
      leafPreimages2[deviatingIndex] = web3.utils.sha3('I made a mistake');

      // Construct the following leaves according to the different one, so all
      // leaves will be different beginning at deviatingIndex.
      for (let i = deviatingIndex+1; i < numberLeaves; i++) {
        leafPreimages2.push(getNextState(leafPreimages2[i-1]));
      }

      leaves2 = leafPreimages2.map(lp => web3.utils.sha3(lp));
    }


    let merkleTree1 = createMerkleTree(leaves1);
    let merkleTree2 = createMerkleTree(leaves2);
    return {
      'merkleTree1': merkleTree1,
      'merkleTree2': merkleTree2,
      'leafPreimages': leafPreimages,
      'deviatingIndex': deviatingIndex
    }
  }

  /***
  * Correponds to the makeStep function in ExampleAdjucator but the new state
  * does not get hashed becaue we need it to calcuate the following leafs.
  * @param leafPreimage The preimage of the leaf that should be used to
  * calcuate the following leaf.
  * @returns The next state whereas its hash corresponds to the next leaf.
  */
  function getNextState(leafPreimage) {
    var nonce = leafPreimage.substring(0, 64); // The current nonce.
    var counter = leafPreimage.substring(64); // The current counter in hex.

    // The new nonce is the hash of the old one.
    nonce = web3.utils.sha3(nonce).substring(0, 64);
    // Parse the counter to an integer and increase/decrease it accordingly.
    counter = parseInt(counter, 16);
    counter = BigInt(nonce) % 2n == 0 ? counter + 1 : counter - 1;

    // Simulate overflow.
    if (counter < 0) {
      counter = 255;
    } else if (counter > 255) {
      counter = 0;
    }

    counter = counter.toString(16);

    if (counter.length < 2) {
      counter = '0'.concat(counter);
    }

    return nonce.concat(counter);
  }


  function incHash(array1, array2) {
    let left = 0;
    let right = array1.length-1;
    let lastCommonHash;
    let lastDiffHash = [];

    let times = 0;

    while (left < right) {
      let index = left + Math.floor((right-left)/2);
      times++;
      if (array1[index] == array2[index]) {
        lastCommonHash = array1[index];
        left = index + 1;
      } else {
        lastDiffHash[0] = array1[index];
        lastDiffHash[1] = array2[index];
        right = index - 1;
      }
    }

    if (array1[left] == array2[left]) {
      lastCommonHash = array1[left];
    } else {
      lastDiffHash[0] = array1[left];
      lastDiffHash[1] = array2[left];
    }

    times++;

    return times;
  }

  /***
  * Returns a random value between min and max.
  * @param min The minimum number (inclusive).
  * @param max The maximum number (exclusive).
  * @returns A random value between min and max.
  */
  function getRandomInt(min, max) {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min)) + min;
}

module.exports = {
  createMerkleTree,
  getTwoDifferentTrees,
  getNextState
}
