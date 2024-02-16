module managed_coin::btc {
    use std::option;
    use sui::coin;
    use sui::coin::{TreasuryCap, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    const TOTAL_SUPPLY: u64 = 100_000_000_000;

    struct BTC has drop {}

    const EExceedSupply: u64 = 99;

    fun init(witness: BTC,
             ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(witness, 6, b"BTC", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    public entry fun mint(treasury_cap: &mut TreasuryCap<BTC>,
                          amount: u64,
                          ctx: &mut TxContext) {
        let supply = coin::total_supply(treasury_cap);
        assert!((supply + amount) <= TOTAL_SUPPLY, EExceedSupply);

        let to = tx_context::sender(ctx);
        coin::mint_and_transfer(treasury_cap, amount, to, ctx);
    }

    public entry fun mint_to(treasury_cap: &mut TreasuryCap<BTC>,
                             amount: u64,
                             to: address,
                             ctx: &mut TxContext) {
        let supply = coin::total_supply(treasury_cap);
        assert!((supply + amount) <= TOTAL_SUPPLY, EExceedSupply);

        coin::mint_and_transfer(treasury_cap, amount, to, ctx);
    }

    public entry fun transfer(coin: Coin<BTC>,
                              to: address) {
        transfer::public_transfer(coin, to);
    }

    public entry fun burn(treasury_cap: &mut TreasuryCap<BTC>,
                          coin: Coin<BTC>) {
        coin::burn(treasury_cap, coin);
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(BTC {}, ctx)
    }
}
