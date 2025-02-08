# Directory Structure

blackeyehole/                # Root directory for macOS application
├── Sources/                 # Main source code directory
│   ├── App/                 # Core application components
│   │   ├── UI/              # User interface components (SwiftUI)
│   │   │   ├── MenuBar/     # Menu bar icon and controls
│   │   │   │   └── MenuBarController.swift # NSStatusItem management
│   │   │   ├── Settings/    # User preferences interface
│   │   │   │   ├── SettingsView.swift # SwiftUI settings view
│   │   │   │   └── SettingsViewModel.swift # Combine-based view model
│   │   │   └── FadeButton/  # Custom animated button component
│   │   │       └── FadeButton.swift # Primary fade activation control
│   │   ├── Logic/           # Business logic layer (Combine/MVVM)
│   │   │   ├── Display/     # Display control subsystem
│   │   │   │   ├── DisplayManager.swift # Core display API integration
│   │   │   │   └── GammaController.swift # Gamma adjustment logic
│   │   │   ├── Fade/        # Fade animation subsystem
│   │   │   │   ├── FadeController.swift # Fade timing/coordination
│   │   │   │   └── FadeParameters.swift # Fade curve configuration
│   │   │   └── Energy/      # Power management subsystem
│   │   │       ├── PowerMonitor.swift # IOPMLib integration
│   │   │       └── VSyncCoordinator.swift # CVDisplayLink management
│   │   └── Utilities/       # Shared utility components
│   │       ├── ErrorHandling/ # Recovery systems
│   │       │   ├── DisplayStateSnapshot.swift # Gamma state preservation
│   │       │   └── GammaReset.swift # Safety reset mechanisms
│   │       └── Security/    # Permission handling
│   │           └── PermissionManager.swift # Screen Recording auth
├── Tests/                   # Automated test suite
│   ├── UnitTests/           # Business logic tests
│   │   ├── DisplayTests/    # Display API validation
│   │   │   └── DisplayManagerTests.swift # Core functionality tests
│   │   └── FadeTests/       # Fade animation tests
│   │       └── FadeControllerTests.swift # Timing/coordination tests
│   └── UITests/             # UI interaction tests
│       └── FadeUITests.swift # End-to-end fade operation tests
└── .notes/                  # Project documentation
    ├── project_overview.md  # Architecture/requirements
    └── task_list.md         # Development roadmap

