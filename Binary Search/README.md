# Binary Search in Solidity
Includes a simple Binary Search implementation for bytes32 values in Solidity. \
For supporting other ordering relations than "=" and "<", a new contract only needs to implement the two abstract comparison gates in "AbstractBinarySearch". \
For example, the cross sum could be used as an ordering relation.


# Usage

The **findIndex** function expects a bytes32 array and a bytes32 value, which the function will search for in the given array. The array should be ordered according to the two comparison gates.
```javascript
let instance = await BinarySearch.deployed();
let array = ["0x13600b294191fc92924bb3ce4b969c1e7e2bab8f4c93c3fc6d0a51733df3c060","0x3ac225168df54212a25c1c01fd35bebfea408fdac2e31ddd6f80a4bbf9a5f1cb",
"0xb5553de315e0edf504d9150af82dafa5c4667fa618ed0a6f19c69b41166c5510", "0xb6f6286492d9985aa817e37ce0f7aeb25be56f6fb7fb715008cc732b99c95855"];
let val = "0x3ac225168df54212a25c1c01fd35bebfea408fdac2e31ddd6f80a4bbf9a5f1cb";
let result = await instance.findIndex(array.valueOf(), val);
```

# Testing

We use [Truffle](https://truffleframework.com/) for testing.

```
$ truffle test
> Compiling .\contracts\BinarySearch.sol
> Compiling .\contracts\Migrations.sol


  Contract: BinarySearch
    √ Should return the index of a included value (60ms)
    √ Should not find a value not included (64ms)


  2 passing (176ms)
```
