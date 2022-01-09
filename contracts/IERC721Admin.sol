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
    event AdminSet(uint256 indexed tokenId, address indexed oldAdmin, address indexed newAdmin);

    /**
     * @notice Emitted when a new admin is reset back to `address(0)`
     */
    event AdminReset(uint256 indexed tokenId, address indexed oldAdmin, address indexed newAdmin);

    /**
     * @notice Emitted when an account has been granted approval
     */
    event AdminApprovalSet(uint256 indexed tokenId, address indexed owner, address indexed recepient);

    /**
     * @notice Returns admin associated with `tokenId
     * @param tokenId The id of the asset
     * @return The admin address
     */
    function getAdmin(uint256 tokenId) external view returns (address);

    /**
     * @notice Returns approved party associated with `tokenId
     * @param tokenId The id of the asset
     * @return The approved party address
     */
    function getAdminApproved(uint256 tokenId) external view returns (address);

    /**
     * @notice Set admin for `tokenId
     * @param tokenId The id of the asset
     * @param newAdmin The new admin
     */
    function setAdmin(uint256 tokenId, address newAdmin) external;

    /**
     * TODO: Change language
     * @notice Give recepient approval to set the admin for `tokenId`, whilst admin remains not set
     * @param tokenId The id of the asset
     * @param recepient The approved party
     */
    function setApproval(uint256 tokenId, address recepient) external;

    /**
     * @notice Reset admin, reinstating the NFT owner the right to set a new admin
     * @dev Throws if `msg.sender` != `admin`.
     * @param tokenId The id of the asset
     */
    function resetAdmin(uint256 tokenId) external;
}
