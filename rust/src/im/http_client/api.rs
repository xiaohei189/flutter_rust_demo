use super::conversation::ConversationApi;
use super::friend::FriendApi;
use super::group::GroupApi;
use super::message::MessageApi;
use super::object::ObjectApi;
use super::token::AuthApi;
use super::user::UserApi;

#[derive(Clone)]
pub struct Api {
    pub auth: AuthApi,
    pub message: MessageApi,
    pub conversation: ConversationApi,
    pub friend: FriendApi,
    pub group: GroupApi,
    pub user: UserApi,
    pub object: ObjectApi,
}

impl Api {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        let auth_api = AuthApi::new(client.clone(), api_base_url.clone());
        let message_api = MessageApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let conversation_api = ConversationApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let friend_api = FriendApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let group_api = GroupApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let user_api = UserApi::new(client.clone(), api_base_url.clone(), user_id.clone(), token);
        let object_api = ObjectApi::new(client, api_base_url, token);
        Self {
            auth: auth_api,
            message: message_api,
            conversation: conversation_api,
            friend: friend_api,
            group: group_api,
            user: user_api,
            object: object_api,
        }
    }
}