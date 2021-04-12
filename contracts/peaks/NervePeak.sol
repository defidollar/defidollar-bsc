pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20, SafeMath} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {ICore,INervePeak} from "../interfaces/IDefiDollar.sol";
import {IMasterMind,INerve} from "../interfaces/Nerve.sol";
import {GovernableProxy} from "../proxy/GovernableProxy.sol";

contract NervePeak is GovernableProxy, INervePeak {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    uint constant FEE_PRECISION = 10000;

    ICore public immutable core;

    INerve public immutable nerve;
    IERC20 public immutable nrvLP;
    IMasterMind public immutable masterMind;

    Uni public immutable uni;
    IERC20 public immutable nrv;
    IERC20 public immutable busd;

    uint constant public PID = 0;

    constructor(
        address _core,
        address _nerve,
        address _nrvLP,
        address _masterMind,
        address _nrv,
        address _busd,
        address _uni
    )
        public
    {
        core = ICore(_core);
        nerve = INerve(_nerve);
        nrvLP = IERC20(_nrvLP);
        masterMind = IMasterMind(_masterMind);
        nrv = IERC20(_nrv);
        busd = IERC20(_busd);
        uni = Uni(_uni);
    }

    function mint(uint nrvLPAmount) override external returns (uint dusd) {
        nrvLP.safeTransferFrom(msg.sender, address(this), nrvLPAmount);
        dusd = calcMint(nrvLPAmount);
        core.mint(dusd, msg.sender);
        nrvLP.safeApprove(address(masterMind), nrvLPAmount);
        masterMind.deposit(PID, nrvLPAmount);
    }

    function redeem(uint dusd) override external returns (uint nrvLPAmount) {
        uint usd = core.redeem(dusd, msg.sender);
        nrvLPAmount = usd.mul(1e18).div(nerve.getVirtualPrice());
        masterMind.withdraw(PID, nrvLPAmount);
        nrvLP.safeTransfer(msg.sender, nrvLPAmount);
    }

    function harvest() override external returns(uint) {
        require(msg.sender == address(core), "HARVEST_NO_AUTH");

        // Claim all NRV
        masterMind.withdraw(PID, 0);

        // Swap NRV for BUSD
        uint _nrv = nrv.balanceOf(address(this));
        if (_nrv > 0) {
            address[] memory path = new address[](2);
            path[0] = address(nrv);
            path[1] = address(busd);
            nrv.safeApprove(address(uni), _nrv);
            uint[] memory amounts = Uni(uni).swapExactTokensForTokens(
                nrv.balanceOf(address(this)),
                0,
                path,
                address(this),
                now
            );

            // addLiquidity to Nerve
            uint _busd = amounts[1];
            uint[] memory liquidity = new uint[](3);
            liquidity[0] = _busd;
            busd.safeApprove(address(nerve), _busd);
            nerve.addLiquidity(liquidity, 0, now);

            // Stake
            uint nrvLPAmount = nrvLP.balanceOf(address(this));
            if (nrvLPAmount > 0) {
                nrvLP.safeApprove(address(masterMind), nrvLPAmount);
                masterMind.deposit(PID, nrvLPAmount);
            }
        }
        return portfolioValue();
    }

    function calcMint(uint nrvLPAmount) override public view returns(uint) {
        return nrvLPAmount.mul(nerve.getVirtualPrice()).div(1e18);
    }

    function calcRedeem(uint dusd) override public view returns(uint) {
        return dusd
            .mul(core.redeemFactor())
            .div(FEE_PRECISION)
            .mul(1e18)
            .div(nerve.getVirtualPrice());
    }

    function portfolioValue() override public view returns(uint) {
        (uint amount,) = masterMind.userInfo(PID, address(this));
        return amount.mul(nerve.getVirtualPrice()).div(1e18);
    }
}

interface Uni {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}
