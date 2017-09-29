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

    function HTLC (address _recipient, bytes32 _image, uint _expirationTime) payable {
        sender = msg.sender;
        recipient = _recipient;
        image = _image;
        expires = now + _expirationTime;
        state = State.INITIATED;
    }

    function complete (bytes _preimage) public nonReentrant {
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

    function reclaim (bytes _preimage) public nonReentrant {
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

    function hash (bytes _preimage) internal returns (bytes32 _image) {
      return sha256(_preimage);
    }
}
