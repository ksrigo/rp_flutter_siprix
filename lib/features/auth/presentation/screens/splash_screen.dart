import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 SplashScreen: initState called');
    _initializeAnimations();
    _initializeApp();
  }

  /// Preload the splash image to prevent flicker
  Future<void> _preloadImage() async {
    try {
      await precacheImage(const AssetImage('assets/images/ringplus_cloud.webp'), context);
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
      debugPrint('✅ SplashScreen: Image preloaded successfully');
    } catch (e) {
      debugPrint('❌ SplashScreen: Error preloading image: $e');
      // Set image as loaded anyway to show fallback
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    ));

    // Start animation immediately - don't wait for image preloading
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload image here where MediaQuery context is available
    if (!_imageLoaded) {
      _preloadImage();
    }
  }

  Future<void> _initializeApp() async {
    debugPrint('🔄 SplashScreen: _initializeApp started');
    
    try {
      // Ensure minimum splash duration - adjusted for smooth transition from Android splash
      final minimumDurationFuture = Future.delayed(const Duration(milliseconds: 2000));
      
      // Start initialization but don't wait for it initially
      final initializationFuture = _performInitialization();
      
      // Always wait for minimum duration first
      debugPrint('🕒 SplashScreen: Starting 2-second minimum display...');
      await minimumDurationFuture;
      debugPrint('✅ SplashScreen: 2-second minimum display completed');
      
      // Then ensure initialization is complete
      debugPrint('🔧 SplashScreen: Ensuring initialization is complete...');
      final targetRoute = await initializationFuture;
      debugPrint('✅ SplashScreen: All initialization completed');
      
      // Navigate to the determined route
      if (targetRoute != null) {
        _navigateToRoute(targetRoute);
      }
      
    } catch (e) {
      debugPrint('❌ SplashScreen: Error during app initialization: $e');
      debugPrint('❌ SplashScreen: Error stack trace: ${e.toString()}');
      
      // Wait minimum duration even on error
      await Future.delayed(const Duration(milliseconds: 1500));
      
      debugPrint('🔐 SplashScreen: Error occurred, navigating to login as fallback');
      _navigateToRoute('/login');
    }
    
    debugPrint('🏁 SplashScreen: _initializeApp finished');
  }

  Future<String?> _performInitialization() async {
    debugPrint('🔧 SplashScreen: Initializing AuthService...');
    
    // Initialize AuthService first
    await AuthService.instance.initialize();
    debugPrint('✅ SplashScreen: AuthService initialization completed');
    
    debugPrint('🔍 SplashScreen: Checking authentication state...');
    
    // Use AuthService to check if user is authenticated and get valid token
    // This will trigger token refresh if needed
    final validToken = await AuthService.instance.getValidAccessToken();
    debugPrint('🎟️ SplashScreen: getValidAccessToken result: ${validToken != null ? "token present" : "no token"}');
    
    // Return the route to navigate to
    return validToken != null ? '/keypad' : '/login';
  }
  
  void _navigateToRoute(String route) {
    debugPrint('📱 SplashScreen: Checking if widget is mounted: $mounted');
    if (mounted) {
      if (route == '/keypad') {
        debugPrint('🎯 SplashScreen: User has valid token, navigating to keypad');
        // ignore: use_build_context_synchronously
        context.go('/keypad');
        debugPrint('✅ SplashScreen: Navigation to keypad completed');
      } else {
        debugPrint('🔐 SplashScreen: No valid token, navigating to login');
        // ignore: use_build_context_synchronously
        context.go('/login');
        debugPrint('✅ SplashScreen: Navigation to login completed');
      }
    } else {
      debugPrint('❌ SplashScreen: Widget not mounted, skipping navigation');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get responsive image size based on screen dimensions
  double _getImageSize(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final baseSize = isTablet ? 200.0 : 140.0;
    
    // Scale based on screen width but cap the maximum size
    final scaleFactor = (screenSize.width / (isTablet ? 800 : 400)).clamp(0.8, 1.5);
    return baseSize * scaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.surface;
    final imageSize = _getImageSize(context);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ringplus Cloud Logo
                    Container(
                      width: imageSize,
                      height: imageSize,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(imageSize * 0.15),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/ringplus_cloud.webp',
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ SplashScreen: Error loading image: $error');
                          return _buildFallbackIcon(imageSize, theme);
                        },
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading Indicator
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Loading text
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Fallback icon widget when image fails to load
  Widget _buildFallbackIcon(double size, ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Icon(
        Icons.cloud_queue_rounded,
        size: size * 0.5,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

// Alternative splash screen with gradient background
class GradientSplashScreen extends ConsumerStatefulWidget {
  const GradientSplashScreen({super.key});

  @override
  ConsumerState<GradientSplashScreen> createState() =>
      _GradientSplashScreenState();
}

class _GradientSplashScreenState extends ConsumerState<GradientSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  /// Preload the splash image to prevent flicker
  Future<void> _preloadImage() async {
    try {
      await precacheImage(const AssetImage('assets/images/ringplus_cloud.webp'), context);
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('❌ GradientSplashScreen: Error preloading image: $e');
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    ));

    // Start animation immediately
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload image here where MediaQuery context is available
    if (!_imageLoaded) {
      _preloadImage();
    }
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 3));

    debugPrint('GradientSplash: Initializing AuthService...');
    
    // Initialize AuthService first
    await AuthService.instance.initialize();
    
    debugPrint('GradientSplash: Checking authentication state...');
    
    // Use AuthService to check if user is authenticated and get valid token
    // This will trigger token refresh if needed
    final validToken = await AuthService.instance.getValidAccessToken();

    if (mounted) {
      if (validToken != null) {
        debugPrint('GradientSplash: User has valid token, navigating to keypad');
        // User is authenticated, navigate to main app
        // ignore: use_build_context_synchronously
        context.go('/keypad');
      } else {
        debugPrint('GradientSplash: No valid token, navigating to login');
        // User is not authenticated, navigate to login screen
        // ignore: use_build_context_synchronously
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get responsive image size based on screen dimensions
  double _getImageSize(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final baseSize = isTablet ? 180.0 : 140.0;
    
    final scaleFactor = (screenSize.width / (isTablet ? 800 : 400)).clamp(0.8, 1.4);
    return baseSize * scaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _getImageSize(context);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6B46C1),
              Color(0xFF8B5CF6),
              Color(0xFF9333EA),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    ScaleTransition(
                      scale: _logoAnimation,
                      child: FadeTransition(
                        opacity: _logoAnimation,
                        child: Container(
                          width: imageSize,
                          height: imageSize,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(imageSize * 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(imageSize * 0.1),
                            child: Image.asset(
                              'assets/images/ringplus_cloud.webp',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.cloud_queue_rounded,
                                  size: imageSize * 0.5,
                                  color: const Color(0xFF6B46C1),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Animated Text
                    FadeTransition(
                      opacity: _textAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(_textAnimation),
                        child: Column(
                          children: [
                            const Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppConstants.appDescription,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w300,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'v${AppConstants.appVersion}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 80),

                    // Loading Indicator
                    FadeTransition(
                      opacity: _textAnimation,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
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
  }
}