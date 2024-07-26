// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;

    IERC20 token;

    event EthToTokenSwap(address sender, string message, uint256 amountEth, uint256 amountToken);
    event TokenToEthSwap(address sender, string message, uint256 amountToken, uint256 amountEth);
    event LiquidityProvided(address sender, uint256 liquidityMinted, uint256 amountEth, uint256 tokenDeposit);
    event LiquidityRemoved(address sender, uint256 liquidityAmount, uint256 ethAmount, uint256 tokenAmount);

    constructor(address token_addr) {
        token = IERC20(token_addr);
    }

    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX: already initialized");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), tokens), "DEX: transfer failed");

        return totalLiquidity;
    }

    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = 997 * xInput;
        uint256 numerator = yReserves * xInputWithFee;
        uint denominator = 1000*xReserves + xInputWithFee;
        yOutput = numerator / denominator;

        return yOutput;
    }

    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }

    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "cannot swap 0 ETH");

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));
        
        tokenOutput = price(msg.value, ethReserve, tokenReserve);
        require(token.transfer(msg.sender, tokenOutput), "DEX: ethToToken swap failed");

        emit EthToTokenSwap(msg.sender, "Eth to Balloons", msg.value, tokenOutput);

        return tokenOutput;
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "cannot swap 0 tokens");

        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        ethOutput = price(tokenInput, tokenReserve, ethReserve);
        require(token.transferFrom(msg.sender, address(this), tokenInput), "DEX: tokenToEth swap failed to send tokens");

        (bool sentEth, ) = msg.sender.call{value: ethOutput}("");
        require(sentEth, "DEX: tokenToEth swap failed to send ETH");
        
        emit TokenToEthSwap(msg.sender, "Balloons to ETH", tokenInput, ethOutput);

        return ethOutput;
    }

    function deposit() public payable returns (uint256 tokenDeposit) {
        require(msg.value > 0, "DEX: deposit failed, no ETH sent");

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));

        tokenDeposit = (msg.value * tokenReserve / ethReserve) + 1;

        require(token.transferFrom(msg.sender, address(this), tokenDeposit));

        uint256 liquidityMinted = msg.value * totalLiquidity / ethReserve;
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenDeposit);

        return tokenDeposit;
    }

    function withdraw(uint256 liquidityAmount) public returns (uint256 ethAmount, uint256 tokenAmount) {
        require(liquidity[msg.sender] >= liquidityAmount, "DEX: withdraw failed, sender does not have enough liquidity");

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));
        ethAmount = liquidityAmount * ethReserve / totalLiquidity;
        tokenAmount = liquidityAmount * tokenReserve / totalLiquidity;

        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        (bool sent, ) = payable(msg.sender).call{ value: ethAmount }("");
        require(sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, tokenAmount));

        emit LiquidityRemoved(msg.sender, liquidityAmount, ethAmount, tokenAmount);
        
        return (ethAmount, tokenAmount);
    }
}