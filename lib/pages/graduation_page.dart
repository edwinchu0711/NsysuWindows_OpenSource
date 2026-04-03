import 'package:flutter/material.dart';
import '../models/graduation_model.dart';
import '../services/graduation_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text("正在連線教務處資料庫...", style: TextStyle(color: Colors.grey)),
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
                          Text("讀取失敗：\n${snapshot.error}", textAlign: TextAlign.center),
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
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "此頁面資料僅供參考，請務必以官方查詢結果為準",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
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
                  const Text("畢業檢核", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
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
    return InkWell(
      onTap: _isRefreshing ? null : _handleRefresh,
      mouseCursor: _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            _isRefreshing 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
              : Icon(Icons.refresh_rounded, size: 18, color: Colors.purple[700]),
            const SizedBox(width: 8),
            Text(_isRefreshing ? "同步中" : "重新整理", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(GraduationData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.purple[50],
            child: Text(
              data.studentName.isNotEmpty ? data.studentName[0] : "生",
              style: TextStyle(color: Colors.purple[700], fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.studentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text("${data.department} • ${data.studentId}", style: TextStyle(color: Colors.grey[600], fontSize: 15)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCreditProgress(GraduationData data) {
    double progress = data.currentCredits / data.minCredits;
    if (progress > 1.0) progress = 1.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("畢業學分達成進度", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 20),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 24,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    "${(progress * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
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
                    TextSpan(text: "已獲得 ", style: TextStyle(color: Colors.grey[600])),
                    TextSpan(text: "${data.currentCredits}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                    TextSpan(text: " 學分", style: TextStyle(color: Colors.grey[600])),
                  ]
                )
              ),
              Text("應修 ${data.minCredits}", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
            ],
          ),
          if (data.currentCredits < data.minCredits)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Text(
                "尚缺 ${data.minCredits - data.currentCredits} 學分即可達標",
                style: TextStyle(color: Colors.red[700], fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildMissingRequiredCard(GraduationData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.error_rounded, color: Colors.red, size: 28),
        title: const Text("尚未修習之必修課", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 17)),
        children: data.missingRequiredCourses.map((course) => ListTile(
          dense: true,
          leading: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
          title: Text(course, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        )).toList(),
      ),
    );
  }

  Widget _buildGenEdCard(GraduationData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
              color: isOk ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isOk ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
            ),
            child: Text(item.status, style: TextStyle(color: isOk ? Colors.green[700] : Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold)),
          );

          if (item.details.isNotEmpty) {
            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(isOk ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isOk ? Colors.green : Colors.redAccent, size: 22),
              title: Row(
                children: [
                  Flexible(child: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty ? Text(item.description, style: const TextStyle(color: Colors.red, fontSize: 13)) : null,
              children: item.details.map((detail) => Container(
                color: Colors.grey[50],
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 64, right: 24),
                  leading: const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Colors.grey),
                  title: Text(detail, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
                ),
              )).toList(),
            );
          } else {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Icon(isOk ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isOk ? Colors.green : Colors.redAccent, size: 22),
              title: Row(
                children: [
                  Flexible(child: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  statusBadge,
                ],
              ),
              subtitle: item.description.isNotEmpty ? Text(item.description, style: const TextStyle(color: Colors.red, fontSize: 13)) : null,
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _buildElectivesCard(GraduationData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
                  leading: Icon(Icons.bookmark_added_rounded, size: 18, color: Colors.indigo[300]),
                  title: Text(data.takenElectiveCourses[i], style: const TextStyle(fontSize: 15)),
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