pragma solidity ^0.5.7;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VerifiedAccount is ERC20, Ownable {

    mapping(address => bool) private _isRegistered;

    constructor () internal {
        registerAccount();
    }

    event AccountRegistered(address indexed account);

    function registerAccount() public returns (bool ok) {
        _isRegistered[msg.sender] = true;
        emit AccountRegistered(msg.sender);
        return true;
    }

    function isRegistered(address account) public view returns (bool ok) {
        return _isRegistered[account];
    }

    function _accountExists(address account) internal view returns (bool exists) {
        return account == msg.sender || _isRegistered[account];
    }

    modifier onlyExistingAccount(address account) {
        require(_accountExists(account), "account not registered");
        _;
    }

    function safeTransfer(address to, uint256 value) public onlyExistingAccount(to) returns (bool ok) {
        transfer(to, value);
        return true;
    }

    function safeApprove(address spender, uint256 value) public onlyExistingAccount(spender) returns (bool ok) {
        approve(spender, value);
        return true;
    }

    function safeTransferFrom(address from, address to, uint256 value) public onlyExistingAccount(to) returns (bool ok) {
        transferFrom(from, to, value);
        return true;
    }

    function transferOwnership(address newOwner) public onlyExistingAccount(newOwner) onlyOwner {
        super.transferOwnership(newOwner);
    }
}
