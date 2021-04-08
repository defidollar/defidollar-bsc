pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {GovernableProxy} from "../proxy/GovernableProxy.sol";
import {
    ICore,
    IDUSD,
    IPeak
} from "../interfaces/IDefiDollar.sol";

contract ibDUSD is GovernableProxy, ERC20 {
    using SafeERC20 for IERC20;

    uint constant FEE_PRECISION = 10000;

    ICore public immutable core;
    IERC20 public immutable dusd;

    uint public redeemFactor;

    /**
    * @dev Since this is a proxy, the values set in the ERC20Detailed constructor are not actually set in the main contract.
    */
    constructor (address _core, address _dusd)
        public
        ERC20("interest-bearing DUSD", "ibDUSD")
    {
        core = ICore(_core);
        dusd = IERC20(_dusd);
    }

    function deposit(uint _amount) external {
        // core.harvest();
        uint _pool = balance();

        // If no funds are staked, send the accrued reward to governance multisig
        uint totalSupply = totalSupply();
        if (totalSupply == 0) {
            dusd.safeTransfer(owner(), _pool);
            _pool = 0;
        }

        uint shares = 0;
        if (_pool == 0) {
            shares = _amount;
        } else {
            shares = _amount.mul(totalSupply).div(_pool);
        }
        dusd.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, shares);
    }

    function withdraw(uint _shares) external {
        // core.harvest();
        uint r = balance()
            .mul(_shares)
            .mul(redeemFactor)
            .div(totalSupply().mul(FEE_PRECISION));
        _burn(msg.sender, _shares);
        dusd.safeTransfer(msg.sender, r);
    }

    /* ##### View ##### */

    function balance() public view returns (uint) {
        return dusd.balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns (uint) {
        if (totalSupply() == 0) {
            return 1e18;
        }
        return balance()
            .add(core.earned())
            .mul(1e18)
            .div(totalSupply());
    }

    /* ##### Admin ##### */

    function setFee(uint _redeemFactor)
        external
        onlyGovernance
    {
        require(
            _redeemFactor <= FEE_PRECISION,
            "Incorrect upper bound for fee"
        );
        redeemFactor = _redeemFactor;
    }
}
