// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional admin extension
 * @dev See https://eips.ethereum.org/EIPS/eip-xxx
 */
interface IERC721Admin is IERC721 {
    /**
     * @notice Emitted when a new admin is set
     */
    event AdminSet(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @notice Returns admin associated with `tokenId
     * @param tokenId The id of the asset
     * @return The admin address
     */
    function getAdmin(uint256 tokenId) external view returns (address);

    /**
     * @notice Set an admin for `tokenId
     * @dev Throws if `msg.sender` != `admin || `msg.sender == ownerOf(tokenId) && admin == address(0))
     * @dev Throws if `!_isContract(admin)`
     * @param tokenId The id of the asset
     * @param admin The new admin
     */
    function setAdmin(uint256 tokenId, address admin) external;

    /**
     * @notice Reset admin, giving the NFT owner the right to set a new admin
     * @dev Throws if `msg.sender` != `admin`.
     * @param tokenId The id of the asset
     */
    function burnAdmin(uint256 tokenId) external;
}
