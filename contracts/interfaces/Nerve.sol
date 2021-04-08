pragma solidity 0.6.10;

interface INerve {
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function calculateTokenAmount(
        address account,
        uint256[] calldata amounts,
        bool deposit
    ) external view returns (uint256);

    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    )
        external
        returns (uint256);

    function calculateRemoveLiquidity(address account, uint256 amount)
        external
        view
        returns (uint256[] memory);

    function calculateRemoveLiquidityOneToken(
        address account,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 availableTokenAmount);

    function getVirtualPrice() external view returns (uint256);
}

interface IMasterMind {
    function deposit(uint, uint) external;
    function withdraw(uint, uint) external;
    function pendingNerve(uint,address) external view returns (uint256);
    function userInfo(uint,address) external view returns (uint256 amount,uint256 rewardDebt);
}
