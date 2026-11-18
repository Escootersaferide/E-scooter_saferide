
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TipsPage extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const TipsPage({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  static const Color green = Color(0xFF16A991);
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
                        horizontal: horizontalPadding,
                        vertical: 12 * scale,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [


                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: onBack,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                size: 21 * scale,
                                color: darkText,
                              ),
                            ),
                          ),


                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              SizedBox(
                                width: 150 * scale,
                                height: 150 * scale,
                                child: SvgPicture.asset(
                                  'assets/svg/lamp.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              SizedBox(height: 20 * scale),


                              Text(
                                'Советы для вас',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),

                              SizedBox(height: 22 * scale),


                              Text(
                                'Рекомендуем сделать\n'
                                'небольшой перерыв, если\n'
                                'вы чувствуете усталость.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  height: 1.45,
                                  color: greyText,
                                ),
                              ),

                              SizedBox(height: 20 * scale),


                              Text(
                                'Помните: хорошее\n'
                                'самочувствие — залог\n'
                                'безопасной поездки!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  height: 1.45,
                                  color: greyText,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 100 * scale),


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
                                'Понятно',
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
