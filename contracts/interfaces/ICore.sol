pragma solidity 0.6.10;

interface ICore {
    function mint(uint dusdAmount, address account) external returns(uint usd);
    function redeem(uint dusdAmount, address account) external returns(uint usd);
}
