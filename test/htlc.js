const shajs = require('sha.js')
const pad = require('pad')

const HTLC = artifacts.require('./HTLC.sol')

/**
 * Utilities
 */

const etherToWei = value => web3.toWei(value, 'ether')
const weiToEther = value => web3.fromWei(value, 'ether')

// 0-pads a string to 64 characters (32 bytes)
const to32No0x = buffer => pad(buffer, 64, '0')
// 0-pads a string into 64 characters (32 bytes) and prepends a 0x
const to32 = buffer => `0x${to32No0x(buffer)}`
// Converts an ascii string into a hex string
const encodeString = str => Buffer.from(str).toString('hex')
// Converts a hex string into an ascii string
const decodeString = hex => new Buffer(to32No0x(hex), 'hex').toString()

const delay = t => new Promise(resolve => setTimeout(resolve, t))

const transactionCost = tx =>
  web3.eth.getTransactionReceipt(tx).gasUsed * web3.eth.getTransaction(tx).gasPrice

const sha256 = preimage =>
  shajs('sha256')
    .update(preimage)
    .digest('hex')

const hash = preimage => sha256(preimage)

const to32 = buffer => `0x${pad(buffer, 64, '0')}`

const increaseTime = seconds =>
  web3.currentProvider.send({
    jsonrpc: '2.0',
    method: 'evm_increaseTime',
    params: [seconds],
    id: 0,
  })

/**
 * Contract tests
 */

contract('HTLC', async accounts => {
  before(() => {})

  it('conversion helpers between Ether and Wei are correct', () => {
    assert(2 == weiToEther(etherToWei(2)), 'Wei <-> Ether conversion is correct')
  })

  it('has a zero balance initially', async () => {
    const instance = await HTLC.new()
    const balance = web3.eth.getBalance(instance.address)
    assert(balance.toNumber() === 0, 'Contract balance is 0')
  })

  it('balances are correct after exchange is initiated', async () => {
    const sender = accounts[0]
    const recipient = accounts[1]

    const image = hash('secret')

    const senderBalanceBefore = web3.eth.getBalance(sender)
    const recipientBalanceBefore = web3.eth.getBalance(recipient)

    // Create a HTLC contract to send 2 ETH from sender to recipient
    // if the recipient can provide the secret within 10 seconds
    const instance = await HTLC.new(recipient, image, 10, {
      from: sender,
      value: etherToWei(2),
    })

    // Verify that the contract balance is updated correctly
    const balance = web3.eth.getBalance(instance.address)
    assert(weiToEther(balance).equals(2), 'Contract balance is 2 ETH')

    // Verify that the sender balance is reduced by the amount to be exchanged
    const senderBalanceAfter = web3.eth.getBalance(sender)
    assert(
      senderBalanceBefore
        .minus(transactionCost(instance.transactionHash))
        .minus(etherToWei(2))
        .equals(senderBalanceAfter),
      'Sender balance is 2 ETH less than before'
    )

    // Verify that the recipient balance remains unchanged (since the exchange
    // has not been completed yet)
    const recipientBalanceAfter = web3.eth.getBalance(recipient)
    assert(
      recipientBalanceAfter.equals(recipientBalanceBefore),
      'Recipient balance remains unchanged'
    )
  })

  it('balances are correct after exchange is completed', async () => {
    const sender = accounts[0]
    const recipient = accounts[1]
    const secret = 'secret'

    /**
     * This decode(encode(x)) is absolute magic. I can't explain why this is necessary but it's the only way
     * I've found to get the images to match between JS and the EVM when using a 32-byte
     * preimage.
     */
    const image = to32(hash(decodeString(encodeString(secret))))

    const senderBalanceBefore = web3.eth.getBalance(sender)
    const recipientBalanceBefore = web3.eth.getBalance(recipient)

    // Create a HTLC contract to send 2 ETH from sender to recipient
    // if the recipient can provide the secret within 10 seconds
    const instance = await HTLC.new(recipient, image, 10, {
      from: sender,
      value: etherToWei(2),
    })

    // Complete the exchange and send the 2 ETH to the recipient

    const completion = await instance.complete(secret, { from: recipient })

    // Verify that the contract balance is back to 0
    const balance = web3.eth.getBalance(instance.address)
    assert(weiToEther(balance).equals(0), 'Contract balance is 0 ETH')

    // Verify that the sender balance is reduced by the amount to be exchanged
    const senderBalanceAfter = web3.eth.getBalance(sender)
    assert(
      senderBalanceBefore
        .minus(transactionCost(instance.transactionHash))
        .minus(etherToWei(2))
        .equals(senderBalanceAfter),
      'Sender balance is 2 ETH less than before creating the contract'
    )

    // Verify that the recipient balance is increased by the amount to be exchanged
    const recipientBalanceAfter = web3.eth.getBalance(recipient)
    assert(
      recipientBalanceBefore
        .plus(etherToWei(2))
        .minus(transactionCost(completion.tx))
        .equals(recipientBalanceAfter),
      'Receipient balance is 2 ETH more than before'
    )
  })

  it('allows the sender to reclaim their ETH after time expiration', async () => {
    const sender = accounts[0]
    const recipient = accounts[1]
    const secret = 'secret'
    const image = to32(hash(decodeString(encodeString(secret))))

    const senderBalanceBefore = web3.eth.getBalance(sender)
    const recipientBalanceBefore = web3.eth.getBalance(recipient)

    // Create a HTLC contract to send 2 ETH from sender to recipient
    // if the recipient can provide the secret within 100ms
    const instance = await HTLC.new(recipient, image, 0.1, {
      from: sender,
      value: etherToWei(2),
    })

    // Advance the time by one second
    increaseTime(1)

    // Reclaim the ether
    const reclamation = await instance.reclaim(secret, { from: sender })

    // Verify that the contract balance is back to 0
    const balance = web3.eth.getBalance(instance.address)
    assert(weiToEther(balance).equals(0), 'Contract balance is 0 ETH')

    // Verify that the sender has had their balance restored minus fees
    const senderBalanceAfter = web3.eth.getBalance(sender)
    assert(
      senderBalanceBefore
        .minus(transactionCost(instance.transactionHash))
        .minus(transactionCost(reclamation.tx))
        .equals(senderBalanceAfter),
      'Sender balance has been restored minus feels'
    )
  })

  it('prevents the sender from reclaiming their ETH before the expiration', async () => {
    const sender = accounts[0]
    const recipient = accounts[1]
    const secret = 'secret'

    const image = to32(hash(decodeString(encodeString(secret))))

    // Create a HTLC contract to send 2 ETH from sender to recipient
    // if the recipient can provide the secret within 10 seconds
    const instance = await HTLC.new(recipient, image, 10, {
      from: sender,
      value: etherToWei(2),
    })

    // Advance the time by a second
    increaseTime(1)

    // Attempt to reclaim too early
    try {
      await instance.reclaim(secret, { from: sender })
    } catch (e) {
      return
    }
    throw new Error('Expected calling reclaim before the exparation to throw')
  })
})
