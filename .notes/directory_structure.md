# Directory Structure

blackeyehole/                # Root directory for macOS application
├── Package.swift            # Swift package manager configuration
├── blackeyehole.entitlements # Application permissions entitlements
├── Info.plist               # Application configuration properties
├── Sources/                 # Main source code directory
│   ├── App/                 # Core application components
│   │   ├── UI/              # User interface components (SwiftUI)
│   │   │   ├── Recovery/    # New recovery UI components
│   │   │   │   └── RecoveryIndicatorView.swift
│   │   │   ├── MenuBar/     # Menu bar icon and controls
│   │   │   │   └── MenuBarController.swift # Updated with status
│   │   │   ├── Settings/    # User preferences interface
│   │   │   │   ├── SettingsView.swift # SwiftUI settings view
│   │   │   │   └── SettingsViewModel.swift # Combine-based view model
│   │   │   └── FadeButton/  # Custom animated button component
│   │   │       └── FadeButton.swift # Primary fade activation control
│   │   ├── Logic/           # Business logic layer (Combine/MVVM)
│   │   │   ├── Display/     # Display control subsystem
│   │   │   │   ├── DisplayManager.swift # Core display API integration
│   │   │   │   ├── DisplayValidator.swift  # Serial validation implementation
│   │   │   │   └── GammaController.swift
│   │   │   └── Fade/        # Fade animation subsystem
│   │   │       ├── FadeController.swift # Fade timing/coordination
│   │   │       └── FadeParameters.swift # Fade curve configuration
│   │   │   └── Energy/      # Power management subsystem
│   │   │       ├── PowerMonitor.swift # Updated with 2s sampling
│   │   │       └── VSyncCoordinator.swift # CVDisplayLink management
│   │   └── Utilities/       # Shared utility components
│   │       ├── ErrorHandling/ # Recovery systems
│   │       │   ├── DisplayStateSnapshot.swift # Gamma state preservation
│   │       │   └── GammaReset.swift # Safety reset mechanisms
│   │       └── Security/    # Permission handling
│   │           ├── PermissionManager.swift # Updated with audit trails
│   │           └── SecurityAuditLogger.swift # New component
│   │   └── Preferences/   # New preferences subsystem
│   │       └── PreferenceStore.swift
│   │   └── Preferences/   # New preferences subsystem
│   │       └── PreferenceValidator.swift # New validation component
│   ├── Tests/                   # Automated test suite
│   │   ├── UnitTests/           # Business logic tests
│   │   │   ├── DisplayTests/    # Display API validation
│   │   │   │   ├── DisplayManagerTests.swift
│   │   │   │   ├── DisplayValidatorTests.swift  # Validation tests added
│   │   │   │   └── GammaControllerTests.swift
│   │   │   ├── FadeTests/       # Fade animation tests
│   │   │   │   └── FadeControllerTests.swift # Timing/coordination tests
│   │   │   └── EnergyTests/     # New test group
│   │   │       ├── PowerMonitorTests.swift  # Sampling tests added
│   │   │       └── VSyncCoordinatorTests.swift # New test file
│   │   └── UITests/             # UI interaction tests
│   │       ├── SecurityAuditTests.swift # New audit tests
│   │       └── FadeUITests.swift # End-to-end fade operation tests
│   └── .notes/                  # Project documentation
│       ├── SecurityAuditTrail.md # Added security audit documentation
│       ├── EntitlementJustification.md # New entitlement docs
│       ├── project_overview.md  
│       ├── task_list.md         
│       └── meeting_notes.md     
│   │   ├── Localization/    # Added localization files
│   │   │   └── en.lproj/
│   │   │       └── Localizable.strings
│   │   └── Recovery/
│   │       └── RecoveryIndicatorView.swift # Localized strings

