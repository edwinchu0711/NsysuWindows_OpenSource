import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      "content": "此功能僅在每年 5/15~6/15 及 12/15~1/15 自動更新。非此期間若有需要，請進入功能頁面手動更新。",
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
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: isWide ? 0.85 : 1.0,
            child: Column(
              children: [
                _buildHeader(context, "使用須知與資訊"),
                Expanded(
                  child: SingleChildScrollView(
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
                                          right: j < columns - 1 ? 16.0 : 0.0,
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
                                  padding: const EdgeInsets.only(bottom: 16.0),
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

                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.isDark
                                ? Colors.blue[900]!.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.isDark
                                  ? Colors.blue[700]!.withOpacity(0.3)
                                  : Colors.blue.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.volunteer_activism,
                                    color: Theme.of(context).colorScheme.isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[400],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "與開源社群共同成長",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "特別感謝 NSYSU Open Development Community 提供的開源貢獻，為本專案的基礎架構提供了寶貴的參考與支援。",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.subtitleText,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
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
                ),
              ],
            ),
          ),
        ),
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
