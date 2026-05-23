//! 文件上传核心逻辑 - 参考 Go SDK 实现
//! openim-sdk-core/internal/third/file/upload.go

use crate::im::http_client::object::{ObjectApi, InitiateMultipartUploadReq, AuthSignReq, CompleteMultipartUploadReq};
use anyhow::{Context, Result};
use md5::{Digest, Md5};
use std::collections::HashMap;
use tracing::{info, debug, error};
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

/// 文件上传服务
pub struct FileService {
    object_api: ObjectApi,
}

impl FileService {
    /// 创建文件上传服务实例
    pub fn new(object_api: ObjectApi) -> Self {
        Self { object_api }
    }

    /// 上传文件
    ///
    /// # 参数
    /// - `file_path`: 文件路径
    /// - `file_name`: 文件名（需要包含用户ID前缀，如 "user123/avatar.jpg"）
    ///
    /// # 返回值
    /// - 成功：返回文件的 URL
    /// - 失败：返回错误
    pub async fn upload_file(&self, file_path: &str, file_name: &str) -> Result<String> {
        self.upload_file_with_progress(file_path, file_name, |_| {}).await
    }

    /// 上传文件并返回进度
    ///
    /// # 参数
    /// - `file_path`: 文件路径
    /// - `file_name`: 文件名
    /// - `callback`: 进度回调函数，参数为进度 (0.0 - 1.0)
    ///
    /// # 返回值
    /// - 成功：返回文件的 URL
    /// - 失败：返回错误
    pub async fn upload_file_with_progress<F>(
        &self,
        file_path: &str,
        file_name: &str,
        callback: F,
    ) -> Result<String>
    where
        F: Fn(f64),
    {
        info!("[FileUpload] 开始上传文件: path={}, name={}", file_path, file_name);
        
        // 1. 打开文件并获取文件大小
        let mut file = File::open(file_path).context("failed to open file")?;
        let file_size = file.metadata()?.len();
        info!("[FileUpload] 文件大小: {} bytes", file_size);

        // 2. 获取分块大小限制
        info!("[FileUpload] 获取分块限制...");
        let part_limit = self.object_api.part_limit().await?;
        info!("[FileUpload] 分块限制: min={}, max={}, maxNum={}", part_limit.min_part_size, part_limit.max_part_size, part_limit.max_num_size);
        let part_size = self.calculate_part_size(file_size, &part_limit)?;
        let part_num = self.calculate_part_num(file_size, part_size);
        info!("[FileUpload] 计算的分块大小: {}, 分块数: {}", part_size, part_num);

        // 3. 计算文件 MD5 和分块信息
        let part_info = self.calculate_part_info(&mut file, file_size, part_size, part_num, &callback)?;
        info!("[FileUpload] 文件 MD5: {}, 分块 MD5: {}", part_info.file_md5, part_info.part_md5);

        // 4. 初始化分块上传
        // 注意：hash 应该使用 part_md5（所有分块MD5组合后的MD5），而不是 file_md5
        let content_type = &part_info.content_type;
        info!("[FileUpload] 初始化分块上传 with hash: {}", part_info.part_md5);
        let upload_resp = self.object_api.initiate_multipart_upload(InitiateMultipartUploadReq {
            hash: part_info.part_md5.clone(),
            size: file_size as i64,
            part_size: part_size as i64,
            max_parts: part_num.min(20) as i32,
            cause: "upload".to_string(),
            name: file_name.to_string(),
            content_type: content_type.clone(),
        }).await?;
        
        info!("[FileUpload] 初始化响应: url={}, upload={:?}", upload_resp.url, upload_resp.upload);

        // 如果 upload 为 None，表示服务器已存在该文件，直接返回 URL
        if upload_resp.upload.is_none() {
            callback(1.0);
            info!("[FileUpload] 文件已存在，直接返回 URL: {}", upload_resp.url);
            return Ok(upload_resp.url);
        }

        let upload_info = upload_resp.upload.unwrap();
        info!("[FileUpload] 开始上传 {} 个分块...", part_num);

        // 验证分块大小
        if upload_info.part_size != part_size as i64 {
            anyhow::bail!(
                "part size not match, expect {}, got {}",
                part_size,
                upload_info.part_size
            );
        }

        // 5. 上传每个分块
        let mut uploaded_size: u64 = 0;
        file.seek(SeekFrom::Start(0))?;

        for (i, current_part_size) in part_info.part_sizes.iter().enumerate() {
            let part_number = (i + 1) as i32;

            // 读取分块数据
            let mut part_data = vec![0u8; *current_part_size as usize];
            file.read_exact(&mut part_data)?;

            // 直接使用预计算的 MD5（来自 calculate_part_info）
            let part_md5_val = &part_info.part_md5s[i];

            // 获取分块上传签名
            let auth_sign = if let Some(ref sign) = upload_info.sign {
                // 检查是否已有签名（sign.parts 是 Vec）
                if !sign.parts.is_empty() {
                    if let Some(part) = sign.parts.iter().find(|p| p.part_number == part_number) {
                        // 使用已有签名
                        let mut headers = HashMap::new();
                        if let Some(ref hdr) = part.header {
                            for kv in hdr {
                                if let Some(v) = kv.values.first() {
                                    headers.insert(kv.key.clone(), v.clone());
                                }
                            }
                        }
                        (part.url.clone(), headers)
                    } else {
                        // 需要重新获取签名
                        self.get_part_sign(&upload_info.upload_id, part_number).await?
                    }
                } else {
                    self.get_part_sign(&upload_info.upload_id, part_number).await?
                }
            } else {
                self.get_part_sign(&upload_info.upload_id, part_number).await?
            };
            
            info!("[FileUpload] 上传分块 {}/{}, size={}", part_number, part_num, current_part_size);

            // 上传分块
            match self.object_api.put_part(&auth_sign.0, auth_sign.1, part_data).await {
                Ok(_) => info!("[FileUpload] 分块 {} 上传成功", part_number),
                Err(e) => {
                    error!("[FileUpload] 分块 {} 上传失败: {}", part_number, e);
                    return Err(e);
                }
            }

            uploaded_size += current_part_size;
            let progress = uploaded_size as f64 / file_size as f64;
            callback(progress);
        }

        // 6. 完成分块上传
        info!("[FileUpload] 完成分块上传...");
        let complete_resp = self.object_api.complete_multipart_upload(CompleteMultipartUploadReq {
            upload_id: upload_info.upload_id.clone(),
            parts: part_info.part_md5s.clone(),
            name: file_name.to_string(),
            content_type: content_type.clone(),
            cause: "upload".to_string(),
        }).await?;
        
        info!("[FileUpload] 上传完成，返回 URL: {}", complete_resp.url);

        Ok(complete_resp.url)
    }

    /// 获取分块上传签名
    async fn get_part_sign(&self, upload_id: &str, part_number: i32) -> Result<(String, HashMap<String, String>)> {
        let auth_sign = self.object_api.auth_sign(AuthSignReq {
            upload_id: upload_id.to_string(),
            part_numbers: vec![part_number],
        }).await?;

        if let Some(part) = auth_sign.parts.iter().find(|p| p.part_number == part_number) {
            let mut headers = HashMap::new();
            if let Some(ref hdr) = part.header {
                for kv in hdr {
                    if let Some(v) = kv.values.first() {
                        headers.insert(kv.key.clone(), v.clone());
                    }
                }
            }
            Ok((part.url.clone(), headers))
        } else {
            anyhow::bail!("part sign not found for part {}", part_number)
        }
    }

    /// 计算分块大小
    fn calculate_part_size(&self, file_size: u64, part_limit: &crate::im::http_client::object::PartLimitResp) -> Result<u64> {
        let min_part_size = part_limit.min_part_size as u64;
        let max_part_size = part_limit.max_part_size as u64;
        let max_num_size = part_limit.max_num_size as u64;

        if file_size == 0 {
            anyhow::bail!("file size must be greater than 0");
        }

        if file_size > max_part_size * max_num_size {
            anyhow::bail!("file too large");
        }

        if file_size <= min_part_size * max_num_size {
            Ok(min_part_size)
        } else {
            let part_size = file_size / max_num_size;
            if file_size % max_num_size != 0 {
                Ok(part_size + 1)
            } else {
                Ok(part_size)
            }
        }
    }

    /// 计算分块数量
    fn calculate_part_num(&self, file_size: u64, part_size: u64) -> usize {
        let part_num = file_size / part_size;
        if file_size % part_size != 0 {
            (part_num + 1) as usize
        } else {
            part_num as usize
        }
    }

    /// 计算分块信息（MD5、Content-Type 等）
    fn calculate_part_info<F>(
        &self,
        file: &mut File,
        file_size: u64,
        part_size: u64,
        part_num: usize,
        callback: &F,
    ) -> Result<PartInfo>
    where
        F: Fn(f64),
    {
        let mut file_md5 = Md5::new();
        let mut part_md5s = Vec::with_capacity(part_num);
        let mut part_sizes = Vec::with_capacity(part_num);

        // 计算每个分块的大小
        for i in 0..part_num {
            let size = if i == part_num - 1 {
                file_size - part_size * (part_num as u64 - 1)
            } else {
                part_size
            };
            part_sizes.push(size);
        }

        // 重置文件指针
        file.seek(SeekFrom::Start(0))?;

        let mut buffer = vec![0u8; 8192];
        let mut content_type = String::new();

        // 计算每个分块的 MD5
        for i in 0..part_num {
            let mut part_md5 = Md5::new();
            let mut remaining = part_sizes[i];

            while remaining > 0 {
                let read_size = std::cmp::min(remaining, buffer.len() as u64) as usize;
                let n = file.read(&mut buffer[..read_size])?;
                if n == 0 {
                    break;
                }

                // 检测文件类型
                if content_type.is_empty() {
                    content_type = self.detect_content_type(&buffer[..n]);
                }

                part_md5.update(&buffer[..n]);
                file_md5.update(&buffer[..n]);
                remaining -= n as u64;
            }

            let part_md5_str = format!("{:x}", part_md5.finalize());
            part_md5s.push(part_md5_str);

            // 更新进度
            let progress = ((i + 1) as u64 * part_size) as f64 / file_size as f64;
            callback(progress * 0.5); // 哈希计算占 50% 进度
        }

        let file_md5_str = format!("{:x}", file_md5.finalize());
        let part_md5_val = self.calculate_part_md5(&part_md5s);

        Ok(PartInfo {
            content_type,
            part_size,
            part_num,
            file_md5: file_md5_str,
            part_md5: part_md5_val,
            part_sizes,
            part_md5s,
        })
    }

    /// 检测文件类型
    fn detect_content_type(&self, data: &[u8]) -> String {
        if data.starts_with(b"\x89PNG") {
            "image/png".to_string()
        } else if data.starts_with(b"\xFF\xD8\xFF") {
            "image/jpeg".to_string()
        } else if data.starts_with(b"GIF87a") || data.starts_with(b"GIF89a") {
            "image/gif".to_string()
        } else if data.starts_with(b"%PDF") {
            "application/pdf".to_string()
        } else {
            "application/octet-stream".to_string()
        }
    }

    /// 计算分块 MD5 组合值
    fn calculate_part_md5(&self, parts: &[String]) -> String {
        let s = parts.join(",");
        let mut md5_sum = Md5::new();
        md5_sum.update(s.as_bytes());
        format!("{:x}", md5_sum.finalize())
    }
}

/// 分块信息
struct PartInfo {
    content_type: String,
    part_size: u64,
    part_num: usize,
    file_md5: String,
    part_md5: String,
    part_sizes: Vec<u64>,
    part_md5s: Vec<String>,
}
