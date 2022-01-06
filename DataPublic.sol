// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library eAddr {
    uint constant owner = 1;
}

contract DataPublic   {
    mapping(address=>bool) private _isBindParent;
    mapping(address=>bool) private _mgr;
    mapping(uint=>address) private _dataAddr;
    mapping(address=>address) private _parent;
    mapping(address=>address[]) private _children;
    mapping (address=>BindRecord[]) private _bindRecord;
    mapping(address=>mapping(address=>uint256)) private _lpRebates;
    mapping(address=>mapping(address=>uint256)) private _gameRebates;
    mapping(address=>RevenuesRecord[]) private _revenuesRecord;
    
    struct BindRecord {
        uint256 blockTime;
        address child;
    }

    struct RevenuesRecord {
        uint8 tp;
        uint256 blockTime;
        uint256 amt;
    }

    modifier onlyMgr() {
        require(_mgr[msg.sender], 'mgr');
        _;
    }

    function init() public {
        require(_dataAddr[eAddr.owner] == address(0), "inited");
        _mgr[msg.sender] = true;
        _dataAddr[eAddr.owner] = msg.sender;
    }

    function getChildrenCount(address addr) public view returns (uint256) {
        return _children[addr].length;
    }

    function getChildren(address addr, uint256 from) public view returns(address[20] memory) {
        address[20] memory rs;
        uint256 index = 0;
        while (from < _children[addr].length && index < 20) {
            rs[index] = _children[addr][from];
            index++;
            from++;
        }
        return rs;
    }

    function getBindLogCount(address addr) public view returns (uint256) {
        return _bindRecord[addr].length;
    }

    function getBindRecord(address addr, uint256 from) public view returns (uint256[20] memory, address[20] memory, uint256[20] memory, uint256[20] memory) {
        uint256[20] memory times;
        address[20] memory addrs;
        uint256[20] memory gRebate;
        uint256[20] memory lpRebate;

        uint256 index = 0;
        while (index < 20 && from < _bindRecord[addr].length) {
            times[index] = _bindRecord[addr][from].blockTime;
            addrs[index] = _bindRecord[addr][from].child;
            gRebate[index] = _gameRebates[addr][addrs[index]]; 
            lpRebate[index] = _lpRebates[addr][addrs[index]];
            index++;
            from++;
        }

        return (times, addrs, gRebate, lpRebate); 
    }

    function setMgr(address addr, bool v) public onlyMgr {
        if (addr == _dataAddr[eAddr.owner]) {
            return;
        }
        if (_mgr[addr] == v) {
            return;
        }
        _mgr[addr] = v;
    }

    function getMgr(address addr) public view returns(bool) {
        return _mgr[addr];
    }

    function bind(address addr, address parent) private {
        _parent[addr] = parent;
        _isBindParent[addr] = true;
        if (parent == address(0)) {
            return;
        }
        _children[parent].push(addr);
        
        _bindRecord[parent].push(BindRecord({
            blockTime: block.timestamp,
            child: addr
        }));
    }

    function checkParent(address addr, address parent) public onlyMgr {
        if (addr == parent) {
            return;
        }
        if (_isBindParent[addr]) {
            return;
        }
        bind(addr, parent);
    }

    function bindParent(address addr, address parent) public onlyMgr {
        if (addr == parent) {
            return;
        }
        bind(addr, parent);
    }

    function getParent(address addr) public view returns (address, bool) {
        return (_parent[addr],_isBindParent[addr]);
    }

    function onChildWithdrawLp(address parent, address child, uint256 amt, uint256 pRebate, bool isReward) public onlyMgr {
        _lpRebates[parent][child] +=  pRebate;
        _revenuesRecord[child].push(RevenuesRecord({
            blockTime: block.timestamp,
            amt: amt,
            tp: isReward ? 1 : 2
        }));
    }

    function onWithdrawGameRebate(address addr,  uint256 rebate) public onlyMgr {
        _revenuesRecord[addr].push(RevenuesRecord({
            blockTime: block.timestamp,
            amt: rebate,
            tp: 3
        }));
    }

    function addGameRebate(address parent, address child, uint256 amt) public onlyMgr{
        _gameRebates[parent][child] += amt;
    }

    function getRebateFromChild(address parent, address child) public view returns(uint256, uint256) {
        return (_gameRebates[parent][child], _lpRebates[parent][child]);
    }


    function getRevenuesCount(address addr) public view returns(uint256) {
        return _revenuesRecord[addr].length;
    }

    function getRevenuesRecord(address addr, uint256 from) public view returns(uint256[20] memory, uint256[20] memory, uint8[20] memory) {
        uint256[20] memory times;
        uint256[20] memory amts;
        uint8[20] memory tps;
        uint256 index = 0;
        while (from < _revenuesRecord[addr].length && index < 20) {
            times[index] = _revenuesRecord[addr][from].blockTime;
            amts[index] = _revenuesRecord[addr][from].amt;
            tps[index] = _revenuesRecord[addr][from].tp;
            index++;
            from++;
        }
        return (times, amts, tps);
    }
}