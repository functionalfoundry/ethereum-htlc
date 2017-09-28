pragma solidity ^0.4.0;


/**
 * @title Hashed time-locked contract.
 */
contract HTLC {
    enum ExchangeState {
        INITIATED,
        COMPLETED,
        EXPIRED,
        RECLAIMED
    }

    struct Exchange {
        // Participants in the exchange
        address sender;
        address recipient;

        // Secret hashed by sender
        bytes32 image;

        // Expiration timestamp
        uint expires;

        // State of the exchange
        ExchangeState state;
    }

    Exchange public exchange;

    function HTLC (address recipient, bytes32 image, uint expirationTime) payable {
        exchange.sender = msg.sender;
        exchange.recipient = recipient;
        exchange.image = image;
        exchange.expires = now + expirationTime;
        exchange.state = ExchangeState.INITIATED;
    }

    function complete (bytes preimage) public {
        require(hash(preimage) == exchange.image);
        require(msg.sender == exchange.recipient);
        require(exchange.state == ExchangeState.INITIATED);

        if (now <= exchange.expires) {
            msg.sender.transfer(this.balance);
            exchange.state = ExchangeState.COMPLETED;
        } else {
            exchange.state = ExchangeState.EXPIRED;
        }
    }

    function reclaim (bytes preimage) public {
        require(hash(preimage) == exchange.image);
        require(msg.sender == exchange.sender);
        require(
            exchange.state == ExchangeState.EXPIRED ||
            exchange.state == ExchangeState.INITIATED
        );

        if (exchange.state == ExchangeState.EXPIRED) {
            msg.sender.transfer(this.balance);
            exchange.state = ExchangeState.RECLAIMED;
        } else if (exchange.state == ExchangeState.INITIATED) {
            if (now > exchange.expires) {
                msg.sender.transfer(this.balance);
                exchange.state = ExchangeState.RECLAIMED;
            } else {
                revert(); // Is this the right thing to do?
            }
        }
    }

    function hash (bytes preimage) internal returns (bytes32 image) {
      return sha256(preimage);
    }
}
