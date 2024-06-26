#[starknet::contract]
pub mod RainbowQuest {
    use starknet::{ContractAddress, get_caller_address};
    use art_peace::{IArtPeaceDispatcher, IArtPeaceDispatcherTrait};
    use art_peace::quests::{IQuest, IRainbowQuest};

    #[storage]
    struct Storage {
        art_peace: ContractAddress,
        reward: u32,
        claimed: LegacyMap<ContractAddress, bool>,
    }

    #[derive(Drop, Serde)]
    pub struct RainbowQuestInitParams {
        pub art_peace: ContractAddress,
        pub reward: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_params: RainbowQuestInitParams) {
        self.art_peace.write(init_params.art_peace);
        self.reward.write(init_params.reward);
    }

    #[abi(embed_v0)]
    impl RainbowQuestImpl of IRainbowQuest<ContractState> {
        fn is_claimed(self: @ContractState, user: ContractAddress) -> bool {
            self.claimed.read(user)
        }
    }

    #[abi(embed_v0)]
    impl RainbowQuest of IQuest<ContractState> {
        fn get_reward(self: @ContractState) -> u32 {
            self.reward.read()
        }

        fn is_claimable(
            self: @ContractState, user: ContractAddress, calldata: Span<felt252>
        ) -> bool {
            if self.claimed.read(user) {
                return false;
            }

            let art_piece = IArtPeaceDispatcher { contract_address: self.art_peace.read() };

            for i in 0..7 { 
                if art_piece.get_user_pixels_placed_color(user, i) == 0 {
                    return false; 
                }
            }

            true
        }

        fn claim(ref self: ContractState, user: ContractAddress, calldata: Span<felt252>) -> u32 {
            assert(get_caller_address() == self.art_peace.read().contract_address, 'Only ArtPeace can claim quests');

            assert(self.is_claimable(user, calldata), 'Quest not claimable');

            self.claimed.write(user, true);
            let reward = self.reward.read();

            reward
        }
    }
}

