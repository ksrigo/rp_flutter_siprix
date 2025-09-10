import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse(AppConstants.privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToLogin() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App Logo and Branding
                            _buildHeader(),
                            
                            const SizedBox(height: 48),
                            
                            // Welcome Content
                            _buildWelcomeContent(),
                            
                            const SizedBox(height: 64),
                            
                            // Action Buttons
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                      
                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.phone_in_talk,
            size: 50,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // App Name
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // App Description
        Text(
          AppConstants.appDescription,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWelcomeContent() {
    return Column(
      children: [
        Text(
          'Welcome to Professional VoIP Calling',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Connect to your cloud PBX system and enjoy crystal-clear voice calls, advanced call management, and seamless communication.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // Feature Highlights
        _buildFeatureHighlights(),
      ],
    );
  }

  Widget _buildFeatureHighlights() {
    final features = [
      {
        'icon': Icons.phone_enabled,
        'title': 'HD Voice Calls',
        'description': 'Crystal-clear audio quality',
      },
      {
        'icon': Icons.contacts,
        'title': 'Contact Management',
        'description': 'Organize and manage contacts',
      },
      {
        'icon': Icons.voicemail,
        'title': 'Voicemail',
        'description': 'Never miss important messages',
      },
      {
        'icon': Icons.call_merge,
        'title': 'Call Transfer',
        'description': 'Advanced call management',
      },
    ];

    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                feature['icon'] as IconData,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    feature['description'] as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary Action Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Enter Details Manually',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Secondary Action Button (for future QR code scanning)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement QR code scanning
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR code scanning coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text(
              'Scan QR Code',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 24),
        
        // Privacy Policy Link
        TextButton(
          onPressed: _launchPrivacyPolicy,
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Version Info
        Text(
          'Version ${AppConstants.appVersion}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// Alternative welcome screen with carousel
class CarouselWelcomeScreen extends StatefulWidget {
  const CarouselWelcomeScreen({super.key});

  @override
  State<CarouselWelcomeScreen> createState() => _CarouselWelcomeScreenState();
}

class _CarouselWelcomeScreenState extends State<CarouselWelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WelcomePageData> _pages = [
    WelcomePageData(
      icon: Icons.phone_in_talk,
      title: 'Professional VoIP Calling',
      description: 'Connect to your cloud PBX system for crystal-clear voice communication.',
    ),
    WelcomePageData(
      icon: Icons.contacts,
      title: 'Smart Contact Management',
      description: 'Organize contacts, manage favorites, and quick-dial your frequent contacts.',
    ),
    WelcomePageData(
      icon: Icons.call_merge,
      title: 'Advanced Call Features',
      description: 'Transfer calls, hold conversations, and manage multiple calls with ease.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Skip'),
                ),
              ),
            ),
            
            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            
            // Page Indicator
            _buildPageIndicator(),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _currentPage == _pages.length - 1
                  ? _buildFinalPageButtons()
                  : _buildNavigationButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(WelcomePageData page) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            page.icon,
            size: 120,
            color: Theme.of(context).primaryColor,
          ),
          
          const SizedBox(height: 48),
          
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Theme.of(context).primaryColor
                : Theme.of(context).primaryColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _currentPage > 0
              ? () {
                  _pageController.previousPage(
                    duration: AppConstants.mediumAnimation,
                    curve: Curves.easeInOut,
                  );
                }
              : null,
          child: const Text('Previous'),
        ),
        
        ElevatedButton(
          onPressed: () {
            _pageController.nextPage(
              duration: AppConstants.mediumAnimation,
              curve: Curves.easeInOut,
            );
          },
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildFinalPageButtons() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => context.go('/login'),
        child: const Text(
          'Get Started',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class WelcomePageData {
  final IconData icon;
  final String title;
  final String description;

  WelcomePageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

