import 'package:url_launcher/url_launcher.dart';

abstract class LinkService {
  Future<bool> open(Uri uri);
}

class BrowserLinkService implements LinkService {
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
