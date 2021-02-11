# GasEstimator
Estimates the gas usage for functions that use the `setLastGas` modifier. \
The estimations differ from the actual cost if functions have parameters not from type uint256 parameters and for contracts with more than 7 functions.
In addition to the calculated execution costs, constant costs, that depend on the name of the function, number of parameters, and on the other existing functions, are also added.



# Usage
For using the modifier `setLastGas`, your contract needs to derive from GasEstimator. \
The `constructor` of GasEstimator expects an array of function signature hashes of the inherited contract that can be generated using `getFunctionHash`. \
Then, you can apply the modifier to functions for which it will set the lastGas variable to the estimated gas costs of future calls of this function. \
The modifier expects the index of the hashed function signature in functionHashes, which you can get by calling `getFunctionHashIndex`, and a number corresponding to the return value of your function:

```
returnType
= 1 for uint256 or int256
= 2 for uintX with X < 256 (includes bool = uint8)
= 3 for intX with X < 256
= 4 for bytes32
= 5 for bytesX with X < 32
```
If your function has any parameters, you have to include them in the `functionParams` array as bytes32 values before returning and making any changes to them.
Finally, you can get the estimated gas after a function call with `getLastGas`.

##### See SampleContract for an example of using GasEstimator.


# Testing

We use [Truffle](https://truffleframework.com/) for testing.



```
$ truffle test

Compiling your contracts...
===========================

> Compiling .\contracts\GasEstimator.sol
> Compiling .\contracts\Migrations.sol
> Compiling .\contracts\SampleContract.sol

Contract: SampleContract
  √ Calculate gas correctly for return type uint256. (429ms)
  √ Calculate gas correctly for return type bool. (136ms)
  √ Calculate gas correctly a function with parameters. (327ms)


3 passing (1s)
```

# TODO

- [x] Add testing
- [x] Support more than 3 functions in a single contract
- [x] Support for different return values
- [x] Adapt code according to the style guide
- [x] Support for functions with parameters
- [ ] Support for contracts with more than 7 functions
