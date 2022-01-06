// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TransferHelper.sol";
import "./SafeMath.sol";

library eAddr {
    uint constant owner = 1;
    uint constant hpc = 2;
    uint constant lpContract = 3;
}

library eUint256 {
    // scale 1e10
    uint constant developerRate = 1;
    uint constant developerMint = 2;
    uint constant developerBalance = 3;
    uint constant lpMint = 4;
}

// HPC-LP miner pool 
contract MinerPool
{
    using TransferHelper for address;
    using SafeMath for uint256;

    // for game and LP
    mapping(address=>bool) _mgr;
    mapping(uint=>address) _dataAddr;
    mapping(uint=>uint256) _dataUint256;
    mapping(uint256=>uint256) _dayMintLog;
   
  
    modifier onlyMgr() {
        require(_mgr[msg.sender], "owner");
        _;
    }

    function init(address hpc, uint256 developerRate) public {
        require(_dataAddr[eAddr.owner] == address(0) ,"Inited");
        _dataAddr[eAddr.owner] = msg.sender;
        _dataAddr[eAddr.hpc] = hpc;
        _dataUint256[eUint256.developerRate] = developerRate;
        _mgr[msg.sender] = true;
    }

    function getAddr(uint idx) public view returns(address) {
        return _dataAddr[idx];
    }

    function setAddr(uint idx, address v) public onlyMgr  {
        if (_dataAddr[idx] != v){
            _dataAddr[idx] = v;
        }
    }

    function setUint256(uint idx, uint256 v) public onlyMgr {
        if (_dataUint256[idx] != v) {
            _dataUint256[idx] = v;
        }
    }

    function getUint256(uint idx) public view returns(uint256){
        return _dataUint256[idx];
    }

    function getUint256s() public view returns(uint256[4] memory) {
        uint256[4] memory rs;
        rs[0] = _dataUint256[eUint256.developerRate];
        rs[1] = _dataUint256[eUint256.developerMint];
        rs[2] = _dataUint256[eUint256.developerBalance];
        rs[3] = _dataUint256[eUint256.lpMint];
        return rs;
    }

    function sendOut(address to,uint256 amount) public onlyMgr  {
        _dataAddr[eAddr.hpc].safeTransfer(to, amount);
    }

    function getToday() private view returns (uint256) {
        uint256 cur = uint256(block.timestamp);
        return cur - (cur % 86400);
    }

    function onMint(uint256 mintAmt, uint256 devMintAmt, bool isInc) private  {
        if (isInc) {
            _dataUint256[eUint256.lpMint] = _dataUint256[eUint256.lpMint].add(mintAmt);
            _dataUint256[eUint256.developerMint] = _dataUint256[eUint256.developerMint].add(devMintAmt);
            _dataUint256[eUint256.developerBalance] = _dataUint256[eUint256.developerBalance].add(devMintAmt);
            uint256 today = getToday();
            _dayMintLog[today] = _dayMintLog[today].add(mintAmt).add(devMintAmt);
        } else {
            _dataUint256[eUint256.developerBalance] = _dataUint256[eUint256.developerBalance].subBe0(devMintAmt);
        }
    }

    function mineOut(address to,uint256 amount) public  {
        require(msg.sender == _dataAddr[eAddr.lpContract], "L");

        uint256 rate = _dataUint256[eUint256.developerRate];
        uint256 mintAmt = amount.mul(rate).div(1e10);
   
        onMint(amount, mintAmt, true);
        _dataAddr[eAddr.hpc].safeTransfer(to, amount);
    }

    function developerMint(address to) public onlyMgr {
        uint256 amount = _dataUint256[eUint256.developerBalance];
        if (amount == 0) {
            return;
        }
        onMint(0, amount, false);

        _dataAddr[eAddr.hpc].safeTransfer(to, amount);
    }

    function setMgr(address addr, bool v) public onlyMgr {
        if (addr == _dataAddr[eAddr.owner]) {
            return;
        }
        if (_mgr[addr] != v) {
            _mgr[addr] = v;
        }
    }

    function getMgr(address addr) public view returns(bool) {
        return _mgr[addr];
    }

    function getTodayMint() public view returns(uint256) {
        uint256 today = getToday();
        return _dayMintLog[today];
    }

    function getDayMint(uint256 d) public view returns(uint256) {
        return _dayMintLog[d];
    }
}