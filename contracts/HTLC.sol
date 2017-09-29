pragma solidity ^0.4.0;

import 'zeppelin-solidity/contracts/ReentrancyGuard.sol';

/**
 * @title Hashed time-locked contract.
 */
contract HTLC is ReentrancyGuard {
    enum State {
        INITIATED,
        COMPLETED,
        EXPIRED,
        RECLAIMED
    }

    // Participants in the exchange
    address sender;
    address recipient;

    // Secret hashed by sender
    bytes32 image;

    // Expiration timestamp
    uint expires;

    // State of the exchange
    State state;

    // Events
    event Initiated(address from, address to, uint amount, uint expirationTimestamp);
    event Completed(address from, address to, uint amount);
    event Expired(address from, address to, uint amount);
    event Reclaimed(address from, uint amount);

    function HTLC (address _recipient, bytes32 _image, uint _expirationTime) payable {
        // Define internal state
        sender = msg.sender;
        recipient = _recipient;
        image = _image;
        expires = now + _expirationTime;
        state = State.INITIATED;

        // Emit an 'Initiated' event
        Initiated(sender, recipient, msg.value, expires);
    }

    function complete (bytes _preimage) public nonReentrant {
        require(hash(_preimage) == image);
        require(msg.sender == recipient);
        require(state == State.INITIATED);

        // Check if the completion comes early enough
        if (now <= expires) {
            // Remember the amount to be transfered
            uint amount = this.balance;

            // Attempt to transfer it
            msg.sender.transfer(this.balance);

            // The exchange is completed
            state = State.COMPLETED;
            Completed(sender, recipient, amount);
        } else {
            // The exchange has expired
            state = State.EXPIRED;
            Expired(sender, recipient, this.balance);
        }
    }

    function reclaim (bytes _preimage) public nonReentrant {
        require(hash(_preimage) == image);
        require(msg.sender == sender);
        require(
            state == State.EXPIRED ||
            state == State.INITIATED
        );

        // Check if reclaiming is possible at all
        if (state == State.EXPIRED || state == State.INITIATED && now > expires) {
            // Remember the amount to be transfered
            uint amount = this.balance;

            // Attempt to transfer it
            sender.transfer(amount);

            // The intiator has reclaimed their funds
            state = State.RECLAIMED;
            Reclaimed(sender, amount);
        } else {
            revert();
        }
    }

    // Helper functions

    function hash (bytes _preimage) internal returns (bytes32 _image) {
      return sha256(_preimage);
    }
}
