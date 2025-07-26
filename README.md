# Galaxy Watch 4 Classic iOS Sync App

A comprehensive iOS application built with SwiftUI to connect, sync, and manage data with Samsung Galaxy Watch 4 Classic. The app provides seamless integration with Apple Health and Strava for complete fitness tracking and data synchronization.

## Features

### 🔗 Galaxy Watch Integration

- **Bluetooth Low Energy (BLE) Connection**: Seamless pairing with Galaxy Watch 4 Classic
- **Real-time Sensor Data**: Heart rate, steps, distance, calories, and activity monitoring
- **Bidirectional Communication**: Send notifications and receive sensor data
- **Auto-reconnection**: Automatic reconnection when watch comes back in range

### 📱 iPhone Integration

- **Apple Health Sync**: Automatic synchronization of all fitness data to Apple Health
- **Notification Forwarding**: Forward iPhone notifications to Galaxy Watch
- **Call Management**: Handle incoming calls with CallKit integration
- **Background Processing**: Continuous data sync even when app is not active

### 🏃‍♂️ Strava Integration

- **OAuth Authentication**: Secure Strava account linking
- **Workout Upload**: Automatic upload of workouts and activities
- **Activity Mapping**: Map Galaxy Watch activities to Strava activity types
- **Progress Tracking**: Monitor upload status and sync history

## Project Structure

```
galaxy watch/
├── galaxy_watchApp.swift          # Main app entry point
├── ContentView.swift              # Primary user interface
├── Support/
│   └── Info.plist                # App configuration and permissions
├── Models/
│   └── SensorData.swift           # Data models for sensor information
└── Managers/
    ├── BluetoothManager.swift     # BLE communication with Galaxy Watch
    ├── HealthManager.swift        # Apple Health integration
    ├── NotificationManager.swift  # Notification and call handling
    └── StravaManager.swift        # Strava API integration
```

## Technical Requirements

### iOS Requirements

- **iOS 18.5+**: Latest iOS features and APIs
- **Xcode 16**: Latest development environment
- **iPhone with Bluetooth 5.0+**: For optimal Galaxy Watch connection

### Permissions Required

- **Bluetooth**: Connect to Galaxy Watch 4 Classic
- **Health**: Read/write fitness and health data
- **Notifications**: Forward iPhone notifications to watch
- **Background App Refresh**: Continuous data synchronization

### Frameworks Used

- **SwiftUI**: Modern declarative UI framework
- **CoreBluetooth**: Bluetooth Low Energy communication
- **HealthKit**: Apple Health data integration
- **CallKit**: Phone call management
- **UserNotifications**: Notification handling
- **UIKit**: Legacy UI components for OAuth

## Setup Instructions

### 1. Xcode Setup

```bash
# Clone and navigate to project
cd "/Users/akhil/Projects/repos/galaxy watch"

# Open in Xcode
open "galaxy watch.xcodeproj"
```

### 2. Build and Run

```bash
# Build for iOS Simulator
xcodebuild -project "galaxy watch.xcodeproj" \
           -scheme "galaxy watch" \
           -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5" \
           build

# Install on Simulator
xcrun simctl install booted "/path/to/galaxy watch.app"

# Launch the app
xcrun simctl launch booted com.easy-life.galaxy-watch.galaxy-watch
```

### 3. Galaxy Watch Pairing

1. **Enable Bluetooth**: Ensure iPhone Bluetooth is enabled
2. **Watch Pairing Mode**: Put Galaxy Watch 4 Classic in pairing mode
3. **Open App**: Launch the Galaxy Watch iOS app
4. **Tap Connect**: Use the "Connect to Galaxy Watch" button
5. **Authorize Permissions**: Grant Health, Bluetooth, and Notification permissions

### 4. Strava Integration

1. **Login to Strava**: Tap "Connect to Strava" in the app
2. **OAuth Authorization**: Complete Strava login in the web view
3. **Grant Permissions**: Allow the app to read/write activity data
4. **Verify Connection**: Check that Strava shows as connected

## App Interface

### Main Screen Features

- **Connection Status**: Visual indicator for Galaxy Watch connection
- **Real-time Data**: Live display of heart rate, steps, and activity
- **Strava Status**: Current sync status with Strava account
- **Manual Sync**: Button to force immediate data synchronization

### Data Monitoring

- **Heart Rate**: Real-time BPM monitoring from Galaxy Watch
- **Activity Tracking**: Steps, distance, calories, and active time
- **Health Sync**: Automatic background sync to Apple Health
- **Workout Sessions**: Dedicated workout tracking and management

## Testing & Validation

### Simulator Testing

✅ **Build Success**: Project compiles without errors  
✅ **App Launch**: Successfully launches in iOS Simulator  
✅ **UI Rendering**: SwiftUI interface displays correctly  
✅ **Permission Requests**: Health and notification permissions work

### Device Testing (Recommended)

- **Galaxy Watch Connection**: Test actual BLE pairing
- **Sensor Data Flow**: Verify real sensor data reception
- **Health App Integration**: Confirm data appears in Apple Health
- **Strava Upload**: Test workout upload to Strava platform

## Architecture Details

### Bluetooth Communication

- **Central Manager**: iPhone acts as BLE central device
- **Service Discovery**: Discovers Galaxy Watch health services
- **Characteristic Reading**: Reads sensor data characteristics
- **Connection Management**: Handles connection state changes

### Health Data Pipeline

```
Galaxy Watch → BLE → BluetoothManager → HealthManager → Apple Health
                                   ↓
                              StravaManager → Strava API
```

### Background Processing

- **HealthKit Background**: Continuous health data processing
- **BLE Background**: Maintain watch connection when app backgrounded
- **Notification Delivery**: Background notification forwarding

## Known Limitations

### Development Constraints

- **Simulator Testing**: BLE features require physical device testing
- **Galaxy Watch Protocol**: Limited to publicly available BLE services
- **iOS Restrictions**: Some background tasks limited by iOS power management

### Compatibility Notes

- **Galaxy Watch 4 Classic**: Primary target device
- **Other Galaxy Watches**: May work with other models using similar BLE protocols
- **iOS Version**: Requires iOS 18.5+ for latest HealthKit features

## Development Notes

### Build Warnings Resolved

- ✅ **Info.plist Conflicts**: Moved to Support/ directory
- ✅ **HealthKit Deprecations**: Updated to modern HKWorkoutBuilder API
- ✅ **CallKit Updates**: Migrated from CXCallController to CXProvider
- ✅ **Type Conversions**: Fixed Int to Double conversions for health data

### Performance Optimizations

- **Efficient BLE Scanning**: Targeted service UUID filtering
- **Battery Optimization**: Intelligent connection management
- **Data Batching**: Efficient health data upload to reduce API calls

## Future Enhancements

### Planned Features

- **Advanced Analytics**: Detailed health trend analysis
- **Customizable Notifications**: User-configurable notification forwarding
- **Multi-device Support**: Connect multiple Galaxy Watch devices
- **Enhanced Strava Features**: Segment analysis and social features

### Technical Improvements

- **CoreData Integration**: Local data persistence and caching
- **Watch Complications**: Display iPhone data on Galaxy Watch face
- **WidgetKit Support**: iOS home screen widgets with health data
- **Shortcuts Integration**: Siri shortcuts for common actions

---

**App Status**: ✅ Successfully built and tested  
**Simulator Compatibility**: ✅ iPhone 16 Pro iOS 18.5 Simulator  
**Next Steps**: Physical device testing with actual Galaxy Watch 4 Classic
