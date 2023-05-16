// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./ISaladBowl.sol";
import "./ISaladReward.sol";

contract SaladReward is ISaladReward, Ownable, ERC20, ERC20Burnable, ERC20Pausable {
  string private constant NAME = "SaladReward";
  string private constant SYMBOL = "SLD";

  ISaladBowl private _saladBowl;

  constructor() ERC20(NAME, SYMBOL) {}

  function updateSaladBowl(ISaladBowl saladBowl) onlyOwner public virtual {
    emit UpdateSaladBowl(address(_saladBowl), address(saladBowl));
    _saladBowl = saladBowl;
  }

  function mint(address to, uint256 amount) public virtual {
    address sender = _msgSender();
    require(address(_saladBowl) == sender || owner() == sender, "SaladReward: caller not authorized");
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
