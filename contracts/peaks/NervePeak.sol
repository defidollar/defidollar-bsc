pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20, SafeMath} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {ICore} from "../interfaces/ICore.sol";

contract NervePeak {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    ICore public immutable core;

    INerve public immutable nerve;
    IERC20 public immutable nrvLP;
    IMasterMind public immutable masterMind;

    uint constant public PID = 0;

    constructor(
        address _core,
        address _nerve,
        address _nrvLP,
        address _masterMind
    )
        public
    {
        core = ICore(_core);
        nerve = INerve(_nerve);
        nrvLP = IERC20(_nrvLP);
        masterMind = IMasterMind(_masterMind);
    }

    function mint(uint amount) external returns (uint dusd) {
        nrvLP.safeTransferFrom(msg.sender, address(this), amount);
        dusd = amount.mul(nerve.getVirtualPrice()).div(1e18);
        core.mint(dusd, msg.sender);
        nrvLP.safeApprove(address(masterMind), amount);
        masterMind.deposit(PID, amount);
    }

    function redeem(uint dusd) external returns (uint nrvLPAmount) {
        core.redeem(dusd, msg.sender);
        nrvLPAmount = dusd.mul(1e18).div(nerve.getVirtualPrice());
        masterMind.withdraw(PID, nrvLPAmount);
        nrvLP.safeTransfer(msg.sender, nrvLPAmount);
    }
}

interface INerve {
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function getVirtualPrice() external returns (uint256);
}

interface IMasterMind {
    function deposit(uint, uint) external;
    function withdraw(uint, uint) external;
}
