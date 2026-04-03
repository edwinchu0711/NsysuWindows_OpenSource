import 'package:flutter/material.dart';

class AssistantAddEventPane extends StatefulWidget {
  final List<String> periods;
  final List<String> fullWeekDays;
  final Function(String title, String location, String details, int day, List<String> selectedPeriods) onSave;

  const AssistantAddEventPane({
    Key? key,
    required this.periods,
    required this.fullWeekDays,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AssistantAddEventPane> createState() => _AssistantAddEventPaneState();
}

class _AssistantAddEventPaneState extends State<AssistantAddEventPane> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _detailsCtrl = TextEditingController();
  int _selectedDay = 1;
  final Set<String> _selectedPeriods = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("新增其他行程", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: '標題 (如: 工讀、社團)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(labelText: '位置', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _detailsCtrl,
                    decoration: const InputDecoration(labelText: '詳細內容 (地點、備註)', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text("選擇星期：", style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedDay,
                    mouseCursor: SystemMouseCursors.click,
                    items: List.generate(7, (index) {
                      return DropdownMenuItem(value: index + 1, child: Text("星期${widget.fullWeekDays[index]}"));
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("選擇節次 (可多選)：", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: widget.periods.map((p) {
                      final isSelected = _selectedPeriods.contains(p);
                      return FilterChip(
                        label: Text(p),
                        selected: isSelected,
                        selectedColor: Colors.blue[100],
                        showCheckmark: false,
                        mouseCursor: SystemMouseCursors.click,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedPeriods.add(p);
                            } else {
                              _selectedPeriods.remove(p);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    _titleCtrl.text,
                    _locationCtrl.text,
                    _detailsCtrl.text,
                    _selectedDay,
                    _selectedPeriods.toList(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text("儲存行程", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
