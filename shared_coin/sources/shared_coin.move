module shared_coin::ETH {
    use std::option;
    use sui::coin;
    use sui::coin::TreasuryCap;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ETH has drop {}

    fun init(witness: ETH, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"ETH", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury);
    }

    public entry fun mint(treasury_cap: &mut TreasuryCap<ETH>,
                          amount: u64,
                          ctx: &mut TxContext) {
        let to = tx_context::sender(ctx);
        coin::mint_and_transfer(treasury_cap, amount, to, ctx);
    }
}
