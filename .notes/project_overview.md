# Project Overview

## Goal
Build a macOS application that allows users to fade screen black when a button is pressed.

## Core Functionalities
- Fade screen black when a button is pressed
- Menu bar icon to open settings interface for controls 

## Architecture

### UI Layer
- **SwiftUI Components**
  - Custom animated button with fade activation
  - Settings interface for user preferences and controls
  - Visual feedback during fade operations

### Business Logic
- **Combine Framework**
  - MVVM pattern for state management
  - Observable objects for fade parameters
  - DisplayManager class abstraction layer

### System Integration
**Primary Display Control:**
- Use public Display Services API

### Energy Considerations
- CVDisplayLink for vsync-aligned updates
- Dynamic fade step calculation
- Pixel buffer flushing control via `CGDisplayFlush()`
- Timer coalescing implementation
- Low Power Mode detection/handling

### Security Requirements
- "Screen Recording" permission requirement
- Removed problematic entitlements
- Public API-only implementation

### Error Handling & Recovery
- Display state snapshot/restore system
- Fade interrupt handling
- Automatic gamma reset on app termination
- Wake from sleep reinitialization

### Testing Strategy
- XCTest unit test coverage
- UI automation tests
- Memory-mapped I/O validation
- GCD queue prioritization checks

### Documentation Requirements
- API justification matrix
- Security audit trail
- Energy impact disclosure
- Recovery flow diagrams
- Screen recording exception documentation