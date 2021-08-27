import { utils } from "ethers";
import {ethers, run} from "hardhat"



async function main() {
    let Greeter = await ethers.getContractFactory("GDLToken");
    let greeter = await Greeter.deploy(10e9);

    await greeter.deployed();

    console.log(`token address is ${greeter.address}`);

    await run("verify:verify", {
        address: greeter.address,
        constructorArguments: [
            10e9
        ],
      })
}


main()