import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTextStyles {
  static TextStyle h1() => TextStyle(
        fontSize: 26.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
      );
  static TextStyle h2() => TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );
  static TextStyle title() => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );
  static TextStyle body() => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );
  static TextStyle caption() => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );
  static TextStyle label() => TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      );
  static TextStyle messageBubble() => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );
  static TextStyle timestamp() => TextStyle(
        fontSize: 10.sp,
        fontWeight: FontWeight.w400,
      );
}
