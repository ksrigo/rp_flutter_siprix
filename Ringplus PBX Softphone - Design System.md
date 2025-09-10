# Ringplus PBX Softphone - Design System

## Overview
This design system defines the visual language, components, and patterns for the Ringplus PBX softphone mobile application. The design emphasizes professionalism, clarity, and ease of use while maintaining a modern, accessible interface.

## Design Principles

### 1. Professional Clarity
- Clean, uncluttered interfaces that prioritize essential functions
- Clear visual hierarchy with proper spacing and typography
- Professional color palette suitable for business environments

### 2. Accessibility First
- WCAG AA compliance with proper contrast ratios
- Large touch targets (minimum 44px)
- Screen reader compatibility
- Support for dynamic text sizing

### 3. Cross-Platform Consistency
- Platform-appropriate navigation patterns (iOS large titles, Android app bars)
- Consistent core functionality across platforms
- Adaptive layouts for different screen sizes

### 4. Intuitive Interaction
- Familiar patterns from native phone apps
- Clear visual feedback for all interactions
- Logical information architecture

## Color Palette

### Primary Colors
- **Primary Purple**: `#6B46C1` - Main brand color, primary actions
- **Primary Purple Light**: `#8B5CF6` - Hover states, secondary elements
- **Primary Purple Dark**: `#553C9A` - Active states, emphasis

### Secondary Colors
- **Secondary Purple**: `#9333EA` - Accent elements, highlights
- **Accent Purple**: `#DDD6FE` - Light backgrounds, subtle highlights

### Neutral Colors
- **Background Light**: `#FAFAFA` - Main background
- **Background Dark**: `#121212` - Dark mode background
- **Surface Light**: `#FFFFFF` - Cards, elevated surfaces
- **Surface Dark**: `#1E1E1E` - Dark mode surfaces

### Semantic Colors
- **Success**: `#059669` - Call connected, positive actions
- **Error**: `#DC2626` - Call failed, destructive actions
- **Warning**: `#D97706` - Alerts, caution states
- **Info**: `#2563EB` - Information, neutral states

### Text Colors
- **Text Primary Light**: `#1F2937` - Main text in light mode
- **Text Secondary Light**: `#6B7280` - Secondary text in light mode
- **Text Primary Dark**: `#E5E7EB` - Main text in dark mode
- **Text Secondary Dark**: `#9CA3AF` - Secondary text in dark mode

## Typography

### Font Families
- **Android**: Roboto (Regular, Medium, Bold)
- **iOS**: SF Pro Display (Regular, Medium, Bold)

### Type Scale
- **Display Large**: 32px, Bold - App titles, welcome screens
- **Display Medium**: 28px, Bold - Large section headers
- **Headline Large**: 24px, Bold - Screen titles
- **Headline Medium**: 20px, SemiBold - Card titles, important labels
- **Title Large**: 18px, Medium - List item titles
- **Title Medium**: 16px, Medium - Button text, form labels
- **Body Large**: 16px, Regular - Main body text
- **Body Medium**: 14px, Regular - Secondary text
- **Body Small**: 12px, Regular - Captions, metadata
- **Label Large**: 14px, Medium - Form field labels
- **Label Medium**: 12px, Medium - Small labels, badges

## Iconography

### Icon Style
- **Style**: Material Design Icons with custom VoIP-specific icons
- **Size**: 24px standard, 20px small, 32px large
- **Weight**: Regular (400) for most icons, Bold (600) for active states
- **Color**: Follows text color hierarchy

### Key Icons
- **Phone**: `phone` - Primary calling action
- **Phone In Talk**: `phone_in_talk` - Active call state
- **Call End**: `call_end` - Hang up action
- **Dialpad**: `dialpad` - Keypad access
- **Contacts**: `contacts` - Contact management
- **Access Time**: `access_time` - Call history
- **Voicemail**: `voicemail` - Voicemail access
- **Settings**: `settings` - Configuration
- **Mic/Mic Off**: `mic`/`mic_off` - Mute toggle
- **Volume Up/Down**: `volume_up`/`volume_down` - Speaker toggle

## Layout & Spacing

### Grid System
- **Base Unit**: 8px
- **Margins**: 16px (2 units) for mobile, 24px (3 units) for tablets
- **Gutters**: 16px between components
- **Safe Areas**: Respect platform safe areas (notches, home indicators)

### Spacing Scale
- **XS**: 4px - Tight spacing within components
- **SM**: 8px - Close related elements
- **MD**: 16px - Standard component spacing
- **LG**: 24px - Section spacing
- **XL**: 32px - Major section breaks
- **XXL**: 48px - Screen-level spacing

### Component Sizing
- **Touch Targets**: Minimum 44px x 44px
- **Buttons**: Height 48px (standard), 56px (prominent)
- **List Items**: Height 56px (single line), 72px (two lines)
- **App Bar**: Height 56px (Android), Variable (iOS with large titles)
- **Bottom Navigation**: Height 80px
- **Keypad Buttons**: 72px x 72px

## Component Specifications

### Buttons

#### Primary Button
- **Background**: Primary Purple (`#6B46C1`)
- **Text**: White
- **Border Radius**: 8px
- **Height**: 48px (standard), 56px (prominent)
- **Padding**: 24px horizontal, 12px vertical
- **Typography**: Title Medium (16px, Medium)

#### Secondary Button
- **Background**: Transparent
- **Text**: Primary Purple
- **Border**: 1px solid Primary Purple
- **Border Radius**: 8px
- **Height**: 48px
- **Padding**: 24px horizontal, 12px vertical

#### Text Button
- **Background**: Transparent
- **Text**: Primary Purple
- **Border**: None
- **Padding**: 16px horizontal, 8px vertical

### Cards
- **Background**: Surface color
- **Border Radius**: 12px
- **Elevation**: 2dp (Android), subtle shadow (iOS)
- **Padding**: 16px
- **Margin**: 16px horizontal, 8px vertical

### Input Fields
- **Background**: Background color (filled style)
- **Border**: 1px solid outline color
- **Border Radius**: 8px
- **Height**: 48px
- **Padding**: 16px horizontal, 12px vertical
- **Focus State**: 2px border in Primary Purple

### Bottom Navigation
- **Background**: Surface color
- **Height**: 80px
- **Elevation**: 8dp
- **Icon Size**: 24px
- **Label Typography**: Body Small (12px)
- **Active Color**: Primary Purple
- **Inactive Color**: Text Secondary

## Screen Layouts

### Keypad Screen
- Large dialpad with 72px buttons
- Number display at top
- Call button prominently placed
- Quick access to contacts and recents

### Call Screens
- Full-screen layouts with dark backgrounds
- Large contact avatars (140px)
- Clear call status indicators
- Accessible control buttons (64px minimum)

### List Screens (Recents, Contacts, Voicemail)
- Standard list items with 56px height
- Clear visual hierarchy
- Swipe actions for quick operations
- Search functionality at top

### Settings Screens
- Grouped list items
- Clear section headers
- Toggle switches for boolean options
- Navigation to sub-screens

## Accessibility Guidelines

### Color Contrast
- **Normal Text**: Minimum 4.5:1 contrast ratio
- **Large Text**: Minimum 3:1 contrast ratio
- **UI Components**: Minimum 3:1 contrast ratio

### Touch Targets
- **Minimum Size**: 44px x 44px
- **Recommended Size**: 48px x 48px for primary actions
- **Spacing**: Minimum 8px between adjacent targets

### Screen Reader Support
- Meaningful labels for all interactive elements
- Proper heading hierarchy
- State announcements for dynamic content
- Alternative text for images

### Motion & Animation
- **Respect Reduced Motion**: Disable animations when requested
- **Duration**: 200ms (short), 300ms (medium), 500ms (long)
- **Easing**: Material Design standard curves

## Platform Adaptations

### iOS Specific
- Large title navigation bars
- Cupertino-style tab bars
- iOS-specific icons and patterns
- Respect iOS safe areas

### Android Specific
- Material Design 3 components
- Standard app bars
- Material icons
- Android-specific navigation patterns

## Dark Mode Support

### Color Adaptations
- Surfaces use dark variants
- Text colors invert appropriately
- Primary colors maintain accessibility
- Reduced elevation shadows

### Implementation
- Automatic system theme detection
- Manual theme override option
- Consistent theming across all screens

## Internationalization

### Text Handling
- Support for RTL languages
- Flexible layouts for text expansion
- Proper text direction handling
- Cultural color considerations

### Layout Adaptations
- Mirror layouts for RTL languages
- Flexible component sizing
- Icon direction adjustments
- Proper text alignment

This design system provides the foundation for creating a cohesive, professional, and accessible mobile PBX application that meets the needs of business users while maintaining modern design standards.

