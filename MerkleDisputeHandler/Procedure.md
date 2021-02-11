### Procedure of the MerkleDisputeHandler

1. Both parties register the dispute by depositing a collateral and providing the address of the other party for the identification of the dispute. If they don't want to use the default values for the collateral and the time limit, they both need to sent the same corresponding values.
2. The "calculator" party sends its root hash and its first leaf with its signatures of both to the "verifier" party. The verifier checks if their first leaves are equal and only continues if this is true.
3. The verifier initializes the dispute through sending the tree height, its root hash, the first leaf, the calculator's root hash and both signatures to the contract.
4. The contract uses bisection search to find the deviating leaf as before. When the index of the deviating leaf is found, it sets indexToSubmit to the index of the previous leaf (indexToSubmit-1), which is the last leaf that is equal for both parties.
5. Then, any of the two parties submit the preimage of the leaf with index indexToSubmit-1 and a corresponding Merkle proof.
6. Finally, any party can call the function determineGuiltier, which makes one step using the preimage to get the correct leaf, and then checks which party was correct and which party cheated.
