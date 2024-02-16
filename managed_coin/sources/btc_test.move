#[test_only]
module managed_coin::btc_tests {

    use managed_coin::btc::{Self, BTC};
    use sui::coin::{Coin, TreasuryCap};
    use sui::test_scenario::{Self, next_tx, ctx};

    #[test]
    fun mint_burn() {
        let addr1 = @0xA;
        let scenario = test_scenario::begin(addr1);

        // init
        {
            btc::test_init(ctx(&mut scenario))
        };

        // mint
        next_tx(&mut scenario, addr1);
        {
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<BTC>>(&scenario);
            btc::mint(&mut treasurycap, 100, test_scenario::ctx(&mut scenario));
            test_scenario::return_to_address<TreasuryCap<BTC>>(addr1, treasurycap);
        };

        // burn
        next_tx(&mut scenario, addr1);
        {
            let coin = test_scenario::take_from_sender<Coin<BTC>>(&scenario);
            let treasurycap = test_scenario::take_from_sender<TreasuryCap<BTC>>(&scenario);
            btc::burn(&mut treasurycap, coin);
            test_scenario::return_to_address<TreasuryCap<BTC>>(addr1, treasurycap);
        };

        // Cleans up the scenario object
        test_scenario::end(scenario);
    }
}