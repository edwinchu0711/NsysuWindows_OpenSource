import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({Key? key}) : super(key: key);

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final List<Map<String, dynamic>> _infoList = [
    {
      "id": 1,
      "title": "初次登入加載",
      "content": "本應用程式初次登入需要較多時間爬取歷年資料，請在進度條介面耐心等候，請勿中途關閉。",
    },
    {
      "id": 2,
      "title": "增量更新機制",
      "content": "初始化完成後，每次登入僅會自動更新「近期」的課表與成績資料，以節省流量與時間。",
    },
    {
      "id": 3,
      "title": "舊資料更新",
      "content": "若過去資料（超過 1 年）有變動且希望強制同步，請點擊「登出」後重新登入。",
    },
    {
      "id": 4,
      "title": "開放成績查詢",
      "content": "此功能僅在每年 5/15~6/25 及 12/15~1/25 自動更新。非此期間若有需要，請進入功能頁面手動更新。",
    },
    {
      "id": 5,
      "title": "學期資料切換",
      "content": "系統採用自動化學期識別引擎，每年 2 月起切換至下學期數據，8 月起切換至新學年上學期數據，確保資料時效性。",
    },
    {"id": 6, "title": "名次預覽", "content": "此功能顯示之排名並非校方正式官方排名，僅供參考之用。"},
    {
      "id": 7,
      "title": "選課系統",
      "content":
          "在學期選課期間可透過應用程式進行選課。使用後請務必回到學校官方選課系統再次確認，若因系統同步延遲或錯誤導致選課失敗，恕不負責。",
    },
    {
      "id": 8,
      "title": "選課助手",
      "content": "支援使用者自訂預排課程，並提供匯入課表與匯出至選課系統直接選課的功能。",
    },
    {
      "id": 9,
      "title": "行事曆與選課提醒",
      "content": "行事曆與選課自動提醒功能之資料來源未來可能異動，該功能可能無法長期持續運作，請見諒。",
    },
    {"id": 10, "title": "異常處理功能", "content": "僅在特定時間於「選課系統」內顯示按鈕，供下載並產出異常處理單。"},
    {
      "id": 11,
      "title": "網路大學存取規範",
      "content": "讀取作業、考試與公告時設有數據保護。請勿頻繁手動重新整理，避免因異常流量遭校方平台封鎖。",
    },
    {
      "id": 12,
      "title": "畢業審核說明",
      "content": "受限於資料轉換方式，畢業審核資訊可能不完整，內容僅供參考，請務必以學校官網查詢結果為準。",
    },
    {
      "id": 13,
      "title": "異常處理與重啟",
      "content": "若遇到資料無法顯示，請嘗試「完全關閉應用程式後重開」，通常可解決暫時性的網路問題。",
    },
    {
      "id": 14,
      "title": "AI 模型使用限制",
      "content": "使用 AI 模型時請務必留意請求頻率。若您使用自定義 API 金鑰，請自行注意用量以免產生額外費用。",
    },
    {
      "id": 15,
      "title": "AI 隱私與安全",
      "content":
          "與模型對話時，系統不會主動傳送您的個人隱私資料。然而，您自行輸入的對話內容仍會傳送至 AI 服務商，請避免在對話中提供敏感個資。",
    },
    {
      "id": 16,
      "title": "學程進度說明",
      "content":
          "本功能學程規則由 AI 自動解析，數據可能存在誤差；部分跨院認定較為複雜，系統無法涵蓋所有情況；進度百分比為系統估算值，僅供選課參考，不代表最終審核結果。建議同學與系辦再次確認。",
    },
  ];

  Future<void> _launchGitHubUrl() async {
    final Uri url = Uri.parse(
      'https://github.com/edwinchu0711/NsysuWindows_OpenSource',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.pageBackground,
        body: SafeArea(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: isWide ? 0.85 : 1.0,
              child: Column(
                children: [
                  _buildHeader(context, "使用須知與資訊"),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryCardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      tabs: const [
                        Tab(text: "使用說明"),
                        Tab(text: "關於開發者"),
                      ],
                      labelColor: colorScheme.accentBlue,
                      unselectedLabelColor: colorScheme.subtitleText,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: colorScheme.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              colorScheme.isDark ? 0.2 : 0.05,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: 使用說明
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              _buildWelcomeCard(),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  int columns = constraints.maxWidth > 1000
                                      ? 3
                                      : (constraints.maxWidth > 650 ? 2 : 1);
                                  List<Widget> rows = [];
                                  for (
                                    int i = 0;
                                    i < _infoList.length;
                                    i += columns
                                  ) {
                                    List<Widget> rowChildren = [];
                                    for (int j = 0; j < columns; j++) {
                                      if (i + j < _infoList.length) {
                                        final item = _infoList[i + j];
                                        rowChildren.add(
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: j < columns - 1
                                                    ? 16.0
                                                    : 0.0,
                                              ),
                                              child: _buildInfoItem(
                                                item['id'],
                                                item['title'],
                                                item['content'],
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        rowChildren.add(
                                          const Expanded(child: SizedBox()),
                                        );
                                      }
                                    }
                                    rows.add(
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: rowChildren,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Column(children: rows);
                                },
                              ),
                              const Divider(
                                height: 40,
                                thickness: 1,
                                indent: 20,
                                endIndent: 20,
                              ),
                              // 最後的免責與開源聲明
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                child: Text(
                                  "⚠️ 重要聲明：使用此應用程式產生之任何問題與風險均須由使用者自行承擔。本專案採開源形式，開放大眾自由修改、下載，感謝您的理解。",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.isDark
                                        ? Colors.red[300]
                                        : Colors.red[500],
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                        // Tab 2: 關於開發者
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: _buildAboutDeveloperContent(
                            context,
                            isWide,
                            colorScheme,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutDeveloperContent(
    BuildContext context,
    bool isWide,
    ColorScheme colorScheme,
  ) {
    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Developer Card & GitHub Button
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDeveloperCard(context, colorScheme),
                    const SizedBox(height: 20),
                    _buildGitHubButton(context, colorScheme),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column: Special Thanks, Credits & MIT License
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSpecialThanksCard(context, colorScheme),
                    const SizedBox(height: 20),
                    _buildCreditsCard(context, colorScheme),
                    const SizedBox(height: 20),
                    _buildLicenseCard(context, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDeveloperCard(context, colorScheme),
        const SizedBox(height: 16),
        _buildSpecialThanksCard(context, colorScheme),
        const SizedBox(height: 16),
        _buildCreditsCard(context, colorScheme),
        const SizedBox(height: 16),
        _buildLicenseCard(context, colorScheme),
        const SizedBox(height: 24),
        _buildGitHubButton(context, colorScheme),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDeveloperCard(BuildContext context, ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top Gradient Cover
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E2D4A), const Color(0xFF0D47A1)]
                      : [const Color(0xFFE3F2FD), const Color(0xFF90CAF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Content
            Transform.translate(
              offset: const Offset(0, -38),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // Avatar with glowing border
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.cardBackground,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.accentBlue.withOpacity(
                          0.12,
                        ),
                        child: Icon(
                          Icons.code_rounded,
                          size: 38,
                          color: colorScheme.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Steven",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryText,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tagline quote box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryCardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.borderColor.withOpacity(0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Just for fun.",
                            style: TextStyle(
                              fontSize: 13.5,
                              color: colorScheme.bodyText,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialThanksCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "特別感謝",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildThanksItem(
            context,
            colorScheme,
            title: "NSYSU Open Development Community\n中山大學開源社群",
            subtitle: "特別感謝社群內許多熱心開源的夥伴，無私地貢獻了精湛的程式碼架構與核心模組，為本專案奠定了無可替代的穩健基石。",
            icon: Icons.people_outline_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildThanksItem(
            context,
            colorScheme,
            title: "中山大學 GDG on Campus x 程式設計社",
            subtitle: "感謝技術社群與社團夥伴慷慨提供了專業且具建設性的產品、設計方向及資訊安全建議。",
            icon: Icons.tips_and_updates_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildThanksItem(
            context,
            colorScheme,
            title: "ClearGrad. 畢經之路",
            subtitle:
                "本專案部分創意靈感源於「© 2026 ClearGrad. 畢經之路」（由 葉峻銓 創作，邱俊博 搭配色彩）。並特別感謝 葉峻銓 為本專案提供寶貴的想法與功能建議。",
            icon: Icons.palette_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildThanksItem(
            context,
            colorScheme,
            title: "Sunny Fan",
            subtitle:
                "特別感謝他長期擔任本專案的專屬測試員，無論大小 Bug 均在第一時間詳盡回報，協助系統穩定度把關，更給予了開發者無比的溫慢與前行動力。",
            icon: Icons.person_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildThanksItem(
    BuildContext context,
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.accentBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: colorScheme.accentBlue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.subtitleText,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreditsCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "素材與開源宣告",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "本應用程式部分圖示與視覺素材來自於開源社群與平台，在此致謝：\n\n"
            "• Icon 'ic_school' designed by lutfix from Flaticon",
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.bodyText.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: colorScheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "開源授權條款 (MIT)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: colorScheme.secondaryCardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              "MIT License\n\n"
              "Copyright (c) 2026 Edwin Chu\n\n"
              "Permission is hereby granted, free of charge, to any person obtaining a copy "
              "of this software and associated documentation files (the \"Software\"), to deal "
              "in the Software without restriction, including without limitation the rights "
              "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell "
              "copies of the Software, and to permit persons to whom the Software is "
              "furnished to do so, subject to the following conditions:\n\n"
              "The above copyright notice and this permission notice shall be included in all "
              "copies or substantial portions of the Software.\n\n"
              "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR "
              "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, "
              "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE "
              "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER "
              "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, "
              "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE "
              "SOFTWARE.",
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.bodyText.withOpacity(0.9),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubButton(BuildContext context, ColorScheme colorScheme) {
    return ElevatedButton.icon(
      onPressed: _launchGitHubUrl,
      icon: const Icon(Icons.launch_rounded, size: 18),
      label: const Text(
        "GitHub 開源網址",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.primaryText,
            ),
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          SizedBox(height: 10),
          Text(
            "歡迎使用學生服務系統",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "為了確保最佳使用體驗，請詳閱以下說明",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(int index, String title, String content) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colorScheme.isDark ? 0.15 : 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.isDark
                ? Colors.blue[900]
                : Colors.blue[100],
            child: Text(
              index.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.isDark
                    ? Colors.blue[100]
                    : Colors.blue[800],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.subtitleText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
