pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20, SafeMath} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {
    IbDUSD,
    INervePeak
} from "./interfaces/IDefiDollar.sol";
import {IMasterMind,INerve} from "./interfaces/Nerve.sol";

contract Zap {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using SafeERC20 for IbDUSD;

    uint constant N_COINS = 3;
    string constant ERR_SLIPPAGE = "ERR_SLIPPAGE";

    INerve public immutable nerve;
    IERC20 immutable nrvLP;
    IERC20 immutable dusd;
    IbDUSD immutable ibdusd;
    INervePeak immutable nervePeak;

    // [ BUSD, USDT, USDC ]
    address[] coins;
    uint[] ZEROES = [uint(0),uint(0),uint(0)];

    constructor(
        INerve _nerve,
        IERC20 _nrvLP,
        INervePeak _nervePeak,
        IERC20 _dusd,
        IbDUSD _ibdusd,
        address[] memory _coins
    ) public {
        nerve = _nerve;
        nrvLP = _nrvLP;
        nervePeak = _nervePeak;
        dusd = _dusd;
        ibdusd = _ibdusd;
        coins = _coins;
    }

    /**
    * @notice Mint DUSD
    * @param inAmounts Exact inAmounts in the same order as required by the curve pool
    * @param minDusdAmount Minimum DUSD to mint, used for capping slippage
    */
    function mint(uint[] memory inAmounts, uint minDusdAmount)
        public
        returns (uint dusdAmount)
    {
        dusdAmount = _mint(inAmounts, minDusdAmount);
        dusd.safeTransfer(msg.sender, dusdAmount);
    }

    function _mint(uint[] memory inAmounts, uint minDusdAmount)
        internal
        returns (uint dusdAmount)
    {
        address[] memory _coins = coins;
        for (uint i = 0; i < N_COINS; i++) {
            if (inAmounts[i] > 0) {
                IERC20(_coins[i]).safeTransferFrom(msg.sender, address(this), inAmounts[i]);
                IERC20(_coins[i]).safeApprove(address(nerve), inAmounts[i]);
            }
        }
        nerve.addLiquidity(inAmounts, 0, now);
        uint inAmount = nrvLP.balanceOf(address(this));
        nrvLP.safeApprove(address(nervePeak), 0);
        nrvLP.safeApprove(address(nervePeak), inAmount);
        dusdAmount = nervePeak.mint(inAmount);
        require(dusdAmount >= minDusdAmount, ERR_SLIPPAGE);
    }

    function calcMint(uint[] memory inAmounts)
        public
        view
        returns (uint dusdAmount)
    {
        return nervePeak.calcMint(
            nerve.calculateTokenAmount(address(this), inAmounts, true /* deposit */)
        );
    }

    /**
    * @dev Redeem DUSD
    * @param dusdAmount Exact dusdAmount to burn
    * @param minAmounts Min expected amounts to cap slippage
    */
    function redeem(uint dusdAmount, uint[] memory minAmounts)
        public
    {
        redeemTo(dusdAmount, minAmounts, msg.sender);
    }

    function redeemTo(uint dusdAmount, uint[] memory minAmounts, address destination)
        public
    {
        dusd.safeTransferFrom(msg.sender, address(this), dusdAmount);
        _redeemTo(dusdAmount, minAmounts, destination);
    }

    function _redeemTo(uint dusdAmount, uint[] memory minAmounts, address destination)
        internal
    {
        uint r = nervePeak.redeem(dusdAmount);
        nrvLP.safeApprove(address(nerve), r);
        nerve.removeLiquidity(r, ZEROES, now);
        address[] memory _coins = coins;
        uint toTransfer;
        for (uint i = 0; i < N_COINS; i++) {
            toTransfer = IERC20(_coins[i]).balanceOf(address(this));
            if (toTransfer > 0) {
                require(toTransfer >= minAmounts[i], ERR_SLIPPAGE);
                IERC20(_coins[i]).safeTransfer(destination, toTransfer);
            }
        }
    }

    function calcRedeem(uint dusdAmount)
        public view
        returns (uint[] memory)
    {
        return nerve.calculateRemoveLiquidity(
            address(this),
            nervePeak.calcRedeem(dusdAmount)
        );
    }

    function redeemInSingleCoin(uint dusdAmount, uint8 i, uint minOut)
        public
        returns (uint amount)
    {
        return redeemInSingleCoinTo(dusdAmount, i, minOut, msg.sender);
    }

    function redeemInSingleCoinTo(uint dusdAmount, uint8 i, uint minOut, address destination)
        public
        returns (uint)
    {
        dusd.safeTransferFrom(msg.sender, address(this), dusdAmount);
        return _redeemInSingleCoinTo(dusdAmount, i, minOut, destination);
    }

    function _redeemInSingleCoinTo(uint dusdAmount, uint8 i, uint minOut, address destination)
        internal
        returns (uint amount)
    {
        uint r = nervePeak.redeem(dusdAmount);
        nrvLP.safeApprove(address(nerve), r);
        nerve.removeLiquidityOneToken(r, i, minOut, now); // checks for slippage
        IERC20 coin = IERC20(coins[i]);
        amount = coin.balanceOf(address(this));
        coin.safeTransfer(destination, amount);
    }

    function calcRedeemInSingleCoin(uint dusdAmount, uint8 i)
        public view
        returns(uint)
    {
        return nerve.calculateRemoveLiquidityOneToken(
            address(this),
            nervePeak.calcRedeem(dusdAmount),
            i
        );
    }

    function deposit(uint[] calldata inAmounts, uint minDusdAmount)
        external
        returns (uint dusdAmount)
    {
        dusdAmount = _mint(inAmounts, minDusdAmount);
        dusd.safeApprove(address(ibdusd), dusdAmount);
        ibdusd.deposit(dusdAmount);
        ibdusd.safeTransfer(msg.sender, ibdusd.balanceOf(address(this)));
    }

    function withdraw(uint shares, uint8 i, uint minOut)
        external
        returns (uint)
    {
        ibdusd.safeTransferFrom(msg.sender, address(this), shares);
        ibdusd.withdraw(shares);
        return _redeemInSingleCoinTo(
            dusd.balanceOf(address(this)),
            i,
            minOut,
            msg.sender
        );
    }

    function withdrawInAll(uint shares, uint[] calldata minAmounts)
        external
    {
        ibdusd.safeTransferFrom(msg.sender, address(this), shares);
        ibdusd.withdraw(shares);
        _redeemTo(
            dusd.balanceOf(address(this)),
            minAmounts,
            msg.sender
        );
    }
}


