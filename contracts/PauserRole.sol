pragma solidity ^0.5.7;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/access/Roles.sol";

contract PauserRole is Ownable {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender), "onlyPauser");
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyOwner {
        _addPauser(account);
    }

    function removePauser(address account) public onlyOwner {
        _removePauser(account);
    }

    function _addPauser(address account) private {
        require(account != address(0));
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) private {
        require(account != address(0));
        _pausers.remove(account);
        emit PauserRemoved(account);
    }

    function renounceOwnership() public onlyOwner {
        require(false, "forbidden");
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
        _removePauser(msg.sender);
        super.transferOwnership(newOwner);
        _addPauser(newOwner);
    }
}
