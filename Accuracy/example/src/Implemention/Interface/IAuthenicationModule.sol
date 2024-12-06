pragma solidity ^0.8.0;

interface IAuthenicationModule{
    function batchSetInfo(bytes memory data) external virtual;

    function changeMode(bytes memory data) external virtual;
}