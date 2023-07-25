# `Constant Product Automated Market Maker`
The following repo contains a Constant Product Automated Market Maker implemented using the Move programming language which is a Rust-based smart contract programming language. 

The contract has three main functionalities:

* #### `Swapping Assets` 
    The liquidity pool supports the swapping of two assets from one kind to the other. 
* #### `Providing liquidity`
    Interested parties can provide liquidity by depositing amounts of each assets into the pool. The amount of liquidity provided by liquidity providers (LPs) is reflected on their `LP_Balance` and also tracked on the `LP_Ledger`.
* #### `Removing liquidity`
    A LP can remove the liquidity they provided. The contract currently doesn't support LP fees but that will be implemented in a future update.