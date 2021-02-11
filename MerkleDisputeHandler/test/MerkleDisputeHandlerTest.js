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

const ExampleAdjucator = artifacts.require("ExampleAdjucator");
const MerkleTree = require("./MerkleTree.js");

let numberLeaves, height, rootIndex, testObj, leafPreimages, merkleTree1,
  merkleTree2, deviatingIndex, nonce1, nonce2;


function initMerkleTree(_numberLeaves) {
  numberLeaves = _numberLeaves;
  height = Math.log(numberLeaves) / Math.log(2) + 1;
  rootIndex = 2**height - 2;

  // The Merkle Dispute Handler finds the deviating leaf regardless of whether
  // only one the deviating leaf is different (onlySingleDiffLeaf = true) or
  // every leaf after this one (onlySingleDiffLeaf = false).
  testObj = MerkleTree.getTwoDifferentTrees(numberLeaves, true);

  leafPreimages = testObj["leafPreimages"];
  merkleTree1 = testObj["merkleTree1"];
  merkleTree2 = testObj["merkleTree2"];
  deviatingIndex = testObj["deviatingIndex"];

  nonce1 = web3.utils.randomHex(32);
  nonce2 = web3.utils.randomHex(32);
  while (nonce1 == nonce2) { // Make sure that they are not equal (which is very unlikely).
    nonce2 = web3.utils.randomHex(32);
  }
}

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function sign(message, account) {
  var sig = await web3.eth.sign(message, account);
  // web3.eth.sign returns the v value in an older format, we need to add 27.
  var v = sig.substring(sig.length -2);
  v = parseInt(v, 16);
  v += 27;
  v = v.toString(16);
  v = v.substring(v.length -2, v.length);
  sig = sig.substring(0, sig.length -2) + v;
  return sig;
}


contract("MerkleDisputeHandler", async accounts => {
  let collateral;
  let gasUsed = 0;

  it("Finds the index of the deviating leaf of two parties", async () => {
    let instance = await ExampleAdjucator.deployed();

    initMerkleTree(2048);

    collateral = await instance.defaultCollateral();
    collateral = parseInt(collateral);

    let result = await instance.registerDispute(
      accounts[1],
      {from: accounts[0], value: collateral}
    );

    gasUsed += result.receipt.gasUsed;

    result = await instance.registerDispute(
      accounts[0],
      {from: accounts[1], value: collateral}
    );

    gasUsed += result.receipt.gasUsed;

    let disputeId = await instance.getDisputeId(
      accounts[1], {from: accounts[0]}
    );

    let firstLeafSig = await sign(merkleTree2[0], accounts[1]);
    let rootOtherPartySig = await sign(merkleTree2[rootIndex], accounts[1]);

    result = await instance.initDispute(
      accounts[1],
      height,
      merkleTree1[0], // The first leaf is equal for both parties.
      merkleTree1[rootIndex],
      merkleTree2[rootIndex],
      firstLeafSig,
      rootOtherPartySig,
      {from: accounts[0]}
    );

    gasUsed += result.receipt.gasUsed;


    let indexToSubmit;

    while (!(await instance.leafIsFound(disputeId))) {

      indexToSubmit = (await instance.getIndexToSubmit(disputeId)).toNumber();

      result = await instance.submitHash(
        accounts[1],
        merkleTree1[indexToSubmit],
        indexToSubmit,
        {from: accounts[0]}
      );

      gasUsed += result.receipt.gasUsed;

      result = await instance.submitHash(
        accounts[0],
        merkleTree2[indexToSubmit],
        indexToSubmit,
        {from: accounts[1]}
      );

      gasUsed += result.receipt.gasUsed;
    }


    // The last index to submit equals the index of the deviating leaf.
    // If we would call getIndexToSubmit again, we would get the predecessor.
    assert.equal(indexToSubmit, deviatingIndex);
  });

  it("Determines the guilty party correctly", async () => {
    let instance = await ExampleAdjucator.deployed();

    let disputeId = await instance.getDisputeId(
      accounts[1], {from: accounts[0]}
    );

    let revealIndex = (await instance.getIndexToSubmit(disputeId)).toNumber();

    // They used the same preimage since revealIndex+1 is the first index where
    // the hashes of both parties differ.

    let mpIndexes = await instance.getMerkleProofIndexes(disputeId);
    mpIndexes = mpIndexes.map((mpIndex) => mpIndex.toNumber());

    let merkleProof = [];

    mpIndexes.forEach((mpIndex) => merkleProof.push(merkleTree1[mpIndex]));


    let result = await instance.revealPreimage(
      accounts[1],
      leafPreimages[revealIndex],
      merkleProof,
      {from: accounts[0]}
    );

    gasUsed += result.receipt.gasUsed;

    result = await instance.determineGuiltier(
      accounts[1],
      {from: accounts[0]}
    );

    gasUsed += result.receipt.gasUsed;

    let guiltyPartyIndex = accounts[0] < accounts[1] ? 1 : 0;

    assert.equal(
      result.logs[0].args['partyIndex'].toNumber(),
      guiltyPartyIndex
    );
  });

  it("The honest party can withdraw the compensation", async () => {
    let instance = await ExampleAdjucator.deployed();

    let initBal1 = await web3.eth.getBalance(accounts[0]);
    let initBal2 = await web3.eth.getBalance(accounts[1]);
    initBal1 = parseInt(initBal1);
    initBal2 = parseInt(initBal2);

    let result = await instance.withdrawFunds({from: accounts[0]});

    gasUsed += result.receipt.gasUsed;

    result = await instance.withdrawFunds({from: accounts[1]});

    gasUsed += result.receipt.gasUsed;

    let newBal1 = await web3.eth.getBalance(accounts[0]);
    newBal1 = parseInt(newBal1);
    let newBal2 = await web3.eth.getBalance(accounts[1]);
    newBal2 = parseInt(newBal2);

    // Allows a max deviation 0.001 ETH.
    let tolerance = 10**15;
    assert.isAtLeast(newBal1 + tolerance, initBal1 + collateral*2);
    assert.isAtMost(newBal1, initBal1 + collateral*2 + tolerance);
    assert.isAtLeast(newBal2 + tolerance, initBal2);
    assert.isAtMost(newBal2, initBal2 + tolerance);

    let gasPrice = await web3.eth.getGasPrice();
    console.log(`    Total gas used for ${numberLeaves} leaves: ${gasUsed} resulting in ${gasUsed*gasPrice*10**-18} ETH.`);
    gasUsed = 0;
  });

  // In this test, a party cheats by using a different first leaf, than the one,
  // they initially agreed on.
  it("Determines a cheating party", async () => {
    let instance = await ExampleAdjucator.deployed();

    initMerkleTree(8);

    collateral = await instance.defaultCollateral();
    collateral = parseInt(collateral);

    await instance.registerDispute(
      accounts[1],
      {from: accounts[0], value: collateral}
    );
    await instance.registerDispute(
      accounts[0],
      {from: accounts[1], value: collateral}
    );

    let disputeId = await instance.getDisputeId(
      accounts[1], {from: accounts[0]}
    );

    let firstLeafSig = await sign(merkleTree2[0], accounts[1]);
    let rootOtherPartySig = await sign(merkleTree2[rootIndex], accounts[1]);

    await instance.initDispute(
      accounts[1],
      height,
      merkleTree1[0],
      merkleTree1[rootIndex],
      merkleTree2[rootIndex],
      firstLeafSig,
      rootOtherPartySig,
      {from: accounts[0]}
    );

    // The second party uses a different first leaf (results in a completely
    // different tree), even though they initially agreed on the same first
    // leaf. (The second party could also just submit random hashes.)
    merkleTree2 = MerkleTree.getTwoDifferentTrees(8, false)['merkleTree2'];


    let indexToSubmit;

    while (!(await instance.leafIsFound(disputeId))) {

      indexToSubmit = (await instance.getIndexToSubmit(disputeId)).toNumber();

      await instance.submitHash(
        accounts[1],
        merkleTree1[indexToSubmit],
        indexToSubmit,
        {from: accounts[0]}
      );

      await instance.submitHash(
        accounts[0],
        merkleTree2[indexToSubmit],
        indexToSubmit,
        {from: accounts[1]}
      );
    }

    let result = await instance.determineGuiltier(
      accounts[1],
      {from: accounts[0]}
    );

    assert.equal(indexToSubmit, 0);

    let guiltyPartyIndex = accounts[0] < accounts[1] ? 1 : 0;

    assert.equal(
      result.logs[0].args['partyIndex'].toNumber(),
      guiltyPartyIndex
    );
  });

  it("The non-responding party is convicted", async () => {
    let instance = await ExampleAdjucator.deployed();

    initMerkleTree(32);

    let customCollateral = 23*10**15;
    let customTimeLimit = 3;

    // We have to specify the function ABI because Truffle does not detect
    // overloading automatically.
    await instance.methods['registerDispute(address,uint256,uint256)'](
      accounts[3],
      customCollateral.toString(),
      customTimeLimit,
      {from: accounts[2], value: customCollateral}
    );

    await instance.methods['registerDispute(address,uint256,uint256)'](
      accounts[2],
      customCollateral.toString(),
      customTimeLimit,
      {from: accounts[3], value: customCollateral}
    );

    let disputeId = await instance.getDisputeId(accounts[3], {from: accounts[2]});

    collateral = await instance.getCollateral(disputeId);

    // Check if the custom collateral is applied.
    assert.equal(collateral.toString(), customCollateral.toString());

    let firstLeafSig = await sign(merkleTree2[0], accounts[3]);
    let rootOtherPartySig = await sign(merkleTree2[rootIndex], accounts[3]);

    await instance.initDispute(
      accounts[3],
      height,
      merkleTree1[0], // The first leaf is equal for both parties.
      merkleTree1[rootIndex],
      merkleTree2[rootIndex],
      firstLeafSig,
      rootOtherPartySig,
      {from: accounts[2]}
    );

    let indexToSubmit = (await instance.getIndexToSubmit(disputeId)).toNumber();

    // Only accounts[3] submits the next required node.
    await instance.submitHash(accounts[2], merkleTree2[indexToSubmit], indexToSubmit, {from: accounts[3]});

    // Wait until the timeLimit is exceeded..
    await sleep((customTimeLimit + 1) * 1000);
    let result = await instance.reportExceededTimeLimit(accounts[2], {from: accounts[3]});

    let guiltyPartyIndex = accounts[2] < accounts[3] ? 0 : 1;

    assert.equal(guiltyPartyIndex, result.logs[0].args['partyIndex']);
  });
});
