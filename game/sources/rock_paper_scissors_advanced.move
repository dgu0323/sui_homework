// 石头剪子布高级版本
// 支持同时多个游戏
module game::rock_paper_scissors_advanced {
    use std::hash;
    use std::vector;
    use sui::balance;
    use sui::balance::Balance;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object;
    use sui::object::UID;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context;
    use sui::tx_context::TxContext;

    // 每1把游戏的奖金数量
    const PRIZE_PRE_GAME: u64 = 1000;

    // 默认玩家地址，未进入游戏时
    const DEFAULT_PLAYER: address = @0x11;

    // 游戏手势
    const NONE: u8 = 0;
    const ROCK: u8 = 1;
    const PAPER: u8 = 2;
    const SCISSORS: u8 = 3;
    const CHEAT: u8 = 111;

    // 游戏状态
    // 玩家1刚创建游戏
    const STATUS_WAITING: u8 = 1;
    // 玩家2进入游戏
    const STATUS_READY: u8 = 2;
    // 一个玩家add hash
    const STATUS_HASH_SUBMISSION: u8 = 3;
    // 所有玩家都add hash完毕
    const STATUS_HASHES_SUBMITTED: u8 = 4;
    // 一个玩家add salt
    const STATUS_REVEALING: u8 = 5;
    // 所有玩家都add salt完毕，并自动出结果
    const STATUS_REVEALED: u8 = 6;

    // 奖池金额不够
    const EPrizePoolNotEnough: u64 = 1;
    // 游戏状态不允许add_hash
    const ENotAllowAddHashBecauseStatus: u64 = 2;
    // 已经add hash了
    const EAlreadyAddHash: u64 = 3;
    // 不是游戏参与者
    const ENotPlayer: u64 = 4;
    // 游戏状态不允许add salt
    const ENotAllowAddSaltBecauseStatus: u64 = 5;
    const EIsInGame: u64 = 7;
    const ENotAllowAddGameBecauseStatus: u64 = 8;
    // 已经add hash了
    const EAlreadyAddSalt: u64 = 9;

    // 奖池
    struct PrizePool has key, store {
        id: UID,
        balance: Balance<SUI>
    }

    // 管理员权限
    struct AdminCap has key {
        id: UID
    }

    // 游戏大厅
    struct GameSpace has key {
        id: UID,
        owner: address,
        // 奖池
        prize_pool: PrizePool
    }

    // 游戏
    struct Game has key {
        id: UID,
        // 这个游戏的奖金
        balance: Balance<SUI>,
        // 两名玩家地址
        player1: address,
        player2: address,
        // 两名玩家hash
        hash1: vector<u8>,
        hash2: vector<u8>,
        // 两名玩家实际手势
        gesture1: u8,
        gesture2: u8,
        // 游戏状态，对应 STATUS_xxx
        status: u8
    }

    fun init(ctx: &mut TxContext) {
        let deployer = tx_context::sender(ctx);

        let gameSpace = GameSpace {
            id: object::new(ctx),
            owner: deployer,
            prize_pool: PrizePool {
                id: object::new(ctx),
                balance: balance::zero<SUI>()
            }
        };

        transfer::transfer(AdminCap { id: object::new(ctx) }, deployer);

        transfer::share_object(gameSpace);
    }


    // 部署人可往奖池放奖金
    public entry fun add_prize(
        _: & AdminCap,
        gameSpace: &mut GameSpace,
        pay: Coin<SUI>
    ) {
        balance::join(&mut gameSpace.prize_pool.balance, coin::into_balance(pay));
    }


    // 任何人都可以开始游戏，并等待另一位玩家
    public entry fun start_game(gameSpace: &mut GameSpace, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);
        let prize_pool_balance_value = balance::value(&gameSpace.prize_pool.balance);

        // 奖池没奖金无法开启一个游戏
        assert!(prize_pool_balance_value > PRIZE_PRE_GAME, EPrizePoolNotEnough);

        let game = Game {
            id: object::new(ctx),
            balance: balance::split(&mut gameSpace.prize_pool.balance, PRIZE_PRE_GAME),
            player1: player,
            player2: DEFAULT_PLAYER,
            hash1: vector[],
            hash2: vector[],
            gesture1: NONE,
            gesture2: NONE,
            status: STATUS_WAITING
        };

        transfer::share_object(game);
    }

    // 另一个玩家加入游戏（暂不实现退出游戏）
    public entry fun add_game(game: &mut Game, ctx: &mut TxContext){
        // 游戏状态是否合法
        assert!(game.status == STATUS_WAITING && game.player2 == DEFAULT_PLAYER, ENotAllowAddGameBecauseStatus);

        let player = tx_context::sender(ctx);
        // 玩家1不能再次进入游戏
        assert!(game.player1 != player, EIsInGame);

        // 增加玩家2
        game.player2 = player;
        // 修改游戏状态
        game.status = STATUS_READY;
    }

    // 是否已经添加过hash
    public fun is_already_add_hash(game: &Game, player: address): bool {
        if (game.player1 == player && vector::length(&game.hash1) > 0) {
            // 如果地址是玩家1，且hash1有值，则代表加过hash了
            true
        } else if (game.player2 == player && vector::length(&game.hash2) > 0) {
            // 如果地址是玩家2，且hash2有值，则代表加过hash了
            true
        }else {
            false
        }
    }

    public fun is_already_add_salt(game: &Game, player: address): bool {
        if (game.player1 == player && game.gesture1 != NONE) {
            // 如果地址是玩家1，且gesture1有值，则代表加过salt
            true
        } else if (game.player2 == player && game.gesture2 != NONE) {
            // 如果地址是玩家2，且gesture2有值，则代表加过salt
            true
        }else {
            false
        }
    }

    // 是否是游戏的玩家
    fun is_player(game: &Game, player: address): bool {
        game.player1 == player || game.player2 == player
    }

    // 玩家出手势的hash
    public entry fun add_hash(
        game: &mut Game,
        hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let s = game.status;
        // 以下游戏状态才可以增加hash
        assert!(s == STATUS_READY || s == STATUS_HASH_SUBMISSION, ENotAllowAddHashBecauseStatus);

        let player = tx_context::sender(ctx);
        // 是否是该游戏的玩家
        assert!(is_player(game, player), ENotPlayer);
        // 是否已经添加过hash
        assert!(!is_already_add_hash(game, player), EAlreadyAddHash);

        // add hash
        if (game.player1 == player) {
            game.hash1 = hash;
        } else if (game.player2 == player) {
            game.hash2 = hash;
        };

        // 修改游戏状态
        let hash1_len = vector::length(&game.hash1);
        let hash2_len = vector::length(&game.hash2);
        if (hash1_len > 0 && hash2_len > 0) {
            // 所有玩家hash提交完毕
            game.status = STATUS_HASHES_SUBMITTED;
        } else if (hash1_len > 0 || hash2_len > 0) {
            // 有一个hash没提交代表hash提交中
            game.status = STATUS_HASH_SUBMISSION;
        }
    }

    // 玩家出手势的salt
    // 当两名玩家都出完手势之后自动出结果
    public entry fun add_salt(
        gameSpace: &mut GameSpace,
        game: &mut Game,
        salt: vector<u8>,
        ctx: &mut TxContext
    ) {
        let s = game.status;

        // 游戏状态合法才可以增加salt
        assert!(s == STATUS_HASHES_SUBMITTED || s == STATUS_REVEALING, ENotAllowAddSaltBecauseStatus);

        let player = tx_context::sender(ctx);

        // 是否是该游戏的玩家
        assert!(is_player(game, player), ENotPlayer);

        // 是否已经add salt
        assert!(!is_already_add_salt(game, player), EAlreadyAddSalt);

        if (game.player1 == player) {
            game.gesture1 = find_gesture(salt, &game.hash1);
        } else if (game.player2 == player) {
            game.gesture2 = find_gesture(salt, &game.hash2);
        };

        // 修改游戏状态
        if (game.gesture1 != NONE && game.gesture2 != NONE) {
            // 都有手势，代表已经披露
            game.status = STATUS_REVEALED;
        } else if (game.gesture1 != NONE || game.gesture2 != NONE) {
            // 有一个手势是NONE，代表披露中
            game.status = STATUS_REVEALING;
        };


        // 都有手势则自动开奖
        if (game.gesture1 != NONE && game.gesture2 != NONE) {
            // battle
            let p1win = play(game.gesture1, game.gesture2);
            let p2win = play(game.gesture2, game.gesture1);

            let prize = balance::split(&mut game.balance, PRIZE_PRE_GAME);
            if (p1win) {
                // 给玩家1发奖
                transfer::public_transfer(coin::from_balance(prize, ctx), game.player1);
            }else if (p2win) {
                // 给玩家2发奖
                transfer::public_transfer(coin::from_balance(prize, ctx), game.player2);
            } else {
                // 平局将奖金放回奖池
                balance::join(&mut gameSpace.prize_pool.balance, prize);
            }
        }
    }

    fun find_gesture(salt: vector<u8>, hash: &vector<u8>): u8 {
        if (hash(ROCK, salt) == *hash) {
            ROCK
        } else if (hash(PAPER, salt) == *hash) {
            PAPER
        } else if (hash(SCISSORS, salt) == *hash) {
            SCISSORS
        } else {
            CHEAT
        }
    }

    fun hash(gesture: u8, salt: vector<u8>): vector<u8> {
        vector::push_back(&mut salt, gesture);
        hash::sha2_256(salt)
    }

    fun play(one: u8, two: u8): bool {
        if (one == ROCK && two == SCISSORS) { true }
        else if (one == PAPER && two == ROCK) { true }
        else if (one == SCISSORS && two == PAPER) { true }
        else if (one != CHEAT && two == CHEAT) { true }
        else { false }
    }
}