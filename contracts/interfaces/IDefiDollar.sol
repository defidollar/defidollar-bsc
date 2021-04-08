pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICore {
    function mint(uint dusdAmount, address account) external returns(uint usd);
    function redeem(uint dusdAmount, address account) external returns(uint usd);
    function harvest() external;
    function earned() external view returns(uint);
    function redeemFactor() external view returns(uint);
}

interface IDUSD {
    function mint(address account, uint amount) external;
    function burn(address account, uint amount) external;
    function totalSupply() external view returns(uint);
}

interface IPeak {
    function portfolioValue() external view returns(uint);
    function harvest() external returns(uint);
}

interface INervePeak is IPeak {
    function mint(uint inAmount) external returns(uint dusdAmount);
    function redeem(uint dusdAmount) external returns(uint _nrvLP);
    function calcMint(uint nrvLPAmount) external view returns(uint);
    function calcRedeem(uint dusd) external view returns(uint);
}

interface IbDUSD is IERC20 {
    function deposit(uint) external;
    function withdraw(uint) external;
    function getPricePerFullShare() external view returns (uint);
    function balance() external view returns (uint);
}
