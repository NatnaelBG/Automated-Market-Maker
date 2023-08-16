/// This module defines a minimal Asset and Balance.
module NamedAddr::CPAMM {
    use std::signer;
    use std::debug;
    use std::vector;

    /// Address of the owner of this module
    const MODULE_OWNER: address = @NamedAddr;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 441;
    const EINSUFFICIENT_BALANCE: u64 = 442;
    const EALREADY_HAS_BALANCE: u64 = 443;
    const EINVALID_ASSET_RATIO: u64 = 444;
    const EINVALID_BALANCE: u64 = 445;
    const EINVALID_RESERVE_BAL: u64 = 551;
    const EINVALID_OPERATION: u64 = 600;
    

    struct Asset has key, store, drop, copy {
        value: u64
    }

    // struct to link addresses to their amm balances
    struct AMM_Balance has key, copy {
        asset1: Asset,
        asset2: Asset
    }

    struct Reserve has key, store {
        asset1_reserve: u64,
        asset2_reserve: u64
    }

    struct LP_Balance has key, store, copy, drop {
        addr: address,
        asset1_lp: Asset,
        asset2_lp: Asset
    }

    // struct to keep track of all liquidity providers, their addresses and the amount of liquidity they provided
    struct LP_Ledger has key, store, copy, drop {
        ledger: vector<LP_Balance>
    }

    fun publish_reserve(account: &signer):bool {
        assert!(signer::address_of(account) == MODULE_OWNER, ENOT_MODULE_OWNER);
        let reserve = Reserve { asset1_reserve: 100000, asset2_reserve: 100000 };
        assert!(!exists<Reserve>(signer::address_of(account)), EALREADY_HAS_BALANCE);
        move_to(account, reserve);
        return true
    }

    fun publish_LP_ledger(account: &signer):bool {
        assert!(signer::address_of(account) == MODULE_OWNER, ENOT_MODULE_OWNER);
        let lp_ledger_vector = vector::empty<LP_Balance>();
        let lp_ledger = LP_Ledger { ledger: lp_ledger_vector };
        // assert!(!exists<LP_Ledger>(signer::address_of(account)), EALREADY_HAS_BALANCE);
        // move_to(account, lp_ledger);
        if(!exists<LP_Ledger>(signer::address_of(account))) {
            move_to(account, lp_ledger);
        };
        
        return true
    }

    /// Publish an empty balance resource under `account`'s address in global storage. This function must be called before

    fun publish_AMM_balance(account: &signer):bool {
        let null_asset = Asset { value: 0 };
        // assert!(!exists<AMM_Balance>(signer::address_of(account)), EALREADY_HAS_BALANCE);
        // move_to(account, AMM_Balance { asset1:  null_asset, asset2:  null_asset  });
        if(!exists<AMM_Balance>(signer::address_of(account))) {
            move_to(account, AMM_Balance { asset1:  null_asset, asset2:  null_asset  });
        };
        
        return true
    }

    public fun get_amm_balance_of(account: address): (u64, u64) acquires AMM_Balance {
        return (borrow_global<AMM_Balance>(account).asset1.value, borrow_global<AMM_Balance>(account).asset2.value)
    }

    fun get_reserve_balance(owner: &signer): (u64, u64) acquires Reserve {
        let addr: address = signer::address_of(owner);
        return (borrow_global<Reserve>(addr).asset1_reserve, borrow_global<Reserve>(addr).asset2_reserve)
    }

    /// Deposit `amount` number of tokens to the balance under `addr`.
    fun deposit_asset1_to_address(addr: address,  _value: u64) acquires AMM_Balance, Reserve{
        // check if we have enough balance in the reserve
        let reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset1_reserve;
        assert!(*reserve_ref > _value, EINVALID_RESERVE_BAL);      
        let (bal1, _) = get_amm_balance_of(addr);
        let balance_ref = &mut borrow_global_mut<AMM_Balance>(addr).asset1.value;
        *balance_ref = bal1 + _value;
        *reserve_ref = *reserve_ref - _value;
    }

    fun deposit_asset2_to_address(addr: address,  _value: u64) acquires AMM_Balance, Reserve{
        // check if we have enough balance in the reserve
        let reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset2_reserve;
        assert!(*reserve_ref > _value, EINVALID_RESERVE_BAL); 

        let (_, bal2) = get_amm_balance_of(addr);
        let balance_ref = &mut borrow_global_mut<AMM_Balance>(addr).asset2.value;
        *balance_ref = bal2 + _value; 
        *reserve_ref = *reserve_ref - _value;
    }

    fun withdraw_asset1_from_address(addr: address, amount: u64) : bool acquires AMM_Balance, Reserve {
        assert!(amount > 0, EINVALID_BALANCE);
        // let (bal1, _) = get_amm_balance_of(addr);
        // balance must be greater than the withdraw amount
        let balance_ref = &mut borrow_global_mut<AMM_Balance>(addr).asset1.value;
        let bal1: u64 = *balance_ref;
        assert!(bal1 >= amount, EINSUFFICIENT_BALANCE);
        // let balance_ref = &mut borrow_global_mut<AMM_Balance>(addr).asset1.value;
        *balance_ref = bal1 - amount;
        let asset1_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset1_reserve;
        *asset1_reserve_ref = *asset1_reserve_ref + amount;
        return true
    }

    fun withdraw_asset2_from_address(addr: address, amount: u64) : bool acquires AMM_Balance, Reserve {
        assert!(amount > 0, EINVALID_BALANCE);
        // let (_, bal2) = get_amm_balance_of(addr);
        // balance must be greater than the withdraw amount
        let balance_ref = &mut borrow_global_mut<AMM_Balance>(addr).asset2.value;
        let bal2: u64 = *balance_ref;
        assert!(bal2 >= amount, EINSUFFICIENT_BALANCE);
        *balance_ref = bal2 - amount;
        let asset2_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset2_reserve;
        *asset2_reserve_ref = *asset2_reserve_ref + amount;
        return true
    }

    // 

    fun publish_LP_balance(account: &signer):bool {
        let user_addr: address = signer::address_of(account);
        if (!exists<LP_Balance>(user_addr)) {
            
            let null_asset = Asset { value: 0 };
            move_to(account, LP_Balance { addr: user_addr, asset1_lp:  null_asset, asset2_lp:  null_asset  });
        };
        return true
    }

    public fun provide_liquidity(account: &signer, amount1: u64, amount2: u64): bool acquires AMM_Balance, Reserve, LP_Balance, LP_Ledger {
        let isWithdrawal = false;
        assert!(amount1 > 0 && amount2 > 0, EINVALID_ASSET_RATIO);
        let new_lp_bal_created: bool = publish_LP_balance(account);
        assert!(new_lp_bal_created == true, EINVALID_OPERATION);
        // formula: dy/dx = Y / X -> Xdy = Ydx
        let asset1_reserve_ref_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset1_reserve;
        let asset1_reserve_bal = *asset1_reserve_ref_ref;
        let asset2_reserve_ref_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset2_reserve;
        let asset2_reserve_bal = *asset2_reserve_ref_ref;

        // let's check if dy/dx == Y/X -> new_asset2 / new_asset1 = asset2_reserve / asset1_reserve
        assert!((amount2 / amount1) == (asset2_reserve_bal / asset1_reserve_bal), EINVALID_ASSET_RATIO);
        
        // withdraw both amounts from the account and add it to reserve
        let addr: address = signer::address_of(account);
        withdraw_asset1_from_address(addr, amount1); 
        withdraw_asset2_from_address(addr, amount2); 

        // update LP's `LP_Balance`
        let lp_asset1_ref = &mut borrow_global_mut<LP_Balance>(addr).asset1_lp.value;
        *lp_asset1_ref = *lp_asset1_ref + amount1 ;
        let lp_asset2_ref = &mut borrow_global_mut<LP_Balance>(addr).asset2_lp.value;
        *lp_asset2_ref = *lp_asset2_ref + amount2 ;

        // update LP list
        assert!(update_lp_ledger(addr, amount1, amount2, isWithdrawal) == true, EINVALID_OPERATION);

        return true
    }

    fun update_lp_ledger(account: address, amount1: u64, amount2: u64, withdrawal: bool): bool acquires LP_Ledger {
        let lp_ledger_ref = &mut borrow_global_mut<LP_Ledger>(@NamedAddr).ledger;
        let lp_ledger_list = *lp_ledger_ref;
        // iterate to find the LP provider
        let size = vector::length(&lp_ledger_list);
        let index = 0;
        let found: bool = false;

        while (index < size) {
            let element = vector::borrow(&lp_ledger_list, index);

            if ((*element).addr == account) {
                if (withdrawal == false) {
                    found = true;
                (*element).asset1_lp.value = (*element).asset1_lp.value + amount1;
                (*element).asset2_lp.value = (*element).asset2_lp.value + amount2;
                break
                // Exit the loop since we found the value 
                }
                else {
                    found = true;
                (*element).asset1_lp.value = (*element).asset1_lp.value - amount1;
                (*element).asset2_lp.value = (*element).asset2_lp.value - amount2;
                break
                }
                
            }
            else {
                index = index + 1;
                }
        };
    
        if (!found) {
            /*vector::push_back<T>(v: &mut vector<T>, t: T)*/
            let asset1 = Asset { value: amount1 };
            let asset2 = Asset { value: amount2 };
            let new_lp_balance = LP_Balance {addr: account, asset1_lp: asset1, asset2_lp: asset2};
            vector::push_back<LP_Balance>(lp_ledger_ref, new_lp_balance);
            found = true;
        };
        return found
    }

    public fun remove_liquidity(account: &signer, amount1: u64, amount2: u64): bool acquires AMM_Balance, Reserve, LP_Balance, LP_Ledger {
        let isWithdrawal: bool = true;
        let addr: address = signer::address_of(account);
        // let's ensure the account doesn't withdraw more liquidity than it provided
        // let lp_asset_ref = &mut borrow_global_mut<LP_Balance>(addr);
        let lp_asset_ref = &mut borrow_global_mut<LP_Balance>(addr).asset1_lp;
        assert!((*lp_asset_ref).value > amount1, EINSUFFICIENT_BALANCE);
        lp_asset_ref = &mut borrow_global_mut<LP_Balance>(addr).asset2_lp;
        assert!((*lp_asset_ref).value > amount2, EINSUFFICIENT_BALANCE);

        // formula: dy/dx = Y / X -> Xdy = Ydx
        let asset1_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset1_reserve;
        let asset1_reserve_bal = *asset1_reserve_ref;
        let asset2_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset2_reserve;
        let asset2_reserve_bal = *asset2_reserve_ref;

        assert!(amount1 > 0 && amount2 > 0, EINVALID_BALANCE);
        assert!(asset1_reserve_bal > 0, EINVALID_RESERVE_BAL);

        // let's check if dy/dx == Y/X -> new_asset2 / new_asset1 = asset2_reserve / asset1_reserve
        assert!((amount2 / amount1) == (asset2_reserve_bal / asset1_reserve_bal), EINVALID_ASSET_RATIO);
        
        // withdraw both amounts from the reserve and add it to account
        deposit_asset1_to_address(addr, amount1); 
        deposit_asset2_to_address(addr, amount2); 

        // update LP's `LP_Balance`
        let lp_asset_val_ref = &mut borrow_global_mut<LP_Balance>(addr).asset1_lp.value;
        (*lp_asset_val_ref) = (*lp_asset_val_ref) - amount1 ;
        let lp_asset_val_ref = &mut borrow_global_mut<LP_Balance>(addr).asset2_lp.value;
        *lp_asset_val_ref = *lp_asset_val_ref - amount2 ;

        // update LP list
        assert!(update_lp_ledger(addr, amount1, amount2, isWithdrawal) == true, EINVALID_OPERATION);

        
        return true
    }

    public fun swap_asset1_to_asset2 (owner: &signer, amount: u64): bool acquires AMM_Balance, Reserve { 
        assert!(amount > 0, EINVALID_BALANCE);

        // calculate the amount of the return asset i.e. the amount asset we'll be returning
        // formula: dy = Ydx / (X + dx) -> return_amount = (asset2_reserve * amount) / (asset1_reserve + amount)
        let asset1_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset1_reserve;
        let asset1_reserve_bal = *asset1_reserve_ref;
        let asset2_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset2_reserve;
        let asset2_reserve_bal = *asset2_reserve_ref;

        let return_amount: u64;
        return_amount = (asset2_reserve_bal * amount) / (asset1_reserve_bal + amount);
        let addr: address = signer::address_of(owner);
        withdraw_asset1_from_address(addr, amount);
        deposit_asset2_to_address(addr, return_amount);
        return true
    }

    public fun swap_asset2_to_asset1 (owner: &signer, amount: u64): bool acquires AMM_Balance, Reserve { 
        assert!(amount > 0, EINVALID_BALANCE);
        // calculate the amount of the return asset i.e. the amount asset we'll be returning
        // formula: dy = Ydx / (X + dx) -> return_amount = (asset1_reserve * amount) / (asset2_reserve + amount)
        let asset1_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset1_reserve;
        let asset1_reserve_bal = *asset1_reserve_ref;
        let asset2_reserve_ref = &mut borrow_global_mut<Reserve>(@NamedAddr).asset2_reserve;
        let asset2_reserve_bal = *asset2_reserve_ref;

        let return_amount: u64;
        return_amount = (asset1_reserve_bal * amount) / (asset2_reserve_bal + amount);
        let addr: address = signer::address_of(owner);
        withdraw_asset2_from_address(addr, amount);
        deposit_asset1_to_address(addr, return_amount);
        return true
    }

    #[test(account = @0x1)]
    fun test_publish_LP_balance(account: signer) {
        assert!(publish_LP_balance(&account) == true, EINVALID_BALANCE);
    }


    #[test(account = @0x1)]
    fun test_publish_AMM_balance(account: signer) {
        assert!(publish_AMM_balance(&account) == true, 0);
    }

    #[test(account = @0x1)]
    fun test_get_amm_balance_of(account:signer) acquires AMM_Balance {
        publish_AMM_balance(&account);
        let addr = signer::address_of(&account);
        let (bal1, bal2): (u64, u64) = get_amm_balance_of(addr);
        assert!(bal1 == 0 && bal2 == 0, 0);
        // debug::print(&bal1);
        // debug::print(&bal2);
    }
    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_publish_reserve(owner_acc: &signer) {
        publish_reserve(owner_acc);

    }

    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_deposit_asset1_to_address(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve {
        publish_AMM_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 900;

        // initialise reserve
        publish_reserve(owner_acc);

        // deposit
        deposit_asset1_to_address(addr, first_deposit);
        let (new_bal1, _): (u64, u64) = get_amm_balance_of(addr);
        assert!(new_bal1 == first_deposit, 0);
        debug::print(&new_bal1);
    }

    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_deposit_asset2_to_address(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve {
        publish_AMM_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 900;

        // initialise reserve
        publish_reserve(owner_acc);

        // deposit
        deposit_asset2_to_address(addr, first_deposit);
        let (_, new_bal2): (u64, u64) = get_amm_balance_of(addr);
        assert!(new_bal2 == first_deposit, 0);
        debug::print(&new_bal2);
    }

    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_withdraw_asset1_from_address(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve {
        publish_AMM_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 900;
        // initialise reserve
        publish_reserve(owner_acc);
        // deposit
        deposit_asset1_to_address(addr, first_deposit);

        // pre withdrawal balances
        let (pre_withdrawal_bal1, _): (u64, u64) = get_amm_balance_of(addr);
        let (pre_withdrawal_reserve1_bal, _) = get_reserve_balance(owner_acc);

        // withdrawal
        let withdrawal_amount: u64 = 250;
        let withdrawal_status: bool = withdraw_asset1_from_address(addr, withdrawal_amount);
        assert!(withdrawal_status == true, 0);

        // post withdrawal
        let (post_withdrawal_bal1, _): (u64, u64) = get_amm_balance_of(addr);
        let (post_withdrawal_reserve1_bal, _) = get_reserve_balance(owner_acc);

        // check user bal
        assert!(post_withdrawal_bal1 == pre_withdrawal_bal1 - withdrawal_amount, 0);

        // check reserve bal
        assert!(post_withdrawal_reserve1_bal == pre_withdrawal_reserve1_bal + withdrawal_amount, 0);  

    }

    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_withdraw_asset2_from_address(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve {
        publish_AMM_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 900;
        // initialise reserve
        publish_reserve(owner_acc);
        // deposit
        deposit_asset2_to_address(addr, first_deposit);

        // pre withdrawal balances
        let (_, pre_withdrawal_bal2): (u64, u64) = get_amm_balance_of(addr);
        let (_, pre_withdrawal_reserve2_bal) = get_reserve_balance(owner_acc);

        // withdrawal
        let withdrawal_amount: u64 = 250;
        let withdrawal_status: bool = withdraw_asset2_from_address(addr, withdrawal_amount);
        assert!(withdrawal_status == true, 0);

        // post withdrawal
        let (_, post_withdrawal_bal2): (u64, u64) = get_amm_balance_of(addr);
        let (_, post_withdrawal_reserve2_bal) = get_reserve_balance(owner_acc);

        // check user bal
        assert!(post_withdrawal_bal2 == pre_withdrawal_bal2 - withdrawal_amount, 0);

        // check reserve bal
        assert!(post_withdrawal_reserve2_bal == pre_withdrawal_reserve2_bal + withdrawal_amount, 0);
        

    }
    #[test(account = @0x1, owner_acc = @NamedAddr)]
    fun test_provide_liquidity(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve, LP_Balance, LP_Ledger {
        publish_LP_ledger(owner_acc);
        publish_AMM_balance(account);
        publish_LP_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 1000;
        // initialise reserve
        publish_reserve(owner_acc);
        // deposit
        deposit_asset1_to_address(addr, first_deposit);
        deposit_asset2_to_address(addr, first_deposit);
        let amount1: u64 = 100;
        let amount2: u64 = 100;
        assert!(provide_liquidity(account, amount1, amount2), 0);
    }

    #[test(account = @0x1, owner_acc = @0x42)]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE)]
    fun test_remove_liquidity(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve, LP_Balance, LP_Ledger {
        publish_LP_ledger(owner_acc);
        publish_AMM_balance(account);
        publish_LP_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 10000;
        // initialise reserve
        assert!(publish_reserve(owner_acc) == true, 999);
        // deposit
        deposit_asset1_to_address(addr, first_deposit);
        deposit_asset2_to_address(addr, first_deposit);
        let amount1: u64 = 1000;
        let amount2: u64 = 1000;
        provide_liquidity(account, amount1, amount2);
        assert!(remove_liquidity(account, amount1, amount2), 0);
    }
    
    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_swap_asset1_to_asset2(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve {
        publish_AMM_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 1000;
        // initialise reserve
        assert!(publish_reserve(owner_acc) == true, 999);
        // deposit
        deposit_asset1_to_address(addr, first_deposit);
        let swap_amount: u64 = 1000;
        assert!(swap_asset1_to_asset2(account, swap_amount), 0);
    }

    #[test(account = @0x1, owner_acc = @0x42)]
    fun test_swap_asset2_to_asset1(account: &signer, owner_acc: &signer) acquires AMM_Balance, Reserve {
        publish_AMM_balance(account);
        let addr = signer::address_of(account);
        let first_deposit: u64 = 1000;
        // initialise reserve
        assert!(publish_reserve(owner_acc) == true, 999);
        // deposit
        deposit_asset2_to_address(addr, first_deposit);
        let swap_amount: u64 = 1000;
        assert!(swap_asset2_to_asset1(account, swap_amount), 0);
    }
}
