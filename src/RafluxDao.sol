// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

error transactReverted(string data);

contract RafluxDao{


  constructor() public {}
  
   //map of address to bool used to set a validator
   mapping(address => bool) public Validators;

   //map of address to index
   mapping(address => uint256) public indexes;


   //state Variables
   address[] public currentValidators;
   uint256 public current;

   function removeAllValidators() public {
     for(uint i = 0; i < currentValidators.length; i++){
       Validators[currentValidators[i]] = false;
     }
     address[] memory currentVa;
     currentValidators = currentVa;
     current = 0;
   }

   
    function addValidators(address _validator) public {
        if(current == 7) revert transactReverted("maximum validators reached");
        if(Validators[_validator] == true) revert transactReverted("already a validator");
        Validators[_validator] = true;
        indexes[_validator] = current;
        currentValidators.push(_validator);
        currentValidators.length == 1 ? current : current++;
    }


    /// @notice Explain tontract name)
    function removeValidator(address _validator) public {
       if(currentValidators.length == 0) revert transactReverted("no validators available");
       if(Validators[_validator] == false) revert transactReverted("this address is not a validator");
       if(indexes[_validator] == current){
          Validators[_validator] = false;
          currentValidators.pop();
       }else{
         uint256 address1 = indexes[_validator];
         address address2 = currentValidators[current];
         currentValidators[current] = _validator;
         currentValidators[address1] = address2;
         Validators[_validator] = false;
         currentValidators.pop();  
         current--;
       }
    }
}