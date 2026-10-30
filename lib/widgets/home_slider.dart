import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../screens/product_list_screen.dart';
import 'common.dart';

/// Auto-playing banner carousel at the top of the start page. The four banners
/// are the website's own banner images (see AppConfig.slides).
class HomeSlider extends StatefulWidget {
  const HomeSlider({super.key, this.slides = AppConfig.slides});
  final List<HomeSlide> slides;

  @override
  State<HomeSlider> createState() => _HomeSliderState();
}

class _HomeSliderState extends State<HomeSlider> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.slides.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open(HomeSlide slide) {
    openProductList(
      context,
      title: slide.title,
      category: slide.categoryId == null ? null : '${slide.categoryId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 690 / 417,
              child: Listener(
                onPointerDown: (_) => _timer?.cancel(),
                onPointerUp: (_) => _restartTimer(),
                onPointerCancel: (_) => _restartTimer(),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final s = slides[i];
                    return GestureDetector(
                      onTap: () => _open(s),
                      child: Semantics(
                        button: true,
                        label: s.title,
                        child: _SlideImage(slide: s),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              slides.length,
              (i) => GestureDetector(
                onTap: () => _controller.animateToPage(i, duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? ArkaColors.ink : const Color(0x401C1B19),
                    borderRadius: BorderRadius.circular(4),
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

class _SlideImage extends StatelessWidget {
  const _SlideImage({required this.slide});
  final HomeSlide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetImage(slide.image, alignment: slide.alignment),
      ],
    );
  }
}
