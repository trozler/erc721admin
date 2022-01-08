// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC721Admin.sol";
import "./IERC721AdminReceiver.sol";

/**
 * @notice This implements an optional extension of {ERC721}, as defined in ERCxxx
 * @dev An extra "admin" role is established, which is a super user for a given `tokenId`
 */
abstract contract ERC721Admin is ERC721, IERC721Admin {
    // Mapping from token ID to the assigned admin
    mapping(uint256 => address) private _admins;

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
    function setAdmin(uint256 tokenId, address newAdmin) public virtual override {
        // Owner of NFT can set admin, only if admin not already set
        // Or admin can replace themselves
        require(
            msg.sender == getAdmin(tokenId) || (msg.sender == ownerOf(tokenId) && !_existsAdmin(tokenId)),
            "ERC721Admin: not allowed to set admin"
        );
        _admins[tokenId] = newAdmin;
    }

    /// @inheritdoc IERC721Admin
    function burnAdmin(uint256 tokenId) public virtual override {
        require((msg.sender == getAdmin(tokenId)), "ERC721Admin: caller not admin");
        _admins[tokenId] = address(0);
    }

    function canTransfer(uint256 tokenId, address spender) public view virtual returns (bool) {
        return IERC721(this).ownerOf(tokenId) != spender;
    }

    /**
     * @notice Returns whether admin exists for `tokenId.
     */
    function _existsAdmin(uint256 tokenId) internal view virtual returns (bool) {
        return _admins[tokenId] != address(0);
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
        if (to.code.length > 0) {
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

        // If we are not minting and admin exists forward call
        if (from != address(0) && _existsAdmin(tokenId)) {
            require(_checkOnAdmin(from, to, tokenId), "ERC721Admin: transfer to non ERC721Receiver implementer");
        }
    }
}
