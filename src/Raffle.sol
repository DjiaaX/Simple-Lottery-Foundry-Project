// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {IVRFCoordinatorV2Plus} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title Sample for Raffle Smart Contract
 * @author Adji
 * @notice This contract is for creating a sample Raffle
 * @dev Implements ChainLink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__upkeepNotNeeded(uint256 balance, uint256 playerslength, uint256 RaffleState);
    // error Raffle__winnerSelectedAndPayed(address winner, uint256 amount);

    /* Type Delcaration */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1

    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATION = 5;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    //@dev Duration of the Lottery in second
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    IVRFCoordinatorV2Plus private immutable i_vrfCoordinatorContract;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleWinnerSelectedAndPaid(address indexed winner, uint256 amount);

    /* event DebugRequest(
    bytes32 keyHash,
    uint256 subId,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords,
    bytes extraArgs
    ); */

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_vrfCoordinatorContract = IVRFCoordinatorV2Plus(vrfCoordinator);

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough eth")
        // require(msg.value >= i_entranceFee, sendMoreEthToEnterRaffle());
        /* Validation */
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        /* Adding players to array */
        s_players.push(payable(msg.sender));

        /* Emit */
        emit RaffleEntered(msg.sender);
    }

    /*  1. Get a random number
        2. Use a random number to pick a player
        3. Be automatically called
    */

    /**
     *
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. There are players registered.
     * 5. Implicity, your subscription is funded with LINK.
     * - ignored
     * upKeepNeeded - true if its time to restart the lottery
     * - ignored
     */
    function checkUpkeep(bytes memory /* checkdata */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpKeep(bytes calldata /* performData */ ) external {
        // Check to see if enough time who passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__upkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinatorContract.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    // Checks-Effects-Interactions or CEI.
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        // Checks
        // Effect (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        emit WinnerPicked(s_recentWinner);
        // Interactions (Internal Contract State)
        (bool succes,) = recentWinner.call{value: address(this).balance}("");
        if (!succes) {
            revert Raffle__TransferFailed();
        }
    }

    /* Gather Function */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
