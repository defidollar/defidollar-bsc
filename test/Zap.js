const { BigNumber } = ethers

const { expect } = require("chai")

const {
    constants: { _1e18, ZERO },
    setupMainnetContracts,
    getCoins
} = require('./utils')

describe('Savings Zap', function() {
    before('setup contracts', async function() {
        ;({ underlyingCoins, dusd, ibdusd, zap } = await setupMainnetContracts())
        ;([ busd, tether] =  underlyingCoins)
        signers = await ethers.getSigners()
        alice = signers[0].address
    })

    it('deposit', async function() {
        const amount = _1e18.mul(10)
        await getCoins(tether, alice, amount)

        await tether.approve(zap.address, amount)
        await zap.deposit([0,amount,0], 0);

        expect(await dusd.balanceOf(alice)).to.eq(ZERO)
        expect(await tether.balanceOf(alice)).to.eq(ZERO)
        expect((await ibdusd.balanceOf(alice)).gt(ZERO)).to.be.true
    })

    it('withdraw', async function() {
        const bal = await ibdusd.balanceOf(alice)
        const amount = bal.div(2)

        await ibdusd.approve(zap.address, amount)
        await zap.withdraw(amount, 0, 0)

        expect((await busd.balanceOf(alice)).gt(ZERO)).to.be.true
        expect(await tether.balanceOf(alice)).to.eq(ZERO)
        expect(await ibdusd.balanceOf(alice)).to.eq(bal.sub(amount))
    })

    it('withdrawInAll', async function() {
        const amount = await ibdusd.balanceOf(alice)

        expect(await tether.balanceOf(alice)).to.eq(ZERO)

        await ibdusd.approve(zap.address, amount)
        await zap.withdrawInAll(amount, [0,0,0])

        underlyingCoins.forEach(async coin => {
            expect((await coin.balanceOf(alice)).gt(ZERO)).to.be.true
        })
        expect(await ibdusd.balanceOf(alice)).to.eq(ZERO)
    })
})
