// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import {ethers} from "hardhat";

import * as IUniswapV2Factory from  "../abi/IUniswapV2Factory.json";
import * as ILendingPool from '../abi/ILendingPool.json';
import * as ILendingPoolAddressesProvider from '../abi/ILendingPoolAddressesProvider.json';
import * as IERC20 from '../abi/IERC20.json';
import * as IUniswapV2Pair from '../abi/IUniswapV2Pair.json';

const DAI_ADDR = '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD'; //DAI 合约地址
const POOL_PROV_ADDR = '0x88757f2f99175387aB4C6a4b3067c77A695b0349'; //aave地址获取地址

async function main(){
  const UniswapV2Factory =  await ethers.getContractAt(IUniswapV2Factory.abi, '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f');

  ethers.provider.on("block", async (blockNumber)=> {
    console.log("on block: ", blockNumber);
    
    // const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f';
    const daiAddress  = '0xff795577d9ac8bd7d90ee22b6c1703490b6512fd';
    // const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
    const wethAddress = '0xd0a1e359811322d97991e03f863a0c30c2cf029c';

    const uniswapEthDai = await ethers.getContractAt(IUniswapV2Pair.abi,
       await UniswapV2Factory.getPair(wethAddress, daiAddress));

    const uniswapReserves = await uniswapEthDai.getReserves();


    const reserve0Uni = Number(ethers.utils.formatUnits(uniswapReserves.reserve0, 18));
    const reserve1Uni = Number(ethers.utils.formatUnits(uniswapReserves.reserve1, 18));
    console.log(`reserve1Uni: ${reserve1Uni}, reserve0Uni: ${reserve0Uni}`);

    const priceUniswap = reserve0Uni / reserve1Uni;
    console.log("priceUniswap: ",  priceUniswap);

  });

  const addrProvider = await ethers.getContractAt(ILendingPoolAddressesProvider.abi, POOL_PROV_ADDR);
  const LendingPoolAddr = await addrProvider.getLendingPool();
  console.log("LendingPoolAddr: ", LendingPoolAddr);

  const LendingPool = await ethers.getContractAt(ILendingPool.abi, LendingPoolAddr);
  
  const daiToken = await ethers.getContractAt(IERC20.abi, DAI_ADDR);

  //授权
  const amount = '99';
  let tx = await daiToken.approve(LendingPool.address, ethers.utils.parseUnits(amount));
  console.log("approve successed: ", tx.hash);

  //存款
  const [signer] = await ethers.getSigners();
  console.log("signer: ", signer.address);
  await LendingPool.deposit(daiToken.address, 
    ethers.utils.parseUnits(amount),
    signer.address,
    '0');

  console.log("deposit success: ", tx.hash);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
