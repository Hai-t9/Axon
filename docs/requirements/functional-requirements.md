---
sidebar_position: 1
---

# Functional Requirements

## Use Cases

### Registration & Access
- **Register as Organiser**: Organizers can register to create and manage competitions
- **Register as Participant**: Participants can register to join competitions via web version
- **Register via Mobile**: Participants can register and participate via mobile application
- **View Competition Dashboard**: Users can view competition details and status

### Competition Management
- **Create Competition**: Organizers (Host) can create new competitions
- **Configure Competition**: Set competition parameters including:
  - Goals and objectives
  - Competition formats
  - Deadlines and timelines
  - Evaluation metrics
  - Duplicate threshold settings
- **Set Phase Transition Mode**: Configure automatic or manual phase transitions
- **Generate Competition Link**: Create shareable links for team registration
- **Invite Users**: Send invitations to participants via email, link, or QR code
- **Manage Phases**: Transition between Phase-1 through Phase-5

### Team Management
- **Create Teams**: Manual team creation by organizers or participants
- **Import Teams**: Bulk import teams using data files
- **Join Competition**: Participants attempt to join competitions using links or QR codes
- **Confirm Invitations**: Participants confirm team invitations before joining
- **Define Classes/Hierarchy**: Establish file organization and classification hierarchy
- **View Team Statistics**: Display team performance and participation metrics
- **Jumpstart/Advance Phase**: Allow manual phase advancement

### Data Collection & Cleaning (Phase-1 & Phase-2)
- **Extract Device Metadata**: Automatically capture device information during image capture
- **Capture Images**: Mobile device image capture with location and timestamp metadata
- **Select Labels**: Assign labels to captured images
- **Enter Labels Manually**: Option to manually input custom labels
- **Check Device Name Existence**: Validate device identifiers
- **Upload Images**: Submit captured images to system
- **Monitor Phase Status**: Check if Phase-1 is ongoing before allowing uploads
- **Data Cleaning**: Display 40-60 randomly selected images for review
- **Validate Labels**: Review and validate assigned labels
- **Modify Labels**: Correct or update incorrect labels
- **Detect & Remove Duplicates**: Identify and eliminate duplicate images
- **Resize/Normalize Images**: Process images for consistency
- **Add/Correct Metadata**: Update image metadata and attributes
- **Monitor Data Anomalies**: Track and flag unusual data patterns
- **View Data Dump & Metadata**: Access complete dataset information
- **Export Dataset**: Generate and download final cleaned dataset

### Validation & Submission (Phase-3)
- **Curate Validation Display**: Prepare validation dataset presentation
- **Validate Labels (Mixed Dataset)**: Verify labels on combined/shuffled dataset
- **Review Model Submissions**: Examine submitted model artifacts
- **Submit Docker Model Image**: Allow teams to upload containerized models
- **Adjust Phase Deadline**: Modify submission deadlines if needed
- **Verify Team Eligibility**: Confirm team meets competition requirements

### Model Evaluation & Results (Phase-4 & Phase-5)
- **Submit Model**: Upload trained models for evaluation
- **Check Model Structure**: Validate model conforms to required specifications
- **Run Model Evaluation**: Execute evaluation on test dataset
- **Display Leaderboard**: Show team rankings and scores
- **View Final Results**: Display final competition results
- **Rank Teams**: Establish final team rankings based on performance
- **View Accuracy & Contribution**: Show individual accuracy metrics and team contributions
- **Announce Final Leaderboard**: Publish final results to all participants

## User Stories

### Organizer Stories
- As an Organizer, I want to create competitions so that I can organize collaborative challenges
- As an Organizer, I want to configure competition parameters so that the competition aligns with my goals
- As an Organizer, I want to invite users via email, link, or QR code so that participants can easily join
- As an Organizer, I want to manage teams and their hierarchies so that the competition is well-organized
- As an Organizer, I want to transition between phases so that participants progress through the competition
- As an Organizer, I want to monitor data collection and quality so that the dataset is clean and reliable
- As an Organizer, I want to evaluate submitted models so that I can rank teams fairly
- As an Organizer, I want to view leaderboards so that teams can see competition rankings

### Participant Stories
- As a Participant, I want to register for competitions so that I can compete
- As a Participant, I want to view competition details so that I understand the requirements
- As a Participant, I want to capture and upload images from mobile so that I can contribute data
- As a Participant, I want to label and validate images so that the dataset is accurate
- As a Participant, I want to submit a trained model so that I can participate in evaluation
- As a Participant, I want to view my team's performance on the leaderboard so that I can see how we're doing
- As a Participant, I want to access team statistics so that I can track our progress

### Data Annotator Stories
- As a Data Annotator, I want to review and validate labels so that the dataset maintains quality
- As a Data Annotator, I want to remove duplicate images so that the dataset is clean
- As a Data Annotator, I want to normalize and resize images so that all data is consistent
