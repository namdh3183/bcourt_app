import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';
import 'edit_court_bank_screen.dart';

class SelectCourtForBankScreen extends StatelessWidget {
  final String ownerId;

  const SelectCourtForBankScreen({super.key, required this.ownerId});

  bool _hasBankInfo(CourtModel court) {
    return (court.bankAccountNumber?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();
    const Color primaryPurple = Color(0xFFBF89F5);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chọn sân cần chỉnh thông tin ngân hàng',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CourtModel>>(
        stream: dbService.getOwnerCourtsStream(ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Bạn chưa có sân nào.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final courts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courts.length,
            itemBuilder: (context, index) {
              final court = courts[index];
              final hasBankInfo = _hasBankInfo(court);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditCourtBankScreen(court: court),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Icon sân
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryPurple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sports_tennis,
                              color: primaryPurple, size: 24),
                        ),
                        const SizedBox(width: 14),

                        // Tên và địa chỉ sân
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                court.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (court.address?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        court.address!,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Badge trạng thái tài khoản
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: hasBankInfo
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: hasBankInfo
                                  ? Colors.green.withOpacity(0.4)
                                  : Colors.orange.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            hasBankInfo ? 'Đã có TK' : 'Chưa có TK',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  hasBankInfo ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
