import { ChainId, Fetcher, Pair, Route, Token, WETH, Trade,TokenAmount,TradeType, Percent, JSBI } from '@pancakeswap-libs/sdk-v2'
import { BigNumber } from 'ethers';
import { ethers, network } from 'hardhat';
import { IERC20_ABI } from '../abis/IERC20';
import { abi as IUniswapV2PairABI } from '../abis/IUniswapV2Pair.json'

import moment from 'moment'
const JSONdb = require('simple-json-db');
import * as fs from "fs";

import * as readLastLines from "read-last-lines";

//1. 获取价格

//bsc test
type TToken = {[key:number]:string}
const esctokenAddress:TToken= {56: "0xc2ce07b9c0B6916C9912Fb923bA0103906279e9E", 97: "0x0Dab0336C03154e1dA5e758A77bE2CD0d23e66ae"};
const usdtAddress:TToken    = {56: "0x55d398326f99059fF775485246999027B3197955", 97:"0x16A20c27eFA360C8DE31AADE8638BB2D16006332"};

//2. 获取流动池
const chainId = network.config.chainId!;
const provider = ethers.provider;

const getPrice = async():Promise<{price:string, liquid:string, marketCap:string}>=>{
	console.log(`provider is ${JSON.stringify(provider)}`)
	const [ signer ] = await ethers.getSigners();
    const ESCTToken = ethers.ContractFactory.getContract(esctokenAddress[chainId], IERC20_ABI, signer);
    //总供应量
    const totalSupply = await ESCTToken.totalSupply();
    console.log(`totalSupply is ${totalSupply}`)

	console.log(`chainId is ${chainId}`)

	const escToken:Token = new Token(chainId, esctokenAddress[chainId], 9);
	const usdtToken:Token = new Token(chainId, usdtAddress[chainId], 18);

	const pairAddress =Pair.getAddress(usdtToken, escToken);
	console.log(`pairAddress: ${pairAddress}`)

	const pairToken = ethers.ContractFactory.getContract(pairAddress, IUniswapV2PairABI, signer)

	const [reserve0, reserve1] = await pairToken.getReserves();

	console.log(`reserve0 is ${reserve0}, reserve1 is ${reserve1}`)

	const dec = '000000000'; // 精度
	const amountIn = `1000000${dec}`; // 100万 esct

	const tokens = [escToken, usdtToken]
  	const [token0, token1] = tokens[0].sortsBefore(tokens[1]) ? tokens : [tokens[1], tokens[0]]

  	const pair = new Pair(new TokenAmount(token0, reserve0), new TokenAmount(token1, reserve1))
	const route = new Route([pair], escToken)
	const trade = new Trade(route, new TokenAmount(escToken, amountIn), TradeType.EXACT_INPUT)

	// 除9位精度 * 1000000万 = 除 1000
	const price = trade.executionPrice.raw.divide(JSBI.BigInt(1000)).toSignificant(6);
	console.log(price)
	console.log(trade.nextMidPrice.toSignificant(6))

	const liquid = pair.reserve1.toSignificant(6);
	console.log(`liquid is ${liquid}`)

	//市值
	const marketCap = trade.executionPrice.raw.divide(JSBI.BigInt(1000)) // 100万个的价格
	.divide(JSBI.BigInt(1000000)) // 1个的价格
	.multiply(JSBI.BigInt(totalSupply)) // 总量
	.divide(JSBI.BigInt(1000000000)) // 精度
	.divide(JSBI.BigInt(2)) // 有一半打入了黑洞
	.toSignificant(6);

	console.log(`market cap is ${marketCap}`)

	return {price, liquid, marketCap};
}


let [lastPrice,lastLiquid, lastMarketCap] = ['','',''];

const saveToDB = async (time:string, price:string, liquid:string, marketCap:string)=>{
	//与上次数据相同，不记录
	if(lastPrice===price && lastLiquid===liquid && marketCap === lastMarketCap){
		return;
	}

	[lastPrice,lastLiquid,lastMarketCap] = [price, liquid, marketCap]

	const dbFile = "./db.csv";
	fs.writeFileSync(dbFile, `${time},${price},${liquid},${marketCap}\n`, {flag: 'a+'});
	const fileLines = await readLastLines.read(dbFile, 100, "utf-8");

	type ChartValue = {Date:string,value:number};
	let jsonFile:{price: Array<ChartValue>,liquid: Array<ChartValue>, marketCap: Array<ChartValue>} = 
		{price:[] , liquid: [], marketCap: []};

	const lines = fileLines.split(/\n/)
	for(let i =0; i < lines.length; ++i){
		const line = lines[i];
		const [time1, price1, liquid1, marketCap1 ] = line.split(",");
		if(time1 && price1 && liquid1 && marketCap1){
			jsonFile.price.push({
				Date: time1,
				value: parseFloat(price1)
			});
			jsonFile.liquid.push({
				Date: time1,
				value: parseFloat(liquid1)
			})
			jsonFile.marketCap.push({
				Date: time1,
				value: parseFloat(marketCap1)
			})
		}

	}

	try {
		fs.writeFileSync(process.env.jsonfile || '10days.json', JSON.stringify(jsonFile));
		console.log("JSON data is saved.");
	} catch (error) {
		console.error(error);
	}
}


(async()=>{
	setInterval(async ()=>{
		const {price,liquid,marketCap } = await getPrice();
		console.log(`${moment().format("YYYY-MM-DD hh:mm:ss")} price is ${price}, liquid is ${liquid}, marketCap is ${marketCap}`);
		await saveToDB(moment().format("YYYYMMDDhhmmss"),price,liquid,marketCap)
	}, 10*1000)
})();
