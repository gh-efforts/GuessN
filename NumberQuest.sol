// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NumberQuest {
    address public owner;
    uint256 public constant GUESS_FEE = 0.01 ether; // 猜测费用，使用tAI3
    uint256 public constant MAX_LEVEL = 100;        // 等级上限
    uint256 private secretNumber;                   // 全局随机数

    struct Explorer {
        uint256 level;     // 等级（每猜中1次+1）
        uint256 guessCount;// 参与次数
        uint256 lastGuess; // 上次猜测时间戳
    }

    mapping(address => Explorer) public explorers;

    event GuessResult(address player, uint256 guess, bool success, uint256 newLevel, uint256 reward);
    event Withdrawal(address indexed owner, uint256 amount);
    event Funded(address indexed funder, uint256 amount);

    constructor() payable {
        owner = msg.sender;
        secretNumber = generateRandomNumber();
    }

    function guess(uint256 _number) external payable {
        require(msg.value == GUESS_FEE, "Must send exactly 0.01 tAI3");
        require(_number >= 1 && _number <= 10, "Guess must be between 1 and 10");

        Explorer storage player = explorers[msg.sender];

        // 记录参与次数
        player.guessCount += 1;
        player.lastGuess = block.timestamp;

        if (_number == secretNumber) {
            uint256 reward = calculateReward(player.level == 0 ? 1 : player.level);
            require(address(this).balance >= reward, "Contract out of tAI3 for reward");

            // 猜中后升级（不超过100）
            if (player.level < MAX_LEVEL) {
                player.level += 1;
            }
            secretNumber = generateRandomNumber();
            payable(msg.sender).transfer(reward);
            emit GuessResult(msg.sender, _number, true, player.level, reward);
        } else {
            emit GuessResult(msg.sender, _number, false, player.level, 0);
        }
    }

    // 计算奖励：1级0.015 tAI3到100级0.05 tAI3
    function calculateReward(uint256 _level) private pure returns (uint256) {
        uint256 multiplier = 1500 + 35 * (_level - 1) / 99; // 1500 = 1.5倍，到100级0.05
        return (GUESS_FEE * multiplier) / 1000;             // 0.015到0.05 tAI3
    }

    // 生成随机数，范围1-10
    function generateRandomNumber() private view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender, block.timestamp))) % 10) + 1;
    }

    function getExplorerInfo(address _player) external view returns (uint256 level, uint256 guessCount, uint256 lastGuess) {
        Explorer memory player = explorers[_player];
        return (player.level, player.guessCount, player.lastGuess);
    }

    receive() external payable {
        require(msg.value > 0, "Must send some tAI3 to fund");
        emit Funded(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == owner, "Only owner can withdraw");
        require(_amount > 0, "Amount must be greater than 0");
        uint256 minReserve = 1 ether; // 保留1 tAI3
        require(address(this).balance >= _amount + minReserve, "Insufficient balance for withdrawal");
        
        payable(owner).transfer(_amount);
        emit Withdrawal(owner, _amount);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
