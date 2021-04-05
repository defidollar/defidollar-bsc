pragma solidity 0.6.10;

interface IERCProxy {
    function proxyType() external pure returns (uint proxyTypeId);
    function implementation() external view returns (address codeAddr);
}
