const { BigNumber } = require("@ethersproject/bignumber")

const constants = {
    _1e18: ethers.constants.WeiPerEther,
    ZERO: BigNumber.from(0)
}
const whale = '0x631Fc1EA2270e98fbD9D92658eCe0F5a269Aa161' // Binance hot wallet

function impersonateAccount(account) {
    return network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [account],
    })
}

async function setupMainnetContracts() {
    await network.provider.request({
        method: "hardhat_reset",
        params: [{
            forking: {
                jsonRpcUrl: 'https://bsc-dataseed.binance.org/',
                // blockNumber: 6368892
            }
        }]
    })

    ;([ nerve, nrvLP, masterMind, nrv ] = await Promise.all([
        ethers.getContractAt('INerve', '0x1B3771a66ee31180906972580adE9b81AFc5fCDc'),
        ethers.getContractAt('IERC20', '0xf2511b5e4fb0e5e2d123004b672ba14850478c14'),
        ethers.getContractAt('IMasterMind', '0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E'),
        ethers.getContractAt('IERC20', '0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096'),
    ]))

    const [ Core, NervePeak, UpgradableProxy, DUSD, Zap, ibDUSDProxy, ibDUSD ] = await Promise.all([
        ethers.getContractFactory('Core'),
        ethers.getContractFactory('NervePeak'),
        ethers.getContractFactory('UpgradableProxy'),
        ethers.getContractFactory('DUSD'),
        ethers.getContractFactory('Zap'),
        ethers.getContractFactory('ibDUSDProxy'),
        ethers.getContractFactory('ibDUSD'),
    ])
    core = await UpgradableProxy.deploy()
    dusd = await DUSD.deploy(core.address)
    await core.updateImplementation(
        (await Core.deploy(dusd.address)).address
    )
    core = await ethers.getContractAt('Core', core.address)
    redeemFactor = BigNumber.from(9990) // 0.1% fee
    await core.setFee(redeemFactor)

    ibdusd = await ibDUSDProxy.deploy()
    await ibdusd.updateImplementation(
        (await ibDUSD.deploy(core.address, dusd.address)).address
    )
    ibdusd = await ethers.getContractAt('ibDUSD', ibdusd.address)
    await ibdusd.setFee(redeemFactor)

    nervePeak = await UpgradableProxy.deploy()
    await nervePeak.updateImplementation(
        (await NervePeak.deploy(
            core.address,
            nerve.address,
            nrvLP.address,
            masterMind.address,
            nrv.address,
            '0xe9e7cea3dedca5984780bafc599bd69add087d56', // BUSD
            '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F' // pancake swap
        )).address
    )
    nervePeak = await ethers.getContractAt('NervePeak', nervePeak.address)
    await core.whitelistPeak(nervePeak.address, constants._1e18.mul(100))

    // [ BUSD, USDT, USDC ]
    const underlyingCoins = await Promise.all([
        ethers.getContractAt('IERC20', '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'),
        ethers.getContractAt('IERC20', '0x55d398326f99059fF775485246999027B3197955'),
        ethers.getContractAt('IERC20', '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'),
    ])
    zap = await Zap.deploy(
        nerve.address,
        nrvLP.address,
        nervePeak.address,
        dusd.address,
        ibdusd.address,
        underlyingCoins.map(u => u.address)
    )
    await impersonateAccount(whale)
    return { core, zap, dusd, ibdusd, nervePeak, redeemFactor, underlyingCoins }
}

function getCoins(erc20, account, amount) {
    return erc20.connect(ethers.provider.getSigner(whale)).transfer(account, amount)
}

module.exports = {
    constants,
    impersonateAccount,
    setupMainnetContracts,
    getCoins
}
