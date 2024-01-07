# ZapWarrant

## Summary

- a protocol to let anyone list any option as long as its underlying is an ERC20 token.
- any token, strike, maturity
- option type: european
- roles
    - seller: the person who list call or put option
    - buyer: the person who buy call or put option
- at maturity, if in the money the buyer can execute the right, do actual or cash settlement.

### Why doing this

- Most of the crypto options are traded in a traditional option way, that is there will be some fixed maturities and strikes
- For warrants, the theoretical price calculation is the same as option, while the seller can decide any maturity and strike.
- Currently underlying assets for option are quite limited to main coins such as BTC and ETH, hopefully more people will list options on RWA tokens.

![Untitled](Appworks%20Final%20Project%2001e45ebb620d44c2909e2bd2ecf6ca43/Untitled.png)

### Background introduction on option and warrant

#### Example: BTC/USDT call option

1. terms
    1. strike: 40,000
    2. maturity: 12/10/2023
    3. quantity: 1
2. On 12/10/2023, the buyer has the right to buy 1 BTC with 40,000 USDT
    1. if the option is in the money (current price > 40,000), the buyer can execute the right
    2. if the option is out of the money (current price ≤ 40,000), the buyer has no incentive to use this right.

#### Option vs Warrant

In finance, a warrant and an option are similar but distinct financial instruments, both giving the holder the right, but not the obligation, to buy or sell a security at a specified price before a certain date. However, there are key differences between them:

|  | Option | Warrant |
| --- | --- | --- |
| Issuer | Issued by options exchanges and not directly by companies. | Typically issued by the company whose stock is the subject of the warrant.  |
| Maturity | Fixed dates and frequency | flexible dates and no pre determined frequency |
| Exercise price | Usually has a rule of strike is decided | no obvious rule |
| Liquidity | widely traded on options exchanges | traded less frequently and may be less liquid than options. |

### Roles

#### Role: Seller

1. choose an pair to list option
    1. if the pair address not existed yet, anyone can create it
2. list option
    1. call: escrow base asset
    2. put: escrow quote asset
3. before maturity
    1. cancel listing: listing CANCELED, release escrow asset back to the seller
    2. sold to buyer
4. on maturity date
    1. option not sold: listing EXPIRED, release escrow back to the seller
    2. option SOLD
        1. out of the money: listing EXPIRED, release escrow back to the seller
        2. in the money
            1. buyer execute the right within 24 hours
                1. actual settlement: transfer assets between buyer and seller
                2. cash settlement: transfer the profit to buyer and the rest back to the seller
                    1. call: transfer `(last_price - strike) / last_price * quantity` of base asset
                    2. put: transfer `(strike_price - last_price) * quantity` of quote asset 
            2. buyer doesn’t execute the right within 24 hours: listing EXPIRED, release escrow back to the seller

#### Role: Buyer

1. choose a pair
2. buy one listing
    1. transfer premium to seller
3. hold an option
4. on maturity
    1. out of the money: listing EXPIRED
    2. in the money
        1. executes the right with 24 hours
            1. actual settlement: transfer assets between buyer and seller
            2. cash settlement: transfer the profit to buyer and the rest back to the seller
                1. call: transfer `(last_price - strike) / last_price * quantity` of base asset
                2. put: transfer `(strike_price - last_price) * quantity` of quote asset 
        2. doesn’t execute the right within 24 hours: listing EXPIRED

## Implementation

### Flows

#### Warrant lifcycle

![Untitled](Appworks%20Final%20Project%2001e45ebb620d44c2909e2bd2ecf6ca43/Untitled%201.png)

#### Contracts relationships

[https://imgr.whimsical.com/object/AS21J9tDBmTmEzip1mLUMj](https://imgr.whimsical.com/object/AS21J9tDBmTmEzip1mLUMj)

### Core components

#### Warrant

1. id
2. seller
3. buyer
4. baseToken
5. quoteToken
6. warrantType: CALL, PUT
7. strikePrice
8. maturity
9. baseAmount
10. quoteAmount
11. premium
12. isCashSettled
13. status: INIT, ACTIVE, CANCELED, SOLD, EXPIRED, EXERCISED

#### Contracts

| Contract | Description | Key functions | Key events |
| --- | --- | --- | --- |
| WarrantFactory | Manage all pairs’ address and the creation of new venue | - get warrant pair address<br>- create new pair | - WarrantPairCreated<br>- SettlementCreated |
| WarrantPair | The pair’s main trading venue, for all the trading activities | - sell<br>- buy<br>- cancel<br>- exercise: actual or cash<br>- expire | - WarrantListed<br>- WarrantSold<br>- WarrantCanceled<br>- WarrantExercised<br>- WarrantExpired |
| Settlement | Responsible for all the money related actions | - escrow<br>- release<br>- pay premium<br>- cash settlement<br>- actual settlement | - FundsEscrowed<br>- FundsReleased |
