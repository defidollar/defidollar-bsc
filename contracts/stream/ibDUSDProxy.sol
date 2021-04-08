pragma solidity 0.6.10;

import {UpgradableProxy} from "../proxy/UpgradableProxy.sol";

contract ibDUSDProxy is UpgradableProxy {

    function name() public pure returns (string memory) {
        return "interest-bearing DUSD";
    }

    function symbol() public pure returns (string memory) {
        return "ibDUSD";
    }

    /* NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }
}
