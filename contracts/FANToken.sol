pragma solidity ^0.5.7;

import "./Identity.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "./UniformTokenGrantor.sol";

contract FANToken is Identity, ERC20, ERC20Pausable, ERC20Burnable, ERC20Detailed, UniformTokenGrantor {
    uint32 public constant VERSION = 8;

    uint8 private constant DECIMALS = 18;
    uint256 private constant TOKEN_WEI = 10 ** uint256(DECIMALS);

    uint256 private constant INITIAL_WHOLE_TOKENS = uint256(5 * (10 ** 9));
    uint256 private constant INITIAL_SUPPLY = uint256(INITIAL_WHOLE_TOKENS) * uint256(TOKEN_WEI);

    constructor () ERC20Detailed("FAN TOKEN", "FAN", DECIMALS) public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    event DepositReceived(address indexed from, uint256 value);

    function() payable external {
        emit DepositReceived(msg.sender, msg.value);
    }
    
    function burn(uint256 value) onlyIfFundsAvailableNow(msg.sender, value) public {
        _burn(msg.sender, value);
    }

    function kill() whenPaused onlyPauser public returns (bool itsDeadJim) {
        require(isPauser(msg.sender), "onlyPauser");
        address payable payableOwner = address(uint160(owner()));
        selfdestruct(payableOwner);
        return true;
    }
}
