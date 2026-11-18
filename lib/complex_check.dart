
import 'package:flutter/material.dart';

class ComprehensiveCheckPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ComprehensiveCheckPage({
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

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (contentWidth * 0.06)
                            .clamp(16.0, 28.0),
                        vertical: 12 * scale,
                      ),
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
                                    '1 из 10',
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
                                  value: 0.1,
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
                                decoration: const BoxDecoration(
                                  color: lightGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.school_rounded,
                                  size: 65 * scale,
                                  color: const Color(0xFF168D7B),
                                ),
                              ),

                              SizedBox(height: 48 * scale),


                              Text(
                                'Комплексная проверка',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),

                              SizedBox(height: 14 * scale),


                              Text(
                                'Проверьте знания ПДД\n'
                                'и оцените свою готовность\n'
                                'к поездке.',
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
                                    'Примерное время:\n5–7 минут',
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
            );
          },
        ),
      ),
    );
  }
}
