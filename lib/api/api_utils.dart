class ApiUtils {
  /*static const String baseUrl =
      'http://103.130.205.198:1415/Masters/UploadAPI/Upload'; //LIVE URL*/
  static const String baseUrl =
      'http://103.130.205.198:14146/Masters/UploadAPI/Upload'; //TEST URL

  static Uri getUri(String endpoint) {
    // Handle cases where endpoint might start/end with slashes
    String cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    cleanEndpoint = cleanEndpoint.endsWith('/')
        ? cleanEndpoint.substring(0, cleanEndpoint.length - 1)
        : cleanEndpoint;

    return Uri.parse('$baseUrl/$cleanEndpoint');
  }
}
