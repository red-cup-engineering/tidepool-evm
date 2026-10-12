// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @notice An ERC-4626 vault a test can make gain, lose and run short of liquidity:
///         `donate` raises the share price (yield), `burnAssets` lowers it (loss), `setMaxWithdraw` caps what
///         `maxWithdraw`/`maxRedeem` report (an illiquid vault; `type(uint256).max` lifts the cap).
///         Used by MemberSleeveV1's fuzz (TP-EVM-004a) and the invariant suite (TP-EVM-015).
contract MockERC4626Lossy is ERC4626 {
    using SafeERC20 for IERC20;

    address public constant BURN = address(0xdead);

    uint256 public withdrawCap = type(uint256).max;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC4626(asset_) ERC20(name_, symbol_) {}

    /// @notice Pull `assets` from the caller into the vault without minting shares: the share price rises.
    function donate(uint256 assets) external {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
    }

    /// @notice Destroy `assets` held by the vault (sent to 0xdead): the share price falls.
    function burnAssets(uint256 assets) external {
        IERC20(asset()).safeTransfer(BURN, assets);
    }

    /// @notice Cap `maxWithdraw` and `maxRedeem` (in assets); `type(uint256).max` removes the cap.
    function setMaxWithdraw(uint256 cap) external {
        withdrawCap = cap;
    }

    function maxWithdraw(address owner_) public view override returns (uint256) {
        uint256 base = super.maxWithdraw(owner_);
        return base < withdrawCap ? base : withdrawCap;
    }

    function maxRedeem(address owner_) public view override returns (uint256) {
        uint256 shares = super.maxRedeem(owner_);
        uint256 capShares = _convertToShares(withdrawCap, Math.Rounding.Floor);
        return shares < capShares ? shares : capShares;
    }
}
