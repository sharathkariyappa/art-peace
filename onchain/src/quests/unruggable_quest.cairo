#[starknet::contract]
pub mod UnruggableQuest {
    use starknet::{ContractAddress, get_caller_address};
    use art_peace::{IArtPeaceDispatcher, IArtPeaceDispatcherTrait};
    use art_peace::quests::{
        IQuest, IUnruggableQuest, IUnruggableMemecoinDispatcher, IUnruggableMemecoinDispatcherTrait
    };

    #[storage]
    struct Storage {
        art_peace: ContractAddress,
        reward: u32,
        required_balance: u32,
        claimed: LegacyMap<ContractAddress, bool>,
        coin_address: ContractAddress,
    }

    #[derive(Drop, Serde)]
    pub struct UnruggableQuestInitParams {
        pub art_peace: ContractAddress,
        pub reward: u32,
        pub required_balance: u32,
        pub coin_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_params: UnruggableQuestInitParams) {
        self.art_peace.write(init_params.art_peace);
        self.reward.write(init_params.reward);
        self.required_balance.write(init_params.required_balance);
        self.coin_address.write(init_params.coin_address);
    }

    #[abi(embed_v0)]
    impl UnruggableQuestImpl of IUnruggableQuest<ContractState> {
        fn is_claimed(self: @ContractState, user: ContractAddress) -> bool {
            self.claimed.read(user)
        }
    }

    #[abi(embed_v0)]
    impl UnruggableQuest of IQuest<ContractState> {
        fn get_reward(self: @ContractState) -> u32 {
            self.reward.read()
        }

        fn is_claimable(
            self: @ContractState, user: ContractAddress, calldata: Span<felt252>
        ) -> bool {
            if self.claimed.read(user) {
                return false;
            }

            let coin = IUnruggableMemecoinDispatcher { contract_address: self.coin_address.read() };

            coin.owner() == user && coin.is_launched() && coin.balance() >= self.required_balance.read();
        }

        fn claim(ref self: ContractState, user: ContractAddress, calldata: Span<felt252>) -> u32 {
            assert(get_caller_address() == self.art_peace.read().coin_address, 'Only ArtPeace can claim quests');

            assert(self.is_claimable(user, calldata), 'Quest not claimable');

            self.claimed.write(user, true);
            let reward = self.reward.read();

            reward
        }
    }
}

