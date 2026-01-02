use crate::im::http::context::HttpRequestContext;
use http::{Request, Response};
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use tower::{Layer, Service};

/// 在 `Request.extensions()` 中注入 [`HttpRequestContext`] 的 Tower Layer。
#[derive(Debug, Clone, Default)]
pub struct RequestContextPropagateLayer;

impl<S> Layer<S> for RequestContextPropagateLayer {
    type Service = HttpRequestContextService<S>;

    fn layer(&self, inner: S) -> Self::Service {
        HttpRequestContextService { inner }
    }
}

#[derive(Debug, Clone)]
pub struct HttpRequestContextService<S> {
    inner: S,
}

impl<S, B> Service<Request<B>> for HttpRequestContextService<S>
where
    S: Service<Request<B>, Response = Response<B>> + Send + 'static,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self,  req: Request<B>) -> Self::Future {
        let ctx = HttpRequestContext {
            method: req.method().clone(),
            uri: req.uri().clone(),
            request_id: uuid::Uuid::new_v4().to_string(),
            started_at: std::time::Instant::now(),
        };

        let fut = self.inner.call(req);
        Box::pin(async move {
            let mut resp = fut.await?;
            // 将请求上下文透传到 Response.extensions，便于后续日志/错误输出
            resp.extensions_mut().insert(ctx);
            Ok(resp)
        })
    }
}


