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
    function addValidators(address _validator) public {
        if (current == 7) revert transactReverted("maximum validators reached");
        if (Main.checkValidator(_validator) == true)
            revert transactReverted("already a validator");
        Main.changeValidator(_validator, true);
        currentsValidator.push(_validator);
        currentsValidator.length == 1 ? current : current++;
        indexes[_validator] = current;
        emit Log_addValidator(_validator, current);
    }

    /// @notice Explain tontract name)
    function removeValidator(address _validator) public {
        if (currentsValidator.length == 0)
            revert transactReverted("no validators available");
        if (Main.checkValidator(_validator) == false)
            revert transactReverted("this address is not a validator");
        if (indexes[_validator] == current) {
            Validators[_validator] = false;
            currentsValidator.length == 1 ? current : current--;
            currentsValidator.pop();
        } else {
            uint256 address1 = indexes[_validator];
            address address2 = currentsValidator[currentsValidator.length - 1];
            currentsValidator[address1] = address2;
            Validators[_validator] = false;
            currentsValidator.pop();
            current--;
        }
        for (uint256 i = 0; i < currentsValidator.length; i++) {
            indexes[currentsValidator[i]] = i;
        }
        emit Log_removeValidator(_validator, current);
    }
}
