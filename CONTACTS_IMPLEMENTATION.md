# Contacts Management Implementation

This document describes the complete contacts management system implemented for the Flutter softphone app.

## Overview

The contacts system supports both API phonebook and device contacts with local caching using SQLite database. Contacts can be searched, filtered, and managed through a clean UI that matches the app's design system.

## Architecture

### Data Layer

#### Models
- **ContactModel**: Main contact entity with SQLite serialization
  - Supports both API and device contact sources
  - Includes phone numbers, emails, and metadata
  - Auto-generates initials for avatars
  - Handles favorite status

#### Repository
- **ContactsRepository**: Core data management
  - Fetches contacts from API endpoint
  - Syncs with device contacts using flutter_contacts
  - Caches all contacts in SQLite database
  - Handles real-time updates and manual refresh

### Service Layer

#### ContactsService
- **ContactsService**: Business logic wrapper
  - Initializes the repository
  - Provides streams for UI consumption
  - Handles enabling/disabling device contacts
  - Centralized error handling

### Presentation Layer

#### Screens
- **ContactsPage**: Main contacts interface
  - All/Favorites tabs with custom toggle design
  - Search functionality
  - Alphabetical grouping with quick index
  - Pull-to-refresh support
  - Contact source indicators (API vs Device)

#### Widgets
- **DeviceContactsSetting**: Settings toggle component
  - Integrates with main settings screen
  - Real-time status updates
  - Error handling and user feedback

## Features

### Contact Sources

#### API Phonebook (Primary)
- **Endpoint**: `GET /extension/{extension_id}/contacts`
- **Features**:
  - Server-side contact management
  - Synchronization across devices
  - API icon indicator in UI
  - Favorite status support
  - Graceful handling of non-200 responses (ignored)

#### Device Contacts (Optional)
- **Source**: Device contact database via flutter_contacts
- **Features**:
  - Read-only access to device contacts
  - Only contacts with phone numbers included
  - Device icon indicator in UI
  - Can be enabled/disabled in Settings

### UI Features

#### Contact List
- **Layout**: Alphabetical sections with quick index
- **Display**: Avatar, name, phone label, source indicator
- **Actions**: Call button, favorite toggle
- **Navigation**: Smooth scrolling to alphabetical sections

#### Search & Filter
- **Search**: Real-time search across name fields
- **Tabs**: All contacts / Favorites only
- **Performance**: Efficient Isar queries with streaming

#### Settings Integration
- **Location**: Main Settings screen
- **Control**: Toggle device contacts on/off
- **Feedback**: Status indicators and error messages

## Technical Implementation

### Database Schema (SQLite)

```sql
CREATE TABLE contacts(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id TEXT NOT NULL,
  name TEXT NOT NULL,
  display_name TEXT,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  source TEXT NOT NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  phones TEXT,          -- JSON array of phone objects
  emails TEXT,          -- JSON array of email objects
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
-- Indexes for performance
CREATE INDEX idx_contact_id ON contacts(contact_id);
CREATE INDEX idx_name ON contacts(name);
CREATE INDEX idx_source ON contacts(source);
CREATE INDEX idx_is_favorite ON contacts(is_favorite);
```

### API Integration

#### Get Contacts
```http
GET /extension/{extension_id}/contacts
Authorization: Bearer {jwt_token}
```

**Response Handling:**
- Only HTTP 200 responses are processed
- Non-200 responses are ignored gracefully
- Supports both `{"contacts": [...]}` and direct array `[...]` formats

#### Add Contact (Placeholder)
```http
POST /extension/{extension_id}/contacts
Content-Type: application/json

{
  "name": "John Doe",
  "phones": [{"number": "+1234567890", "label": "Mobile"}],
  "emails": [{"address": "john@example.com", "label": "Work"}]
}
```

### Device Contacts Integration

```dart
// Permission handling
final permission = await Permission.contacts.request();

// Fetch contacts with phone numbers
final contacts = await FlutterContacts.getContacts(
  withProperties: true,
  withPhoto: false,
);
```

### State Management

#### Streams for Real-time Updates
```dart
// All contacts
Stream<List<ContactModel>> getAllContacts()

// Search functionality  
Stream<List<ContactModel>> searchContacts(String query)

// Favorites only
Stream<List<ContactModel>> getFavoriteContacts()
```

## Installation & Setup

### Dependencies Added

```yaml
dependencies:
  sqflite: ^2.3.0           # Already present
  flutter_contacts: ^1.1.7+1  # Already present
  path: ^1.8.3              # Already present
```

### Database Initialization
The SQLite database is automatically created and initialized when the ContactsRepository starts.

### Service Initialization
The ContactsService is automatically initialized in `main.dart` during app startup.

## Usage

### Enable Device Contacts
1. Navigate to Settings
2. Toggle "Device Contacts" switch
3. Grant contacts permission when prompted

### Using Contacts
1. **Search**: Type in search bar for real-time filtering
2. **Favorites**: Use star icon to mark/unmark favorites
3. **Call**: Tap call button to initiate call
4. **Refresh**: Pull down to refresh all contacts

### Adding API Contacts
Currently shows placeholder message. Implementation requires:
1. Contact form UI
2. API endpoint integration
3. Validation and error handling

## File Structure

```
lib/
├── core/
│   └── services/
│       └── contacts_service.dart          # Main service
├── features/
│   └── contacts/
│       ├── data/
│       │   ├── models/
│       │   │   └── contact_model.dart     # Data models
│       │   └── repositories/
│       │       └── contacts_repository.dart # Data access
│       └── presentation/
│           ├── screens/
│           │   └── contacts_page.dart     # Main UI
│           └── widgets/
│               └── device_contacts_setting.dart # Settings widget
```

## Performance Considerations

### Optimizations Implemented
- **SQLite Database**: Fast local storage with efficient queries and indexes
- **Streaming UI**: Real-time updates without manual refreshes
- **Batch Operations**: Efficient bulk inserts for contact syncing
- **Efficient Search**: Indexed fields for fast searching

### Memory Management
- **JSON Serialization**: Efficient storage of nested phone/email data
- **Cache Strategy**: Local-first with background sync
- **Image Handling**: Generated avatars instead of contact photos

## Security & Privacy

### Permissions
- **Contacts**: Only requested when device contacts enabled
- **API Access**: Authenticated via JWT tokens
- **Local Storage**: SQLite database with proper access controls

### Data Handling
- **Source Isolation**: API and device contacts clearly distinguished
- **User Control**: Device contacts can be disabled completely
- **Privacy**: No unnecessary data collection or transmission

## Future Enhancements

### Planned Features
1. **Real-time Device Sync**: Live updates from device contacts
2. **Contact Creation**: Full CRUD operations for API contacts
3. **Import/Export**: Backup and restore functionality
4. **Advanced Search**: Search by phone numbers and companies
5. **Contact Groups**: Organize contacts into groups
6. **Profile Pictures**: Support for contact photos

### API Enhancements Needed
1. **PUT /extension/{id}/contacts/{contact_id}**: Update contact
2. **DELETE /extension/{id}/contacts/{contact_id}**: Delete contact
3. **POST /extension/{id}/contacts**: Create contact
4. **Contact Groups API**: Group management endpoints

## Testing

### Manual Testing Checklist
- [ ] API contacts load correctly
- [ ] Device contacts can be enabled/disabled
- [ ] Search works across all fields
- [ ] Favorites toggle works
- [ ] Call functionality works
- [ ] UI matches design specifications
- [ ] Settings integration works
- [ ] Refresh functionality works
- [ ] Error handling shows appropriate messages
- [ ] Performance is acceptable with large contact lists

### Test Data
The implementation includes placeholder contacts for testing. Real data will come from:
1. Your API endpoint responses
2. Device contacts (when enabled)

## Troubleshooting

### Common Issues

#### "No contacts found"
1. Check API authentication
2. Verify extension ID is correct
3. Enable device contacts if needed
4. Check network connectivity

#### Device contacts not loading
1. Verify contacts permission granted
2. Check device has contacts with phone numbers
3. Toggle device contacts off/on in settings

#### Performance issues
1. Check contact count with `getContactsCount()`
2. Monitor memory usage during large syncs
3. Consider implementing pagination for very large datasets

## API Documentation Reference

### Expected API Response Format

```json
{
  "contacts": [
    {
      "id": "12345",
      "name": "John Doe",
      "display_name": "John Doe",
      "first_name": "John", 
      "last_name": "Doe",
      "company": "Acme Inc",
      "is_favorite": false,
      "phones": [
        {
          "number": "+1234567890",
          "label": "Mobile",
          "is_primary": true
        }
      ],
      "emails": [
        {
          "address": "john@acme.com",
          "label": "Work"
        }
      ],
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

This completes the contacts management implementation for the Flutter softphone app.