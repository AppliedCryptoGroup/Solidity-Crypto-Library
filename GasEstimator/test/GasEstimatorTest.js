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

const SampleContract = artifacts.require("SampleContract");

contract("SampleContract", async accounts => {
  it("Calculate gas correctly for return type uint256.", async () => {
    let instance = await SampleContract.deployed();
    let result = await instance.someFunction();
    let estimatedGas = await instance.getLastGas();
    assert.equal(estimatedGas.toNumber(), result.receipt.gasUsed);

    // Gas usage will be different after the first call.
    result = await instance.someFunction();
    estimatedGas = await instance.getLastGas();
    assert.equal(estimatedGas.toNumber(), result.receipt.gasUsed);

    // And after it is called the second time in a row.
    result = await instance.someFunction();
    estimatedGas = await instance.getLastGas();
    assert.equal(estimatedGas.toNumber(), result.receipt.gasUsed);


  });

  it("Calculate gas correctly for return type bool.", async () => {
    let instance = await SampleContract.deployed();
    let result = await instance.functionBool();
    let estimatedGas = await instance.getLastGas();
    assert.equal(estimatedGas.toNumber(), result.receipt.gasUsed);
  });

  it("Calculate gas correctly a function with uint parameters.", async () => {
    let instance = await SampleContract.deployed();
    let result = await instance.funcWithParams(99128, 1337, 5);
    let estimatedGas = await instance.getLastGas();
    assert.equal(estimatedGas.toNumber(), result.receipt.gasUsed);
  });
});
