pragma solidity 0.6.10;

interface IDUSD {
    function mint(address account, uint amount) external;
    function burn(address account, uint amount) external;
    // function totalSupply() external view returns(uint);
}
