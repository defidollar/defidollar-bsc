require('@nomiclabs/hardhat-waffle')
require("@nomiclabs/hardhat-etherscan")

const PRIVATE_KEY = `0x${process.env.PRIVATE_KEY || '2c82e50c6a97068737361ecbb34b8c1bd8eb145130735d57752de896ee34c74b'}`

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    bsc: {
      url: 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      gasPrice: 5000000000, // 5 gwei
      accounts: [ PRIVATE_KEY ]
    }
  },
  solidity: {
    version: '0.6.10',
  },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN || ''}`
  },
  mocha: {
    timeout: 0
  }
};
