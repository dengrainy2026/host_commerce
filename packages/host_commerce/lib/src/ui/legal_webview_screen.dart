import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

const Color _canvasColor = Color(0xFFFAF9F7);
const Color _primaryText = Color(0xFF111111);

final class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({
    required this.title,
    required this.url,
    required this.systemUiStyle,
    super.key,
  });

  final String title;
  final String url;
  final SystemUiOverlayStyle systemUiStyle;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(_canvasColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
        ),
      );
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.systemUiStyle,
      child: Scaffold(
        backgroundColor: _canvasColor,
        appBar: AppBar(
          backgroundColor: _canvasColor,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: _primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: WebViewWidget(controller: _controller)),
              if (_loadingProgress < 100)
                Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: _primaryText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
