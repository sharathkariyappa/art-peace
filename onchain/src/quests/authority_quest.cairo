#[starknet::contract]
pub mod AuthorityQuest {
    use core::traits::TryInto;
    use starknet::{ContractAddress, get_caller_address};
    use art_peace::templates::interfaces::{ITemplateStoreDispatcher, ITemplateStoreDispatcherTrait};
    use art_peace::quests::{IAuthorityQuest, IQuest};

    #[storage]
    struct Storage {
        art_peace: ContractAddress,
        authority: ContractAddress,
        reward: u32,
        extra_pixel_required: u32,
        claimed: LegacyMap<ContractAddress, bool>,
    }

    #[derive(Drop, Serde)]
    pub struct AuthorityQuestInitParams {
        pub art_peace: ContractAddress,
        pub authority: ContractAddress,
        pub reward: u32,
        pub extra_pixel_required: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_params: AuthorityQuestInitParams) {
        self.art_peace.write(init_params.art_peace);
        self.authority.write(init_params.authority);
        self.reward.write(init_params.reward);
        self.extra_pixel_required.write(init_params.extra_pixel_required);
    }

    #[abi(embed_v0)]
    impl AuthorityQuestImpl of IAuthorityQuest<ContractState> {
        fn is_claimed(self: @ContractState, user: ContractAddress) -> bool {
            self.claimed.read(user)
        }

        fn mark_claimable(ref self: ContractState, calldata: Span<felt252>) {
            assert(get_caller_address() == self.authority.read(), 'Only authority address allowed');
            let mut i = 0;
            while i < calldata.len() {
                self.claimable.write((*calldata[i]).try_into().unwrap(), true);
                i += 1;
            }
        }
    }

    #[abi(embed_v0)]
    impl AuthorityQuest of IQuest<ContractState> {
        fn get_reward(self: @ContractState) -> u32 {
            self.reward.read()
        }

        fn is_claimable(
            self: @ContractState, user: ContractAddress, calldata: Span<felt252>
        ) -> bool {
            if self.claimed.read(user) {
                return false;
            }

            let extra_pixel_count = self.fetch_extra_pixel_count(user);

            if extra_pixel_count >= self.extra_pixel_required.read() {
                return true;
            }
            false
        }

        fn fetch_extra_pixel_count(self: @ContractState, user: ContractAddress) -> u32 {
            let template_store = ITemplateStoreDispatcher {
                contract_address: self.art_peace.read()
            };
            
            template_store.get_extra_pixel_count(user)
        }

        fn claim(ref self: ContractState, user: ContractAddress, calldata: Span<felt252>) -> u32 {
            assert(get_caller_address() == self.art_peace.read(), 'Only ArtPeace can claim quests');

            assert(self.is_claimable(user, calldata), 'Quest not claimable');

            self.claimed.write(user, true);
            let reward = self.reward.read();

            reward
        }
    }
}
