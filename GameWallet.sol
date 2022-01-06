// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./TransferHelper.sol";
import "./IBEP20.sol";

contract GameWallet  {
    using SafeMath for uint256;
    using TransferHelper for address;

    mapping(address => uint256) private _balances;
    address private _token;
    address private _game;
    constructor(address token) {
        _token = token;
        _game = msg.sender;
    }

    function addBalance(address addr, uint256 amt) public {
        require(msg.sender == _game,"g");
        _balances[addr] = _balances[addr].add(amt);
    }

    function decBalance(address addr, uint256 amt) public {
        require(msg.sender == _game, "g");
        require(_balances[addr] >= amt);
        _balances[addr] = _balances[addr].sub(amt);
    }

    function withdrawlByAmt(address addr, uint256 amt) public returns(uint256) {
        require(msg.sender == _game,"g");
        require(amt > 0 && amt <= _balances[addr], "amt");
        if (amt > 0) {
            _balances[addr] = _balances[addr].sub(amt);
            _token.safeTransfer(addr, amt);
        }
        return amt;
    }

    function withdrawl(address addr, uint256 percent) public returns(uint256)  {
        require(msg.sender == _game,"g");
        require(percent > 0 && percent <= 100, "percent");
        uint256 amt = _balances[addr].mul(percent).div(100);
        if (amt > 0) {
            _balances[addr] = _balances[addr].sub(amt);
            _token.safeTransfer(addr, amt);
        }
        return amt;
    }

    function getBalance(address addr) public view returns (uint256) {
        return _balances[addr];
    }
    
    function burn(uint256 amt) public {
        require(msg.sender == _game,"g");
        IBEP20(_token).burn(amt);
    }

    function sendRebate(address addr, uint256 amt) public {
        require(msg.sender == _game,"g");
         _token.safeTransfer(addr, amt);
    }
    
    function sendFee(address addr, uint256 amt) public {
         require(msg.sender == _game,"g");
         _token.safeTransfer(addr, amt);
    }

}