/*
     ,-""""-.
   ,'      _ `.
  /       )_)  \
 :              :
 \              /
  \            /
   `.        ,'
     `.    ,'
       `.,'
        /\`.   ,-._
            `-'         Banksy.farm

 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/*
  TABLE ERROR REFERENCE:
  ERR1: The sender is on the blacklist. Please contact to support.
  ERR2: The recipient is on the blacklist. Please contact to support.
  ERR3: User cannot send more than allowed.
  ERR4: User is not operator.
  ERR5: User is excluded from antibot system.
  ERR6: Bot address is already on the blacklist.
  ERR7: The expiration time has to be greater than 0.
  ERR8: Bot address is not found on the blacklist.
  ERR9: Address cant be 0.
*/

// BanksyToken
contract BanksyTokenV3 is ERC20, Ownable {

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event TransferTaxRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);
    event HoldingAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);
    event AntiBotWorkingStatus(address indexed operator, bool previousStatus, bool newStatus);
    event AddBotAddress(address indexed botAddress);
    event RemoveBotAddress(address indexed botAddress);
    event ExcludedOperatorsUpdated(address indexed operatorAddress, bool previousStatus, bool newStatus);
    event ExcludedHoldersUpdated(address indexed holderAddress, bool previousStatus, bool newStatus);
    

    using SafeMath for uint256;

    ///@dev Max transfer amount rate. (default is 3% of total supply)
    uint16 public maxUserTransferAmountRate = 300;
    
    ///@dev Max holding rate. (default is 9% of total supply)
    uint16 public maxUserHoldAmountRate = 900;

    ///@dev Length of blacklist addressess
    uint256 public blacklistLength;
 
    ///@dev Enable|Disable antiBot
    bool public antiBotWorking;
    
    ///@dev Exclude operators from antiBot system
    mapping(address => bool) private _excludedOperatorsFromAntiBot;

    ///@dev Exclude holders from antiBot system
    mapping(address => bool) private _excludedHoldersFromAntiBot;

    ///@dev mapping store blacklist. address=>ExpirationTime 
    mapping(address => uint256) private _blacklist;
    

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    // operator role
    address internal _operator;

    // MODIFIERS
    modifier antiBot(address _sender, address _recipient, uint256 _amount) { 
        //check blacklist
        require(!_blacklistCheck(_sender), "ERR1");
        require(!_blacklistCheck(_recipient), "ERR2");

        // This code will be disabled after launch and before farming
        if (antiBotWorking){
            // check  if sender|recipient has a tx amount is within the allowed limits
            if (_isNotOperatorExcludedFromAntiBot(_sender)){
                if(_isNotOperatorExcludedFromAntiBot(_recipient))
                    require(_amount <= _maxUserTransferAmount(), "ERR3");
            }
        }
        _;
    }

    modifier onlyOperator() {
        require(_operator == _msgSender(), "ERR4");
        _;
    }
    
    constructor() 
        ERC20('BANKSY', 'BANKSY')
    {
      // Exclude operator addresses, lps, etc from antibot system
        _excludedOperatorsFromAntiBot[msg.sender] = true;
        _excludedOperatorsFromAntiBot[address(0)] = true;
        _excludedOperatorsFromAntiBot[address(this)] = true;
        _excludedOperatorsFromAntiBot[BURN_ADDRESS] = true;

        _operator = _msgSender();
    }
    

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
    //INTERNALS
    
    /// @dev overrides transfer function to use antibot system
    function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual override antiBot(_sender, _recipient, _amount) {
        // Autodetect is sender is a BOT
        // This code will be disabled after launch and before farming
        if (antiBotWorking){
            // check  if sender|recipient has a tx amount is within the allowed limits
            if (_isNotHolderExcludedFromAntiBot(_sender)){
                if(_isNotOperatorExcludedFromAntiBot(_sender)){
                    if (balanceOf(_sender) > _maxUserHoldAmount()) {
                        _addBotAddressToBlackList(_sender, type(uint256).max);
                        return;
                    }
                }
            }
        }
        
        super._transfer(_sender, _recipient, _amount);
    }

    /// @dev internal function to add address to blacklist.
    function _addBotAddressToBlackList(address _botAddress, uint256 _expirationTime) internal {
        require(_isNotHolderExcludedFromAntiBot(_botAddress), "ERR5");
        require(_isNotOperatorExcludedFromAntiBot(_botAddress), "ERR5");
        require(_blacklist[_botAddress] == 0, "ERR6");
        require(_expirationTime > 0, "ERR7");

        _blacklist[_botAddress] = _expirationTime;
        blacklistLength = blacklistLength.add(1);

        emit AddBotAddress(_botAddress);
    }
    
    ///@dev internal function to remove address from blacklist.
    function _removeBotAddressToBlackList(address _botAddress) internal {
        require(_blacklist[_botAddress] > 0, "ERR8");

        delete _blacklist[_botAddress];
        blacklistLength = blacklistLength.sub(1);

        emit RemoveBotAddress(_botAddress);
    }

    ///@dev Check if the address is excluded from antibot system.
    function _isNotHolderExcludedFromAntiBot(address _userAddress) internal view returns(bool) {
        return(!_excludedHoldersFromAntiBot[_userAddress]);
    }

    ///@dev Check if the address is excluded from antibot system.
    function _isNotOperatorExcludedFromAntiBot(address _userAddress) internal view returns(bool) {
        return(!_excludedOperatorsFromAntiBot[_userAddress]);
    }

    ///@dev Max user transfer allowed
    function _maxUserTransferAmount() internal view returns (uint256) {
        return totalSupply().mul(maxUserTransferAmountRate).div(10000);
    }

    ///@dev Max user Holding allowed
    function _maxUserHoldAmount() internal view returns (uint256) {
        return totalSupply().mul(maxUserHoldAmountRate).div(10000);
    }

    ///@dev check if the address is in the blacklist or expired
    function _blacklistCheck(address _botAddress) internal view returns(bool) {
        if(_blacklist[_botAddress] > 0)
            return _blacklist[_botAddress] > block.timestamp;
        else 
            return false;
    }

    // PUBLICS
 
    ///@dev Max user transfer allowed
    function maxUserTransferAmount() external view returns (uint256) {
        return _maxUserTransferAmount();
    }

    ///@dev Max user Holding allowed
    function maxUserHoldAmount() external view returns (uint256) {
        return _maxUserHoldAmount();
    }

     ///@dev check if the address is in the blacklist or expired
    function blacklistCheck(address _botAddress) external view returns(bool) {
        return _blacklistCheck(_botAddress);     
    }
    
    ///@dev check if the address is in the blacklist or not
    function blacklistCheckExpirationTime(address _botAddress) external view returns(uint256){
        return _blacklist[_botAddress];
    }


    // EXTERNALS

    ///@dev Update operator address status
    function updateOperatorsFromAntiBot(address _operatorAddress, bool _status) external onlyOwner {
        require(_operatorAddress != address(0), "ERR9");

        emit ExcludedOperatorsUpdated(_operatorAddress, _excludedOperatorsFromAntiBot[_operatorAddress], _status);

        _excludedOperatorsFromAntiBot[_operatorAddress] = _status;
    }

    ///@dev Update operator address status
    function updateHoldersFromAntiBot(address _holderAddress, bool _status) external onlyOwner {
        require(_holderAddress != address(0), "ERR9");

        emit ExcludedHoldersUpdated(_holderAddress, _excludedHoldersFromAntiBot[_holderAddress], _status);

        _excludedHoldersFromAntiBot[_holderAddress] = _status;
    }


    ///@dev Update operator address
    function transferOperator(address newOperator) external onlyOperator {
        require(newOperator != address(0), "ERR9");
        
        emit OperatorTransferred(_operator, newOperator);

        _operator = newOperator;
    }

    function operator() external view returns (address) {
        return _operator;
    }

     ///@dev Updates the max holding amount. 
    function updateMaxUserHoldAmountRate(uint16 _maxUserHoldAmountRate) external onlyOwner {
        require(_maxUserHoldAmountRate >= 500);
        require(_maxUserHoldAmountRate <= 10000);
        
        emit TransferTaxRateUpdated(_msgSender(), maxUserHoldAmountRate, _maxUserHoldAmountRate);

        maxUserHoldAmountRate = _maxUserHoldAmountRate;
    }

    ///@dev Updates the max user transfer amount. 
    function updateMaxUserTransferAmountRate(uint16 _maxUserTransferAmountRate) external onlyOwner {
        require(_maxUserTransferAmountRate >= 50);
        require(_maxUserTransferAmountRate <= 10000);
        
        emit HoldingAmountRateUpdated(_msgSender(), maxUserHoldAmountRate, _maxUserTransferAmountRate);

        maxUserTransferAmountRate = _maxUserTransferAmountRate;
    }

    
    ///@dev Update the antiBotWorking status: ENABLE|DISABLE.
    function updateStatusAntiBotWorking(bool _status) external onlyOwner {
        emit AntiBotWorkingStatus(_msgSender(), antiBotWorking, _status);

        antiBotWorking = _status;
    }

     ///@dev Add an address to the blacklist. Only the owner can add. Owner is the address of the Governance contract.
    function addBotAddress(address _botAddress, uint256 _expirationTime) external onlyOwner {
        _addBotAddressToBlackList(_botAddress, _expirationTime);
    }
    
    ///@dev Remove an address from the blacklist. Only the owner can remove. Owner is the address of the Governance contract.
    function removeBotAddress(address botAddress) external onlyOperator {
        _removeBotAddressToBlackList(botAddress);
    }
    
    ///@dev Add multi address to the blacklist. Only the owner can add. Owner is the address of the Governance contract.
    function addBotAddressBatch(address[] memory _addresses, uint256 _expirationTime) external onlyOwner {
        require(_addresses.length > 0);

        for(uint i=0;i<_addresses.length;i++){
            _addBotAddressToBlackList(_addresses[i], _expirationTime);
        }
    }
    
    ///@dev Remove multi address from the blacklist. Only the owner can remove. Owner is the address of the Governance contract.
    function removeBotAddressBatch(address[] memory _addresses) external onlyOperator {
        require(_addresses.length > 0);

        for(uint i=0;i<_addresses.length;i++){
            _removeBotAddressToBlackList(_addresses[i]);
        }
    }

    ///@dev Check if the address is excluded from antibot system.
    function isExcludedOperatorFromAntiBot(address _userAddress) external view returns(bool) {
        return(_excludedOperatorsFromAntiBot[_userAddress]);
    }

    ///@dev Check if the address is excluded from antibot system.
    function isExcludedHolderFromAntiBot(address _userAddress) external view returns(bool) {
        return(_excludedHoldersFromAntiBot[_userAddress]);
    }
}