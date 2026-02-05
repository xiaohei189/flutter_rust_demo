use crate::im::api::message::MessageApi;
use crate::im::api::conversation::ConversationApi;
use crate::im::api::friend::FriendApi;

pub struct Api {
    pub message_api: MessageApi,
    pub conversation_api: ConversationApi,
    pub friend_api: FriendApi,
}

impl Api {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {

        let message_api = MessageApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let conversation_api = ConversationApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let friend_api = FriendApi::new(client.clone()  , api_base_url.clone(), user_id.clone(), token);
        Self { message_api, conversation_api, friend_api }
    }
}