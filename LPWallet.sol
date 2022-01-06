// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
import "./SafeMath.sol";
import "./TransferHelper.sol";
import "./IBEP20.sol";

//https://docs.venus.io/docs/getstarted#guides
interface IVToken {
    function underlying() external returns (address);
    // for bep20
    function mint(uint256 mintAmount) external  returns (uint256);
    //for BNB
    function mint() external  payable ;
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
}



contract LpWallet 
{
    using TransferHelper for address;
    using SafeMath for uint256;

    address _token;
    address _mainContract;
    uint256 _total;
    address _owner;
    address _vToken;
    mapping(address=>uint256) _balances;

    constructor(address token, address owner, address vToken) {
        _mainContract = msg.sender;
        _token = token;
        _owner = owner;
        _vToken = vToken;

        if (vToken != address(0) && _token != address(2)) {
            // only call once
            _token.safeApprove(vToken, type(uint256).max);
        }
    }

    // for receive BNB
    receive() external payable { }

    // for main contract update
    function setMainContract(address newContract) public {
        require(msg.sender == _owner);
        _mainContract = newContract;
    }

    function getMainContract() public view returns (address) {
        return _mainContract;
    }

    function setVToken(address vToken) public {
        require(_mainContract == msg.sender);
        if (vToken != address(0) && _token != address(2) && vToken != _vToken) {
            // only call once
            _token.safeApprove(vToken, type(uint256).max);
        }
        if (_vToken != vToken) {
            _vToken = vToken;
        }
    }

    function approveVToken(bool isApprove) public {
        require(_mainContract == msg.sender);
        if (_vToken == address(0) || _token == address(2)) {
            return;
        }
        if (isApprove) {
             _token.safeApprove(_vToken, type(uint256).max);
         } else {
             _token.safeApprove(_vToken, 0);
         }
    }
    
    function deposite(address addr, uint256 amt) public payable {
        require(_mainContract == msg.sender, "owner");
        _balances[addr] = _balances[addr].add(amt);
        _total = _total.add(amt);

        // Venus 
        if (_vToken != address(0)) {
            if (_token != address(2)) {
                uint256 code = IVToken(_vToken).mint(amt);
                require(code == 0, "Venus");
            } else {
                IVToken(_vToken).mint{value: amt}();
            }
        }
    }
    
    function getBalance(address addr) public view returns (uint256){
        return _balances[addr];
    }
    
    function getTotalLp() public view returns (uint256) {
        return _total;
    }

    function redeemForTakeBack(uint256 amount) internal {
        if (_vToken == address(0)) {
            return;
        }
        // check balance 
        uint256 balance = 0;
        //BNB
        if(_token != address(2)) {
            balance = IBEP20(_token).balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        if (balance >= amount) {
            return;
        }
        
        uint256 code = IVToken(_vToken).redeemUnderlying(amount);
        require(code == 0, "Venus");
    }
    
    function takeBack(address addr, uint256 amt) public returns(uint256)  {
        require(_mainContract == msg.sender, "owner");
        require(amt <=  _balances[addr], "B");

        redeemForTakeBack(amt);

        _total = _total.subBe0(amt);
        _balances[addr] = _balances[addr].sub(amt);
        if(_token != address(2)) {
            _token.safeTransfer(addr, amt);
        } else {
            // BNB
            (bool success, ) = addr.call{value: amt}(new bytes(0));
            require(success, "TransferHelper: BNB_TRANSFER_FAILED");
        }
        return _balances[addr];
    }

    function reedeemFromVenus(address to) public {
        require(_mainContract == msg.sender || msg.sender == _owner);
        if (_vToken == address(0)) {
            return;
        }
        uint256 balance = IBEP20(_vToken).balanceOf(address(this));
        if (balance == 0) {
            return;
        }
        uint256 code = IVToken(_vToken).redeem(balance);
        require(code == 0, "Venus");

        uint256 curBalance = 0;
        if (_token == address(2)) {
            curBalance = address(this).balance;
        } else {
            curBalance = IBEP20(_token).balanceOf(address(this));
        }
        if (curBalance <= _total) {
            return;
        }
        uint256  earnings = curBalance.subBe0(_total);
        if (_token == address(2)) {
            (bool success, ) = to.call{value: earnings}(new bytes(0));
            require(success, "BNB_TRANSFER_FAILED");
        } else {
            _token.safeTransfer(to, earnings);
        }
    }


    function depositeToVenus() public {
        require(_mainContract == msg.sender || msg.sender == _owner);
        if (_vToken == address(0)) {
            return;
        }
        uint256 balance = 0;
        if (_token != address(2)) {
            balance = IBEP20(_token).balanceOf(address(this));
        } else {
            balance = address(this).balance;
        }
        if (balance == 0) {
            return;
        }
        if (_token != address(2)) {
            uint256 code = IVToken(_vToken).mint(balance);
            require(code == 0, "Venus");
        } else {
            IVToken(_vToken).mint{value: balance}();
        }
    }
}