import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

import '../providers/azkar_provider.dart';
import '../../data/models/zekr_model.dart';
import 'azkar_widgets/progress_header_widget.dart';
import 'azkar_widgets/page_indicator_widget.dart';
import 'azkar_widgets/completion_message_widget.dart';
import 'azkar_widgets/share_service.dart';
import 'azkar_widgets/azkar_dialogs.dart';
import 'azkar_widgets/azkar_base_mixin.dart';

class AzkarDetailsScreen extends StatefulWidget {
  final String category;
  final String title;

  const AzkarDetailsScreen({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<AzkarDetailsScreen> createState() => _AzkarDetailsScreenState();
}

class _AzkarDetailsScreenState extends State<AzkarDetailsScreen> 
    with SingleTickerProviderStateMixin, AzkarBaseMixin {
  
  late PageController _pageController;
  int _currentPage = 0;
  final GlobalKey _shareWidgetKey = GlobalKey();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingSound = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // ✅ متغيرات الدروب داون
  OverlayEntry? _actionOverlayEntry;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadAudio();
    
    // ✅ تحسين: الانتقال لأول ذكر غير مكتمل بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToFirstIncompleteZekr();
    });
  }

  // ✅ دالة جديدة: الانتقال لأول ذكر غير مكتمل
  void _navigateToFirstIncompleteZekr() {
    final provider = Provider.of<AzkarProvider>(context, listen: false);
    final azkar = _getAzkarList(provider);
    
    if (azkar.isEmpty) return;
    
    final firstIncompleteIndex = getFirstIncompleteZekrIndex(azkar);
    
    if (firstIncompleteIndex != _currentPage) {
      setState(() {
        _currentPage = firstIncompleteIndex;
      });
      
      if (_pageController.hasClients) {
        _pageController.jumpToPage(firstIncompleteIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    _animationController.dispose();
    _removeActionOverlay();
    super.dispose();
  }

  // ✅ دوال الدروب داون
  void _showActionMenu(Zekr zekr, BuildContext context) {
    _removeActionOverlay();

    final theme = Theme.of(context);
    
    _actionOverlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeActionOverlay,
        behavior: HitTestBehavior.translucent,
        child: Container(
          color: theme.shadowColor.withOpacity(0.4),
          child: DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.3,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // مقبض السحب فقط
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.dividerColor!.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    // قائمة الإجراءات المدمجة
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // زر المفضلة
                          _buildActionListItem(
                            icon: zekr.isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                            text: zekr.isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                            onTap: () {
                              _removeActionOverlay();
                              _toggleFavorite(zekr, context);
                            },
                          ),
                          
                          // زر المشاركة كصورة
                          _buildActionListItem(
                            icon: Icons.photo_library_rounded,
                            text: 'مشاركة الذكر كصورة',
                            onTap: () {
                              _removeActionOverlay();
                              _shareZekrAsImage(zekr);
                            },
                          ),
                          
                          // زر المشاركة كنص
                          _buildActionListItem(
                            icon: Icons.share_rounded,
                            text: 'مشاركة الذكر كنص',
                            onTap: () {
                              _removeActionOverlay();
                              ShareService.shareZekrAsText(zekr);
                            },
                          ),
                          
                          // زر النسخ
                          _buildActionListItem(
                            icon: Icons.content_copy_rounded,
                            text: 'نسخ الذكر',
                            onTap: () {
                              _removeActionOverlay();
                              _copyZekrToClipboard(zekr);
                            },
                          ),
                          
                          // زر إعادة التعيين
                          _buildActionListItem(
                            icon: Icons.refresh_rounded,
                            text: 'إعادة تعيين العداد',
                            onTap: () {
                              _removeActionOverlay();
                              _showResetCurrentZekrDialog(zekr);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_actionOverlayEntry!);
  }

  Widget _buildActionListItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor!.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: theme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeActionOverlay() {
    if (_actionOverlayEntry != null) {
      _actionOverlayEntry!.remove();
      _actionOverlayEntry = null;
    }
  }

  void _toggleFavorite(Zekr zekr, BuildContext context) {
    final provider = Provider.of<AzkarProvider>(context, listen: false);
    provider.toggleFavorite(zekr.id);
    
    AzkarDialogs.showSuccessDialog(
      context: context,
      message: zekr.isFavorite ? 'تمت الإزالة من المفضلة' : 'تمت الإضافة إلى المفضلة',
    );
  }

  Future<void> _loadAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('assets/audios/tasbeh.mp3'));
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  Future<void> _playTasbehSound() async {
    if (_isPlayingSound) return;
    
    setState(() {
      _isPlayingSound = true;
    });

    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
      
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _isPlayingSound = false;
        });
      });
    } catch (e) {
      debugPrint('Error playing sound: $e');
      setState(() {
        _isPlayingSound = false;
      });
    }
  }

  List<Zekr> _getAzkarList(AzkarProvider provider) {
    switch (widget.category) {
      case 'morning':
        return provider.morningAzkar;
      case 'evening':
        return provider.eveningAzkar;
      case 'after_prayer':
        return provider.afterPrayerAzkar;
      case 'after_fajr':
      case 'after_dhuhr':
      case 'after_asr':
      case 'after_maghrib':
      case 'after_isha':
      case 'sleep':
      case 'misc':
      case 'general':
      case 'morning_start':
      case 'friday':
        return provider.getAzkarByCategory(widget.category);
      default:
        return [];
    }
  }

  // ✅ إصلاح كامل لدالة التعامل مع الضغط على التسبيح - الإصدار النهائي
  void _handleZekrTap(Zekr currentZekr, List<Zekr> azkar, AzkarProvider provider) async {
    // 1. حفظ الفهرس الحالي قبل أي عملية
    final currentIndexBeforeUpdate = _currentPage;
    
    // 2. تفعيل الأنيميشن عند الضغط
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      _animationController.reverse();
    });

    // 3. تشغيل الصوت
    await _playTasbehSound();

    // 4. زيادة العداد
    await provider.incrementCounter(currentZekr.id);

    // 5. ✅ إصلاح: الحصول على البيانات المحدثة مع الحفاظ على الفهرس
    final updatedAzkar = _getAzkarList(provider);
    
    // 6. ✅ إصلاح: استخدام الفهرس المحفوظ بدلاً من الفهرس الحالي
    final currentZekrAfterUpdate = updatedAzkar[currentIndexBeforeUpdate];
    
    // 7. ✅ إصلاح: التحقق من اكتمال الذكر الحالي (باستخدام الفهرس المحفوظ)
    final isCompleted = isZekrCompleted(currentZekrAfterUpdate);

    // 8. ✅ إصلاح: الانتقال للذكر التالي غير المكتمل إذا اكتمل الحالي
    if (isCompleted) {
      final nextIncompleteIndex = getNextIncompleteZekrIndex(updatedAzkar, currentIndexBeforeUpdate);
      
      if (nextIncompleteIndex != currentIndexBeforeUpdate) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _currentPage = nextIncompleteIndex;
            });
            
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                nextIncompleteIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        });
      }
    }
  }

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary = _shareWidgetKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing PNG: $e');
      return null;
    }
  }

  Future<void> _shareZekrAsImage(Zekr zekr) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final imageBytes = await _capturePng();

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/zekr_${zekr.id}_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: zekr.name,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (file.existsSync()) {
            file.delete();
          }
        });
      } else {
        await ShareService.shareZekrAsText(zekr);
      }
    } catch (e) {
      debugPrint('Error sharing image: $e');
      await ShareService.shareZekrAsText(zekr);
    }
  }

  Future<void> _copyZekrToClipboard(Zekr zekr) async {
    String copyText = """
${zekr.name}

${zekr.content}

${zekr.description.isNotEmpty ? '${zekr.description}\n' : ''}${zekr.time.isNotEmpty ? 'الوقت: ${zekr.time}\n' : ''}${zekr.reward.isNotEmpty ? 'الأجر: ${zekr.reward}\n' : ''}
    """;

    await Clipboard.setData(ClipboardData(text: copyText));
    ShareService.showSuccessSnackBar(context, 'تم نسخ الذكر');
  }

  void _resetAllAzkar(List<Zekr> azkar, AzkarProvider provider) {
    AzkarDialogs.showResetDialog(
      context: context,
      title: 'إعادة تعيين جميع الأذكار',
      content: 'هل تريد إعادة تعيين جميع أذكار هذه الصفحة إلى الصفر؟',
      onConfirm: () {
        for (final zekr in azkar) {
          provider.resetCounter(zekr.id);
        }
        
        // ✅ إصلاح: الانتقال لأول ذكر بعد إعادة التعيين
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToFirstIncompleteZekr();
        });
        
        ShareService.showSuccessSnackBar(context, 'تم إعادة تعيين جميع الأذكار إلى الصفر');
      },
    );
  }

  void _showResetCurrentZekrDialog(Zekr zekr) {
    final provider = Provider.of<AzkarProvider>(context, listen: false);
    
    AzkarDialogs.showResetDialog(
      context: context,
      title: 'إعادة تعيين الذكر',
      content: 'هل تريد إعادة تعيين عداد هذا الذكر إلى الصفر؟',
      onConfirm: () {
        provider.resetCounter(zekr.id);
        ShareService.showSuccessSnackBar(context, 'تم إعادة تعيين العداد إلى الصفر');
      },
    );
  }

  // ✅ تصميم جديد لزر التسبيح الرئيسي مع بصمة كاملة
  Widget _buildTasbeehMainButton({
    required bool isCompleted,
    required int remainingCount,
    required VoidCallback onTap,
    required bool isPlayingSound,
    required Zekr currentZekr,
  }) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final buttonSize = size.width * 0.25;

    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isCompleted
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.tertiary.withOpacity(0.8),
                    theme.colorScheme.tertiary,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor,
                    theme.primaryColorDark ?? theme.primaryColor,
                  ],
                ),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? theme.colorScheme.tertiary : theme.primaryColor).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // تأثير النبض عند التشغيل
            if (isPlayingSound)
              Positioned.fill(
                child: ClipOval(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.onPrimary.withOpacity(0.3),
                    ),
                  ),
                ),
              ),

            Center(
              child: Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                color: theme.colorScheme.onPrimary,
                size: buttonSize * 0.6,
              ),
            ),

            // تأثير الحدود
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.onPrimary.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AzkarProvider>(context);
    final azkar = _getAzkarList(provider);

    if (azkar.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: theme.primaryColor,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        body: _buildShimmerLoading(context),
      );
    }

    final progress = calculateProgress(azkar);
    final completedAzkar = getCompletedAzkarCount(azkar);
    
    // ✅ إصلاح: تأكد من أن الفهرس الحالي صالح
    final currentZekr = azkar.isNotEmpty && _currentPage < azkar.length 
        ? azkar[_currentPage] 
        : azkar.first;
        
    final isCurrentCompleted = isZekrCompleted(currentZekr);
    final isAllCompleted = isAllAzkarCompleted(azkar);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Stack(
                  children: [
                    // خلفية متدرجة
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            theme.primaryColor.withOpacity(0.05),
                            theme.colorScheme.surface.withOpacity(0.1),
                            theme.colorScheme.background,
                          ],
                        ),
                      ),
                    ),

                    Column(
                      children: [
                        // ✅ البار العلوي المدمج مع دائرة التقدم وشريط التقدم
                        _buildEnhancedHeader(context, progress, azkar.length, completedAzkar),
                        
                        // ✅ مؤشر الصفحات (مستقل)
                        PageIndicatorWidget(
                          currentPage: _currentPage,
                          totalPages: azkar.length,
                        ),
                        
                        // محتوى الذكر (يأخذ كامل المساحة المتبقية)
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: azkar.length,
                            onPageChanged: (index) {
                              // ✅ إصلاح: تحديث الفهرس الحالي عند التمرير اليدوي
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final zekr = azkar[index];
                              return _buildZekrContentWithStats(context, zekr);
                            },
                          ),
                        ),
                        
                        // ✅ البطاقة السفلية المضغوطة
                        if (!isAllCompleted) _buildCompactBottomActions(
                          context, currentZekr, azkar, provider, isCurrentCompleted
                        ),
                      ],
                    ),

                    // عنصر المشاركة المخفي
                    Positioned(
                      left: -1000,
                      child: RepaintBoundary(
                        key: _shareWidgetKey,
                        child: _buildShareWidget(context, currentZekr),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ دالة جديدة تضم محتوى الذكر مع بطاقة الإحصائيات
  Widget _buildZekrContentWithStats(BuildContext context, Zekr zekr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // محتوى الذكر الأصلي
          _buildZekrContent(context, zekr),
          
          // ✅ بطاقة إحصائيات التكرارات (غير مثبتة - تتحرك مع التمرير)
          _buildCounterStatsCard(context, zekr),
        ],
      ),
    );
  }

  // ✅ بطاقة إحصائيات التكرارات الجديدة (غير مثبتة)
  Widget _buildCounterStatsCard(BuildContext context, Zekr zekr) {
    final theme = Theme.of(context);
    final isCompleted = isZekrCompleted(zekr);
    final remainingCount = zekr.dailyGoal - zekr.count;

    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor!.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // التكرارات المنجزة
          _buildCounterItem(
            context: context,
            icon: Icons.check_circle_rounded,
            value: zekr.count,
            label: 'المنجز',
            color: isCompleted ? theme.colorScheme.tertiary : theme.primaryColor,
          ),

          // الهدف اليومي
          _buildCounterItem(
            context: context,
            icon: Icons.flag_rounded,
            value: zekr.dailyGoal,
            label: 'الهدف',
            color: theme.colorScheme.secondary,
          ),

          // المتبقي
          _buildCounterItem(
            context: context,
            icon: Icons.timelapse_rounded,
            value: remainingCount > 0 ? remainingCount : 0,
            label: 'المتبقي',
            color: remainingCount > 0 ? theme.colorScheme.error : theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  // ✅ عنصر العداد الفردي
  Widget _buildCounterItem({
    required BuildContext context,
    required IconData icon,
    required int value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildShareWidget(BuildContext context, Zekr zekr) {
    final theme = Theme.of(context);
    
    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            theme.primaryColor.withOpacity(0.8),
                            theme.primaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        zekr.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.dividerColor!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        zekr.content,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (zekr.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          zekr.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.secondary,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Image.asset(
                    'assets/images/logo_app/logo_72.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: theme.colorScheme.onPrimary,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'أذكار و أحاديث',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ البار العلوي المحسن مع دائرة التقدم وشريط التقدم في نفس الصف
  Widget _buildEnhancedHeader(BuildContext context, double progress, int totalAzkar, int completedAzkar) {
    final theme = Theme.of(context);
    
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.primaryColor,
            theme.primaryColorDark ?? theme.primaryColor,
          ],
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // الصف العلوي: عناصر التحكم
            Row(
              children: [
                // زر الرجوع
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 22),
                  onPressed: () => Navigator.pop(context),
                  color: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(maxWidth: 40),
                ),
                
                const SizedBox(width: 12),
                
                // العنوان
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // زر إعادة التعيين
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  onPressed: () {
                    final provider = Provider.of<AzkarProvider>(context, listen: false);
                    final azkar = _getAzkarList(provider);
                    _resetAllAzkar(azkar, provider);
                  },
                  color: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(maxWidth: 40),
                ),
              ],
            ),
            
            // الصف السفلي: دائرة التقدم وشريط التقدم في نفس الصف
            const SizedBox(height: 8),
            Row(
              children: [
                // دائرة التقدم
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // الخلفية الدائرية
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.onPrimary.withOpacity(0.2),
                      ),
                    ),
                    
                    // دائرة التقدم
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                        strokeWidth: 2.5,
                      ),
                    ),
                    
                    // النص في المنتصف
                    Text(
                      '$completedAzkar',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // شريط التقدم والمعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // شريط التقدم
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // نص "مكتمل"
                      Text(
                        'مكتمل: $completedAzkar من $totalAzkar',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onPrimary.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZekrContent(BuildContext context, Zekr zekr) {
    final theme = Theme.of(context);
    final isCompleted = isZekrCompleted(zekr);

    return Column(
      children: [
        // نص الذكر - بدون حدود وخلفية وبعرض كامل
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          child: Text(
            zekr.content,
            style: TextStyle(
              fontSize: 18,
              height: 1.8,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Tajawal',
            ),
            textAlign: TextAlign.center,
          ),
        ),

        if (zekr.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zekr.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.secondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (zekr.time.isNotEmpty || zekr.reward.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (zekr.time.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 12, color: theme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        zekr.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              if (zekr.reward.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.celebration, size: 12, color: theme.colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(
                        'الأجر',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],

        // ✅ استخدام CompletionMessageWidget عند الإكمال
        if (isCompleted) ...[
          const SizedBox(height: 16),
          CompletionMessageWidget(
            title: '🎉 مبروك!',
            message: 'لقد أكملت هذا الذكر',
            totalCount: zekr.count,
            onReset: () => _showResetCurrentZekrDialog(zekr),
          ),
        ],
      ],
    );
  }

  // ✅ البطاقة السفلية المضغوطة - مُحسّنة
  Widget _buildCompactBottomActions(
    BuildContext context, 
    Zekr currentZekr, 
    List<Zekr> azkar, 
    AzkarProvider provider,
    bool isCurrentCompleted
  ) {
    final theme = Theme.of(context);
    final remainingCount = currentZekr.dailyGoal - currentZekr.count;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر إعادة التعيين - تصميم مضغوط بدون خلفية
          _buildTransparentActionButton(
            context: context,
            icon: Icons.refresh_rounded,
            onTap: () => _showResetCurrentZekrDialog(currentZekr),
            iconColor: theme.colorScheme.onSurface.withOpacity(0.7),
          ),

          // ✅ زر التسبيح الرئيسي مع بصمة كاملة
          _buildTasbeehMainButton(
            isCompleted: isCurrentCompleted,
            remainingCount: remainingCount,
            onTap: () => _handleZekrTap(currentZekr, azkar, provider),
            isPlayingSound: _isPlayingSound,
            currentZekr: currentZekr,
          ),

          // زر القائمة - تصميم مضغوط بدون خلفية
          _buildTransparentActionButton(
            context: context,
            icon: Icons.more_horiz_rounded,
            onTap: () => _showActionMenu(currentZekr, context),
            iconColor: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  // ✅ تصميم مضغوط للأزرار المساعدة بدون خلفية
  Widget _buildTransparentActionButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: theme.colorScheme.surfaceVariant,
          highlightColor: theme.colorScheme.onSurface.withOpacity(0.1),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Shimmer.fromColors(
          baseColor: theme.colorScheme.surfaceVariant,
          highlightColor: theme.colorScheme.onSurface.withOpacity(0.1),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
