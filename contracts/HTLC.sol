pragma solidity ^0.4.0;

/**
 * @title Hashed time-locked contract.
 */
contract HTLC {
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

    bool locked;
    modifier noReentrancy() {
      require(!locked);
      locked = true;
      _;
      locked = false;
    }


    function HTLC (address _recipient, bytes32 _image, uint _expirationTime) payable {
        sender = msg.sender;
        recipient = _recipient;
        image = _image;
        expires = now + _expirationTime;
        state = State.INITIATED;
    }

    /**
     *  Called by the recipient once they've obtained the primage from the sender.
     *  This allows them to receive their ETH and complete the transaction.
     *  @param _preimage - The secret that when hashed will produce the original image
     */
    function complete (bytes32 _preimage) public noReentrancy {
        require(hash(_preimage) == image);
        require(msg.sender == recipient);
        require(state == State.INITIATED);

        if (now <= expires) {
            msg.sender.transfer(this.balance);
            state = State.COMPLETED;
        } else {
            state = State.EXPIRED;
        }
    }

    /**
     *  Called by the sender after the expiration time has elapsed. If the recipient
     *  was not able to complete the transaction in time and the sender can prove
     *  they have the secret they're able to reclaim their funds.
     *  @param _preimage - The secret that when hashed will produce the original image
     */
    function reclaim (bytes32 _preimage) public noReentrancy {
        require(hash(_preimage) == image);
        require(msg.sender == sender);
        require(
            state == State.EXPIRED ||
            state == State.INITIATED
        );

        if (state == State.EXPIRED) {
            msg.sender.transfer(this.balance);
            state = State.RECLAIMED;
        } else if (state == State.INITIATED) {
            if (now > expires) {
                msg.sender.transfer(this.balance);
                state = State.RECLAIMED;
            } else {
                revert();
            }
        }
    }

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
