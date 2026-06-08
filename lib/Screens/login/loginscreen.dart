import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paradox/Screens/home/post_login_splash.dart';
import 'package:paradox/Screens/Signup/signupscreen.dart';
import 'package:paradox/Widgets/uihelper.dart';
import 'package:paradox/services/auth_service.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final TextEditingController emailcontroller =
      TextEditingController();

  final TextEditingController passwordcontroller =
      TextEditingController();

  final Color primaryColor =
      const Color(0XFF263f4b);

  /// EXIT POPUP
  Future<bool> showExitPopup() async {

    return await showDialog(

          context: context,

          builder: (context) => AlertDialog(

            backgroundColor:
                const Color(0XFF111111),

            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(22),
            ),

            title: const Text(

              "Leave Paradox?",

              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            content: const Text(

              "Your scientific journey will pause here.",

              style: TextStyle(
                color: Colors.white70,
              ),
            ),

            actions: [

              /// STAY BUTTON
              TextButton(

                onPressed: () {

                  Navigator.pop(context, false);
                },

                child: const Text(

                  "STAY",

                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),

              /// EXIT BUTTON
              Container(

                decoration: BoxDecoration(

                  borderRadius:
                      BorderRadius.circular(12),

                  gradient: const LinearGradient(

                    colors: [

                      Color(0XFF263f4b),

                      Color(0XFF3d6272),
                    ],
                  ),
                ),

                child: TextButton(

                  onPressed: () {

                    Navigator.pop(context, true);
                  },

                  child: const Text(

                    "EXIT",

                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(

      canPop: false,

      onPopInvoked: (didPop) async {

        if (didPop) return;

        final shouldPop =
            await showExitPopup();

        if (shouldPop) {

          Navigator.of(context).pop();
        }
      },

      child: Scaffold(

        backgroundColor: Colors.black,

        body: Stack(

          children: [

            /// TOP GLOW
            Positioned(
              top: -120,
              left: -60,

              child: Container(
                height: 260,
                width: 260,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color:
                      primaryColor.withOpacity(0.35),
                ),
              ),
            ),

            /// BOTTOM GLOW
            Positioned(
              bottom: -120,
              right: -60,

              child: Container(
                height: 260,
                width: 260,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color:
                      primaryColor.withOpacity(0.25),
                ),
              ),
            ),

            /// BLUR EFFECT
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 90,
                sigmaY: 90,
              ),

              child: Container(
                color: Colors.transparent,
              ),
            ),

            /// MAIN CONTENT
            Center(

              child: SingleChildScrollView(

                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 25,
                  ),

                  child: Column(

                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [

                      /// LOGO
                      Hero(
                        tag: "logo",

                        child: UiHelper.customImage(
                          imgurl:
                              "textParadox.png",
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// TITLE
                      const Text(
                        "SCIENCE SOCIAL NETWORK",

                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 4,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 45),

                      /// GLASS LOGIN CARD
                      Container(

                        padding:
                            const EdgeInsets.all(20),

                        decoration: BoxDecoration(

                          color: Colors.white
                              .withOpacity(0.05),

                          borderRadius:
                              BorderRadius.circular(
                                  25),

                          border: Border.all(
                            color: Colors.white
                                .withOpacity(0.08),
                          ),

                          boxShadow: [

                            BoxShadow(
                              color: primaryColor
                                  .withOpacity(0.25),

                              blurRadius: 35,
                              spreadRadius: 2,
                            ),
                          ],
                        ),

                        child: Column(

                          children: [

                            /// EMAIL
                            UiHelper.customTextField(
                              controller:
                                  emailcontroller,

                              text: "Username or Email",

                              tohide: false,

                              textinputtype:
                                  TextInputType
                                      .emailAddress,
                            ),

                            const SizedBox(
                                height: 18),

                            /// PASSWORD
                            UiHelper.customTextField(
                              controller:
                                  passwordcontroller,

                              text: "Password",

                              tohide: true,

                              textinputtype:
                                  TextInputType.text,
                            ),

                            const SizedBox(
                                height: 30),

                            /// LOGIN BUTTON
                            GestureDetector(

                              onTap: () async {
                                final identifier = emailcontroller.text.trim();
                                final password = passwordcontroller.text.trim();

                                if (identifier.isEmpty || password.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Enter username/email and password.'),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await AuthService.signInWithUsernameOrEmail(
                                    identifier: identifier,
                                    password: password,
                                  );

                                  if (!mounted) return;

                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PostLoginSplashScreen(),
                                    ),
                                    (route) => false,
                                  );
                                } on FirebaseAuthException catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.message ?? error.code)),
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Login failed: $error')),
                                  );
                                }
                              },

                              child:
                                  AnimatedContainer(

                                duration:
                                    const Duration(
                                  milliseconds: 400,
                                ),

                                height: 55,
                                width:
                                    double.infinity,

                                decoration:
                                    BoxDecoration(

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              18),

                                  gradient:
                                      LinearGradient(

                                    colors: [

                                      primaryColor,

                                      const Color(
                                          0XFF3d6272),
                                    ],
                                  ),

                                  boxShadow: [

                                    BoxShadow(
                                      color:
                                          primaryColor
                                              .withOpacity(
                                                  0.6),

                                      blurRadius: 20,
                                      spreadRadius:
                                          1,
                                    ),
                                  ],
                                ),

                                child:
                                    const Center(

                                  child: Text(
                                    "ENTER PARADOX",

                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize: 15,

                                      fontWeight:
                                          FontWeight
                                              .bold,

                                      letterSpacing:
                                          2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                                height: 18),

                            /// FORGOT
                            TextButton(

                              onPressed: () {},

                              child: Text(

                                "Forgot Password?",

                                style: TextStyle(
                                  color: primaryColor
                                      .withOpacity(
                                          0.9),

                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      /// FOOTER
                      /// FOOTER
                      Text(
                        "Where science meets people.",

                        style: TextStyle(
                          color:
                          Colors.white.withOpacity(0.45),

                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(

                        mainAxisAlignment:
                        MainAxisAlignment.center,

                        children: [

                          Text(

                            "Don't have an account?",

                            style: TextStyle(

                              color:
                              Colors.white.withOpacity(0.6),
                            ),
                          ),

                          GestureDetector(

                            onTap: () {

                              Navigator.push(

                                context,

                                MaterialPageRoute(

                                  builder: (context) =>
                                  const SignupScreen(),
                                ),
                              );
                            },

                            child: Padding(

                              padding:
                              const EdgeInsets.only(left: 6),

                              child: Text(

                                "Sign Up",

                                style: TextStyle(

                                  color: primaryColor,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}