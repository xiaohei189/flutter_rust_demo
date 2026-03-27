import 'package:dio/dio.dart';
import 'logger_service.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  
  late Dio _dio;
  
  NetworkService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    
    // 添加拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          logger.debug('发送请求: ${options.method} ${options.uri}');
          logger.debug('请求参数: ${options.data}');
          // 添加认证头
          // options.headers['Authorization'] = 'Bearer token';
          return handler.next(options);
        },
        onResponse: (response, handler) {
          logger.debug('收到响应: ${response.statusCode} ${response.requestOptions.uri}');
          logger.debug('响应数据: ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) {
          logger.error('请求错误: ${error.message}');
          logger.error('错误信息: ${error.response?.data}');
          return handler.next(error);
        },
      ),
    );
  }
  
  static NetworkService get instance => _instance;
  
  Dio get dio => _dio;
  
  void initialize({required String baseUrl}) {
    _dio.options.baseUrl = baseUrl;
  }
  
  void addAuthToken(String token) {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }
  
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }
  
  Future<Response<dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }
  
  Future<Response<dynamic>> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }
  
  Future<Response<dynamic>> delete(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.delete(path, queryParameters: queryParameters);
  }
}
