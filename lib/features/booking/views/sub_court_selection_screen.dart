import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import 'court_detail_screen.dart';

class SubCourtSelectionScreen extends StatelessWidget {
  final CourtModel court; // Truyền nguyên CLB sang đây

  const SubCourtSelectionScreen({super.key, required this.court});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(court.name)),
      body: Column(
        children: [
          // Banner ảnh của CLB
          SizedBox(
            height: 150,
            width: double.infinity,
            child: court.images.isNotEmpty
                ? Image.network(court.images.first, fit: BoxFit.cover)
                : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50)),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Vui lòng chọn sân để xem lịch:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          // Danh sách các sân con (Sân 1, Sân 2...)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: court.subCourts.length,
              itemBuilder: (context, index) {
                final subCourtName = court.subCourts[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.sports_tennis, color: Colors.green, size: 32),
                    title: Text(subCourtName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text('Giá: ${court.pricePerHour.toStringAsFixed(0)} VNĐ/giờ'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // BẤM VÀO SẼ CHUYỂN SANG MÀN HÌNH DẢI BĂNG
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourtDetailScreen(
                            court: court, 
                            subCourtName: subCourtName, // Truyền tên sân con sang!
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}