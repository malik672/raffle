// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./RaffluxMain.sol";
contract RaffluxValidator is RaffluxMain {
     RaffluxMain Main;

    constructor() public {
        Main = new RaffluxMain();
    }

    //map of address to index
    mapping(address => uint256) public indexes;

    //state Variables
    address[] public currentsValidator;
    uint256 public current;

    //Events
    event Log_addValidator(address indexed _validator, uint256 _validatorIndex);
    event Log_removeValidator(address indexed _validator, uint256 _validatorIndex);
  
    //add validators
    function addValidators() public {
        if (current == 7) revert transactReverted("maximum validators reached");
        if (Main.checkValidator(msg.sender) == true)
            revert transactReverted("already a validator");
        Main.changeValidator(msg.sender, true);
        currentsValidator.push(msg.sender);
        currentsValidator.length == 1 ? current : current++;
        indexes[msg.sender] = current;
        emit Log_addValidator(msg.sender, current);
    }

    /// @notice Explain tontract name)
    function removeValidator(address _validator) public {
        if (currentsValidator.length == 0)
            revert transactReverted("no validators available");
        if (Main.checkValidator(_validator) == false)
            revert transactReverted("this address is not a validator");
        if (indexes[_validator] == current) {
            Main.changeValidator(_validator, false);
            currentsValidator.length == 1 ? current : current--;
            currentsValidator.pop();
        } else {
            uint256 address1 = indexes[_validator];
            address address2 = currentsValidator[currentsValidator.length - 1];
            currentsValidator[address1] = address2;
            Main.changeValidator(_validator, false);
            currentsValidator.pop();
            current--;
        }
        for (uint256 i = 0; i < currentsValidator.length; i++) {
            indexes[currentsValidator[i]] = i;
        }
        emit Log_removeValidator(_validator, current);
    }

    function removeAllValidator() external {
        address[] memory empty;
        for (uint256 i = 0; i < currentsValidator.length; i++) {
            Main.changeValidator(currentsValidator[i], false);
            emit Log_removeValidator(currentsValidator[i], i);
        }
        currentsValidator = empty;
    }

    function checkValidator() public view returns(bool) {
      return Main.checkValidator(msg.sender);
    }

    function returnValidators() public view returns(address[] memory){
        return currentsValidator;
    }
}
