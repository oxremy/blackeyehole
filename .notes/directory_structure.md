# Directory Structure

jeremyknox/
├── blackeyehole/
│   ├── App/                  # Core application components
│   │   ├── AppDelegate.swift # Main app lifecycle management
│   │   ├── MenuController.swift # Menu bar item and menu management
│   │   ├── StatusItemManager.swift # NSStatusItem configuration and handling
│   │   ├── Preferences/          # User preferences management
│   │   │   ├── PreferencesWindowController.swift # NSWindowController for preferences
│   │   │   ├── PreferencesView.swift # SwiftUI view for preferences UI
│   │   ├── Display/              # Display control functionality
│   │   │   ├── DisplayManager.swift # Core display management
│   │   │   ├── BrightnessController.swift # Gradual brightness control
│   │   ├── Power/                # Power management and optimization
│   │   │   ├── PowerMonitor.swift # IOPMLib integration for power state
│   │   │   ├── EnergyOptimizer.swift # Energy efficiency strategies
│   ├── Resources/                # Application assets and localization
│   │   ├── Assets.xcassets       # App icons and image assets
│   │   ├── Localizable.strings   # Localization strings for internationalization
│   ├── Tests/                    # Test coverage
│   │   ├── UnitTests/            # Unit tests for business logic
│   │   ├── UITests/              # UI tests for user interactions
│   ├── .notes/                   # Project documentation and planning
│   │   ├── project_overview.md   # High-level project description
│   │   ├── task_list.md          # Development tasks and roadmap
│   │   ├── energy_optimization.md # Energy efficiency strategies
│   │   ├── directory_structure.md # Directory structure
│   ├── README.md                 # Project overview and setup instructions
│   └── Package.swift             # Swift Package Manager configuration
