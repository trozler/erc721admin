// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC721Admin.sol";
import "./IERC721AdminVerifier.sol";

/**
 * @author Tony Rosler and Francesco Renzi
 * @notice This implements an optional extension of {ERC721}, as defined in ERCxxx
 * @dev An extra "admin" role is established, which is a super user for a given `tokenId`
 */
abstract contract ERC721Admin is ERC721, IERC721Admin {
    // Mapping from token ID to the assigned admin
    mapping(uint256 => address) private _admins;

    /*******************************
     * Admin functions *
     *******************************/

    /// @inheritdoc IERC721Admin
    function getAdmin(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721Admin: Admin qury for nonexistent token");
        return _admins[tokenId];
    }

    /// @inheritdoc IERC721Admin
    /// @dev Requirments for setting admin:
    ///      - Admin can replace themselves with other admins
    ///      - Owners can set admin, but only if admin == address(0)
    ///      - Approved accounts can set admin, but they do not have admin rights e.g. block transfers.
    /// @dev New admin requirments:
    ///      - Must be contract accounts or address(0)
    ///      - Cannot be current admin
    /// NOTE: We do allow admin to be set to owner or approved party
    function setAdmin(uint256 tokenId, address newAdmin) public virtual override {
        address caller = msg.sender;
        address admin = getAdmin(tokenId);

        require(newAdmin != admin, "ERC721Admin: new admin cannot be current admin");
        require(
            _isContract(newAdmin) || newAdmin == address(0),
            "ERC721Admin: new admin must be contract account or zero address"
        );

        bool isAdminCall = caller == admin;
        bool isOwnerCall = admin == address(0) && caller == ERC721.ownerOf(tokenId);
        bool isApproverCall = admin == address(0) && caller == ERC721.getApproved(tokenId);
        require(isAdminCall || isOwnerCall || isApproverCall, "ERC721Admin: caller not allowed to set admin");

        // Set admin
        _admins[tokenId] = newAdmin;
        _approve(address(0), tokenId);

        emit AdminSet(tokenId, admin, newAdmin);
    }

    /// @inheritdoc IERC721Admin
    /// @dev Convenience function that can be used to reset admin
    /// @dev Can only be called by current admin
    /// NOTE: Resetting admin, grants owner of NFT the right to set admin again
    function resetAdmin(uint256 tokenId) public virtual override {
        address admin = getAdmin(tokenId);
        require((msg.sender == admin), "ERC721Admin: caller not admin");

        // Set admin and reset any approval
        _admins[tokenId] = address(0);
        _approve(address(0), tokenId);

        emit AdminSet(tokenId, admin, address(0));
    }

    /*****************************
     * ERC721 override functions *
     *****************************/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Admin).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721Admin
    /// @dev we do not allow for "approved" accounts to transfer away the NFT,
    ///      since the role of the approved account is redefined.
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(IERC721Admin, ERC721) {
        require(_exists(tokenId), "ERC721Admin: operator query for nonexistent token");
        require(msg.sender == ERC721.ownerOf(tokenId), "ERC721Admin: only owner can transfer asset");
        _transfer(from, to, tokenId);
    }

    /// @inheritdoc IERC721Admin
    /// @dev we do not allow for "approved" accounts to transfer away the NFT,
    ///      since the role of the approved account is redefined.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override(IERC721Admin, ERC721) {
        require(_exists(tokenId), "ERC721Admin: operator query for nonexistent token");
        require(msg.sender == ERC721.ownerOf(tokenId), "ERC721Admin: only owner can transfer asset");
        _safeTransfer(from, to, tokenId, _data);
    }

    /// @inheritdoc IERC721Admin
    /// @dev Overrides notion of what it means to `approve`,
    ///      approved accounts can set the admin for a `tokenId` if it is not already set.
    function approve(address to, uint256 tokenId) public virtual override(IERC721Admin, ERC721) {
        address caller = msg.sender;
        address owner = ERC721.ownerOf(tokenId);
        address admin = getAdmin(tokenId);
        address approvedOperator = ERC721.getApproved(tokenId);

        require(
            to != admin && to != owner && to != approvedOperator && !isApprovedForAll(owner, caller),
            "ERC721Admin: cannot approve admin, owner or already approved"
        );

        _approve(to, tokenId);
    }

    /// @notice Safely mints `tokenId` and transfers it to `to`, and sets admin for `tokenId`
    /// @dev admin must be a contract account
    function _safeMint(
        address to,
        uint256 tokenId,
        address admin
    ) internal virtual {
        _safeMint(to, tokenId, "");
        setAdmin(tokenId, admin);
    }

    /// @notice Safely mints `tokenId` and transfers it to `to`, and sets admin for `tokenId`
    /// @dev lets you pass `_data` which is passed to `_checkOnERC721Received()`
    /// @dev admin must be a contract account
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data,
        address admin
    ) internal virtual {
        _safeMint(to, tokenId, _data);
        setAdmin(tokenId, admin);
    }

    /// @notice Mints `tokenId` and transfers it to `to`, and sets admin for `tokenId`
    /// @dev admin must be a contract account
    function _mint(
        address to,
        uint256 tokenId,
        address admin
    ) internal virtual {
        _mint(to, tokenId);
        setAdmin(tokenId, admin);
    }

    /**
     * @notice  Returns true if `account` is a contract.
     * @dev [IMPORTANT]
     * ===================
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     */
    function _isContract(address a) internal view virtual returns (bool) {
        return a.code.length > 0;
    }

    /// @notice Returns whether admin exists for `tokenId.
    function _existsAdmin(uint256 tokenId) internal view virtual returns (bool) {
        return _admins[tokenId] != address(0);
    }

    // TODO: not done, is wrong.
    /**
     * @notice Internal function to invoke {IERC721AdminVerifier-onERC721AdminVerify} on a target address.
     * @dev The call is not executed if the target address is not a contract.
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnAdmin(
        address from,
        address to,
        uint256 tokenId,
        address admin
    ) private returns (bool) {
        try IERC721AdminVerifier(admin).onERC721AdminVerify(msg.sender, from, to, tokenId) returns (bytes4 retval) {
            return retval == IERC721AdminVerifier.onERC721AdminVerify.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("ERC721Admin: admin check to non IERC721AdminReceiver implementer");
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @notice Hook that is called before any token transfer, including minting
     * and burning.
     *
     * @dev Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        address admin = getAdmin((tokenId));
        // If we are not minting and admin exists, forward call to admin and revert on failure
        if (from != address(0) && admin != address(0)) {
            // Check if contract account is admin, should never fail
            assert(_isContract(admin));
            require(_checkOnAdmin(from, to, tokenId, admin), "ERC721Admin: transfer to non ERC721Receiver implementer");
        }
    }
}
