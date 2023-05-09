import 'package:http/http.dart';

class CustomHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    //Return custom status code to check for usage of this client.
    return StreamedResponse(
      request.finalize(),
      420,
      request: request,
    );
  }
}
