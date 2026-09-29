import '../constants/api_constants.dart';

/// Helper to ensure image URLs have a valid host/scheme.
String getFullImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final baseUrl = ApiConstants.baseUrl.endsWith('/')
      ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1)
      : ApiConstants.baseUrl;
  final cleanPath = path.startsWith('/') ? path : '/$path';
  return '$baseUrl$cleanPath';
}
