// This file is part of BinarySearch.
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

const BinarySearch = artifacts.require("BinarySearch");

contract("BinarySearch", async accounts => {
  it("Should return the index of a included value", async () => {
    let instance = await BinarySearch.deployed();
    let array = ["0x13600b294191fc92924bb3ce4b969c1e7e2bab8f4c93c3fc6d0a51733df3c060", "0x3ac225168df54212a25c1c01fd35bebfea408fdac2e31ddd6f80a4bbf9a5f1cb",
     "0xb5553de315e0edf504d9150af82dafa5c4667fa618ed0a6f19c69b41166c5510", "0xb6f6286492d9985aa817e37ce0f7aeb25be56f6fb7fb715008cc732b99c95855"];
    let val = "0x3ac225168df54212a25c1c01fd35bebfea408fdac2e31ddd6f80a4bbf9a5f1cb";
    let result = await instance.findIndex(array.valueOf(), val);

    assert.equal(result, 1);
  });

  it("Should not find a value not included", async () => {
    let instance = await BinarySearch.deployed();
    let array = ["0x13600b294191fc92924bb3ce4b969c1e7e2bab8f4c93c3fc6d0a51733df3c060", "0x3ac225168df54212a25c1c01fd35bebfea408fdac2e31ddd6f80a4bbf9a5f1cb",
     "0xb5553de315e0edf504d9150af82dafa5c4667fa618ed0a6f19c69b41166c5510", "0xb6f6286492d9985aa817e37ce0f7aeb25be56f6fb7fb715008cc732b99c95855"];
    let val = "0xe058762bbc1257399b6a415d06db451f64b60c61489f1933af80a2623998ef59";
    let result = await instance.findIndex(array.valueOf(), val);

    assert.equal(result, -1);
  });


});
