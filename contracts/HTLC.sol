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
    event Initiated(address _sender, address _recipient, uint _amount, uint _expires);
    event Completed(address _sender, address _recipient, uint _amount);
    event Expired(address _sender, address _recipient, uint _amount);
    event Reclaimed(address _sender, uint _amount);

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

    /**
     *  Called by the recipient once they've obtained the primage from the sender.
     *  This allows them to receive their ETH and complete the transaction.
     *  @param _preimage - The secret that when hashed will produce the original image
     */
    function complete (bytes32 _preimage) public nonReentrant {
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

    /**
     *  Called by the sender after the expiration time has elapsed. If the recipient
     *  was not able to complete the transaction in time and the sender can prove
     *  they have the secret they're able to reclaim their funds.
     *  @param _preimage - The secret that when hashed will produce the original image
     */
    function reclaim (bytes32 _preimage) public nonReentrant {
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

    /**
     *  The hash function for producing the image from the preimage. Right now
     *  this is using SHA256 but it should be updated to use SHA256d.
     *  @param _preimage - The value to hash
     *  @return The hashed image
     */
    function hash (bytes32 _preimage) internal returns (bytes32 _image) {
        return sha256(_preimage);
    }
}
