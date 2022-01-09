// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC721Admin.sol";
import "./IERC721AdminReceiver.sol";

/**
 * @author Tony Rosler and Francesco Renzi
 * @notice This implements an optional extension of {ERC721}, as defined in ERCxxx
 * @dev An extra "admin" role is established, which is a super user for a given `tokenId`
 */
abstract contract ERC721Admin is ERC721, IERC721Admin {
    // Mapping from token ID to the assigned admin
    mapping(uint256 => address) private _admins;
    // Mapping from `tokenId` to an approved address, which can set the admin for the `tokenId`
    mapping(uint256 => address) private _approvedAllowance;

    modifier onlyAdmin(uint256 tokenId, address admin) virtual {
        require(_admins[tokenId] == admin, "ERC721Admin: only admin");
        _;
    }

    /*******************************
     * Admin functions *
     *******************************/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Admin).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721Admin
    function getAdmin(uint256 tokenId) public view virtual override returns (address) {
        return _admins[tokenId];
    }

    /// @inheritdoc IERC721Admin
    function getAdminApproved(uint256 tokenId) public view virtual override returns (address) {
        return _approvedAllowance[tokenId];
    }

    /// @inheritdoc IERC721Admin
    /// @dev Requirments for setting admin:
    ///      - Admin can replace themselves with other admins
    ///      - Owners can set admin, but only if currAdmin == address(0)
    ///      - Approved accounts can set admin, but they do not have admin rights e.g. block transfers.
    /// NOTE: New admins must be contract accounts or address(0)
    function setAdmin(uint256 tokenId, address newAdmin) public virtual override {
        address currAdmin = getAdmin(tokenId);
        address currApproved = getAdminApproved(tokenId);

        require(
            msg.sender == currAdmin ||
                (currAdmin == address(0) && (msg.sender == ownerOf(tokenId) || msg.sender == currApproved)),
            "ERC721Admin: caller not allowed to set admin"
        );

        // We handle resetAdmin flow as well
        require(
            _isContract(newAdmin) || newAdmin == address(0),
            "ERC721Admin: new admin must be contract account or zero address"
        );

        // Set admin and reset any approval
        _admins[tokenId] = newAdmin;
        _approvedAllowance[tokenId] = address(0);

        emit AdminSet(tokenId, currAdmin, newAdmin);
    }

    /// @inheritdoc IERC721Admin
    function setApproval(uint256 tokenId, address recepient) public virtual override {
        require(msg.sender == ownerOf(tokenId), "ERC721Admin: caller not allowed to set admin");

        _approvedAllowance[tokenId] = recepient;

        emit AdminApprovalSet(tokenId, msg.sender, recepient);
    }

    /// @inheritdoc IERC721Admin
    /// @dev Convenience function that can be used to reset admin
    /// @dev Can only be called by current admin
    /// NOTE: Resetting admin, grants owner of NFT the right to set admin again
    function resetAdmin(uint256 tokenId) public virtual override {
        address currAdmin = getAdmin(tokenId);
        require((msg.sender == currAdmin), "ERC721Admin: caller not admin");

        // Set admin and reset any approval
        _admins[tokenId] = address(0);
        _approvedAllowance[tokenId] = address(0);

        emit AdminSet(tokenId, currAdmin, address(0));
    }

    /**
     * @notice Safely mints `tokenId` and transfers it to `to`, and sets admin for `tokenId`
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        address admin
    ) internal virtual {
        _safeMint(to, tokenId, "");
        setAdmin(tokenId, admin);
    }

    /**
     * @notice Safely mints `tokenId` and transfers it to `to`, and sets admin for `tokenId`
     * @dev lets you pass `_data` which is passed to `_checkOnERC721Received()`
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data,
        address admin
    ) internal virtual {
        _safeMint(to, tokenId, _data);
        setAdmin(tokenId, admin);
    }

    /**
     * @notice Mints `tokenId` and transfers it to `to`, and sets admin for `tokenId`
     */
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
     * [IMPORTANT]
     * ====
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

    /**
     * @notice Returns whether admin exists for `tokenId.
     */
    function _existsAdmin(uint256 tokenId) internal view virtual returns (bool) {
        return _admins[tokenId] != address(0);
    }

    function _checkOnAdmin(
        address from,
        address to,
        uint256 tokenId
    ) private returns (bool) {
        return _checkOnAdmin(from, to, tokenId, "");
    }

    /**
     * @notice Internal function to invoke {IERC721Admin-onERC721AdminReceived} on a target address.
     * @dev Will check on
     * @dev This implementation is based on OZ {IERC721-_checkOnERC721Received}
     * @dev The call is not executed if the target address is not a contract.
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnAdmin(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        // Check if contract account
        if (_isContract(to)) {
            // TODO: Remove bytes return type, should revert in case of not accapting failure
            try IERC721AdminReceiver(to).onERC721AdminReceived(msg.sender, from, tokenId, _data) returns (
                bytes4 retval
            ) {
                return retval == IERC721AdminReceiver.onERC721AdminReceived.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721Admin: admin check to non IERC721AdminReceiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        // If we are not minting and admin exists, forward call to admin and revert on failure
        if (from != address(0) && _existsAdmin(tokenId)) {
            require(_checkOnAdmin(from, to, tokenId), "ERC721Admin: transfer to non ERC721Receiver implementer");
        }
    }
}
