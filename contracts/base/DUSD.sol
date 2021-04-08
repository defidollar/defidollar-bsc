pragma solidity 0.6.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DUSD is ERC20 {
    address public immutable core;

    constructor(address _core)
        public
        ERC20("DefiDollar", "DUSD")
    {
        core = _core;
    }

    modifier onlyCore() {
        require(msg.sender == core, "Not authorized");
        _;
    }

    function mint(address account, uint amount) public onlyCore {
        _mint(account, amount);
    }

    function burn(address account, uint amount) public onlyCore {
        _burn(account, amount);
    }
}
