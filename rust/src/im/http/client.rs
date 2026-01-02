use crate::im::http::RequestContextPropagateLayer;
use http::HeaderName;
use http::{header::USER_AGENT, HeaderValue};
use tower::ServiceBuilder;
use tower::util::ServiceExt;
use tower_http::ServiceBuilderExt;
use tower_reqwest::HttpClientLayer;

/// Implementation agnostic HTTP client.
pub type HttpClient = tower::util::BoxCloneService<
    http::Request<reqwest::Body>,
    http::Response<reqwest::Body>,
    tower_reqwest::Error,
>;


/// Creates HTTP client with Tower layers on top of the given client.
pub fn make_client(client: reqwest::Client, token: String) -> HttpClient {
    ServiceBuilder::new()
        // Add some layers: 先挂上下文，再加 trace，再加默认 Header，再适配 reqwest Client
        // .layer(TraceLayer::new_for_http())
        .override_request_header(HeaderName::from_static("token"),HeaderValue::from_str(&token).unwrap())
        .override_request_header(USER_AGENT, HeaderValue::from_static("tower-http-client"))
        .layer(RequestContextPropagateLayer)
        .layer(HttpClientLayer)
        .service(client)
        .boxed_clone()
}

