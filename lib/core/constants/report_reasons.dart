class ReportReasons {
  // Chủ sân báo cáo khách hàng
  static const Map<String, String> forCustomer = {
    'cancel_last_minute': 'Hủy sân quá sát giờ (dưới 24h)',
    'no_show': 'Không đến (bom sân)',
    'wrong_amount': 'Chuyển sai số tiền cọc',
    'bad_behavior': 'Hành vi không đúng mực',
    'other': 'Khác (ghi rõ trong mô tả)',
  };

  // Khách hàng báo cáo chủ sân
  static const Map<String, String> forOwner = {
    'cancelled_confirmed_booking': 'Tự ý hủy lịch đã xác nhận',
    'court_not_as_described': 'Sân không đúng mô tả',
    'no_response': 'Không trả lời khi liên hệ',
    'refused_entry': 'Không cho vào sân dù đã đặt',
    'other': 'Khác (ghi rõ trong mô tả)',
  };
}
