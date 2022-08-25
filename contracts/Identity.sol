pragma solidity ^0.5.7;

contract Identity {
    mapping(address => string) private _names;

    function iAm(string memory shortName) public {
        _names[msg.sender] = shortName;
    }

    function whereAmI() public view returns (address yourAddress) {
        address myself = msg.sender;
        return myself;
    }

    function whoAmI() public view returns (string memory yourName) {
        return (_names[msg.sender]);
    }
}
