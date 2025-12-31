# GetSh1tDone

A productivity tool for macOS and iOS that helps you organize your Apple Reminders using the Eisenhower Matrix methodology.

## Features

- **Eisenhower Matrix View**: Visual 4-quadrant matrix for organizing tasks
  - **Do Now** (Urgent/Important)
  - **Delegate** (Urgent/Not Important)
  - **Schedule** (Not Urgent/Important)
  - **Bin** (Not Urgent/Not Important)

- **Drag and Drop**: Easily move tasks between quadrants by dragging and dropping

- **Planning Assistant**: Guided questions for day, week, and fortnight planning

- **Task Challenges**: 
  - Clarity challenges for unclear tasks
  - Delegation suggestions
  - SMART goal validation
  - Relevance checks for old tasks

- **Priorities Management**: Set and review your top 5 priorities to guide task classification

## Setup

1. Open `GetSh1tDone.xcodeproj` in Xcode
2. Build and run the project
3. Grant Reminders access when prompted
4. Your Apple Reminders will be automatically loaded and organized

## How It Works

The app uses hashtags in your Reminders notes to track which quadrant each task belongs to:
- `#DoNow` - Urgent/Important tasks
- `#Delegate` - Urgent/Not Important tasks
- `#Schedule` - Not Urgent/Important tasks
- `#Bin` - Not Urgent/Not Important tasks

When you drag a task to a different quadrant, the app automatically updates the hashtag in the reminder's notes.

## Usage

1. **Matrix Tab**: View and organize all your tasks in the Eisenhower matrix
2. **Plan Tab**: Answer guided questions to plan your day, week, or fortnight
3. **Challenges Tab**: Review tasks that need attention (clarity, delegation, SMART goals, relevance)
4. **Priorities Tab**: Set your top 5 priorities to help guide task classification

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.0 or later

