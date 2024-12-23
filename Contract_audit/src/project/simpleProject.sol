pragma solidity ^0.8.0;

contract simpleProject {
    uint256 public sum;

    function swap(uint256 tokenA, uint256 tokenB) external {
        sum = tokenA + tokenB;
    }
}
