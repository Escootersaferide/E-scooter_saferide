
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'complex_check.dart';
import 'mini_check.dart';
import 'feeling.dart';
import 'tips.dart';

void main() {
  runApp(const ScootApp());
}

class ScootApp extends StatelessWidget {
  const ScootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScootNavigation(),
    );
  }
}


class ScootNavigation extends StatefulWidget {
  const ScootNavigation({super.key});

  @override
  State<ScootNavigation> createState() => _ScootNavigationState();
}

class _ScootNavigationState extends State<ScootNavigation> {
  final PageController controller = PageController();
  String? selectedFeeling;


  void nextPage() {
    controller.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }


  void previousPage() {
    controller.previousPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      children: [

        WelcomeScreen(
          onNext: nextPage,
        ),

        ComprehensiveCheckPage(
          onNext: nextPage,
          onBack: previousPage,
        ),


        FeelingPage(
          onBack: previousPage,
          onNext: (feeling) {
            setState(() {
              selectedFeeling = feeling;
            });

            nextPage();
          },
        ),

        TipsPage(
          onBack: previousPage,
          onNext: nextPage,
        ),
      ],
    );
  }
}


class WelcomeScreen extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomeScreen({
    super.key,
    required this.onNext,
  });

  static const Color green = Color(0xFF16A991);
  static const Color lightGreen = Color(0xFFEAF8F5);
  static const Color darkText = Color(0xFF172B2B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;


            final contentWidth = screenWidth.clamp(0.0, 480.0);


            final scale = (contentWidth / 375).clamp(0.85, 1.2);


            final horizontalPadding =
                (contentWidth * 0.06).clamp(16.0, 28.0);


            final imageWidth =
                contentWidth - horizontalPadding * 2;

            final imageHeight = imageWidth * (960 / 1072);


            final pageHeight = screenHeight >
                    imageHeight + 370 * scale
                ? screenHeight
                : imageHeight + 370 * scale;

            return SingleChildScrollView(
              child: SizedBox(
                height: pageHeight,
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          


                          SizedBox(
                            width: double.infinity,
                            height: imageHeight,
                            child: SvgPicture.asset(
                              'assets/svg/main.svg',
                              fit: BoxFit.contain,
                            ),
                          ),


                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Добро пожаловать\nв Scoot!',
                                style: TextStyle(
                                  fontSize: 22 * scale,
                                  height: 1.05,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),

                              SizedBox(height: 12 * scale),

                              Text(
                                'Безопасные поездки начинаются\nс проверки.',
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  height: 1.35,
                                  color: const Color(0xFF657070),
                                ),
                              ),
                            ],
                          ),


                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 17 * scale,
                              vertical: 14 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(
                                17 * scale,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 27 * scale,
                                  color: green,
                                ),

                                SizedBox(width: 13 * scale),

                                Expanded(
                                  child: Text(
                                    'Проверка займёт\nпримерно 5–7 минут',
                                    style: TextStyle(
                                      fontSize: 12 * scale,
                                      height: 1.3,
                                      color: darkText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),


                          SizedBox(
                            width: double.infinity,
                            height: 45 * scale,
                            child: ElevatedButton(
                              onPressed: onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Начать проверку',
                                    style: TextStyle(
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 8 * scale),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 19 * scale,
                                  ),
                                ],
                              ),
                            ),
                          ),


                          Center(
                            child: TextButton(
                              onPressed: () {

                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey,
                              ),
                              child: Text(
                                'О приложении',
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
