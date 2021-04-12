const { BigNumber } = require("@ethersproject/bignumber")

const _1e18 = ethers.constants.WeiPerEther

async function main() {
    const [ nerve, nrvLP, masterMind, nrv ] = await Promise.all([
        ethers.getContractAt('INerve', '0x1B3771a66ee31180906972580adE9b81AFc5fCDc'),
        ethers.getContractAt('IERC20', '0xf2511b5e4fb0e5e2d123004b672ba14850478c14'),
        ethers.getContractAt('IMasterMind', '0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E'),
        ethers.getContractAt('IERC20', '0x42F6f551ae042cBe50C739158b4f0CAC0Edb9096')
    ])

    const [ Core, NervePeak, UpgradableProxy, DUSD, Zap, ibDUSDProxy, ibDUSD ] = await Promise.all([
        ethers.getContractFactory('Core'),
        ethers.getContractFactory('NervePeak'),
        ethers.getContractFactory('UpgradableProxy'),
        ethers.getContractFactory('DUSD'),
        ethers.getContractFactory('Zap'),
        ethers.getContractFactory('ibDUSDProxy'),
        ethers.getContractFactory('ibDUSD')
    ])
    // core = await ethers.getContractAt('Core', '0xb6Dc09f820682B9318AE8900626136C6FfD9FdB6')
    core = await UpgradableProxy.deploy()
    console.log({ core: core.address })

    // dusd = await ethers.getContractAt('DUSD', '0x154C28BA3736ee4e5E89E0081a00F04ec67992F0')
    dusd = await DUSD.deploy(core.address)
    console.log({ dusd: dusd.address })

    // _core = await ethers.getContractAt('Core', '0xe449ca7d10b041255e7e989d158bee355d8f88d3')
    _core = await Core.deploy(dusd.address)
    await core.updateImplementation(_core.address)
    core = await ethers.getContractAt('Core', core.address)

    // ibdusd = await ethers.getContractAt('ibDUSD', '0x4EaC4c4e9050464067D673102F8E24b2FccEB350')
    ibdusd = await ibDUSDProxy.deploy()
    console.log({ ibdusd: ibdusd.address })

    _ibdusd = await ibDUSD.deploy(core.address, dusd.address)
    await ibdusd.updateImplementation(_ibdusd.address)
    ibdusd = await ethers.getContractAt('ibDUSD', ibdusd.address)

    // nervePeak = await ethers.getContractAt('NervePeak', '0x3889Af04B5C761D7B6d5b2679abFd5A4cc9E4F09')
    nervePeak = await NervePeak.deploy(
        core.address,
        nerve.address,
        nrvLP.address,
        masterMind.address,
        nrv.address,
        '0xe9e7cea3dedca5984780bafc599bd69add087d56', // BUSD
        '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F' // pancake swap
    )
    console.log({ nervePeak: nervePeak.address })

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
    zap = await ethers.getContractAt('Zap', '0x6972Eb9c09db9AC5Ff25ce4102daa08297890738')
    console.log({ zap: zap.address })

    await core.setFee(9990) // 0.1% fee
    await core.whitelistPeak(nervePeak.address, _1e18.mul(3000000))
    await core.authorizeHarvester('0x08F7506E0381f387e901c9D0552cf4052A0740a4', true)
    await core.setHarvestBeneficiary(ibdusd.address)
    await ibdusd.setFee(9950) // 0.5% fee
}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
})
