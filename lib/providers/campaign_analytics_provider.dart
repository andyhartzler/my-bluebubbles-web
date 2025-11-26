import 'package:flutter/foundation.dart';

import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/campaign_analytics.dart';
import 'package:bluebubbles/services/crm/campaign_service.dart';

class CampaignAnalyticsProvider extends ChangeNotifier {
  CampaignAnalyticsProvider({CampaignService? service})
      : _service = service ?? CampaignService();

  final CampaignService _service;

  CampaignAnalytics _analytics = CampaignAnalytics.empty;
  bool _loading = false;
  String? _error;
  Campaign? _campaign;

  CampaignAnalytics get analytics => _analytics;
  bool get isLoading => _loading;
  String? get error => _error;
  Campaign? get campaign => _campaign ?? _analytics.campaign;

  Future<void> loadAnalytics({String? campaignId, Campaign? campaign}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _campaign = campaign;
    notifyListeners();

    try {
      final CampaignAnalytics data =
          await _service.getAnalytics(campaignId: campaignId);
      _analytics = data.copyWith(campaign: campaign ?? data.campaign);
    } catch (error) {
      _error = error.toString();
      _analytics = CampaignAnalytics.empty;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
