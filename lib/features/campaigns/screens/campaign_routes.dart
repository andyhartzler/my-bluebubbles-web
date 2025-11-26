import 'package:get/get.dart';

import 'campaign_detail_screen.dart';
import 'campaigns_screen.dart';

class CampaignRoutes {
  static const String campaigns = '/crm/campaigns';
  static const String campaignDetail = '/crm/campaigns/:campaignId';

  static String detailPath(String campaignId) => '/crm/campaigns/$campaignId';
}

final List<GetPage<dynamic>> campaignPages = <GetPage<dynamic>>[
  GetPage(name: CampaignRoutes.campaigns, page: CampaignsScreen.new),
  GetPage(
    name: CampaignRoutes.campaignDetail,
    page: () => CampaignDetailScreen(campaignId: Get.parameters['campaignId']),
  ),
];
