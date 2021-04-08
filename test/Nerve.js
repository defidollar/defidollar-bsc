const { expect } = require("chai")

const {
    constants: { _1e18, ZERO },
    impersonateAccount,
    setupMainnetContracts,
} = require('./utils')

const nrvLPWhale = '0x3168082c31dc4b03ac752fb43d1c3bf8ae6ee9ae'

describe('Nerve', function() {
    before('setup contracts', async function() {
        signers = await ethers.getSigners()
        alice = signers[0].address
        bob = signers[1].address
        ;({ core, zap, dusd, ibdusd, nervePeak, redeemFactor, underlyingCoins } = await setupMainnetContracts());
        ;([ busd, tether] =  underlyingCoins)
    })

    it('mint', async function() {
        const amount = _1e18.mul(10)
        await impersonateAccount(nrvLPWhale)
        await nrvLP.connect(ethers.provider.getSigner(nrvLPWhale)).transfer(alice, amount)

        await nrvLP.approve(nervePeak.address, amount)
        await nervePeak.mint(amount)

        expect(
            await dusd.balanceOf(alice)
        ).to.eq(
            amount.mul(await nerve.getVirtualPrice()).div(_1e18)
        )
        expect(await nrvLP.balanceOf(alice)).to.eq(ZERO)
        expect(await nrvLP.balanceOf(nervePeak.address)).to.eq(ZERO) // staked
        expect(
            (await masterMind.userInfo(0, nervePeak.address)).amount
        ).to.eq(amount)
    })

    it('redeem', async function() {
        const amount = await dusd.balanceOf(alice)

        await nervePeak.redeem(amount)

        const nrvLPAmount = amount.mul(redeemFactor).div(1e4).mul(_1e18).div(await nerve.getVirtualPrice())
        expect(await nrvLP.balanceOf(alice)).to.eq(nrvLPAmount)
        expect(await dusd.balanceOf(alice)).to.eq(ZERO)
    })

    it('harvest', async function() {
        await core.authorizeHarvester(bob, true)
        await core.setHarvestBeneficiary(bob)
        await core.connect(ethers.provider.getSigner(bob)).harvest()
        // console.log((await masterMind.pendingNerve(0, nervePeak.address)).toString())
        // const bal = await nrvLP.balanceOf(nervePeak.address)
        // console.log((await nrvLP.balanceOf(nervePeak.address)).toString())
        // expect((await nrvLP.balanceOf(nervePeak.address)).gt(bal)).to.be.true
    })
})
