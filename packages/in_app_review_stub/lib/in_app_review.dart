library in_app_review;

class InAppReview {
  InAppReview._();

  static final InAppReview instance = InAppReview._();

  Future<bool> isAvailable() async => false;
  Future<void> requestReview() async {}
  Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId}) async {}
}
