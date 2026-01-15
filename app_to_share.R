library(shiny)
library(shinyjqui)
library(googlesheets4)
library(shinydashboard)
library(shinyjs)

keys_df <- read.csv("keys.csv", stringsAsFactors = FALSE)
e_mail <- "yourname@gmail.com" # The email you use for googlesheets

ui <- dashboardPage(
  dashboardHeader(title = "🗂️ To-Do List"),
  
  dashboardSidebar(
    useShinyjs(),
    
    checkboxGroupInput("in_responsible", "Responsible:", choices = c("Both")),
    hr(),
    
    h4("➕ New Task"),
    textInput("task_name", "Task Name"),
    
    checkboxInput("has_due", "Has due date", value = FALSE),
    conditionalPanel(
      condition = "input.has_due == true",
      dateInput("task_due", "Due Date", value = Sys.Date())
    ),
    
    selectInput("task_responsible", "Responsible", choices = NULL),
    
    selectInput(
      "task_urgency", "Priority",
      choices = c("High", "Medium", "Low", "Quick"),
      selected = "Medium"
    ),
    
    checkboxInput("has_recurrence", "Does the task repeat", value = FALSE),
    conditionalPanel(
      condition = "input.has_recurrence == true",
      p("Recurrent tasks need a due date!"),
      numericInput(
        "recurrence_n",
        label = "Repeat every",
        value = 1,
        min = 1,
        step = 1
      ),
      radioButtons(
        "recurrence_unit",
        label = NULL,
        choices = c("Month(s)" = "m", "Year(s)" = "y"),
        inline = TRUE
      )
    ),
    textInput("notes","Notes",value = ""),
    
    actionButton(
      "add_task",
      "Add",
      icon = icon("plus"),
      class = "btn-primary"
    ),
    
    hr(),
    uiOutput("sheet_link")
  ),
  
  dashboardBody(
    
    ## ---------- GLOBAL STYLES ----------
    tags$head(
      tags$style(HTML("
        .order-container {
          background-color: #f8f9fa;
          padding: 15px;
          border-radius: 12px;
          box-shadow: 0 2px 6px rgba(0,0,0,0.1);
          margin-bottom: 20px;
        }
        .order-title {
          font-weight: bold;
          font-size: 16px;
          margin-bottom: 10px;
          color: #2C3E50;
        }
      "))
    ),
    
    fluidRow(
      column(
        width = 12,
        
        tabsetPanel(
          type = "tabs",
          tabPanel(
            title = "Priority groups",
            
            br(),
            br(),
            div(
              style = "display:flex; gap:10px; margin-bottom:10px;",
              span("⚪ No due date"),
              span("🟢 > 3 months"),
              span("🟡 1–3 months"),
              span("🟠 1 month"),
              span("🔴 ≤ 1 week"),
              span("🟣 Overdue")
            ),
            br(),
            
            uiOutput("dynamic_todo")
          ),
          
          tabPanel(
            title = "Table",
            
            br(),
            br(),
            div(
              style = "display:flex; gap:10px; margin-bottom:10px;",
              span("🟢 Low"),
              span("🟠 Medium"),
              span("🔴 High"),
              span("🟣 Quick")
            ),
            br(),
            
            DT::dataTableOutput("finished_table")
          )
        )
      )
    )
  )
)



server <- function(input, output, session) {
  
  gs4_auth(cache = ".googleToken", email = e_mail)
  
  make_labels <- function(df) {
    display <- df$Name
    for(i in 1:nrow(df)){
      name <- df$Name[i]
      days <- as.integer(df$Due[i] - Sys.Date())
      if(is.na(days)){
        display[i] <- paste0( "⚪ ", name)
      }else{
        if (days < 0) { # Overdue
          display[i] <- paste0( "🟣 ", name)
        } else if (days <= 7) {
          display[i] <- paste0( "🔴 ", name)
        } else if (days < 30) {
          display[i] <- paste0( "🟠 ", name)
        } else if (days < 90) {
          display[i] <- paste0( "🟡 ", name)
        } else{
          display[i] <- paste0( "🟢 ", name)
        }
      }
    }
    return(display)
  }

  current_sheet <- reactiveVal(NULL)
  current_user  <- reactiveVal(NULL)
  
  observeEvent(TRUE, {
    showModal(
      modalDialog(
        title = "🔐 Enter Access Key",
        textInput("access_key", "Key"),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("submit_key", "Access", class = "btn-primary")
        ),
        easyClose = FALSE
      )
    )
  }, once = TRUE)
  
  observeEvent(input$submit_key, {
    req(input$access_key)
    
    row <- keys_df[keys_df$key == input$access_key, ]
    
    if (nrow(row) == 1) {
      current_sheet(row$sheet_url)
      current_user(row$owner)
      
      removeModal()
      
      showNotification(
        paste("✅ Access granted:", row$owner),
        type = "message"
      )
    } else {
      showNotification(
        "❌ Invalid key",
        type = "error"
      )
    }
  })
  
  output$sheet_link <- renderUI({
    req(current_sheet())
    
    tags$a(
      href = current_sheet(),
      "📄 Google Sheet",
      target = "_blank",
      style = "font-weight:bold;"
    )
  })
  
  ToDoList <- reactiveVal()
  
  observe({
    req(current_sheet())
    df <- read_sheet(current_sheet())
    # df <- read_sheet(sheet_URL)
    df$Due <- as.Date(df$Due, format = "%Y-%m-%d")
    
    df$display_name <- make_labels(df)
    ToDoList(df)
    
    people <- sort(unique(df$Responsible))
    people <- people[!is.na(people)]
    
    updateSelectInput(
      session,
      "task_responsible",
      choices = c(people, "Both"),
      selected = "Both"
    )
    
    updateCheckboxGroupInput(
      session,
      "in_responsible",
      choices = people,
      selected = "Both"
    )
  })
  
  
  observeEvent(input$High, { update_tasks(input$High, "High") })
  observeEvent(input$Medium, { update_tasks(input$Medium, "Medium") })
  observeEvent(input$Low, { update_tasks(input$Low, "Low") })
  observeEvent(input$Quick, { update_tasks(input$Quick, "Quick") })
  observeEvent(input$ASAP, { update_tasks_asap(input$ASAP) })
  
  update_tasks <- function(task_names, urgency) {
    df <- ToDoList()
    changed <- FALSE
    for (task in task_names) {
      row <- which(df$display_name == task)
      if (length(row) == 1 && df$Urgency[row] != urgency) {
        df$Urgency[row] <- urgency
        changed <- TRUE
      }
    }
    if (changed) {
      df_print <- df[,-which(names(df) %in% "display_name")]
      sheet_write(df_print, ss = current_sheet(), sheet = 1)
      ToDoList(df)
    }
  }
  
  update_tasks_asap <- function(task_names) {
    df <- ToDoList()
    changed <- FALSE
    for (task in task_names) {
      row <- which(df$display_name == task)
      if (length(row) == 1 && df$Due[row] > Sys.Date()) {
        df$Due[row] <- Sys.Date()
        changed <- TRUE
      }
    }
    if (changed) {
      df_print <- df[,-which(names(df) %in% "display_name")]
      sheet_write(df_print, ss = current_sheet(), sheet = 1)
      ToDoList(df)
    }
  }
  
  
  # Move finished tasks to "Finished Tasks" sheet and remove from main
  observeEvent(input$Finished, {
    df <- ToDoList()
    finished_tasks <- input$Finished
    
    if (length(finished_tasks) > 0) {
      # Subset finished tasks
      finished_df <- df[df$display_name %in% finished_tasks, -which(names(df) %in% "display_name")]
      
      # Add Finished date column
      finished_df$Finished <- Sys.Date()
      
      # Append to "Finished Tasks" sheet
      sheet_append(ss = current_sheet(), data = finished_df, sheet = "Finished Tasks")
      
      recurring <- finished_df$Recurrence
      if(is.na(recurring)){
        # Remove from main sheet
        df <- df[!df$display_name %in% finished_tasks, ]
        showNotification(paste0("✅ Moved ", length(finished_tasks), " task(s) to Finished Tasks."), type = "message")
      }else{
        # Update in main sheet
        recurrence <- strsplit(df$Recurrence[df$display_name %in% finished_tasks]," ")[[1]]
        add_time <- as.numeric(recurrence[1]) * round(if(recurrence[2] == "m") 30.44 else 365.25,0)
        # df[df$display_name %in% finished_tasks,"Due" ] <- df$Due[df$display_name %in% finished_tasks] + add_time
        df[df$display_name %in% finished_tasks,"Due" ] <- Sys.Date() + add_time
        showNotification(paste0("✅  Moved ", length(finished_tasks), " recurring by ", add_time ," days."),type = "message")
      }
      
      # Update main sheet & reactive
      df_print <- df[,-which(names(df) %in% "display_name")]
      sheet_write(df_print, ss = current_sheet(), sheet = 1)
      df$display_name <- make_labels(df)
      ToDoList(df)
      
    }
  })
  
  output$dynamic_todo <- renderUI({
    req(ToDoList())
    df <- ToDoList()
    
    # Filter out tasks with due dates > 6 months
    six_months_later <- Sys.Date() + 180
    df <- df[is.na(df$Due) | df$Due <= six_months_later, ]
    
    categories <- c("Quick","High", "Medium", "Low")
    
    selected <- input$in_responsible
    
    res <- if (length(selected) == 0) {
      # nothing selected → show all
      rep(TRUE, nrow(df))
    } else {
      # df$Responsible %in% c(selected, "Both")
      df$Responsible %in% selected
    }
    
    asap_tasks <- df$display_name[!is.na(df$Due) & res & (df$Due - Sys.Date() <= 7)]
    
    tags_list <- list(
      div(class = "order-container",
          div(class = "order-title", "🔴 ASAP (Due in ≤ 7 days)"),
          orderInput("ASAP", NULL,
                     items = asap_tasks,
                     placeholder = "Add here...",
                     connect = c(categories, "ASAP", "Finished"))
      )
    )
    
    for (urgency in categories) {
      urgency_df <- df$display_name[res & df$Urgency == urgency & (is.na(df$Due) | (df$Due - Sys.Date() > 7))]
      
      tags_list <- append(tags_list, list(
        div(class = "order-container",
            div(class = "order-title", paste("🔷", urgency, "priority")),
            orderInput(urgency, NULL,
                       items = urgency_df,
                       placeholder = "add here...",
                       connect = c(categories, "ASAP", "Finished"))
        )
      ))
    }
    
    # Add the Finished tasks container for dropping tasks to finish
    tags_list <- append(tags_list, list(
      div(class = "order-container",
          div(class = "order-title", "🗑️ Finished Tasks (Drop here to finish)"),
          orderInput("Finished", NULL,
                     items = NULL,
                     placeholder = "Drag tasks here to finish",
                     connect = c(categories, "ASAP", "Finished"))
      )
    ))
    
    tagList(tags_list)
  })
  
  observeEvent(input$add_task, {
    if (isTRUE(input$has_recurrence) && isFALSE(input$has_due)) {
      showNotification(
        "❗ Recurring tasks need a due date",
        type = "warning"
      )
      return()  # ⛔ STOP here
    }
    req(input$task_name, input$task_responsible, input$task_urgency)
    
    due_date <- if (isTRUE(input$has_due)) {
      as.Date(input$task_due)
    } else {
      NA
    }
    
    recurrence <- if (isTRUE(input$has_recurrence)) {
      paste(input$recurrence_n, input$recurrence_unit)
    } else {
      NA
    }
    
    # Generate new ID
    df <- ToDoList()
    new_id <- if (nrow(df) == 0) 1 else max(df$ID, na.rm = TRUE) + 1
    
    new_task <- data.frame(
      ID = new_id,
      Name = input$task_name,
      Responsible = input$task_responsible,
      Due = due_date,
      Urgency = input$task_urgency,
      Recurrence = recurrence,
      Notes = input$notes,
      Date_added = Sys.Date(),
      stringsAsFactors = FALSE
    )
    
    sheet_append(ss = current_sheet(), data = new_task, sheet = 1)
    
    updateTextInput(session, "task_name", value = "")
    updateCheckboxInput(session, "has_due", value = TRUE)
    updateCheckboxInput(session, "has_recurrence", value = FALSE)
    updateSelectInput(session, "task_responsible", selected = "Both")
    updateSelectInput(session, "task_urgency", selected = "Medium")
    
    showNotification("✅ Task Added", type = "message")
    
    df <- read_sheet(current_sheet())
    df$Due <- as.Date(df$Due)
    df$display_name <- make_labels(df)
    ToDoList(df)
  })
  
  #############################
  ### Second Tab with table ###
  #############################
  
  output$finished_table <- DT::renderDataTable({
    df <- ToDoList()
    df <- df[order(df$Due), ]
    selected <- input$in_responsible
    
    res <- if (length(selected) == 0) {
      # nothing selected → show all
      rep(TRUE, nrow(df))
    } else {
      # df$Responsible %in% c(selected, "Both")
      df$Responsible %in% selected
    }
    
    df <- df[res,]
    
    make_urgency_color <- function(urgency){
      out <- urgency
      out[urgency == "Low"] <- "🟢 Low"
      out[urgency == "Medium"] <- "🟠 Medium"
      out[urgency == "High"] <- "🔴 High"
      out[urgency == "Quick"] <- "🟣 Quick"
      return(out)
    }
    df$Urgency <- make_urgency_color(df$Urgency)
    
    DT::datatable(
      df[, c("ID", "Name", "Responsible", "Due", "Urgency","Recurrence","Notes","Date_added")],
      selection = "single",
      options = list(pageLength = 20)
    )
  })
  
  selected_task <- reactive({
    req(input$finished_table_rows_selected)
    df <- ToDoList()
    df <- df[order(df$Due), ]
    selected <- input$in_responsible
    
    res <- if (length(selected) == 0) {
      # nothing selected → show all
      rep(TRUE, nrow(df))
    } else {
      # df$Responsible %in% c(selected, "Both")
      df$Responsible %in% selected
    }
    
    df <- df[res,]
    df[input$finished_table_rows_selected, ]
  })
  
  observeEvent(input$finished_table_rows_selected, {
    task <- selected_task()
    
    showModal(
      modalDialog(
        title = paste("✏️ Edit Task:", task$Name),
        
        textInput("edit_name", "Task Name", value = task$Name),
        selectInput("edit_responsible", "Responsible",
                    choices = unique(ToDoList()$Responsible),
                    selected = task$Responsible),
        checkboxInput("edit_has_due", "Has due date",value = !is.na(task$Due)),
        conditionalPanel(
          condition = "input.edit_has_due == true",
          dateInput("edit_due","Due date",
                    value = ifelse(is.na(task$Due), Sys.Date(), task$Due))
        ),
        selectInput("edit_urgency", "Urgency",
                    choices = c("Quick", "High", "Medium", "Low"),
                    selected = task$Urgency),
        checkboxInput(
          "edit_has_recurrence",
          "Recurring task",
          value = !is.na(task$Recurrence)
        ),
        
        conditionalPanel(
          condition = "input.edit_has_recurrence == true",
          fluidRow(
            column(6,
                   numericInput(
                     "edit_recurrence_n",
                     "Every",
                     value = ifelse(is.na(task$Recurrence), 1,
                                    as.numeric(strsplit(task$Recurrence, " ")[[1]][1])),
                     min = 1
                   )
            ),
            column(6,
                   radioButtons(
                     "edit_recurrence_unit",
                     "Unit",
                     choices = c("month" = "m", "year" = "y"),
                     selected = ifelse(
                       is.na(task$Recurrence), "m",
                       strsplit(task$Recurrence, " ")[[1]][2]
                     ),
                     inline = TRUE
                   )
            )
          )
        ),
        textInput("edit_notes","Notes",value = task$Notes),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("save_task", "Save changes", class = "btn-primary")
        ),
        easyClose = TRUE
      )
    )
  })
  
  observeEvent(input$save_task, {
    # ❌ Recurrence without due date
    if (isTRUE(input$edit_has_recurrence) && !isTRUE(input$edit_has_due)) {
      showNotification(
        "❌ Recurring tasks must have a due date",
        type = "error"
      )
      return(NULL)
    }
    
    df <- ToDoList()
    task <- selected_task()
    
    row <- which(df$ID == task$ID)
    
    df[row, "Name"]        <- input$edit_name
    df[row, "Responsible"] <- input$edit_responsible
    # Due
    df$Due[row] <- if (isTRUE(input$edit_has_due)) {
      as.Date(input$edit_due)
    } else {
      NA
    }
    
    # Recurrence
    df$Recurrence[row] <- if (isTRUE(input$edit_has_recurrence)) {
      paste(input$edit_recurrence_n, input$edit_recurrence_unit)
    } else {
      NA
    }
    df[row, "Urgency"]     <- input$edit_urgency
    df[row,"Notes"] <- input$edit_notes
    
    df_print <- df[,-which(names(df) %in% "display_name")]
    sheet_write(df_print, ss = current_sheet(), sheet = 1)
    ToDoList(df)
    
    removeModal()
    showNotification("✅ Task updated", type = "message")
  })
  
}

shinyApp(ui, server)
