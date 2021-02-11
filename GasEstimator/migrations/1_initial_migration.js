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

const Migrations = artifacts.require("Migrations");
const SampleContract = artifacts.require("SampleContract");


module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(SampleContract,["0x35b09a6e", "0x8fe75f1b", "0x6599a6aa"]);
};
