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

  # --- NEW: helper to enforce ordering and minimum spacing ---
  min_gap <- 1e-4 # 0.0001 => 4 decimal places
  sanitize_stops <- function(x, show_note = TRUE) {
    x <- pmax(0, pmin(1, as.numeric(x)))
    x <- sort(x)
    changed <- FALSE
    if (any(diff(x) < min_gap)) {
      # Nudge overlapping stops forward to enforce minimum spacing
      for (i in seq_along(x)[-1]) {
        if (x[i] <= x[i - 1] + min_gap) {
          x[i] <- min(1 - min_gap * (length(x) - i), x[i - 1] + min_gap)
          changed <- TRUE
        }
      }
      # If end overflowed, nudge earlier ones backward
      for (i in rev(seq_along(x)[-length(x)])) {
        if (x[i + 1] <= x[i] + min_gap) {
          x[i] <- max(0 + min_gap * (i - 1), x[i + 1] - min_gap)
          changed <- TRUE
        }
      }
      if (isTRUE(changed) && isTRUE(show_note)) {
        showNotification(
          paste(
            "Some stops were overlapping or too close.",
            "They were nudged to enforce a minimum spacing of",
            min_gap
          ),
          type = "message",
          duration = 4
        )
      }
    }
    x
  }

  colors_vec <- reactive({
    n_classes <- length(stops_norm()) + 1
    cols <- sapply(seq_len(n_classes), function(i) input[[paste0("col_", i)]])
    # Fallback if any color is missing on first render
    if (any(is.null(cols)) || length(cols) != n_classes) {
      base <- viridisLite::viridis(n_classes)
      if (isTRUE(input$reverse)) {
        base <- rev(base)
      }
      return(base)
    }
    cols
  })

  # --- numeric inputs to type exact values ---
  output$stop_inputs <- renderUI({
    req(input$stops_norm)
    stops <- sort(as.numeric(input$stops_norm))
    tagList(lapply(seq_along(stops), function(i) {
      numericInput(
        inputId = paste0("stop_", i),
        label = paste("Stop", i),
        value = round(stops[i], 4),
        min = 0,
        max = 1,
        step = 0.0001
      )
    }))
  })

  # Collect typed values into a vector (reactive)
  typed_stops <- reactive({
    req(input$stops_norm)
    n <- length(input$stops_norm)
    sapply(seq_len(n), function(i) input[[paste0("stop_", i)]])
  })

  # Update slider from typed inputs (debounced to avoid jitter)
  debounced_typed <- debounce(typed_stops, millis = 200)
  observeEvent(
    debounced_typed(),
    {
      s <- sanitize_stops(debounced_typed(), show_note = TRUE)
      # Only update if values actually changed to avoid loops
      if (
        !identical(round(s, 4), round(sort(as.numeric(input$stops_norm)), 4))
      ) {
        updateNoUiSliderInput(session, "stops_norm", value = s)
      }
    },
    ignoreInit = TRUE
  )

  # Update numeric inputs when slider changes (keep 4-dec precision)
  observeEvent(
    input$stops_norm,
    {
      s <- sort(as.numeric(input$stops_norm))
      s <- sanitize_stops(s, show_note = FALSE)
      for (i in seq_along(s)) {
        # Only update if the displayed value differs; avoids oscillation
        if (!isTRUE(all.equal(input[[paste0("stop_", i)]], round(s[i], 4)))) {
          updateNumericInput(
            session,
            paste0("stop_", i),
            value = round(s[i], 4)
          )
        }
      }
    },
    ignoreInit = FALSE
  )

  # --- colors UI: unchanged in spirit; keeps per-class hex, reversed if needed ---
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

  # --- normalized stops (sanitized) ---
  stops_norm <- reactive({
    sanitize_stops(input$stops_norm, show_note = FALSE)
  })

  # Map normalized → absolute
  breaks_abs <- reactive({
    v <- vals()
    req(v)
    rng <- range(v, na.rm = TRUE)
    c(rng[1], rng[1] + stops_norm() * diff(rng), rng[2])
  })

  # Colors per class
  colors_vec <- reactive({
    k <- length(stops_norm()) + 1
    sapply(seq_len(k), function(i) input[[paste0("col_", i)]])
  })

  # Palette function with guard: strictly increasing breaks

  pal_fn <- reactive({
    # Pre-check: we must have values, colors, and valid breaks
    v <- vals()
    req(v)
    b <- breaks_abs()
    # Strictly increasing breaks? (no zero-width bins)
    if (!isTRUE(all(diff(b) > 0))) {
      showNotification(
        "Breaks are not strictly increasing. Adjust stops (or they were auto-nudged).",
        type = "warning",
        duration = 5
      )
      return(NULL) # signal to renderer to skip for now
    }

    # Colors vector must match number of bins
    k <- length(b) - 1
    cols <- colors_vec()
    if (length(cols) != k || any(is.na(cols))) {
      showNotification(
        sprintf(
          "Color count (%d) must equal number of classes (%d).",
          length(cols),
          k
        ),
        type = "warning",
        duration = 5
      )
      return(NULL)
    }

    # Build palette safely
    leaflet::colorBin(
      palette = cols,
      domain = range(v, na.rm = TRUE),
      bins = b,
      right = FALSE,
      na.color = "#00000000"
    )
  })

  # Base map
  output$map <- renderLeaflet({
    leaflet() %>% addTiles()
  })

  # Redraw map on change

  observe({
    req(r_preview())
    pal <- pal_fn()
    if (is.null(pal)) {
      return()
    } # nothing to draw yet

    # Wrap rendering in tryCatch for extra safety
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

  # Histogram with break lines (unchanged)
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

  # Add/remove stops (respect min_gap)
  observeEvent(input$add_stop, {
    s <- c(0, stops_norm(), 1)
    widths <- diff(s)
    idx <- which.max(widths)
    new_stop <- s[idx] + widths[idx] / 2
    s_new <- sanitize_stops(c(stops_norm(), new_stop), show_note = TRUE)
    updateNoUiSliderInput(session, "stops_norm", value = s_new)
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

  # Export normalized stops + colors
  output$stops_out <- renderPrint({
    stops_norm()
  })
  output$colors_out <- renderPrint({
    colors_vec()
  })
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

shinyApp(ui, server)

targets::tar_load(p2_millcreek_rem_rast)
terra::writeRaster(p2_millcreek_rem_rast$rem, "millcreek.tif")
