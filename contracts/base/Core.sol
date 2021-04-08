pragma solidity 0.6.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20, SafeMath} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";

import {GovernableProxy} from "../proxy/GovernableProxy.sol";
import {
    ICore,
    IDUSD,
    IPeak
} from "../interfaces/IDefiDollar.sol";

contract Core is GovernableProxy, ICore {
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using Math for uint;

    uint constant FEE_PRECISION = 10000;

    IDUSD public immutable dusd;

    // Interface contracts for third-party protocol integrations
    enum PeakState { Extinct, Active, Dormant }
    struct Peak {
        uint amount;
        uint ceiling;
        PeakState state;
    }
    mapping(address => Peak) public peaks;
    address[] public peaksAddresses;

    mapping(address => bool) public harvesters;
    address public beneficiary;
    uint override public redeemFactor;

    // END OF STORAGE VARIABLES

    event Mint(address indexed account, uint amount);
    event Redeem(address indexed account, uint amount);
    event PeakWhitelisted(address indexed peak);

    constructor(address _dusd) public {
        dusd = IDUSD(_dusd);
    }

    /**
    * @notice Mint DUSD
    * @dev Only whitelisted peaks can call this function
    * @param dusdAmount DUSD amount to mint
    * @param account Account to mint DUSD to
    * @return dusdAmount DUSD amount minted
    */
    function mint(uint dusdAmount, address account)
        override
        external
        returns(uint)
    {
        Peak storage peak = peaks[msg.sender];
        uint tvl = peak.amount.add(dusdAmount);
        require(
            dusdAmount > 0
            && peak.state == PeakState.Active
            && tvl <= peak.ceiling,
            "ERR_MINT"
        );
        peak.amount = tvl;
        dusd.mint(account, dusdAmount);
        emit Mint(account, dusdAmount);
        return dusdAmount;
    }

    /**
    * @notice Redeem DUSD
    * @dev Only whitelisted peaks can call this function
    * @param dusdAmount DUSD amount to redeem.
    * @param account Account to burn DUSD from
    */
    function redeem(uint dusdAmount, address account)
        override
        external
        returns(uint usd)
    {
        Peak storage peak = peaks[msg.sender];
        require(
            dusdAmount > 0 && peak.state != PeakState.Extinct,
            "ERR_REDEEM"
        );
        peak.amount = peak.amount.sub(peak.amount.min(dusdAmount));
        dusd.burn(account, dusdAmount);
        emit Redeem(account, dusdAmount);
        return dusdAmount.mul(redeemFactor).div(FEE_PRECISION);
    }

    function harvest() override external {
        require(harvesters[msg.sender], "HARVEST_NO_AUTH");

        uint _totalAssets;
        for (uint i = 0; i < peaksAddresses.length; i++) {
            Peak memory peak = peaks[peaksAddresses[i]];
            if (peak.state == PeakState.Extinct) {
                continue;
            }
            _totalAssets = _totalAssets.add(
                IPeak(peaksAddresses[i]).harvest()
            );
        }

        if (beneficiary != address(0)) {
            uint earned = _earned(_totalAssets);
            if (earned > 0) {
                dusd.mint(beneficiary, earned);
            }
        }
    }

    /* ##### View ##### */

    function earned() override public view returns(uint) {
        return _earned(totalSystemAssets());
    }

    function _earned(uint _totalAssets) internal view returns(uint) {
        uint supply = dusd.totalSupply();
        if (_totalAssets > supply) {
            return _totalAssets.sub(supply);
        }
        return 0;
    }

    function totalSystemAssets() public view returns (uint _totalAssets) {
        for (uint i = 0; i < peaksAddresses.length; i++) {
            Peak memory peak = peaks[peaksAddresses[i]];
            if (peak.state == PeakState.Extinct) {
                continue;
            }
            _totalAssets = _totalAssets.add(
                IPeak(peaksAddresses[i]).portfolioValue()
            );
        }
    }

    /* ##### Governance ##### */

    /**
    * @notice Whitelist a new peak
    * @param peak Address of the contract that interfaces with the 3rd-party protocol
    */
    function whitelistPeak(address peak, uint ceiling)
        external
        onlyGovernance
    {
        require(
            peaks[peak].state == PeakState.Extinct,
            "Peak already exists"
        );
        peaksAddresses.push(peak);
        peaks[peak] = Peak(0, ceiling, PeakState.Active);
        emit PeakWhitelisted(peak);
    }

    /**
    * @notice Change a peaks status
    */
    function setPeakStatus(address peak, uint ceiling, PeakState state)
        external
        onlyGovernance
    {
        require(
            peaks[peak].state != PeakState.Extinct,
            "Peak is extinct"
        );
        peaks[peak].ceiling = ceiling;
        peaks[peak].state = state;
    }

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

    function authorizeHarvester(address _harvester, bool _status)
        external
        onlyGovernance
    {
        require(_harvester != address(0x0), "Zero Address");
        harvesters[_harvester] = _status;
    }

    function setHarvestBeneficiary(address _beneficiary)
        external
        onlyGovernance
    {
        require(_beneficiary != address(0x0), "Zero Address");
        beneficiary = _beneficiary;
    }
}
