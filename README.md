# 🗂️ To-Do List Shiny App

A collaborative task management application built with R Shiny that integrates with Google Sheets for data storage and synchronization.

## Features

- ✅ Drag-and-drop task prioritization
- 📅 Due date tracking with visual indicators
- 🔄 Recurring task support
- 👥 Multi-user collaboration
- 🎨 Color-coded urgency levels
- 📊 Table view for detailed task management
- ✏️ In-app task editing
- 🔐 Access key authentication

## Prerequisites

Install the required R packages:

```r
install.packages(c(
  "shiny",
  "shinyjqui",
  "googlesheets4",
  "shinydashboard",
  "shinyjs",
  "DT"
))
```

## Google Sheets Setup

### 1. Create Your Google Sheet

Create a new Google Sheet with **two tabs**:

#### **Main Tasks Sheet** (Sheet 1)
This sheet must contain the following columns:

| Column Name | Type | Description | Required |
|-------------|------|-------------|----------|
| `ID` | Numeric | Unique task identifier | Yes |
| `Name` | Text | Task name | Yes |
| `Responsible` | Text | Person responsible for the task | Yes |
| `Due` | Date | Due date (format: YYYY-MM-DD) | No |
| `Urgency` | Text | Priority level: "High", "Medium", "Low", or "Quick" | Yes |
| `Recurrence` | Text | Format: "X m" or "X y" (e.g., "3 m" = every 3 months) | No |
| `Notes` | Text | Additional notes | No |
| `Date_added` | Date | Date task was created | Yes |

**Example:**
```
ID | Name              | Responsible | Due        | Urgency | Recurrence | Notes           | Date_added
1  | Review proposal   | Alice       | 2026-01-15 | High    | NA         | Urgent deadline | 2026-01-09
2  | Update website    | Bob         | 2026-02-01 | Medium  | 1 m        | Monthly update  | 2026-01-09
3  | Team meeting prep | Both        | NA         | Low     | NA         |                 | 2026-01-09
```

#### **Finished Tasks Sheet** (Sheet 2)
Name this sheet exactly: `Finished Tasks`

This sheet will automatically be populated when tasks are completed. It should have the same columns as the main sheet, plus:

| Column Name | Type | Description |
|-------------|------|-------------|
| `Finished` | Date | Date the task was completed |

### 2. Share Your Sheet

1. Get your Google Sheet URL
2. Ensure it's shared with the Google account you'll authenticate with
3. Copy the full URL (e.g., `https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit`)

## App Setup

### 1. Create Access Keys File

Create a `keys.csv` file in the app directory:

```csv
key,owner,sheet_url
alice123,Alice,https://docs.google.com/spreadsheets/d/SHEET_ID_1/edit
bob456,Bob,https://docs.google.com/spreadsheets/d/SHEET_ID_2/edit
```

### 2. Configure Google Authentication

Update the authentication line in the server code with your Google account:

```r
gs4_auth(cache = ".googleToken", email = "your-email@example.com")
```

### 3. Run the App

```r
shiny::runApp()
```

## Usage

### Login
Enter your access key from `keys.csv` to access your task sheet.

### Priority View (Tab 1)

**Visual Due Date Indicators:**
- ⚪ No due date
- 🟢 > 3 months away
- 🟡 1–3 months away
- 🟠 Within 1 month
- 🔴 ≤ 1 week
- 🟣 Overdue

**Task Sections:**
- **ASAP**: Tasks due within 7 days
- **Quick**: Quick tasks (< 30 min)
- **High/Medium/Low**: Priority-based organization
- **Finished**: Drag tasks here to complete them

**Note:** Tasks with due dates more than 6 months away are hidden in this view but visible in the Table view.

### Table View (Tab 2)

**Features:**
- View all tasks in a sortable table
- Click any row to edit the task
- Edit name, responsible person, due date, urgency, recurrence, and notes

### Adding Tasks

Use the sidebar form to create new tasks:
1. Enter task name
2. Set due date (optional)
3. Assign responsible person
4. Choose priority level
5. Set recurrence (optional - requires due date)
6. Add notes (optional)

### Recurring Tasks

When you complete a recurring task:
- It's logged in "Finished Tasks"
- A new instance is created with the next due date
- Example: If a task recurs "3 m" (every 3 months), the new due date = today + ~90 days

## Priority Levels

- 🔴 **High**: Urgent, important tasks
- 🟠 **Medium**: Standard priority
- 🟢 **Low**: Can wait
- 🟣 **Quick**: Tasks that take < 30 minutes

## File Structure

```
project/
├── app.R              # Main Shiny app file
├── keys.csv           # Access keys and sheet URLs
├── README.md          # This file
└── .googleToken/      # Google auth cache (auto-generated)
```

## Troubleshooting

**Authentication Issues:**
- Delete `.googleToken` folder and re-authenticate
- Ensure your Google account has access to the sheets

**Tasks Not Updating:**
- Check Google Sheets permissions
- Verify column names match exactly (case-sensitive)

**Recurring Tasks Not Working:**
- Ensure the task has a due date
- Check recurrence format: "NUMBER UNIT" (e.g., "2 m", "1 y")

## Security Notes

- Keep `keys.csv` private (add to `.gitignore`)
- Don't share access keys
- Google authentication tokens are stored locally in `.googleToken`

## License

This project is for personal/organizational use.
