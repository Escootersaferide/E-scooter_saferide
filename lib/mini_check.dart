
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MiniCheckPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const MiniCheckPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  static const Color green = Color(0xFF16A991);
  static const Color lightGreen = Color(0xFFE5F6F2);
  static const Color darkText = Color(0xFF172B2B);
  static const Color greyText = Color(0xFF657070);

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


            final pageHeight = screenHeight > 600 * scale
                ? screenHeight
                : 600 * scale;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: pageHeight,
                ),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 12 * scale,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [


                            Column(
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: onBack,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        Icons.arrow_back_ios_new,
                                        size: 21 * scale,
                                        color: darkText,
                                      ),
                                    ),

                                    const Spacer(),

                                    Text(
                                      '1 из 20',
                                      style: TextStyle(
                                        fontSize: 12 * scale,
                                        color: darkText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12 * scale),


                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: 1 / 20,
                                    minHeight: 5 * scale,
                                    backgroundColor: lightGreen,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      green,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 48 * scale),


                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [

                                Container(
                                  width: 112 * scale,
                                  height: 112 * scale,
                                  child: SvgPicture.asset(
                                    'assets/svg/mini_check.svg',
                                    fit: BoxFit.contain,
                                  ),
                                ),

                                SizedBox(height: 48 * scale),


                                Text(
                                  'Мини-проверка',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: darkText,
                                  ),
                                ),

                                SizedBox(height: 14 * scale),


                                Text(
                                  'Ответьте на 20 вопросов,\n'
                                  'чтобы подтвердить свои\n'
                                  'знания.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14 * scale,
                                    height: 1.4,
                                    color: greyText,
                                  ),
                                ),

                                SizedBox(height: 45 * scale),


                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 22 * scale,
                                      color: greyText,
                                    ),

                                    SizedBox(width: 13 * scale),

                                    Text(
                                      'Примерное время:\n3–5 минут',
                                      style: TextStyle(
                                        fontSize: 13 * scale,
                                        height: 1.4,
                                        color: greyText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 180 * scale),


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
                                child: Text(
                                  'Начать',
                                  style: TextStyle(
                                    fontSize: 14 * scale,
                                    fontWeight: FontWeight.w500,
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
              ),
            );
          },
        ),
      ),
    );
  }
}
