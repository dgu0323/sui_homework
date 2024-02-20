module game::hash_test {
    #[test_only]
    use std::debug;
    #[test_only]
    use std::vector;
    #[test_only]
    use std::hash;

    #[test]
    fun test1(){
        let salt= b"1234";
        let gesture = 3;
        vector::push_back(&mut salt, gesture);
        let h = hash::sha2_256(salt);

        debug::print<vector<u8>>(&h);
    }
}