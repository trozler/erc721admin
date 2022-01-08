// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ERC721Admin token receiver interface
 * @dev Interface for any contract that wants to support being an Admin for an ERC721 asset.
 */
interface IERC721AdminReceiver {
    /// @notice Handle the receipt of an NFT set admin call
    /// @dev The ERC721 smart contract calls this function on the recipient
    ///  after a `setAdmin`. This function MAY throw to revert and reject the
    ///  set admin call. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param operator The address which called `setAdmin` function
    /// @param from The address which previously owned the token
    /// @param tokenId The NFT identifier which is being transferred
    /// @param data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    // TODO: SHould return nothing when checking if allowed transfer
    function onERC721AdminReceived(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
