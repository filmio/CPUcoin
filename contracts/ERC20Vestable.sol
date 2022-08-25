pragma solidity ^0.5.7;

import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "./VerifiedAccount.sol";
import "./GrantorRole.sol";
import "./IERC20Vestable.sol";

contract ERC20Vestable is ERC20, VerifiedAccount, GrantorRole, IERC20Vestable {
    using SafeMath for uint256;

    uint32 private constant THOUSAND_YEARS_DAYS = 365243;
    uint32 private constant TEN_YEARS_DAYS = THOUSAND_YEARS_DAYS / 100;
    uint32 private constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint32 private constant JAN_1_2000_SECONDS = 946684800;
    uint32 private constant JAN_1_2000_DAYS = JAN_1_2000_SECONDS / SECONDS_PER_DAY;
    uint32 private constant JAN_1_3000_DAYS = JAN_1_2000_DAYS + THOUSAND_YEARS_DAYS;

    struct vestingSchedule {
        bool isValid;
        bool isRevocable;
        uint32 cliffDuration;
        uint32 duration;
        uint32 interval;
    }

    struct tokenGrant {
        bool isActive;
        bool wasRevoked;
        uint32 startDay;
        uint256 amount;
        address vestingLocation;
        address grantor;
    }

    mapping(address => vestingSchedule) private _vestingSchedules;
    mapping(address => tokenGrant) private _tokenGrants;

    function _setVestingSchedule(
        address vestingLocation,
        uint32 cliffDuration, uint32 duration, uint32 interval,
        bool isRevocable) internal returns (bool ok) {

        require(
            duration > 0 && duration <= TEN_YEARS_DAYS
            && cliffDuration < duration
            && interval >= 1,
            "invalid vesting schedule"
        );

        require(
            duration % interval == 0 && cliffDuration % interval == 0,
            "invalid cliff/duration for interval"
        );

        _vestingSchedules[vestingLocation] = vestingSchedule(
            true/*isValid*/,
            isRevocable,
            cliffDuration, duration, interval
        );

        emit VestingScheduleCreated(
            vestingLocation,
            cliffDuration, duration, interval,
            isRevocable);
        return true;
    }

    function _hasVestingSchedule(address account) internal view returns (bool ok) {
        return _vestingSchedules[account].isValid;
    }

    function getIntrinsicVestingSchedule(address grantHolder)
    public
    view
    onlyGrantorOrSelf(grantHolder)
    returns (
        uint32 vestDuration,
        uint32 cliffDuration,
        uint32 vestIntervalDays
    )
    {
        return (
        _vestingSchedules[grantHolder].duration,
        _vestingSchedules[grantHolder].cliffDuration,
        _vestingSchedules[grantHolder].interval
        );
    }

    function _grantVestingTokens(
        address beneficiary,
        uint256 totalAmount,
        uint256 vestingAmount,
        uint32 startDay,
        address vestingLocation,
        address grantor
    )
    internal returns (bool ok)
    {
        require(!_tokenGrants[beneficiary].isActive, "grant already exists");
        require(
            vestingAmount <= totalAmount && vestingAmount > 0
            && startDay >= JAN_1_2000_DAYS && startDay < JAN_1_3000_DAYS,
            "invalid vesting params");
        require(_hasVestingSchedule(vestingLocation), "no such vesting schedule");
        _transfer(grantor, beneficiary, totalAmount);
        _tokenGrants[beneficiary] = tokenGrant(
            true/*isActive*/,
            false/*wasRevoked*/,
            startDay,
            vestingAmount,
            vestingLocation,
            grantor
        );

        emit VestingTokensGranted(beneficiary, vestingAmount, startDay, vestingLocation, grantor);
        return true;
    }
    
    function grantVestingTokens(
        address beneficiary,
        uint256 totalAmount,
        uint256 vestingAmount,
        uint32 startDay,
        uint32 duration,
        uint32 cliffDuration,
        uint32 interval,
        bool isRevocable
    ) public onlyGrantor returns (bool ok) {
        require(!_tokenGrants[beneficiary].isActive, "grant already exists");
        _setVestingSchedule(beneficiary, cliffDuration, duration, interval, isRevocable);
        _grantVestingTokens(beneficiary, totalAmount, vestingAmount, startDay, beneficiary, msg.sender);

        return true;
    }

    function safeGrantVestingTokens(
        address beneficiary, uint256 totalAmount, uint256 vestingAmount,
        uint32 startDay, uint32 duration, uint32 cliffDuration, uint32 interval,
        bool isRevocable) public onlyGrantor onlyExistingAccount(beneficiary) returns (bool ok) {

        return grantVestingTokens(
            beneficiary, totalAmount, vestingAmount,
            startDay, duration, cliffDuration, interval,
            isRevocable);
    }

    function today() public view returns (uint32 dayNumber) {
        return uint32(block.timestamp / SECONDS_PER_DAY);
    }

    function _effectiveDay(uint32 onDayOrToday) internal view returns (uint32 dayNumber) {
        return onDayOrToday == 0 ? today() : onDayOrToday;
    }

    function _getNotVestedAmount(address grantHolder, uint32 onDayOrToday) internal view returns (uint256 amountNotVested) {
        tokenGrant storage grant = _tokenGrants[grantHolder];
        vestingSchedule storage vesting = _vestingSchedules[grant.vestingLocation];
        uint32 onDay = _effectiveDay(onDayOrToday);

        if (!grant.isActive || onDay < grant.startDay + vesting.cliffDuration)
        {
            return grant.amount;
        }
        else if (onDay >= grant.startDay + vesting.duration)
        {
            return uint256(0);
        }
        else
        {
            uint32 daysVested = onDay - grant.startDay;
            uint32 effectiveDaysVested = (daysVested / vesting.interval) * vesting.interval;
            uint256 vested = grant.amount.mul(effectiveDaysVested).div(vesting.duration);
            return grant.amount.sub(vested);
        }
    }

    function _getAvailableAmount(address grantHolder, uint32 onDay) internal view returns (uint256 amountAvailable) {
        uint256 totalTokens = balanceOf(grantHolder);
        uint256 vested = totalTokens.sub(_getNotVestedAmount(grantHolder, onDay));
        return vested;
    }

    function vestingForAccountAsOf(
        address grantHolder,
        uint32 onDayOrToday
    )
    public
    view
    onlyGrantorOrSelf(grantHolder)
    returns (
        uint256 amountVested,
        uint256 amountNotVested,
        uint256 amountOfGrant,
        uint32 vestStartDay,
        uint32 vestDuration,
        uint32 cliffDuration,
        uint32 vestIntervalDays,
        bool isActive,
        bool wasRevoked
    )
    {
        tokenGrant storage grant = _tokenGrants[grantHolder];
        vestingSchedule storage vesting = _vestingSchedules[grant.vestingLocation];
        uint256 notVestedAmount = _getNotVestedAmount(grantHolder, onDayOrToday);
        uint256 grantAmount = grant.amount;

        return (
        grantAmount.sub(notVestedAmount),
        notVestedAmount,
        grantAmount,
        grant.startDay,
        vesting.duration,
        vesting.cliffDuration,
        vesting.interval,
        grant.isActive,
        grant.wasRevoked
        );
    }

    function vestingAsOf(uint32 onDayOrToday) public view returns (
        uint256 amountVested,
        uint256 amountNotVested,
        uint256 amountOfGrant,
        uint32 vestStartDay,
        uint32 vestDuration,
        uint32 cliffDuration,
        uint32 vestIntervalDays,
        bool isActive,
        bool wasRevoked
    )
    {
        return vestingForAccountAsOf(msg.sender, onDayOrToday);
    }

    function _fundsAreAvailableOn(address account, uint256 amount, uint32 onDay) internal view returns (bool ok) {
        return (amount <= _getAvailableAmount(account, onDay));
    }

    modifier onlyIfFundsAvailableNow(address account, uint256 amount) {
        require(_fundsAreAvailableOn(account, amount, today()),
            balanceOf(account) < amount ? "insufficient funds" : "insufficient vested funds");
        _;
    }

    function revokeGrant(address grantHolder, uint32 onDay) public onlyGrantor returns (bool ok) {
        tokenGrant storage grant = _tokenGrants[grantHolder];
        vestingSchedule storage vesting = _vestingSchedules[grant.vestingLocation];
        uint256 notVestedAmount;

        require(msg.sender == owner() || msg.sender == grant.grantor, "not allowed");
        require(grant.isActive, "no active grant");
        require(vesting.isRevocable, "irrevocable");
        require(onDay <= grant.startDay + vesting.duration, "no effect");
        require(onDay >= today(), "cannot revoke vested holdings");

        notVestedAmount = _getNotVestedAmount(grantHolder, onDay);
        _approve(grantHolder, grant.grantor, notVestedAmount);
        transferFrom(grantHolder, grant.grantor, notVestedAmount);
        _tokenGrants[grantHolder].wasRevoked = true;
        _tokenGrants[grantHolder].isActive = false;

        emit GrantRevoked(grantHolder, onDay);

        return true;
    }

    function transfer(address to, uint256 value) public onlyIfFundsAvailableNow(msg.sender, value) returns (bool ok) {
        return super.transfer(to, value);
    }

    function approve(address spender, uint256 value) public onlyIfFundsAvailableNow(msg.sender, value) returns (bool ok) {
        return super.approve(spender, value);
    }
}
