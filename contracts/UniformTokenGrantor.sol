pragma solidity ^0.5.7;

import "./ERC20Vestable.sol";

contract UniformTokenGrantor is ERC20Vestable {

    struct restrictions {
        bool isValid;
        uint32 minStartDay;
        uint32 maxStartDay;
        uint32 expirationDay;
    }

    mapping(address => restrictions) private _restrictions;

    event GrantorRestrictionsSet(
        address indexed grantor,
        uint32 minStartDay,
        uint32 maxStartDay,
        uint32 expirationDay);

    function setRestrictions(
        address grantor,
        uint32 minStartDay,
        uint32 maxStartDay,
        uint32 expirationDay
    )
    public
    onlyOwner
    onlyExistingAccount(grantor)
    returns (bool ok)
    {
        require(
            isUniformGrantor(grantor)
         && maxStartDay > minStartDay
         && expirationDay > today(), "invalid params");

        _restrictions[grantor] = restrictions(
            true/*isValid*/,
            minStartDay,
            maxStartDay,
            expirationDay
        );

        emit GrantorRestrictionsSet(grantor, minStartDay, maxStartDay, expirationDay);
        return true;
    }

    function setGrantorVestingSchedule(
        address grantor,
        uint32 duration,
        uint32 cliffDuration,
        uint32 interval,
        bool isRevocable
    )
    public
    onlyOwner
    onlyExistingAccount(grantor)
    returns (bool ok)
    {
        require(isUniformGrantor(grantor), "uniform grantor only");
        require(!_hasVestingSchedule(grantor), "schedule already exists");
        _setVestingSchedule(grantor, cliffDuration, duration, interval, isRevocable);

        return true;
    }

    function isUniformGrantorWithSchedule(address account) internal view returns (bool ok) {
        return isUniformGrantor(account) && _hasVestingSchedule(account);
    }

    modifier onlyUniformGrantorWithSchedule(address account) {
        require(isUniformGrantorWithSchedule(account), "grantor account not ready");
        _;
    }

    modifier whenGrantorRestrictionsMet(uint32 startDay) {
        restrictions storage restriction = _restrictions[msg.sender];
        require(restriction.isValid, "set restrictions first");

        require(
            startDay >= restriction.minStartDay
            && startDay < restriction.maxStartDay, "startDay too early");

        require(today() < restriction.expirationDay, "grantor expired");
        _;
    }
    
    function grantUniformVestingTokens(
        address beneficiary,
        uint256 totalAmount,
        uint256 vestingAmount,
        uint32 startDay
    )
    public
    onlyUniformGrantorWithSchedule(msg.sender)
    whenGrantorRestrictionsMet(startDay)
    returns (bool ok)
    {
        return _grantVestingTokens(beneficiary, totalAmount, vestingAmount, startDay, msg.sender, msg.sender);
    }

    function safeGrantUniformVestingTokens(
        address beneficiary,
        uint256 totalAmount,
        uint256 vestingAmount,
        uint32 startDay
    )
    public
    onlyUniformGrantorWithSchedule(msg.sender)
    whenGrantorRestrictionsMet(startDay)
    onlyExistingAccount(beneficiary)
    returns (bool ok)
    {
        return _grantVestingTokens(beneficiary, totalAmount, vestingAmount, startDay, msg.sender, msg.sender);
    }
}
