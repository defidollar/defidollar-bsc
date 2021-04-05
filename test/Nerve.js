const _1e18 = ethers.constants.WeiPerEther

const blockNumber = 6216992
const nrvLPWhale = '0xfe00888ff72e11b00437a13ff96965b44cbf7d47'

describe('Nerve', function() {
    before('setup contracts', async function() {
        await network.provider.request({
            method: "hardhat_reset",
            params: [{
                forking: {
                    jsonRpcUrl: `https://bsc-dataseed.binance.org/`,
                }
            }]
        })
        signers = await ethers.getSigners()
        alice = signers[0].address

        ;([ nerve, nrvLP, masterMind ] = await Promise.all([
            ethers.getContractAt('INerve', '0x1B3771a66ee31180906972580adE9b81AFc5fCDc'),
            ethers.getContractAt('IERC20', '0xf2511b5e4fb0e5e2d123004b672ba14850478c14'),
            ethers.getContractAt('IMasterMind', '0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E')
        ]))

        const [ Core, NervePeak, UpgradableProxy, DUSD ] = await Promise.all([
            ethers.getContractFactory('Core'),
            ethers.getContractFactory('NervePeak'),
            ethers.getContractFactory('UpgradableProxy'),
            ethers.getContractFactory('DUSD'),
        ])
        core = await UpgradableProxy.deploy()
        dusd = await DUSD.deploy(core.address)
        nervePeak = await NervePeak.deploy(core.address, nerve.address, nrvLP.address, masterMind.address)
        await core.updateImplementation(
            (await Core.deploy(dusd.address)).address
        )
        core = await ethers.getContractAt('Core', core.address)
        await core.whitelistPeak(nervePeak.address, _1e18.mul(100))
    })

    it('mint', async function() {
        const amount = _1e18.mul(10)
        await impersonateAccount(nrvLPWhale)
        await nrvLP.connect(ethers.provider.getSigner(nrvLPWhale)).transfer(alice, amount)

        await nrvLP.approve(nervePeak.address, amount)
        await nervePeak.mint(amount)
    })

    it('redeem', async function() {
        const amount = await dusd.balanceOf(alice)
        await nervePeak.redeem(amount)
    })
})

async function impersonateAccount(account) {
    await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [account],
    })
}
