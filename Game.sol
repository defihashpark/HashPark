// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./TransferHelper.sol";
import "./IBEP20.sol";
import "./GameWallet.sol";



interface IDataPublic {
    function checkParent(address addr, address parent) external;
    function getParent(address addr) external view returns (address, bool);
    function addGameRebate(address addr, address child, uint256 amt) external;
}

// address data index
library eAddr {
    uint constant owner = 1;
    uint constant hpcAddr = 2;
    uint constant feeAddr = 3;
    uint constant dataPublic = 4;
}

// uint256 data index
library eUint256 {
    uint constant fee = 1;
    uint constant feeBurn = 2;
    uint constant feeToParent = 3;
    uint constant feeToOwner = 4;
    uint constant startBlock = 5;
    uint constant openBlock = 6;
    uint constant curFee = 7;
    uint constant curBurn = 8;
    uint constant totalBet = 9;
    uint constant totalWin = 10;
    uint constant totalBurn = 11;
}

// boolean data index
library eBool {
    uint constant isOpen = 1;
    uint constant issueLock = 2;
}

// 
library eBet {
    uint8 constant odd = 1;
    uint8 constant even = 2;
    uint8 constant small = 3;
    uint8 constant big = 4;
    uint8 constant oddBig = 5;
    uint8 constant oddSmall = 6;
    uint8 constant evenBig = 7;
    uint8 constant evenSmall = 8;
    uint8 constant r2 = 9;
    uint8 constant r3 = 10;
    uint8 constant num0 = 11;
    uint8 constant num1 = 12;
    uint8 constant num2 = 13;
    uint8 constant num3 = 14;
    uint8 constant num4 = 15;
    uint8 constant num5 = 16;
    uint8 constant num6 = 17;
    uint8 constant num7 = 18;
    uint8 constant num8 = 19;
    uint8 constant num9 = 20;
}

// the game contract
contract Game  {
    using SafeMath for uint256;
    using TransferHelper for address;

    mapping(uint => uint256) private _dataUint256;
    mapping(uint => address) private _dataAddr;
    mapping(uint => bool) private _dataBool;
    mapping(address => bool) private _userLock;
    mapping(address => bool) private _mgrs;
    mapping(uint8 => uint256) private _mutiple;
    mapping(uint256=>IssueBet) private _issueBets;
    mapping(address => uint256) private _rebate;
    mapping(address=>uint256[]) private _betBlocks; 
    mapping(uint256=>uint256) private _dayBurnLog;

    GameWallet private _wallet;
    
    
    struct AddrBet {
        mapping(uint8=>uint256) bets;
        uint256 totalWin;
        uint256 totalBet;
        uint256 timestamp;
    }
    struct IssueBet {
        uint256 lastSettleIndex;
        address[] betAddrs;
        mapping(address=>AddrBet) betInfo;
        uint8[] result;
    }

    constructor(){
    }

    // modifier lockAddr(address user) {
    //     // On the first call to nonReentrant, _notEntered will be true
    //     require(!_userLock[user], "lock");

    //     // Any calls to nonReentrant after this point will fail
    //     _userLock[user] = true;

    //     _;

    //     // By storing the original value once again, a refund is triggered (see
    //     // https://eips.ethereum.org/EIPS/eip-2200)
    //     _userLock[user] = false;
    // }

    
    event Bet(address user, uint256 amt);
    event NewIssue(uint256 startBlock, uint256 openBlock);
    event Withdrawl(address addr, uint256 percent, uint256 amt);
    event WithdrawlRebate(address addr,  uint256 amt);
    function init(
        address[3] memory addrs
    ) public {
        require(_dataAddr[eAddr.owner] == address(0), "inited");
        _dataAddr[eAddr.owner] = msg.sender;
        _dataAddr[eAddr.hpcAddr] = addrs[0];
        _dataAddr[eAddr.feeAddr] = addrs[1];
        _dataAddr[eAddr.dataPublic] = addrs[2];

        _mgrs[msg.sender] = true;
        _wallet = new GameWallet(addrs[0]);

        // scale 1e4
        //10
        for (uint8 i = eBet.num0; i <= eBet.num9; i++) {
            _mutiple[i] = 100000;
        }
        //2
        for (uint8 i = eBet.odd; i <= eBet.big; i++) {
            _mutiple[i] = 20000;
        }
        //10
        _mutiple[eBet.r2] = 100000;
        //100
        _mutiple[eBet.r3] = 1000000;
        //5
        _mutiple[eBet.evenBig] = 50000;
        //5
        _mutiple[eBet.oddSmall] = 50000;
        //3.3
        _mutiple[eBet.oddBig] = 33000;
        //3.3
        _mutiple[eBet.evenSmall] = 33000;

     
        //scale 10000
        // fee : 3%
        _dataUint256[eUint256.fee] = 300;
        _dataUint256[eUint256.feeBurn] = 100;
        _dataUint256[eUint256.feeToParent] = 100;
        _dataUint256[eUint256.feeToOwner] = 100;
    }

    function getToday() private view returns (uint256) {
        uint256 cur = uint256(block.timestamp);
        return cur - (cur % 86400);
    }
    
    function setMutiple(uint8 t, uint256 m) public {
        require(_mgrs[msg.sender], "mgr");
        if (_mutiple[t] != m) {
            _mutiple[t] = m;
        }
    }
    
    function getMutiple(uint8 t) public view returns(uint256) {
        return _mutiple[t];
    }
    
    function setUint256(uint idx, uint256 value) public {
        require(_mgrs[msg.sender], "mgr");
        if (_dataUint256[idx] != value) {
            _dataUint256[idx] = value;
        }
    }
    
    function getUint256(uint idx) public view returns(uint256) {
        return _dataUint256[idx];
    }
    
    function getUint256s() public view returns(uint256[11] memory) {
        uint256[11] memory rs ;
        for (uint i = 0; i < 11; i++) {
            rs[i] = _dataUint256[i + 1];
        }
        return rs;
    }

    function getMgr(address addr) public view returns(bool) {
        return _mgrs[addr];
    }

    function setMgr(address addr, bool v) public {
        require(_mgrs[msg.sender], "mgr");
        if (addr == _dataAddr[eAddr.owner]) {
            return;
        }
        if (_mgrs[addr] != v) {
            _mgrs[addr] = v;
        }
    }

    function setEnable(bool v) public {
        require(_mgrs[msg.sender], "mgr");
        if (_dataBool[eBool.isOpen] != v) {
            _dataBool[eBool.isOpen] = v;
        }
    }
    
    function getBool(uint idx) public view returns(bool) {
        return _dataBool[idx];
    }
    
    function getBetCount(address addr) public view returns(uint256) {
        return _betBlocks[addr].length;
    }
    
    function getBetBlocks(address addr, uint from) public view returns(uint256[20] memory) {
        uint256[20] memory rs;
        for (uint i = from; i < _betBlocks[addr].length && i < from + 20; i++) {
            rs[i - from] = _betBlocks[addr][i];
        }
        return rs;
    }
    
    function getBetBlock(address addr, uint256 startBlock) public view returns(uint256[26] memory) {
        uint256[26] memory rs ;
        for (uint8 i = eBet.odd; i <= eBet.num9; i++) {
            rs[i - 1] = _issueBets[startBlock].betInfo[addr].bets[i];
        }
        rs[20] = _issueBets[startBlock].betInfo[addr].totalBet;
        rs[21] = _issueBets[startBlock].betInfo[addr].totalWin;
        rs[22] = _issueBets[startBlock].betInfo[addr].timestamp;
        if (_issueBets[startBlock].result.length == 3){
            rs[23] = _issueBets[startBlock].result[0];
            rs[24] = _issueBets[startBlock].result[1];
            rs[25] = _issueBets[startBlock].result[2];
        }
        
        return rs;
    }

    function getIssueInfo() public view returns (uint256[4] memory) {
        uint256[4] memory rs ;
        rs[0] = _dataUint256[eUint256.startBlock];
        rs[1] = _dataUint256[eUint256.openBlock];
        rs[2] = _issueBets[_dataUint256[eUint256.startBlock]].betAddrs.length;
        rs[3] = _issueBets[_dataUint256[eUint256.startBlock]].lastSettleIndex;
        return rs;
    }

    function caculateBlock() private view returns (uint256 startBlock,  uint256 openBlock){
        uint256 b = uint256(block.number);
        uint256 m = b.div(40);
        startBlock = m.mul(40);
        openBlock = startBlock + 40;
    }

    function recharge(uint256 amount) public /*lockAddr(msg.sender)*/ {
        _dataAddr[eAddr.hpcAddr].safeTransferFrom(msg.sender, address(_wallet), amount);
        _wallet.addBalance(msg.sender, amount);
    }

    function withdrawl(uint256 percent) public /*lockAddr(msg.sender)*/  {
        uint256 amt = _wallet.withdrawl(msg.sender, percent);
        emit Withdrawl(msg.sender, percent, amt);
    }

    function withdrawlByAmt(uint256 amt) public  /*lockAddr(msg.sender)*/  {
        _wallet.withdrawlByAmt(msg.sender, amt);
        emit Withdrawl(msg.sender, 100, amt);
    }

    //get user balance
    function balanceOf(address addr) public view returns (uint256 balance) {
        balance = _wallet.getBalance(addr);
    }
    
    function getAddrInfo(address addr) public view returns (uint256[2] memory) {
        uint256[2]   memory rs ;
        rs[0] = _wallet.getBalance(addr);
        rs[1] = _rebate[addr];
        return rs;
    }
    
    function withdrawlRebate() public /*lockAddr(msg.sender)*/ {
        if (_rebate[msg.sender] == 0) {
            return;
        }
        uint256 amt = _rebate[msg.sender];
        _rebate[msg.sender] = 0;
        _wallet.sendRebate(msg.sender, amt);
       emit WithdrawlRebate(msg.sender, amt);
    }

 
    
    function incRebate(address parent, uint256 amt, address child) private /*lockAddr(parent)*/ {
        _rebate[parent] = _rebate[parent].add(amt);
        IDataPublic(_dataAddr[eAddr.dataPublic]).addGameRebate(parent, child, amt);
    }

    function calIssue() private {
        require(!_dataBool[eBool.issueLock], "L");
        _dataBool[eBool.issueLock] = true;
        if (_dataUint256[eUint256.startBlock] != 0) {
            _dataBool[eBool.issueLock] = false;
            return;
        }
        (uint256 startBlock,  uint256 openBlock) = caculateBlock();
        _dataUint256[eUint256.startBlock] = startBlock;
        _dataUint256[eUint256.openBlock] = openBlock;
        emit NewIssue(startBlock, openBlock);
        _dataBool[eBool.issueLock] = false;
        
    }

    function bet(uint8[] memory betTypes,  uint256[] memory amts, address parent) public /*lockAddr(msg.sender) */  {
        require(_dataBool[eBool.isOpen], "not open");
        calIssue();

        uint256 b = uint256(block.number);
        uint256 startBlock = _dataUint256[eUint256.startBlock];
        require(startBlock>0);

        require(b > startBlock  && b < _dataUint256[eUint256.openBlock], "block");
        require(betTypes.length == amts.length, "arg");
        IDataPublic(_dataAddr[eAddr.dataPublic]).checkParent(msg.sender, parent);
        
        // bool isFind = false;
        if (_issueBets[startBlock].betInfo[msg.sender].totalBet == 0) {
            _issueBets[startBlock].betAddrs.push(msg.sender);
            _issueBets[startBlock].betInfo[msg.sender].timestamp = block.timestamp;
        }
        // for (uint256 i = 0; i < _issueBets[startBlock].betAddrs.length; i++) {
        //     if (_issueBets[startBlock].betAddrs[i] == msg.sender) {
        //         isFind = true;
        //         break;
        //     }
        // }
        // if (!isFind) {
        //     _issueBets[startBlock].betAddrs.push(msg.sender);
        // }
        uint256 total = 0;
        for (uint256 i = 0; i < betTypes.length; i++) {
            if (amts[i] > 0) {
                _issueBets[startBlock].betInfo[msg.sender].bets[betTypes[i]] = _issueBets[startBlock].betInfo[msg.sender].bets[betTypes[i]].add(amts[i]);
                total = total.add(amts[i]);
            }
        }
        require(total > 0, "bet");
        _issueBets[startBlock].betInfo[msg.sender].totalBet = _issueBets[startBlock].betInfo[msg.sender].totalBet.add(total);
        _wallet.decBalance(msg.sender, total);
        emit Bet(msg.sender, total);
    }


    function settle(uint256 startBlock, address addr,  uint8[3] memory result, uint256 d) private /*lockAddr(addr)*/ {
        if (addr == address(0)) {
            return;
        }
        uint256 totalBet = _issueBets[startBlock].betInfo[addr].totalBet;
        if (totalBet == 0) {
            return;
        }
        uint256 win = 0;
        uint256 notWinBet = 0;
        
        for (uint8 i = eBet.odd; i <= eBet.num9; i++) {
            uint256 amt = _issueBets[startBlock].betInfo[addr].bets[i];
            if (amt == 0) {
                continue;
            }
            bool isWin = false;
            if (i == eBet.odd) {
                isWin = result[2] % 2 == 1;
            } else if (i == eBet.even) {
                isWin = result[2] % 2 == 0;
            } else if (i == eBet.small) {
                isWin = result[2] <= 4;
            } else if (i == eBet.big) {
                isWin = result[2] >= 5;
            } else if (i == eBet.oddBig) {
                isWin = result[2] == 5 || result[2] == 7 || result[2] == 9;
            } else if (i == eBet.oddSmall) {
                isWin = result[2] == 1 || result[2] == 3;
            } else if (i == eBet.evenBig) {
                isWin = result[2] == 6 || result[2] == 8;
            } else if (i == eBet.evenSmall) {
                isWin = result[2] == 0 || result[2] == 2 || result[2] == 4;
            } else if (i == eBet.r2) {
                isWin =  result[2] == result[1];
            } else if (i == eBet.r3) {
                isWin = result[2] == result[1] && result[1] == result[0];
            } else if (i >= eBet.num0 && i <= eBet.num9) {
                isWin =  result[2] == (i - eBet.num0);
            } 

            if (isWin) {
                win = win.add(amt.mul(_mutiple[i]).div(10000));
            } else {
                notWinBet = notWinBet.add(amt);
            }
        }

        // win = win.mul(10000 - _dataUint256[eUint256.fee]).div(10000);
        if (win > 0) {
            uint256 actualWin = win.mul(10000 - _dataUint256[eUint256.fee]).div(10000);

            _issueBets[startBlock].betInfo[addr].totalWin = _issueBets[startBlock].betInfo[addr].totalWin.add(actualWin);
            _wallet.addBalance(addr, actualWin);
            _dataUint256[eUint256.totalWin] = _dataUint256[eUint256.totalWin].add(actualWin);
        }

        
        uint256 fee = notWinBet.add(win);
        if (fee > 0) {
            uint256 feeToOwner = fee.mul(_dataUint256[eUint256.feeToOwner]).div(10000);
            if (feeToOwner > 0) {
                // _wallet.sendFee(_dataAddr[eAddr.feeAddr], feeToOwner);
                _dataUint256[eUint256.curFee] = _dataUint256[eUint256.curFee].add(feeToOwner);
            }

            uint256 feeToParent = fee.mul(_dataUint256[eUint256.feeToParent]).div(10000);
            if (feeToParent > 0){
                (address parent,) = IDataPublic(_dataAddr[eAddr.dataPublic]).getParent(addr);
                if (parent != address(0)) {
                    incRebate(parent, feeToParent, addr);
                }
            }

            uint256 feeBurn = fee.mul(_dataUint256[eUint256.feeBurn]).div(10000);
            if (feeBurn > 0) {
                // _wallet.burn(burn);
                _dataUint256[eUint256.curBurn] = _dataUint256[eUint256.curBurn].add(feeBurn);
                _dataUint256[eUint256.totalBurn] = _dataUint256[eUint256.totalBurn].add(feeBurn);
                _dayBurnLog[d] = _dayBurnLog[d].add(feeBurn);
            }
        }
    
        // _issueBets[startBlock].betInfo[addr].timestamp = block.timestamp;
        _dataUint256[eUint256.totalBet] = _dataUint256[eUint256.totalBet].add(totalBet);
        
        _betBlocks[addr].push(startBlock);
    }

    function doSettle(uint256 startBlock, uint256 from, uint256 to, uint8[3] memory result, bool isFinish) public {
        require(_mgrs[msg.sender], "mgr");
        uint256 today = getToday();
        for (uint256 i = from; i <= to && i < _issueBets[startBlock].betAddrs.length; i++) {
            address addr = _issueBets[startBlock].betAddrs[i];
            settle(startBlock, addr,  result, today);
        }
        _issueBets[startBlock].lastSettleIndex = to;
        if (isFinish) {
            _dataUint256[eUint256.startBlock] = 0;
        }
        if (_issueBets[startBlock].result.length == 0) {
            _issueBets[startBlock].result.push(result[0]);
            _issueBets[startBlock].result.push(result[1]);
            _issueBets[startBlock].result.push(result[2]);
        }
    }

    function doASettle(uint256 startBlock, address addr, uint8[3] memory result) public {
        require(_mgrs[msg.sender], "mgr");
        uint256 today = getToday();
        settle(startBlock, addr,  result, today);
    }
    
    function sendFeeAndBurn() public  {
        require(_mgrs[msg.sender], "owner");
        if (_dataUint256[eUint256.curFee] > 0) {
            _wallet.sendFee(_dataAddr[eAddr.feeAddr], _dataUint256[eUint256.curFee]);
            _dataUint256[eUint256.curFee] = 0;
        }
        if (_dataUint256[eUint256.curBurn] > 0) {
            _wallet.burn(_dataUint256[eUint256.curBurn]);
            _dataUint256[eUint256.curBurn] = 0;
        }
    }
    
    function getFeeAndBurn() public view returns(uint256[2] memory) {
        uint256[2] memory rs;
        rs[0] = _dataUint256[eUint256.curFee];
        rs[1] = _dataUint256[eUint256.curBurn];
        return rs;
    }
    
    function getWallet() public view returns(address) {
        return address(_wallet);
    }

    function getWinAddrs(uint256 startBlock, uint256 from) public view returns (uint256, address[20] memory, uint256[20] memory) {
        uint256[20] memory wins;
        address[20] memory addrs;
        uint256 idx = 0;
        while (from < _issueBets[startBlock].betAddrs.length && idx < 20) {
            address addr = _issueBets[startBlock].betAddrs[from];
            from++;
            if (_issueBets[startBlock].betInfo[addr].totalWin > 0) {
                wins[idx] = _issueBets[startBlock].betInfo[addr].totalWin;
                addrs[idx] = addr;
                idx++;
            }
        }
        return (from, addrs, wins);
    }

    function getTodayBurn() public view returns (uint256, uint256) {
        uint256 today = getToday();
        return (_dayBurnLog[today], _dataUint256[eUint256.totalBurn]);
    }

    function getDayBurn(uint256 d) public view returns (uint256, uint256) {
        return (_dayBurnLog[d],  _dataUint256[eUint256.totalBurn]);
    }
}