use crate::im::http::RequestContextPropagateLayer;
use http::HeaderName;
use http::HeaderValue;
use http::Request;
use tower::util::BoxCloneSyncService;
use tower::ServiceBuilder;
use tower_http::request_id::PropagateRequestIdLayer;
use tower_http::request_id::RequestId;
use tower_http::request_id::SetRequestIdLayer;
use tower_http::ServiceBuilderExt;
use tower_reqwest::HttpClientLayer;
use tower_http::request_id::MakeRequestId;


// A `MakeRequestId` that increments an atomic counter
#[derive(Clone, Default)]
struct MyMakeRequestId {}

impl MakeRequestId for MyMakeRequestId {
    fn make_request_id<B>(&mut self, _request: &Request<B>) -> Option<RequestId> {
        Some(RequestId::new(
            HeaderValue::from_str(&uuid::Uuid::new_v4().to_string()).unwrap(),
        ))
    }
}


/// Implementation agnostic HTTP client.
pub type HttpClient = BoxCloneSyncService<
    http::Request<reqwest::Body>,
    http::Response<reqwest::Body>,
    tower_reqwest::Error,
>;


/// Creates HTTP client with Tower layers on top of the given client.
pub fn make_client(client: reqwest::Client, token: &str) -> HttpClient {
    // tower-http 的 SetRequestHeaderLayer 支持传 Option<HeaderValue>：
    // - Some(v): 插入/覆盖 header
    // - None: 不插入（保留原请求头不变）
    let token_value: Option<HeaderValue> = if token.trim().is_empty() {
        None
    } else {
        HeaderValue::from_str(&token).ok()
    };
    const X_REQUEST_ID: HeaderName = HeaderName::from_static("x-request-id");

    let svc = ServiceBuilder::new()
       // set `x-request-id` header on all requests
    .layer(SetRequestIdLayer::new(
        X_REQUEST_ID.clone(),
        MyMakeRequestId::default(),
    ))
    .layer(PropagateRequestIdLayer::new(X_REQUEST_ID))
        // Add some layers: 先挂上下文，再加 trace，再加默认 Header，再适配 reqwest Client
        .insert_request_header_if_not_present(HeaderName::from_static("operationid"), |_req: &http::Request<reqwest::Body>| -> Option<HeaderValue> {
         let value =   _req.headers().get(X_REQUEST_ID);

           return value.map(|value| value.clone());
        })
        .override_request_header(HeaderName::from_static("token"), token_value)
        .layer(RequestContextPropagateLayer)
       
         // TraceLayer 会把响应体包成 ResponseBody，先在最外层把它统一转成 BoxBody
        //  .layer(MapResponseLayer::new(to_box_body))
        // .layer(
        //     TraceLayer::new_for_http()
        //     .on_eos(())
        //         .on_request(|req: &http::Request<reqwest::Body>, _span: &Span| {
        //             debug!(method = %req.method(), uri = %req.uri(), headers = ?req.headers(), "HTTP request");
        //         })
        //         .on_response(|resp: &http::Response<_>, latency: std::time::Duration, _span: &Span| {
        //             debug!(status = %resp.status(), latency_ms = latency.as_millis(), headers = ?resp.headers(), "HTTP response");
        //         }),
        // ) 
        .layer(HttpClientLayer)
        .service(client);
    BoxCloneSyncService::new(svc)
}

/// Creates HTTP client without token (for login and other public endpoints).
pub fn make_client_without_token(client: reqwest::Client) -> HttpClient {
    make_client(client, "")
}



