# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About the Project

# BCourt - Ứng dụng quản lý đặt sân cầu lông

## Bối cảnh dự án
Đây là đồ án tốt nghiệp của sinh viên Dương Hoài Nam (MSSV: 21280103E0020) 
tại Đại học Thủ Dầu Một, ngành Kỹ thuật phần mềm.

## Stack công nghệ
- Flutter (đa nền tảng Android/iOS/Web)
- Firebase: Authentication, Cloud Firestore, Firebase Storage
- Google Sign-In
- Image Picker, Intl

## Kiến trúc
- Feature-based architecture
- 3 phân hệ: Customer (khách đặt sân), Owner (chủ sân), Admin (quản trị)
- Models - Services - Features/Views

## Quy ước code
- Code comments và UI string bằng tiếng Việt
- Màu chủ đạo: Color(0xFFBF89F5) - primaryPurple
- Sử dụng StreamBuilder cho real-time data từ Firestore
- Transaction chống trùng lịch đặt sân

## Common Commands

```bash
# Run the app (Android/iOS device or emulator must be connected)
flutter run

# Run on a specific device
flutter run -d <device-id>

# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Analyze code (lint)
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Install dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

## Architecture

The app uses a simple service-based architecture with no state management library — state is managed with `StatefulWidget` + `setState`.

### Layer Structure

```
lib/
├── main.dart                  # App entry point, Firebase init, theme (purple: #8B32E3 / #BF89F5)
├── firebase_options.dart       # Auto-generated Firebase config
├── models/                    # Plain Dart data classes with toMap/fromMap
│   ├── user_model.dart        # roles: 'customer' | 'owner' | 'admin'; status: 'active' | 'banned'
│   ├── court_model.dart       # status: 'active' | 'pending' | 'inactive'; subCourts: List<String>
│   └── booking_model.dart     # bookingStatus: 'pending' | 'confirmed' | 'cancelled'
│                              # paymentStatus: 'unpaid' | 'deposit_paid' | 'fully_paid'
├── services/
│   ├── auth_service.dart      # Firebase Auth + Firestore user creation; Google Sign-In support
│   └── database_service.dart  # All Firestore + Storage operations (courts, bookings, admin)
└── features/                  # Screens grouped by domain
    ├── auth/views/            # login, register, forgot_password
    ├── booking/views/         # customer_home, court_detail, sub_court_selection,
    │                          #   payment, booking_success, booking_history
    ├── court_management/views/ # owner_home, owner_court_detail, owner_court_schedule,
    │                           #   add_court, edit_court, owner_revenue
    └── admin/views/           # admin_home (user & court management)
```

### Key Flows

**Authentication & Role Routing** (`login_screen.dart`): After sign-in (email/password or Google), `AuthService.getCurrentUserData()` fetches the user's Firestore doc and role. Navigation is then routed to `CustomerHomeScreen`, `OwnerHomeScreen`, or `AdminHomeScreen` based on the `role` field. Google sign-in new users see a role-selection dialog before their Firestore record is created.

**Booking Flow** (customer path):
1. `CustomerHomeScreen` — real-time `Stream` of active courts with search (diacritic-normalized) and price-range filter.
2. `SubCourtSelectionScreen` — select a sub-court within a venue.
3. `CourtDetailScreen` → `PaymentScreen` → `BookingSuccessScreen`.
4. `BookingHistoryScreen` — cancel bookings.

**Booking Creation** (`DatabaseService.createBooking`): Uses a Firestore Transaction to prevent double-booking. Returns `"success"`, `"overlap"`, or `"error"` as a string.

**Owner Flow**: `OwnerHomeScreen` lists the owner's courts via `getOwnerCourtsStream(ownerId)`. Owners can add/edit courts (with multi-image upload to Firebase Storage under `courts/<courtId>/`), view the daily schedule (`getAllBookingsForCourtByDate`), approve/cancel bookings, and view monthly revenue stats (`getMonthlyStatistics`).

**Admin Flow**: `AdminHomeScreen` can list all users/courts, approve or lock courts (`updateCourtStatus`), and ban/unban users (`updateUserStatus`). Courts require admin approval before becoming `active`.

### Firestore Collections

| Collection | Key fields |
|---|---|
| `users` | uid, fullName, email, phone, role, status, createdAt |
| `courts` | name, ownerId, description, pricePerHour, images[], subCourts[], status |
| `bookings` | customerId, courtId, subCourtName, bookingDate, startTime, endTime, totalPrice, paymentStatus, bookingStatus, depositProofImageUrl? |

### UI Conventions

- Primary purple: `Color(0xFFBF89F5)` (light) / `Color(0xFF8B32E3)` (dark seed).
- All screens instantiate `AuthService` and `DatabaseService` directly — no dependency injection.
- Streams are consumed with `StreamBuilder`; one-off reads use `async/await` inside `initState`.
- Vietnamese is the primary UI language.

## Known Technical Debt & Areas to Improve

Các phần code hiện tại còn thiếu/tạm thời, cần được cải thiện:

- **Bank info cho thanh toán đặt cọc**: Hiện hardcoded trong `payment_screen.dart` 
  (bankName, accountNumber, accountName). Cần migrate sang lưu trong profile 
  của chủ sân (UserModel) để mỗi chủ sân có thể config tài khoản riêng.
- **Thư mục `lib/core/`**: Hiện đang TRỐNG (constants/, theme/, utils/). 
  Các giá trị hardcoded như primaryPurple, _removeDiacritics helper nên được 
  centralize vào đây.
- **Không có push notification**: Đề cương yêu cầu nhắc lịch tự động, 
  hiện chưa implement (sẽ cần Firebase Cloud Messaging).
- **Không có test**: Thư mục `test/` chỉ có `widget_test.dart` mặc định.

## Coding Rules for Claude Code

Khi sinh code mới cho project này, tuân thủ các quy tắc sau:

1. **Ngôn ngữ**: Comments, UI strings, error messages, log messages BẮT BUỘC 
   bằng tiếng Việt. Tên biến/hàm/class vẫn bằng tiếng Anh.

2. **Màu sắc**: Luôn dùng `const Color(0xFFBF89F5)` cho primaryPurple. 
   KHÔNG tạo màu mới nếu không thực sự cần.

3. **Error handling**: 
   - Services trả về `bool` hoặc `String` (như pattern hiện tại), 
     KHÔNG throw exception lên UI layer.
   - UI dùng `ScaffoldMessenger.showSnackBar` để báo lỗi, có `backgroundColor` 
     tương ứng (đỏ cho lỗi, xanh cho thành công, cam cho cảnh báo).

4. **Immutable models**: Tất cả fields trong `*_model.dart` là `final`. 
   Khi cần "update", tạo instance mới với giá trị mới, KHÔNG tạo copyWith 
   trừ khi thật sự cần.

5. **Firestore queries**: Ưu tiên `StreamBuilder` cho data hiển thị real-time, 
   `FutureBuilder` cho data load 1 lần. Không dùng package state management.

6. **Transaction**: Mọi thao tác ghi booking PHẢI chạy trong transaction 
   để chống trùng lịch (xem mẫu trong `createBooking`).

7. **File naming**: snake_case cho filename, PascalCase cho class name, 
   camelCase cho variables/functions (convention Dart chuẩn).

8. **Không tự ý thêm dependency mới** vào `pubspec.yaml` khi chưa hỏi — 
   đồ án cần kiểm soát scope.

## Project Context

- Đây là ĐỒ ÁN TỐT NGHIỆP, không phải production app. Ưu tiên: code rõ ràng, 
  dễ giải thích khi bảo vệ > tối ưu performance.
- Mọi thay đổi lớn (thêm screen, thêm collection, thay đổi flow) nên được 
  giải thích rõ lý do trong commit message/PR.
- Khi refactor, giữ nguyên tên biến/hàm hiện tại nếu không thực sự cần đổi, 
  để tránh broken dependencies giữa các file.