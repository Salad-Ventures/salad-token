// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract SaladToken is Ownable, ERC20, ERC20Burnable, ERC20Pausable {
  string private constant NAME = "Salad";
  string private constant SYMBOL = "SALD";

  constructor() ERC20(NAME, SYMBOL) {}

  function mint(address to, uint256 amount) onlyOwner public virtual {
    _mint(to, amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20, ERC20Pausable) {
    super._beforeTokenTransfer(from, to, amount);
  }
}
