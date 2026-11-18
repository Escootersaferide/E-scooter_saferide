
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FeelingPage extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onNext;

  const FeelingPage({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<FeelingPage> createState() => _FeelingPageState();
}

class _FeelingPageState extends State<FeelingPage> {
  static const Color green = Color(0xFF16A991);
  static const Color lightGreen = Color(0xFFE5F6F2);
  static const Color darkText = Color(0xFF172B2B);
  static const Color greyText = Color(0xFF657070);


  String selectedFeeling = 'Отлично';


  final List<Map<String, dynamic>> feelings = [
    {
      'title': 'Отлично',
      'icon': Icons.sentiment_satisfied_rounded,
      'color': Color(0xFF32B69B),
    },
    {
      'title': 'Нормально',
      'icon': Icons.sentiment_neutral_rounded,
      'color': Color(0xFFF2B45F),
    },
    {
      'title': 'Устал(а)',
      'icon': Icons.sentiment_dissatisfied_rounded,
      'color': Color(0xFFF2B45F),
    },
  ];

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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [


                          IconButton(
                            onPressed: widget.onBack,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              size: 21 * scale,
                              color: darkText,
                            ),
                          ),


                          Column(
                            children: [

                              SizedBox(
                                width: 190 * scale,
                                height: 145 * scale,
                                child: SvgPicture.asset(
                                  'assets/svg/feeling.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              SizedBox(height: 12 * scale),


                              Text(
                                'Как вы себя\nчувствуете?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  height: 1.15,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),

                              SizedBox(height: 12 * scale),


                              Text(
                                'Отметьте, насколько вы\n'
                                'сейчас готовы к поездке.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  height: 1.4,
                                  color: greyText,
                                ),
                              ),

                              SizedBox(height: 100 * scale),


                              ...feelings.map((feeling) {
                                final title = feeling['title'] as String;
                                final icon = feeling['icon'] as IconData;
                                final color = feeling['color'] as Color;

                                final isSelected =
                                    selectedFeeling == title;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 7 * scale,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      30 * scale,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        selectedFeeling = title;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: double.infinity,
                                      height: 45 * scale,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16 * scale,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? lightGreen
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          30 * scale,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? lightGreen
                                              : const Color(0xFFE3EBE9),
                                          width: 1.3,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            icon,
                                            color: color,
                                            size: 25 * scale,
                                          ),

                                          Expanded(
                                            child: Text(
                                              title,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14 * scale,
                                                color: darkText,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),


                                          SizedBox(width: 25 * scale),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),

                          SizedBox(height: 50 * scale),


                          SizedBox(
                            width: double.infinity,
                            height: 45 * scale,
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onNext(selectedFeeling);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Далее',
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
