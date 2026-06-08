// FILE: lib/Widgets/uihelper.dart

import 'package:flutter/material.dart';

class UiHelper {

  static Widget customTextField({

    required TextEditingController controller,

    required String text,

    required bool tohide,

    required TextInputType textinputtype,
  }) {

    return Container(

      height: 60,

      decoration: BoxDecoration(

        color: Colors.white.withOpacity(0.04),

        borderRadius:
        BorderRadius.circular(16),

        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),

      child: TextField(

        controller: controller,

        obscureText: tohide,

        keyboardType: textinputtype,

        style: const TextStyle(
          color: Colors.white,
        ),

        decoration: InputDecoration(

          contentPadding:
          const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),

          border: InputBorder.none,

          hintText: text,

          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  static Widget customImage({
    required String imgurl,
  }) {

    return Image.asset(
      "assets/images/$imgurl",

      width: 220,
    );
  }
}