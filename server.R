library(shiny)
library(leaflet)
library(sf)
library(shinyWidgets)
library(RColorBrewer)
library(classInt)
# library(leaflet.minicharts)
# library(manipulateWidget)

load("data.RData")

shinyServer(function(input, output) {
  
  # options(warn = -1)

  output$map_rpt <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$OpenStreetMap.HOT,
                       options = providerTileOptions(noWrap = TRUE)
      ) %>%
      setView(lng = -104.9903, lat = 39.7392, zoom = 9)
  })
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$OpenStreetMap.HOT,
                       options = providerTileOptions(noWrap = TRUE)
      ) %>%
      setView(lng = -104.9903, lat = 39.7392, zoom = 9)
  })
  # sync 2 maps view-------------------------------
  observeEvent(paste(input$map_rpt_zoom,input$map_rpt_center),{
    leafletProxy("map") %>%
      setView(lng = input$map_rpt_center[['lng']], lat = input$map_rpt_center[['lat']], zoom = input$map_rpt_zoom)
  })
  
  #react to community resources checkbox -------------------------------------
  
  observeEvent('L' %in% input$charities, {
    if('L' %in% input$charities) {
      leafletProxy("map_rpt") %>%
        addMarkers(
          data = subset(charities, MAJGRPB=='L'),
          popup = charities[charities$MAJGRPB=='L',]$NAME,
          # layerId = charities$id,
          icon = ~charity_house,
          # stroke = FALSE,
          group = "L"
        )
    }
    else{
      leafletProxy("map_rpt") %>%
        clearGroup("L")
    }
  })
  observeEvent('W' %in% input$charities, {
    if('W' %in% input$charities) {
      leafletProxy("map_rpt") %>%
        addMarkers(
          data = subset(charities, MAJGRPB=='W'),
          popup = charities[charities$MAJGRPB=='W',]$NAME,
          # layerId = charities$id,
          icon = ~charity_bene,
          # stroke = FALSE,
          group = "W"
        )
    }
    else{
      leafletProxy("map_rpt") %>%
        clearGroup("W")
    }
  })

  #legislative boundary map/report ------------------------------------
  observeEvent(paste(input$rpt_ind,input$geo), {
    plg <- reactive({rpt_lst[[paste(input$geo)]]})
    tbl <- reactive({as.data.frame(rpt_lst[[paste(input$geo)]])})
    dat <- reactive({
      tbl()[,paste(rpt_index[rpt_index$dropdown==input$rpt_ind,"column"])]
    })
    pp_text <- reactive({
      ~paste(input$geo,' ',tbl()$geoid10,':','<br>',
      tbl()$ttl_fam,' Total Families', '<br>',
      'tbd',' % EITC Qualified', '<br>',
      format(tbl()$eitc_amnt, big.mark=","), ' K Dollars EITC claimed', '<br>',
      'tbd', ' % Estimated Gap',
      sep="")
    })
    col_ramp <- reactive({
      colorBin(
        palette = brewer.pal(7, "Blues"),
        bins = classIntervals(dat(), 7, style = "fisher")$brks,
        na.color = "#808080"
      )
    })
    
    leafletProxy("map_rpt") %>%
      clearGroup("rpt") %>%
      clearControls()
    if(input$geo!='Geographies' && input$rpt_ind!='Choose an Indicator'){
      leafletProxy("map_rpt") %>%
        addPolygons(
          data = plg(),
          stroke = TRUE, color = "000000", weight = 0.5, opacity = 0.5,
          smoothFactor = 1, fillOpacity = 0.7,
          fillColor = ~col_ramp()(dat()),
          popup = pp_text(),
          highlightOptions = highlightOptions(color = "black", weight = 2,
                                              bringToFront = TRUE),
          layerId = plg()$geoid10,
          group = "rpt"
        ) %>%
        addLegend(
          title = input$rpt_ind,
          values = dat(),
          pal = col_ramp(),
          labFormat = labelFormat(digits = 1),
          position = "bottomright"
        )
    }
    
    clk <- reactive({input$map_rpt_shape_click})
    output$boundary <- renderText({
    tbl()[tbl()$geoid10==clk()$id,'name']
    })
    output$ttlfam <- renderText({
      paste("Total Family Households:",format(tbl()[tbl()$geoid10==clk()$id,'ttl_fam'], big.mark=","))
    })
    output$fam_per <- renderText({
      paste("Family with Children of Income < 50K: ",round(tbl()[tbl()$geoid10==clk()$id,'qual_share']*100,1), "%", sep = "")
    })
    output$ttlrt <- renderText({
      paste("Total IRS Filings:",format(tbl()[tbl()$geoid10==clk()$id,'total_return'], big.mark=","))
    })
    output$eitc_per <- renderText({
      paste("EITC Claims: ",round(tbl()[tbl()$geoid10==clk()$id,'eitc_share']*100,1), "%", sep = "")
    })
    output$eitcamnt <- renderText({
      paste("EITC Amount: ",format(tbl()[tbl()$geoid10==clk()$id,'eitc_amnt'], big.mark=","), " K $", sep = "")
    })
    output$pvt <- renderText({
      paste("Population in Poverty: ",format(tbl()[tbl()$geoid10==clk()$id,'poverty_nu'], big.mark=","))
    })
    output$pvt_per <- renderText({
      paste("Percentage: ",round(tbl()[tbl()$geoid10==clk()$id,'poverty_nu']/tbl()[tbl()$geoid10==clk()$id,'poverty_de']*100,1), "%", sep="")
    })
    output$age <- renderPlot({
      pie(
        unlist(tbl()[tbl()$geoid10==clk()$id,c('ageunder18','age18to24','age25to34','age35to44','age45to54','age55to64','age65to74','ageover75')]),
        labels = c('ageunder18','age18to24','age25to34','age35to44','age45to54','age55to64','age65to74','ageover75'),
        radius = 1
      )
    })
    output$race <- renderPlot({
      barplot(
        height=unlist(tbl()[tbl()$geoid10==clk()$id,c('nonhiswhite','hislat','black','native','asian_pacific')]), space = 2
      )
    })
    output$language <- renderPlot({
      pie(
        unlist(tbl()[tbl()$geoid10==clk()$id,c('english_spk','spanish_spk','other_languages')]),
        labels = c('English','Spanish','Others'),
        radius = 1
      )
    })


    output$report <- downloadHandler(
      filename = 'report.html',
      content = function(file) {
        tmpdir <- tempdir()
        tempReport <- file.path(tmpdir, "report.Rmd")
        file.copy("report.Rmd", tempReport, overwrite = TRUE)
        tempDep <- file.path(tmpdir,"infograph")
        dir.create(tempDep,recursive = TRUE)
        file.copy("infograph",tmpdir, recursive = TRUE, overwrite = TRUE)

        # Set up parameters to pass to Rmd document
        params <- list(
          unit = input$geo,
          region = tbl()[tbl()$geoid10==clk()$id,'name'],
          geom = clk()$id,
          pop = tbl()[tbl()$geoid10==clk()$id,'total_population'],
          pvrty = tbl()[tbl()$geoid10==clk()$id,'poverty_nu'],
          income_50k = tbl()[tbl()$geoid10==clk()$id,'qual_share']*tbl()[tbl()$geoid10==clk()$id,'ttl_fam'],
          psv_hs = tbl()[tbl()$geoid10==clk()$id,'aff_units'], #placeholder
          nonhiswhite = tbl()[tbl()$geoid10==clk()$id,'nonhiswhite'],
          hislat = tbl()[tbl()$geoid10==clk()$id,'hislat'],
          black = tbl()[tbl()$geoid10==clk()$id,'black'],
          native = tbl()[tbl()$geoid10==clk()$id,'native'],
          asin = tbl()[tbl()$geoid10==clk()$id,'asian_pacific'],
          under18 = tbl()[tbl()$geoid10==clk()$id,'ageunder18'],
          age18to24 = tbl()[tbl()$geoid10==clk()$id,'age18to24'],
          age25to34 = tbl()[tbl()$geoid10==clk()$id,'age25to34'],
          age35to44 = tbl()[tbl()$geoid10==clk()$id,'age35to44'],
          age45to54 = tbl()[tbl()$geoid10==clk()$id,'age45to54'],
          age55to64 = tbl()[tbl()$geoid10==clk()$id,'age55to64'],
          age65to74 = tbl()[tbl()$geoid10==clk()$id,'age65to74'],
          over75 = tbl()[tbl()$geoid10==clk()$id,'ageover75'],
          eng_spk = tbl()[tbl()$geoid10==clk()$id,'english_spk'],
          spn_spk = tbl()[tbl()$geoid10==clk()$id,'spanish_spk'],
          other_spk = tbl()[tbl()$geoid10==clk()$id,'other_languages'],
          taxsite = 5000 #placeholder
        )

        rmarkdown::render(tempReport, output_file = file,
                          params = params,
                          envir = new.env(parent = globalenv())
        )
      }
    )
  })


  # react to tract level demograph hide
  observeEvent(input$hide, {
    if(input$hide){
      leafletProxy("map") %>%
        hideGroup("demo")
    }
    else{
      leafletProxy("map") %>%
        showGroup("demo")
    }
  })
  
  #react to puma checkbox
  observeEvent(input$puma, {
    if(input$puma){
      leafletProxy("map") %>%
        addPolygons(
          data = puma_units,
          stroke = FALSE, color = "000000", weight = 0.5, opacity = 0.5,
          smoothFactor = 1, fillOpacity = 0.7,
          fillColor = ~pums_ramp(puma_units$EstEITC_QTU),
          # label = ~paste(tract_demo$geoid10, ":", tract_demo[,as.character(index$column[1])]),
          # options = pathOptions(pane="top"),
          group = "puma"
        )
    }
    else{
      leafletProxy("map") %>%
        clearGroup(group = "puma")
    }
  })
})

