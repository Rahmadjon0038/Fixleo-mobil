# Ilova ichidagi xabarlar

Error/success/info xabarlari uchun `AppFeedback.of(context).showSnackBar(...)`
ishlatiladi. Mavjud SnackBar matni, action va duration saqlanadi.

`MaterialApp.builder` ichidagi `AppFeedbackHost` Navigator ustida chiziladi:
bottom sheet, dialog va klaviatura ortida qolmaydi. Bu remote push banner yoki
Android/iOS tizim notificationlarini almashtirmaydi.

- Eng so‘nggi xabar oldingisini almashtiradi; eski timer yangisini yopolmaydi.
- Xabar safe area ostida, 600px max kenglikda ko‘rinadi.
- Uzun matn scroll bo‘ladi; yopish tugmasi matn boshida qoladi.
- Faqat banner hududi touchni ushlaydi, qolgan sahifa/modal ishlayveradi.
- Action callback saqlanadi; xabar yopilgach bajariladi.
- Screen reader uchun live region, actionli xabarda accessible-navigation
  timeout o‘chiriladi. Reduced motion qo‘llab-quvvatlanadi.
- Kontrast uchun banner o‘qilishi aniq rangda chiziladi; qo‘shimcha native
  Liquid Glass platform view yo‘q.
- Host bo‘lmagan standalone screen testlarida ScaffoldMessenger fallback bor.

57 chaqiruv nuqtasi umumiy qatlamga ko‘chirildi, jumladan hamyon to‘ldirish,
buyurtma to‘lovi, profil, chat, usta xizmat narxlari va lokatsiya ruxsatlari.
Matnlar va biznes so‘rovlari o‘zgartirilmagan.

Tekshiruv: `flutter test test/app_feedback_test.dart` va `flutter analyze`.
Modal ustida hit-test, yangi dialogdan keyingi z-order, timer replacement,
action, accessibility, katta shrift va klaviatura ssenariylari bor.
