import 'package:flutter/material.dart';
import '../models/graduation_model.dart';
import '../services/graduation_service.dart';
import '../theme/app_theme.dart';

class GraduationPage extends StatefulWidget {
  const GraduationPage({Key? key}) : super(key: key);

  @override
  State<GraduationPage> createState() => _GraduationPageState();
}

class _GraduationPageState extends State<GraduationPage> {
  late Future<GraduationData?> _dataFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = GraduationService.instance.fetchGraduationData(forceRefresh: false);
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _dataFuture = GraduationService.instance.fetchGraduationData(forceRefresh: true);
    });
    try {
      await _dataFuture;
    } catch (e) {
      debugPrint("Refresh error: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      appBar: null, // 移除 AppBar
      body: Column(
        children: [
          // 1. 自定義桌面標題列
          _buildDesktopHeader(),

          // 2. 主內容區域
          Expanded(
            child: FutureBuilder<GraduationData?>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text("正在連線教務處資料庫...", style: TextStyle(color: Theme.of(context).colorScheme.subtitleText)),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text("讀取失敗：\n${snapshot.error}", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primaryText)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _handleRefresh,
                            child: const Text("重試"),
                          )
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text("無法取得資料，請檢查網路或帳號狀態"));
                }

                final data = snapshot.data!;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: [
                          _buildStudentCard(data),
                          const SizedBox(height: 16),
                          _buildCreditProgress(data),
                          const SizedBox(height: 16),
                          
                          if (data.missingRequiredCourses.isNotEmpty) ...[
                            _buildMissingRequiredCard(data),
                            const SizedBox(height: 16),
                          ],

                          _buildGenEdCard(data),
                          const SizedBox(height: 16),
                          _buildElectivesCard(data),
                          
                          const SizedBox(height: 40),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  "最後更新時間：${data.checkTime}",
                                  style: TextStyle(color: Theme.of(context).colorScheme.subtitleText, fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "此頁面資料僅供參考，請務必以官方查詢結果為準",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Theme.of(context).colorScheme.subtitleText.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 20, top: 25, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text("畢業檢核", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
                ],
              ),
              _buildRefreshButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _isRefreshing ? null : _handleRefresh,
      mouseCursor: _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.borderColor),
        ),
        child: Row(
          children: [
            _isRefreshing 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
              : Icon(Icons.refresh_rounded, size: 18, color: Theme.of(context).colorScheme.accentBlue),
            const SizedBox(width: 8),
            Text(_isRefreshing ? "同步中" : "重新整理", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.accentBlue)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.secondaryCardBackground,
            child: Text(
              data.studentName.isNotEmpty ? data.studentName[0] : "生",
              style: TextStyle(color: Theme.of(context).colorScheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.studentName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.primaryText)),
                const SizedBox(height: 4),
                Text("${data.department} • ${data.studentId}", style: TextStyle(color: colorScheme.subtitleText, fontSize: 15)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCreditProgress(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    double progress = data.currentCredits / data.minCredits;
    if (progress > 1.0) progress = 1.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("畢業學分達成進度", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 24,
                  backgroundColor: Theme.of(context).colorScheme.secondaryCardBackground,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? Colors.green[600] : (Theme.of(context).colorScheme.isDark ? Colors.orange[400] : Colors.orange[600]),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    "${(progress * 100).toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 13, 
                      shadows: [Shadow(color: Theme.of(context).colorScheme.isDark ? Colors.black : Colors.black26, blurRadius: 2)]
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: "已獲得 ", style: TextStyle(color: Theme.of(context).colorScheme.subtitleText)),
                    TextSpan(text: "${data.currentCredits}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).colorScheme.primaryText)),
                    TextSpan(text: " 學分", style: TextStyle(color: Theme.of(context).colorScheme.subtitleText)),
                  ]
                )
              ),
              Text("應修 ${data.minCredits}", style: TextStyle(color: Theme.of(context).colorScheme.subtitleText, fontWeight: FontWeight.w500)),
            ],
          ),
          if (data.currentCredits < data.minCredits)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.isDark ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50], 
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                "尚缺 ${data.minCredits - data.currentCredits} 學分即可達標",
                style: TextStyle(color: Theme.of(context).colorScheme.isDark ? Colors.red[200] : Colors.red[700], fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildMissingRequiredCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.error_rounded, color: Colors.red, size: 28),
        title: const Text("尚未修習之必修課", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 17)),
        children: data.missingRequiredCourses.map((course) => ListTile(
          dense: true,
          leading: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
          title: Text(course, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primaryText)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        )).toList(),
      ),
    );
  }

  Widget _buildGenEdCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text("核心通識與畢業門檻", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        leading: const Icon(Icons.fact_check_rounded, color: Colors.teal, size: 28),
        children: data.genEdStatuses.map((item) {
          bool isOk = item.status == "符合";
          Widget statusBadge = Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isOk 
                  ? (Theme.of(context).colorScheme.isDark ? Colors.green[900]?.withOpacity(0.2) : Colors.green[50]) 
                  : (Theme.of(context).colorScheme.isDark ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50]),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isOk ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
            ),
            child: Text(item.status, style: TextStyle(color: isOk ? (Theme.of(context).colorScheme.isDark ? Colors.green[200] : Colors.green[700]) : (Theme.of(context).colorScheme.isDark ? Colors.red[200] : Colors.red[700]), fontSize: 12, fontWeight: FontWeight.bold)),
          );

          if (item.details.isNotEmpty) {
            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(isOk ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isOk ? Colors.green : Colors.redAccent, size: 22),
              title: Row(
                children: [
                  Flexible(child: Text(item.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primaryText))),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty ? Text(item.description, style: const TextStyle(color: Colors.redAccent, fontSize: 13)) : null,
              children: item.details.map((detail) => Container(
                color: Theme.of(context).colorScheme.secondaryCardBackground,
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 64, right: 24),
                  leading: Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Theme.of(context).colorScheme.subtitleText),
                  title: Text(detail, style: TextStyle(color: Theme.of(context).colorScheme.primaryText, fontSize: 14)),
                ),
              )).toList(),
            );
          } else {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(isOk ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isOk ? Colors.green : Colors.redAccent, size: 22),
              title: Row(
                children: [
                  Flexible(child: Text(item.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primaryText))),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty ? Text(item.description, style: const TextStyle(color: Colors.redAccent, fontSize: 13)) : null,
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _buildElectivesCard(GraduationData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text("已修習選修課程 (${data.takenElectiveCourses.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        leading: const Icon(Icons.book_rounded, color: Colors.indigo, size: 28),
        children: [
          SizedBox(
            height: 300, 
            child: ListView.separated(
              itemCount: data.takenElectiveCourses.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 24, endIndent: 24),
              itemBuilder: (ctx, i) {
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.bookmark_added_rounded, size: 18, color: Theme.of(context).colorScheme.accentBlue),
                  title: Text(data.takenElectiveCourses[i], style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.primaryText)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}