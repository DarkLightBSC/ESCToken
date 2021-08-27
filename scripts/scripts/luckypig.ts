import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, utils } from "ethers";
import {ethers, network, run} from "hardhat"
import {LuckyPigABI} from "../abis/LuckyPig";


const luckypigAddress = "0x3A8049345c07473D5466778CcB5bec5D5F50EcDA";
const luckyhartAddress = "0x74Eb1E91086352Fe96720B46AFC2B3c89bb056ee";
const babyAddress = "0x422d394167F44C8f7F165B6DAF48e828cac4CA70";


const getLuckyPig = async():Promise<{account2:SignerWithAddress, LuckyPig:Contract}>=>{
	const [owner, account2] = await ethers.getSigners(); 


	console.log(`account2 is ${account2.address}`);

	const LuckyPig = ethers.ContractFactory.getContract(babyAddress, LuckyPigABI, owner);

	return {account2, LuckyPig};
}

const main = async (index:number, account2: SignerWithAddress, LuckyPig:Contract)=>{
	console.time();
	console.log(`main start is ${index}`)

	const tx = await LuckyPig.connect(account2).transfer("0xd3777Ff2e8e75cb86C2c897Ca4AD7e46d7f2a523", 100e9, {gasLimit: 181995, gasPrice: 5000000000});

	console.log(`tx hash is ${tx.hash}`);
	console.timeEnd();
	
	index -= 1;


	if(index>0){
		setTimeout(()=>{
			main(index, account2, LuckyPig)
		},1000)
	}
}

(async()=>{

	const {account2, LuckyPig} = await getLuckyPig();

	await main(200, account2, LuckyPig)
})();
