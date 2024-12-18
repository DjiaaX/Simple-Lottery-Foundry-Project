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
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.1.1/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title Sample for Raffle Smart Contract
 * @author Adji
 * @notice This contract is for creating a sample Raffle
 * @dev Implements ChainLink VRFv2.5
 */
 
contract Raffle {
    /* Errors */
    error Raffle__sendMoreToEnterRaffle();

    uint256 private immutable i_entranceFee;

    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;

    }

    function enterRaffle() external payable{
        // require(msg.value >= i_entranceFee, "Not enough eth")
        // require(msg.value >= i_entranceFee, sendMoreEthToEnterRaffle());
        /* Validation */
        if(msg.value < i_entranceFee) {
            revert Raffle__sendMoreToEnterRaffle();
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
    function pickWinner() external {
        // Check to see if enough time who passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /* Gather Function */
    function getEntranceFee() public view returns(uint256) {
        return i_entranceFee;
    }
    
}

/* How it Works?
    1. Validation 
    2. Adding players to array
    3. Get a random number
*/