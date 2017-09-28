# ethereum-htlc

### Prerequisites
Node, npm, testrpc, truffle


To start development and run the tests you'll want at least one account with enough funds to perform the atomic swap. If you're using test rpc the following command should get you up and running
```
testrpc --account="0x22e2ba90f06cb8ba247347e2eff9a3488f71ff76c7110672e117ecb228be80b6,100000000000000000000" --account="0x1b79656d6bd43e7cfd1669885ff8826ba6fb8d8b5d5b16e7fc41c2812ccdbf8d,100000000000000000000"
```
Then in another terminal
```
npm install
truffle test
```
