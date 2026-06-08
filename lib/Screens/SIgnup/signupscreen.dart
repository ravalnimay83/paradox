// FILE: lib/Screens/Signup/signupscreen.dart

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paradox/Screens/Signup/google_profile_setup.dart';
import 'package:paradox/Screens/home/post_login_splash.dart';
import 'package:paradox/Widgets/uihelper.dart';
import 'package:paradox/google_signin.dart';
import 'package:paradox/services/auth_service.dart';

class SignupScreen extends StatefulWidget {

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() =>
      _SignupScreenState();
}

class _SignupScreenState
    extends State<SignupScreen> {

  final TextEditingController
  usernamecontroller =
  TextEditingController();

  final TextEditingController
  emailcontroller =
  TextEditingController();

  final TextEditingController
  passwordcontroller =
  TextEditingController();

  final Color primaryColor =
  const Color(0XFF263f4b);

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      body: Stack(

        children: [

          /// BACKGROUND IMAGE
          SizedBox(

            height: double.infinity,
            width: double.infinity,

            child: Image.asset(

              "assets/images/signupBG.png",

              fit: BoxFit.cover,
            ),
          ),

          /// DARK OVERLAY
          Container(
            color:
            Colors.black.withOpacity(0.72),
          ),

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
                primaryColor.withOpacity(
                    0.35),
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
                primaryColor.withOpacity(
                    0.28),
              ),
            ),
          ),

          /// BLUR
          BackdropFilter(

            filter: ImageFilter.blur(
              sigmaX: 90,
              sigmaY: 90,
            ),

            child: Container(
              color: Colors.transparent,
            ),
          ),

          /// MAIN UI
          SafeArea(

            child: Center(

              child: SingleChildScrollView(

                child: Padding(

                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),

                  child: Column(

                    children: [

                      /// LOGO
                      Hero(

                        tag: "logo",

                        child:
                        UiHelper.customImage(
                          imgurl:
                          "textParadox.png",
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// TITLE
                      const Text(

                        "CREATE YOUR SCIENTIFIC IDENTITY",

                        textAlign:
                        TextAlign.center,

                        style: TextStyle(

                          color: Colors.white,

                          fontSize: 13,

                          letterSpacing: 3,

                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 40),

                      /// GLASS CARD
                      Container(

                        padding:
                        const EdgeInsets.all(
                            22),

                        decoration: BoxDecoration(

                          color: Colors.white
                              .withOpacity(0.05),

                          borderRadius:
                          BorderRadius
                              .circular(28),

                          border: Border.all(

                            color: Colors.white
                                .withOpacity(0.08),
                          ),

                          boxShadow: [

                            BoxShadow(

                              color: primaryColor
                                  .withOpacity(
                                  0.25),

                              blurRadius: 35,

                              spreadRadius: 2,
                            ),
                          ],
                        ),

                        child: Column(

                          children: [

                            /// USERNAME
                            UiHelper
                                .customTextField(

                              controller:
                              usernamecontroller,

                              text: "Username",

                              tohide: false,

                              textinputtype:
                              TextInputType
                                  .text,
                            ),

                            const SizedBox(
                                height: 18),

                            /// EMAIL
                            UiHelper
                                .customTextField(

                              controller:
                              emailcontroller,

                              text: "Email",

                              tohide: false,

                              textinputtype:
                              TextInputType
                                  .emailAddress,
                            ),

                            const SizedBox(
                                height: 18),

                            /// PASSWORD
                            UiHelper
                                .customTextField(

                              controller:
                              passwordcontroller,

                              text: "Password",

                              tohide: true,

                              textinputtype:
                              TextInputType
                                  .text,
                            ),

                            const SizedBox(
                                height: 30),

                            /// CREATE ACCOUNT BUTTON
                            GestureDetector(

                              onTap: () async {
                                final username = usernamecontroller.text.trim();
                                final email = emailcontroller.text.trim();
                                final password = passwordcontroller.text.trim();

                                if (username.isEmpty || email.isEmpty || password.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Enter username, email, and password.'),
                                    ),
                                  );
                                  return;
                                }

                                if (password.length < AuthService.minPasswordLength) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Password must be at least ${AuthService.minPasswordLength} characters.'),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await AuthService.signUpWithEmailAndUsername(
                                    username: username,
                                    email: email,
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
                                    SnackBar(content: Text('Signup failed: $error')),
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

                                      blurRadius:
                                      20,

                                      spreadRadius:
                                      1,
                                    ),
                                  ],
                                ),

                                child:
                                const Center(

                                  child: Text(

                                    "CREATE ACCOUNT",

                                    style:
                                    TextStyle(

                                      color: Colors
                                          .white,

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
                                height: 25),

                            /// DIVIDER
                            Row(

                              children: [

                                Expanded(

                                  child: Divider(

                                    color: Colors
                                        .white
                                        .withOpacity(
                                        0.15),
                                  ),
                                ),

                                Padding(

                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                    horizontal: 12,
                                  ),

                                  child: Text(

                                    "OR",

                                    style:
                                    TextStyle(

                                      color: Colors
                                          .white
                                          .withOpacity(
                                          0.55),
                                    ),
                                  ),
                                ),

                                Expanded(

                                  child: Divider(

                                    color: Colors
                                        .white
                                        .withOpacity(
                                        0.15),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                                height: 25),

                            /// GOOGLE BUTTON
                            GestureDetector(

                              onTap: () async {
                                try {
                                  final credential = await GoogleSignInProvider().googleLogin();
                                  if (!mounted || credential == null) return;

                                  final currentUser = FirebaseAuth.instance.currentUser;
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GoogleProfileSetupScreen(
                                        email: currentUser?.email,
                                        displayName: currentUser?.displayName,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Google sign-in failed: $e')),
                                  );
                                }
                              },

                              child: Container(

                                height: 55,

                                width:
                                double.infinity,

                                decoration:
                                BoxDecoration(

                                  color:
                                  Colors.white,

                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      18),
                                ),

                                child: Row(

                                  mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,

                                  children: [

                                    const Icon(

                                      Icons
                                          .g_mobiledata,

                                      color: Colors
                                          .black,

                                      size: 38,
                                    ),

                                    const SizedBox(
                                        width: 10),

                                    const Text(

                                      "Continue with Google",

                                      style:
                                      TextStyle(

                                        color: Colors
                                            .black,

                                        fontWeight:
                                        FontWeight
                                            .bold,

                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(
                                height: 15),

                            /// APPLE BUTTON
                            GestureDetector(

                              onTap: () {

                                ScaffoldMessenger.of(
                                    context)
                                    .showSnackBar(

                                  const SnackBar(

                                    content: Text(
                                      "Apple Sign-In Coming Soon",
                                    ),
                                  ),
                                );
                              },

                              child: Container(

                                height: 55,

                                width:
                                double.infinity,

                                decoration:
                                BoxDecoration(

                                  color: const Color(
                                      0XFF111111),

                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      18),

                                  border: Border.all(

                                    color: Colors
                                        .white
                                        .withOpacity(
                                        0.08),
                                  ),
                                ),

                                child: const Row(

                                  mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,

                                  children: [

                                    Icon(

                                      Icons.apple,

                                      color: Colors
                                          .white,

                                      size: 24,
                                    ),

                                    SizedBox(
                                        width: 10),

                                    Text(

                                      "Continue with Apple",

                                      style:
                                      TextStyle(

                                        color: Colors
                                            .white,

                                        fontWeight:
                                        FontWeight
                                            .w600,

                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      /// FOOTER
                      Text(

                        "Where science meets people.",

                        style: TextStyle(

                          color: Colors.white
                              .withOpacity(0.45),

                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}