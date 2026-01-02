install.packages(c(
  "shiny",
  "shinyWidgets",
  "leaflet",
  "terra",
  "plotly",
  "classInt",
  "colourpicker",
  "viridisLite",
  "jsonlite"
))
library(shiny)
library(shinyWidgets) # noUiSliderInput (multi-handle slider)
library(leaflet)
library(terra)
library(plotly)
library(classInt)
library(colourpicker)
library(viridisLite)
library(jsonlite)

# Attempt 1 ----

ui <- fluidPage(
  titlePanel("Raster breaks — normalized stops & hex colors"),
  sidebarLayout(
    sidebarPanel(
      fileInput("ras", "Upload raster (.tif)", accept = c(".tif", ".tiff")),
      hr(),

      # Normalized multi-handle slider: 0..1
      noUiSliderInput(
        inputId = "stops_norm",
        label = "Drag internal stops (normalized 0..1)",
        min = 0,
        max = 1,
        value = seq(0.1, 0.9, length.out = 9), # default 9 internal stops -> 10 classes
        step = 0.001,
        tooltips = TRUE,
        behaviour = "drag",
        update_on = "change",
        pips = list(
          mode = "positions",
          values = list(0, 25, 50, 75, 100),
          density = 3
        )
      ),
      fluidRow(
        column(6, actionButton("add_stop", "Add stop")),
        column(6, actionButton("remove_stop", "Remove last stop"))
      ),
      checkboxInput("reverse", "Reverse colors", FALSE),
      checkboxInput("init_viridis", "Initialize colors from viridis", TRUE),
      hr(),

      # Color swatches (1 per class)
      uiOutput("colors_ui"),
      sliderInput("opacity", "Map opacity", 0.2, 1, 0.9),

      # Preview options
      checkboxInput("use_preview", "Use downsampled preview", TRUE),
      numericInput(
        "preview_cells",
        "Preview: target cells",
        150000,
        min = 10000,
        max = 500000,
        step = 50000
      ),
      checkboxInput(
        "project_false",
        "Skip reprojection (project = FALSE)",
        TRUE
      ), # avoids smoothing on geographic rasters
      checkboxInput(
        "use_ngb",
        "Nearest-neighbor reprojection (categorical)",
        FALSE
      ),
      hr(),

      downloadButton("export_json", "Download normalized stops + colors (JSON)")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Map", leafletOutput("map", height = 520)),
        tabPanel("Histogram", plotlyOutput("hist", height = 320)),
        tabPanel(
          "Output",
          h5("Normalized stops [0..1]"),
          verbatimTextOutput("stops_out"),
          h5("Colors (per class, left→right)"),
          verbatimTextOutput("colors_out")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  # Load raster
  r <- reactive({
    req(input$ras)
    terra::rast(input$ras$datapath)
  })

  # Sample values for stats/histogram (fast)
  vals <- reactive({
    req(r())
    v <- terra::spatSample(
      r(),
      size = 200000,
      method = "regular",
      as.df = TRUE
    )[, 1]
    v[is.finite(v)]
  })

  # Downsampled SpatRaster for preview (reduces PNG size in addRasterImage)
  r_preview <- reactive({
    req(r())
    if (!isTRUE(input$use_preview)) {
      return(r())
    }
    terra::spatSample(
      r(),
      size = input$preview_cells,
      method = "regular",
      as.raster = TRUE
    )
  })

  # Initialize color swatches based on the number of classes
  output$colors_ui <- renderUI({
    req(input$stops_norm)
    k <- length(input$stops_norm) + 1
    base <- viridisLite::viridis(k)
    if (isTRUE(input$reverse)) {
      base <- rev(base)
    }

    tagList(
      h5("Class colors (hex; left → right)"),
      lapply(seq_len(k), function(i) {
        colourpicker::colourInput(
          inputId = paste0("col_", i),
          label = paste("Class", i),
          value = if (isTRUE(input$init_viridis)) base[i] else "#66CCFF",
          allowTransparent = TRUE,
          showColour = "both"
        )
      })
    )
  })

  # Normalized stops (internal handles)
  stops_norm <- reactive({
    sort(as.numeric(input$stops_norm))
  })

  # Map normalized stops to absolute domain for preview
  breaks_abs <- reactive({
    v <- vals()
    req(v)
    rng <- range(v, na.rm = TRUE)
    c(rng[1], rng[1] + stops_norm() * diff(rng), rng[2])
  })

  # Colors per class (one per interval)
  colors_vec <- reactive({
    k <- length(stops_norm()) + 1
    sapply(seq_len(k), function(i) input[[paste0("col_", i)]])
  })

  # Palette function (binned)
  pal_fn <- reactive({
    leaflet::colorBin(
      palette = colors_vec(),
      domain = range(vals(), na.rm = TRUE),
      bins = breaks_abs(),
      right = FALSE,
      na.color = "#00000000"
    )
  })

  # Base map
  output$map <- renderLeaflet({
    leaflet() %>% addTiles()
  })

  # Redraw map when stops or colors change
  observe({
    req(r_preview(), pal_fn())
    leafletProxy("map") %>%
      clearImages() %>%
      clearControls() %>%
      addRasterImage(
        x = r_preview(),
        colors = pal_fn(),
        opacity = input$opacity,
        project = !isTRUE(input$project_false),
        method = if (isTRUE(input$use_ngb)) "ngb" else "bilinear"
      ) %>%
      addLegend(
        pal = pal_fn(),
        values = vals(),
        title = "Classes",
        opacity = 0.9
      )
  })

  # Histogram with break lines
  output$hist <- renderPlotly({
    v <- vals()
    req(v)
    b <- breaks_abs()
    p <- plot_ly(
      x = v,
      type = "histogram",
      nbinsx = 60,
      marker = list(color = "rgba(60,60,60,0.6)")
    )
    for (br in b) {
      p <- p %>%
        add_lines(
          x = c(br, br),
          y = c(0, 1),
          line = list(color = "red", dash = "dot", width = 1),
          inherit = FALSE,
          showlegend = FALSE
        )
    }
    p
  })

  # Add/remove stops: add in the widest interval or remove last
  observeEvent(input$add_stop, {
    b <- c(0, stops_norm(), 1)
    widths <- diff(b)
    idx <- which.max(widths)
    new_stop <- b[idx] + widths[idx] / 2
    updateNoUiSliderInput(
      session,
      "stops_norm",
      value = sort(c(stops_norm(), new_stop))
    )
  })
  observeEvent(input$remove_stop, {
    if (length(stops_norm()) > 1) {
      updateNoUiSliderInput(
        session,
        "stops_norm",
        value = stops_norm()[-length(stops_norm())]
      )
    }
  })

  # Outputs (primary deliverable)
  output$stops_out <- renderPrint({
    stops_norm()
  }) # normalized [0..1]
  output$colors_out <- renderPrint({
    colors_vec()
  })

  # Export JSON: normalized stops + colors
  output$export_json <- downloadHandler(
    filename = function() "normalized_stops_colors.json",
    content = function(file) {
      jsonlite::write_json(
        list(stops_norm = stops_norm(), colors = colors_vec()),
        path = file,
        pretty = TRUE,
        auto_unbox = TRUE
      )
    }
  )
}

# Attempt 2 ----
ui <- fluidPage(
  titlePanel("Raster breaks — normalized stops & hex colors"),
  sidebarLayout(
    sidebarPanel(
      fileInput("ras", "Upload raster (.tif)", accept = c(".tif", ".tiff")),
      hr(),

      # Normalized multi-handle slider: 0..1 with 4-decimal precision
      noUiSliderInput(
        inputId = "stops_norm",
        label = "Drag internal stops (normalized 0..1)",
        min = 0,
        max = 1,
        value = seq(0.1, 0.9, length.out = 9), # default 9 internal stops -> 10 classes
        step = 0.0001, # precision: 4 decimals
        margin = 0.0001, # minimum spacing: prevents identical stops
        tooltips = TRUE,
        behaviour = "drag",
        update_on = "change",
        format = wNumbFormat(decimals = 4), # show 4-decimal tooltip
        pips = list(
          mode = "positions",
          values = list(0, 25, 50, 75, 100),
          density = 3
        )
      ),
      fluidRow(
        column(6, actionButton("add_stop", "Add stop")),
        column(6, actionButton("remove_stop", "Remove last stop"))
      ),

      hr(),
      # NEW: type-to-finetune per stop
      h5("Fine-tune stops by typing exact normalized values (0–1):"),
      uiOutput("stop_inputs"), # renders numericInput for each stop

      checkboxInput("reverse", "Reverse colors", FALSE),
      checkboxInput("init_viridis", "Initialize colors from viridis", TRUE),
      hr(),

      uiOutput("colors_ui"),
      sliderInput("opacity", "Map opacity", 0.2, 1, 0.9),

      checkboxInput("use_preview", "Use downsampled preview", TRUE),
      numericInput(
        "preview_cells",
        "Preview: target cells",
        150000,
        min = 10000,
        max = 500000,
        step = 50000
      ),
      checkboxInput(
        "project_false",
        "Skip reprojection (project = FALSE)",
        TRUE
      ),
      checkboxInput(
        "use_ngb",
        "Nearest-neighbor reprojection (categorical)",
        FALSE
      ),
      hr(),

      downloadButton("export_json", "Download normalized stops + colors (JSON)")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Map", leafletOutput("map", height = 520)),
        tabPanel("Histogram", plotlyOutput("hist", height = 320)),
        tabPanel(
          "Output",
          h5("Normalized stops [0..1]"),
          verbatimTextOutput("stops_out"),
          h5("Colors (per class, left→right)"),
          verbatimTextOutput("colors_out")
        )
      )
    )
  )
)


server <- function(input, output, session) {
  # ------------------------------------------------------------
  # Source-of-truth state
  # ------------------------------------------------------------
  rv <- reactiveValues(
    stops = seq(0.1, 0.9, length.out = 9), # 9 internal stops -> 10 classes
    colors = viridisLite::viridis(10) # initial colors; will persist
  )

  # Precision & spacing
  min_gap <- 1e-4 # 0.0001 (4 decimals)
  round4 <- function(x) round(x, 4)

  # Sanitization (internal stops are strictly within (0,1), increasing, min_gap apart)
  sanitize_stops <- function(x, notify = FALSE) {
    x <- as.numeric(x)
    x <- pmax(min_gap, pmin(1 - min_gap, x)) # keep inside (0,1)
    x <- sort(x)
    # enforce min_gap between neighbors
    for (i in 2:length(x)) {
      if (x[i] <= x[i - 1] + min_gap) x[i] <- x[i - 1] + min_gap
    }
    x <- pmin(1 - min_gap, x)
    if (notify) {
      showNotification(
        "Stops adjusted to maintain minimum spacing.",
        type = "message",
        duration = 3
      )
    }
    x
  }

  # ------------------------------------------------------------
  # Raster + values + preview (unchanged behavior)
  # ------------------------------------------------------------
  r <- reactive({
    req(input$ras)
    terra::rast(input$ras$datapath)
  })
  vals <- reactive({
    req(r())
    v <- terra::spatSample(
      r(),
      size = 200000,
      method = "regular",
      as.df = TRUE
    )[, 1]
    v[is.finite(v)]
  })
  r_preview <- reactive({
    req(r())
    if (!isTRUE(input$use_preview)) {
      return(r())
    }
    terra::spatSample(
      r(),
      size = input$preview_cells,
      method = "regular",
      as.raster = TRUE
    )
  })

  # ------------------------------------------------------------
  # Slider ↔ stops sync
  # ------------------------------------------------------------
  # Initialize slider with rv$stops
  observeEvent(
    rv$stops,
    {
      updateNoUiSliderInput(session, "stops_norm", value = rv$stops)
    },
    ignoreInit = FALSE
  )

  # When user drags slider → update stops
  observeEvent(
    input$stops_norm,
    {
      s_new <- sanitize_stops(input$stops_norm, notify = FALSE)
      if (!identical(round4(s_new), round4(rv$stops))) rv$stops <- s_new
    },
    ignoreInit = FALSE
  )

  # ------------------------------------------------------------
  # Type-to-fine-tune inputs (one numericInput per stop)
  # ------------------------------------------------------------
  output$stop_inputs <- renderUI({
    s <- rv$stops
    tagList(lapply(seq_along(s), function(i) {
      numericInput(
        inputId = paste0("stop_", i),
        label = paste("Stop", i),
        value = round4(s[i]),
        min = 0 + min_gap,
        max = 1 - min_gap,
        step = 0.0001
      )
    }))
  })

  typed_stops <- reactive({
    # Gather typed values in current order
    sapply(seq_along(rv$stops), function(i) input[[paste0("stop_", i)]])
  })

  observeEvent(
    debounce(typed_stops, 200)(),
    {
      t <- typed_stops()
      if (length(t) && !any(is.na(t))) {
        s_new <- sanitize_stops(t, notify = FALSE)
        if (!identical(round4(s_new), round4(rv$stops))) rv$stops <- s_new
      }
    },
    ignoreInit = TRUE
  )

  # Keep numeric inputs in sync after slider changes
  observeEvent(
    rv$stops,
    {
      s <- rv$stops
      for (i in seq_along(s)) {
        if (!isTRUE(all.equal(input[[paste0("stop_", i)]], round4(s[i])))) {
          updateNumericInput(session, paste0("stop_", i), value = round4(s[i]))
        }
      }
    },
    ignoreInit = TRUE
  )

  # ------------------------------------------------------------
  # Colors UI (DO NOT reinitialize—always use rv$colors)
  # ------------------------------------------------------------
  # If reverse is toggled, just reverse current colors
  observeEvent(
    input$reverse,
    {
      rv$colors <- rev(rv$colors)
    },
    ignoreInit = TRUE
  )

  # Optional one-shot "reset to viridis" action (if you want a button; see UI tweak below)
  observeEvent(
    input$reset_viridis,
    {
      k <- length(rv$stops) + 1
      pal <- viridisLite::viridis(k)
      rv$colors <- pal
    },
    ignoreInit = TRUE
  )

  # Render color pickers (values come from rv$colors)
  output$colors_ui <- renderUI({
    k <- length(rv$stops) + 1
    # ensure colors length matches number of classes
    if (length(rv$colors) != k) {
      if (length(rv$colors) < k) {
        rv$colors <- c(rv$colors, rep("#66CCFF", k - length(rv$colors)))
      } else {
        rv$colors <- rv$colors[seq_len(k)]
      }
    }
    tagList(lapply(seq_len(k), function(i) {
      colourpicker::colourInput(
        inputId = paste0("col_", i),
        label = paste("Class", i),
        value = rv$colors[i],
        allowTransparent = TRUE,
        showColour = "both"
      )
    }))
  })

  # Capture color changes into rv$colors (persistent)
  observe({
    k <- length(rv$stops) + 1
    for (i in seq_len(k)) {
      col_i <- input[[paste0("col_", i)]]
      if (!is.null(col_i) && !identical(col_i, rv$colors[i])) {
        rv$colors[i] <- col_i
      }
    }
  })

  # ------------------------------------------------------------
  # Add / Remove stops (and preserve colors accordingly)
  # ------------------------------------------------------------
  observeEvent(input$add_stop, {
    s <- rv$stops
    edges <- c(0, s, 1)
    widths <- diff(edges)
    idx <- which.max(widths) # interval to split
    new_s <- edges[idx] + widths[idx] / 2 # midpoint of widest interval
    s_new <- sanitize_stops(c(s, new_s), notify = FALSE)

    # Compute where the new stop ended up; find the interval index after sorting
    edges_new <- c(0, s_new, 1)
    # Find insertion interval by nearest position to new_s in edges_new
    insert_after <- which.min(abs(edges_new - new_s)) - 1
    insert_after <- max(1, min(insert_after, length(rv$colors))) # safety

    if (!identical(round4(s_new), round4(s))) {
      rv$stops <- s_new
      # Insert a color in the split interval (duplicate existing color so your scheme persists)
      rv$colors <- append(
        rv$colors,
        rv$colors[insert_after],
        after = insert_after
      )
    } else {
      showNotification(
        "No room to add a stop (min spacing in effect). Try moving existing stops.",
        type = "warning",
        duration = 4
      )
    }
  })

  observeEvent(input$remove_stop, {
    s <- rv$stops
    if (length(s) <= 1) {
      showNotification(
        "Cannot remove: at least one stop is required.",
        type = "warning",
        duration = 3
      )
      return()
    }
    rv$stops <- s[-length(s)]
    rv$colors <- rv$colors[-length(rv$colors)]
  })

  # ------------------------------------------------------------
  # Breaks and palette (safe; skip if invalid)
  # ------------------------------------------------------------
  breaks_abs <- reactive({
    v <- vals()
    req(v)
    rng <- range(v, na.rm = TRUE)
    c(rng[1], rng[1] + rv$stops * diff(rng), rng[2])
  })

  pal_fn <- reactive({
    v <- vals()
    req(v)
    b <- breaks_abs()
    if (!isTRUE(all(diff(b) > 0))) {
      return(NULL)
    }
    k <- length(b) - 1
    if (length(rv$colors) != k) {
      return(NULL)
    }

    leaflet::colorBin(
      palette = rv$colors,
      domain = range(v, na.rm = TRUE),
      bins = b,
      right = FALSE,
      na.color = "#00000000"
    )
  })

  # ------------------------------------------------------------
  # Map rendering (robust)
  # ------------------------------------------------------------
  output$map <- renderLeaflet({
    leaflet() %>% addTiles()
  })

  observe({
    req(r_preview())
    pal <- pal_fn()
    if (is.null(pal)) {
      return()
    }

    tryCatch(
      {
        leafletProxy("map") %>%
          clearImages() %>%
          clearControls() %>%
          addRasterImage(
            x = r_preview(),
            colors = pal,
            opacity = input$opacity,
            project = !isTRUE(input$project_false),
            method = if (isTRUE(input$use_ngb)) "ngb" else "bilinear"
          ) %>%
          addLegend(
            pal = pal,
            values = vals(),
            title = "Classes",
            opacity = 0.9
          )
      },
      error = function(e) {
        showNotification(
          paste("Rendering skipped:", conditionMessage(e)),
          type = "error",
          duration = 6
        )
      }
    )
  })

  # ------------------------------------------------------------
  # Outputs & export (unchanged)
  # ------------------------------------------------------------
  output$stops_out <- renderPrint({
    rv$stops
  })
  output$colors_out <- renderPrint({
    rv$colors
  })
  output$export_json <- downloadHandler(
    filename = function() "normalized_stops_colors.json",
    content = function(file) {
      jsonlite::write_json(
        list(stops_norm = rv$stops, colors = rv$colors),
        path = file,
        pretty = TRUE,
        auto_unbox = TRUE
      )
    }
  )
}


shinyApp(ui, server)

targets::tar_load(p2_millcreek_rem_rast)
terra::writeRaster(p2_millcreek_rem_rast$rem, "millcreek.tif")
