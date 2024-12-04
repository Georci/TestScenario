// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IModule {
    function setInfo(bytes memory data) external;

    function setMode(bytes memory data) external;

    function removeInfo(bytes memory data) external;

    function detect(
        address project,
        string[] memory params,
        bytes memory data
    ) external returns (bool);
}
