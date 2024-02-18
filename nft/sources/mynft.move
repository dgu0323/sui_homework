module nft::mynft {
    use std::string::utf8;
    use sui::display;
    use sui::object;
    use sui::object::UID;
    use sui::package;
    use sui::transfer;
    use sui::tx_context;
    use sui::tx_context::TxContext;

    struct MYNFT has  drop {
    }

    struct CHENERGE has key, store {
        id: UID,
        tokenId: u64
    }

    struct State has key {
        id: UID,
        count: u64
    }

    fun init(otw: MYNFT, ctx: &mut TxContext){
        let keys = vector[
            utf8(b"name"),
            utf8(b"collection"),
            utf8(b"description"),
            utf8(b"image_url")
        ];

        let values = vector[
            utf8(b"CHENERGE #{tokenId}"),
            utf8(b"CHENERGE collection"),
            utf8(b"CHENERGE nb"),
            utf8(b"https://james-01-1256894360.cos.ap-beijing.myqcloud.com/2024-02-18-WechatIMG691%20-1-.jpg"),
        ];

        let publisher = package::claim(otw, ctx);
        let display = display::new_with_fields<CHENERGE>(&publisher, keys, values, ctx);

        display::update_version(&mut display);

        let deployer = tx_context::sender(ctx);

        transfer::public_transfer(publisher, deployer);
        transfer::public_transfer(display, deployer);

        transfer::share_object(State {
            id: object::new(ctx),
            count: 0
        });
    }

    public entry fun mint(state: &mut State, ctx: &mut TxContext){
        state.count = state.count + 1;

        let nft = CHENERGE {
            id: object::new(ctx),
            tokenId: state.count
        };

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(nft, sender);
    }
}