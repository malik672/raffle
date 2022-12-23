// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./RaffluxMain.sol";
contract RafluxValidator is RaffluxMain {
     RaffluxMain Main;

    constructor() public {
        Main = new RaffluxMain();
    }

    //map of address to bool used to set a validator
    mapping(address => bool) public Validators;

    //map of address to index
    mapping(address => uint256) public indexes;

    //state Variables
    address[] public currentValidators;
    uint256 public current;

    function removeAllValidators() public {
        for (uint256 i = 0; i < currentValidators.length; i++) {
            Validators[currentValidators[i]] = false;
        }
        address[] memory currentVa;
        currentValidators = currentVa;
        current = 0;
    }

    function checkValidator(address _validator) view external returns(bool){
      return Validators[_validator];
    }
  
    //add validators
    function addValidators(address _validator) public {
        if (current == 7) revert transactReverted("maximum validators reached");
        if (Validators[_validator] == true)
            revert transactReverted("already a validator");
        Validators[_validator] = true;
        currentValidators.push(_validator);
        currentValidators.length == 1 ? current : current++;
        indexes[_validator] = current;
    }

    /// @notice Explain tontract name)
    function removeValidator(address _validator) public {
        if (currentValidators.length == 0)
            revert transactReverted("no validators available");
        if (Validators[_validator] == false)
            revert transactReverted("this address is not a validator");
        if (indexes[_validator] == current) {
            Validators[_validator] = false;
            currentValidators.length == 1 ? current : current--;
            currentValidators.pop();
        } else {
            uint256 address1 = indexes[_validator];
            address address2 = currentValidators[currentValidators.length - 1];
            currentValidators[address1] = address2;
            Validators[_validator] = false;
            currentValidators.pop();
            current--;
        }
        for (uint256 i = 0; i < currentValidators.length; i++) {
            indexes[currentValidators[i]] = i;
        }
    }
}
