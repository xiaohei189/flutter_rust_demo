use crate::im::api::message::MessageApi;
use crate::im::api::conversation::ConversationApi;
use crate::im::api::friend::FriendApi;
use crate::im::api::user::UserApi;

#[derive(Clone)]
pub struct Api {
    pub message: MessageApi,
    pub conversation: ConversationApi,
    pub friend: FriendApi,
    pub user: UserApi,
}

impl Api {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {

        let message_api = MessageApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let conversation_api = ConversationApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let friend_api = FriendApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let user_api = UserApi::new(client, api_base_url, user_id, token);
        Self {
            message: message_api,
            conversation: conversation_api,
            friend: friend_api,
            user: user_api,
        }
    }
}